#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Build notlfs, a tiny musl + BusyBox Linux: out/bzImage + out/initramfs.cpio.gz
set -eu
# host deps are checked below; see README "Build host"
for t in curl tar bzip2 xz gzip cpio make gcc flex bison bc perl python3 tic cmake meson ninja pkg-config go gperf; do
  command -v $t >/dev/null 2>&1 || MISSING="${MISSING:-} $t"
done
[ -f /usr/share/hwdata/pnp.ids ] || MISSING="${MISSING:-} hwdata"
[ -f /usr/include/libelf.h ] || MISSING="${MISSING:-} libelf-dev"
[ -f /usr/include/openssl/ssl.h ] || MISSING="${MISSING:-} libssl-dev"
if [ -n "${MISSING:-}" ]; then echo "build.sh: missing host tools:$MISSING (see README)" >&2; exit 1; fi

KERNEL=6.6.160
KERNEL_SHA256=b8334e0dd70d67f05f38d64253c9603501134655d1941616266ed1aedc292828
BUSYBOX=1.36.1
FASTFETCH=2.50.0
JOBS=$(nproc)
TOP=$(pwd)
mkdir -p build out
cd build

# 1. musl cross toolchain (prebuilt from musl.cc)
[ -d x86_64-linux-musl-cross ] || curl -L https://musl.cc/x86_64-linux-musl-cross.tgz | tar xz
CROSS=$PWD/x86_64-linux-musl-cross/bin/x86_64-linux-musl-

# 2. static BusyBox against musl
[ -d busybox-$BUSYBOX ] || curl -L https://busybox.net/downloads/busybox-$BUSYBOX.tar.bz2 | tar xj
cd busybox-$BUSYBOX
make defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/; s/CONFIG_TC=y/# CONFIG_TC is not set/' .config
make -j$JOBS CROSS_COMPILE=$CROSS
cd ..

# 2b. static fastfetch against musl
[ -d fastfetch-$FASTFETCH ] || curl -L https://github.com/fastfetch-cli/fastfetch/archive/refs/tags/$FASTFETCH.tar.gz | tar xz
PKG_CONFIG_LIBDIR= cmake -S fastfetch-$FASTFETCH -B fastfetch-build \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_C_COMPILER=${CROSS}gcc \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS=-static \
  -DBUILD_TESTS=OFF -DBUILD_FLASHFETCH=OFF
cmake --build fastfetch-build -j$JOBS --target fastfetch

# 2c. TUI stack: ncurses, libevent, tmux, LibreSSL, bdwgc, w3m (all static, musl)
# musl static binaries run on the x86_64 build host, so plain ./configure works.
SYS=$PWD/sysroot
export CC="${CROSS}gcc" AR="${CROSS}ar" RANLIB="${CROSS}ranlib"
export CFLAGS="-Os -I$SYS/include -I$SYS/include/ncursesw" LDFLAGS="-static -L$SYS/lib" PKG_CONFIG_PATH=$SYS/lib/pkgconfig PKG_CONFIG_LIBDIR=
get() { [ -d "$2" ] || { curl -L --retry 3 "$1" | tar xz; }; }
getJ() { [ -d "$2" ] || { curl -L --retry 3 "$1" | tar xJ; }; }
printf "[binaries]\ncmake = 'false'\n" > nocmake.ini

cfg() { ./configure --prefix=$SYS --disable-shared --enable-static "$@"; make -j$JOBS; make install; }

get https://invisible-mirror.net/archives/ncurses/ncurses-6.5.tar.gz ncurses-6.5
[ -f $SYS/lib/libncursesw.a ] || (cd ncurses-6.5 && cfg --enable-widec --without-cxx --without-cxx-binding --without-ada \
  --without-tests --without-progs --without-manpages --disable-db-install --with-default-terminfo-dir=/usr/share/terminfo)

get https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz libevent-2.1.12-stable
[ -f $SYS/lib/libevent.a ] || (cd libevent-2.1.12-stable && cfg --disable-openssl --disable-samples --disable-libevent-regress)

get https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz tmux-3.5a
[ -f tmux-3.5a/tmux ] || (cd tmux-3.5a && LIBNCURSES_CFLAGS=-I$SYS/include/ncursesw LIBNCURSES_LIBS=-lncursesw \
  LIBEVENT_CFLAGS=-I$SYS/include LIBEVENT_LIBS=-levent ./configure --enable-static --disable-utf8proc && make -j$JOBS)

get https://cdn.openbsd.org/pub/OpenBSD/LibreSSL/libressl-3.9.2.tar.gz libressl-3.9.2
[ -f $SYS/lib/libssl.a ] || (cd libressl-3.9.2 && cfg --disable-tests)

get https://github.com/ivmai/bdwgc/releases/download/v8.2.8/gc-8.2.8.tar.gz gc-8.2.8
[ -f $SYS/lib/libgc.a ] || (cd gc-8.2.8 && cfg --disable-threads --disable-docs)

get https://github.com/tats/w3m/archive/refs/tags/v0.5.3+git20230121.tar.gz w3m-0.5.3-git20230121
[ -f w3m-0.5.3-git20230121/w3m ] || (cd w3m-0.5.3-git20230121 && LIBS="-lssl -lcrypto -Wl,--allow-multiple-definition" ./configure --prefix=/usr --sysconfdir=/etc --with-gc=$SYS --with-ssl=$SYS \
  --with-termlib=ncursesw --disable-image --disable-mouse --without-migemo --disable-w3mmailer --disable-nls && make -j$JOBS)
[ -f cacert.pem ] || curl -LO https://curl.se/ca/cacert.pem
unset CC AR RANLIB CFLAGS LDFLAGS PKG_CONFIG_PATH PKG_CONFIG_LIBDIR

# 2d. vis editor with static Lua 5.4 + LPeg (syntax highlighting)
export CC="${CROSS}gcc" AR="${CROSS}ar" RANLIB="${CROSS}ranlib"
get https://www.lua.org/ftp/lua-5.4.7.tar.gz lua-5.4.7
[ -f $SYS/lib/liblua.a ] || (cd lua-5.4.7 && make posix CC="$CC" AR="$AR rcu" RANLIB="$RANLIB" && make install INSTALL_TOP=$SYS)
get https://www.inf.puc-rio.br/~roberto/lpeg/lpeg-1.1.0.tar.gz lpeg-1.1.0
[ -f $SYS/lib/liblpeg.a ] || (cd lpeg-1.1.0 && $CC -Os -I$SYS/include -c lp*.c && $AR rcs $SYS/lib/liblpeg.a lp*.o)
get https://www.leonerd.org.uk/code/libtermkey/libtermkey-0.22.tar.gz libtermkey-0.22
[ -f $SYS/lib/libtermkey.a ] || (cd libtermkey-0.22 && $CC -Os -I$SYS/include -I$SYS/include/ncursesw -c termkey.c driver-csi.c driver-ti.c \
  && $AR rcs $SYS/lib/libtermkey.a termkey.o driver-csi.o driver-ti.o && cp termkey.h $SYS/include/)
get https://github.com/martanne/vis/archive/refs/tags/v0.9.tar.gz vis-0.9
[ -f vis-0.9/vis ] || (cd vis-0.9 && CFLAGS="-Os -I$SYS/include -I$SYS/include/ncursesw" LDFLAGS="-static -L$SYS/lib" PKG_CONFIG_LIBDIR= \
  ./configure --prefix=/usr --enable-curses --enable-lua --enable-lpeg-static --disable-tre --disable-selinux --disable-acl \
  && make -j$JOBS)
unset CC AR RANLIB

# 2e. dropbear (ssh), zlib, curl, git
export CC="${CROSS}gcc" AR="${CROSS}ar" RANLIB="${CROSS}ranlib"
export CFLAGS="-Os -I$SYS/include" LDFLAGS="-static -L$SYS/lib" PKG_CONFIG_PATH=$SYS/lib/pkgconfig PKG_CONFIG_LIBDIR=$SYS/lib/pkgconfig
getj() { [ -d "$2" ] || { curl -L "$1" | tar xj; }; }

get https://zlib.net/fossils/zlib-1.3.1.tar.gz zlib-1.3.1
[ -f $SYS/lib/libz.a ] || (cd zlib-1.3.1 && ./configure --prefix=$SYS --static && make -j$JOBS && make install)

getj https://matt.ucc.asn.au/dropbear/releases/dropbear-2026.94.tar.bz2 dropbear-2026.94
[ -f dropbear-2026.94/dropbearmulti ] || (cd dropbear-2026.94 && ./configure --enable-static --disable-wtmp --disable-lastlog --disable-pam \
  && make -j$JOBS PROGRAMS="dropbear dbclient dropbearkey scp" MULTI=1 STATIC=1)

get https://curl.se/download/curl-8.11.1.tar.gz curl-8.11.1
[ -f $SYS/lib/libcurl.a ] || (cd curl-8.11.1 && cfg --with-openssl=$SYS --with-zlib=$SYS --without-libpsl --without-brotli --without-zstd \
  --without-nghttp2 --without-libidn2 --disable-ldap --disable-manual --with-ca-bundle=/etc/ssl/cert.pem)

get https://www.kernel.org/pub/software/scm/git/git-2.47.1.tar.gz git-2.47.1
GITOPTS="prefix=/usr NO_GETTEXT=1 NO_TCLTK=1 NO_PERL=1 NO_PYTHON=1 NO_EXPAT=1 NO_REGEX=NeedsStartEnd NO_INSTALL_HARDLINKS=1 CURL_CONFIG=/bin/false"
[ -d git-install ] || (cd git-2.47.1 && make -j$JOBS $GITOPTS CC="$CC" AR="$AR" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
  CURL_LDFLAGS="-lcurl -lssl -lcrypto -lz" all install DESTDIR=$PWD/../git-install)
unset CC AR RANLIB CFLAGS LDFLAGS PKG_CONFIG_PATH PKG_CONFIG_LIBDIR

# 2g. glib + irssi (meson), aerc (Go, CGO off)
export CC="${CROSS}gcc" AR="${CROSS}ar"
export CFLAGS="-Os -I$SYS/include -I$SYS/include/ncursesw" LDFLAGS="-static -L$SYS/lib" PKG_CONFIG_PATH=$SYS/lib/pkgconfig PKG_CONFIG_LIBDIR=$SYS/lib/pkgconfig
getJ https://download.gnome.org/sources/glib/2.82/glib-2.82.4.tar.xz glib-2.82.4
[ -f $SYS/lib/libglib-2.0.a ] || (cd glib-2.82.4 && meson setup _b --native-file ../nocmake.ini --prefix=$SYS --libdir=lib --default-library=static \
  --prefer-static --buildtype=minsize -Dtests=false -Dintrospection=disabled -Dnls=disabled -Dlibmount=disabled -Dselinux=disabled -Dxattr=false \
  -Dman-pages=disabled -Ddocumentation=false -Dglib_debug=disabled -Dsysprof=disabled && ninja -C _b install)
getJ https://github.com/irssi/irssi/releases/download/1.4.5/irssi-1.4.5.tar.xz irssi-1.4.5
[ -f irssi-1.4.5/_b/src/fe-text/irssi ] || (cd irssi-1.4.5 && \
  sed -i "s|find_library(setupterm_provider, required : false)|find_library(setupterm_provider, required : false, dirs : '$SYS/lib')|" meson.build && \
  meson setup _b --native-file ../nocmake.ini --prefix=/usr --sysconfdir=/etc --default-library=static --prefer-static --buildtype=minsize \
  -Dwith-perl=no -Dwith-proxy=no -Dwith-otr=no -Denable-true-color=yes -Ddisable-utf8proc=yes && ninja -C _b)
unset CC AR CFLAGS LDFLAGS PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
get https://git.sr.ht/~rjarry/aerc/archive/0.20.1.tar.gz aerc-0.20.1
[ -f aerc-0.20.1/aerc ] || (cd aerc-0.20.1 && CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o aerc .)

# 2f. mpv: ffmpeg + libass stack + libplacebo + libdrm, all static meson/autotools
export CC="${CROSS}gcc" AR="${CROSS}ar" RANLIB="${CROSS}ranlib" CXX="${CROSS}g++"
export CFLAGS="-Os -I$SYS/include" CXXFLAGS="-Os -I$SYS/include" LDFLAGS="-static -L$SYS/lib" PKG_CONFIG_PATH=$SYS/lib/pkgconfig PKG_CONFIG_LIBDIR=$SYS/lib/pkgconfig
mb() { [ -f "$1/_b/.done" ] || (cd "$1" && shift && meson setup _b --native-file "$OLDPWD/nocmake.ini" --prefix=$SYS --libdir=lib \
  --default-library=static --prefer-static --buildtype=minsize --wrap-mode=nofallback "$@" && ninja -C _b install && touch _b/.done); }

get https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n7.1.tar.gz FFmpeg-n7.1
[ -f FFmpeg-n7.1/.slim ] || (cd FFmpeg-n7.1 && { make distclean >/dev/null 2>&1 || true; } && ./configure --prefix=$SYS --cc="$CC" --ar="$AR" \
  --ranlib="$RANLIB" --pkg-config=pkg-config --pkg-config-flags=--static --enable-static --disable-shared --disable-programs --disable-doc \
  --disable-autodetect --disable-x86asm --disable-network --enable-zlib --disable-everything --enable-filters --enable-bsfs \
  --enable-decoder=h264,hevc,vp8,vp9,mpeg4,mpeg1video,mpeg2video,mjpeg,png,theora,rawvideo,wrapped_avframe,aac,mp3,mp3float,opus,vorbis,flac,ac3,eac3,pcm_s16le,pcm_s24le,pcm_f32le,ass,ssa,subrip,webvtt,movtext \
  --enable-demuxer=mov,matroska,mp3,ogg,flac,wav,avi,mpegts,mpegps,aac,ass,srt,webvtt,image2,concat \
  --enable-parser=h264,hevc,vp8,vp9,mpeg4video,mpegvideo,aac,mpegaudio,opus,vorbis,flac,ac3,png,mjpeg \
  --enable-encoder=png,mjpeg --enable-protocol=file,pipe --enable-indev=lavfi \
  --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" && make -j$JOBS && make install && touch .slim)

getJ https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz freetype-2.13.3
mb freetype-2.13.3 -Dbrotli=disabled -Dbzip2=disabled -Dharfbuzz=disabled -Dpng=disabled -Dzlib=disabled
# ALSA (static, config in /usr/share/alsa), expat + fontconfig (config in /etc/fonts)
getj https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.13.tar.bz2 alsa-lib-1.2.13
[ -f $SYS/lib/libasound.a ] || (cd alsa-lib-1.2.13 && ./configure --prefix=/usr --enable-static --disable-shared --disable-python \
  --without-debug --disable-topology --disable-ucm && make -j$JOBS && rm -rf ../stage-alsa && make install DESTDIR=$PWD/../stage-alsa \
  && cp -r ../stage-alsa/usr/include/. $SYS/include/ && cp ../stage-alsa/usr/lib/libasound.a $SYS/lib/ \
  && sed "s|^prefix=.*|prefix=$SYS|" ../stage-alsa/usr/lib/pkgconfig/alsa.pc > $SYS/lib/pkgconfig/alsa.pc)
getj https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.13.tar.bz2 alsa-utils-1.2.13
[ -f alsa-utils-1.2.13/amixer/amixer ] || (cd alsa-utils-1.2.13 && ./configure --disable-alsamixer --disable-alsaconf --disable-alsaloop \
  --disable-alsatest --disable-bat --disable-nls --disable-xmlto --disable-rst2man --with-alsa-inc-prefix=$SYS/include \
  --with-alsa-prefix=$SYS/lib && make -C amixer LDFLAGS="-all-static -L$SYS/lib")
getJ https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz expat-2.6.4
[ -f $SYS/lib/libexpat.a ] || (cd expat-2.6.4 && cfg --without-docbook --without-examples --without-tests --without-xmlwf)
getJ https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.15.0.tar.xz fontconfig-2.15.0
[ -f $SYS/lib/libfontconfig.a ] || (cd fontconfig-2.15.0 && meson setup _b --native-file "$OLDPWD/nocmake.ini" --prefix=$SYS --libdir=lib \
  --default-library=static --prefer-static --buildtype=minsize -Ddoc=disabled -Dtests=disabled -Dtools=disabled -Dnls=disabled \
  -Dsysconfdir=/etc -Dcache-dir=/var/cache/fontconfig -Ddefault-fonts-dirs=/usr/share/fonts -Dtemplate-dir=/usr/share/fontconfig/conf.avail \
  && rm -rf ../stage-fc && DESTDIR=$PWD/../stage-fc ninja -C _b install && cp -r ../stage-fc$SYS/. $SYS/)

getJ https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz fribidi-1.0.16
mb fribidi-1.0.16 -Ddocs=false -Dbin=false -Dtests=false
getJ https://github.com/harfbuzz/harfbuzz/releases/download/10.1.0/harfbuzz-10.1.0.tar.xz harfbuzz-10.1.0
mb harfbuzz-10.1.0 -Dglib=disabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dfreetype=enabled
getJ https://github.com/libass/libass/releases/download/0.17.3/libass-0.17.3.tar.xz libass-0.17.3
[ -f libass-0.17.3/.fc ] || (cd libass-0.17.3 && { make distclean >/dev/null 2>&1 || true; } && cfg --enable-fontconfig --disable-asm --disable-libunibreak && touch .fc)
getJ https://dri.freedesktop.org/libdrm/libdrm-2.4.124.tar.xz libdrm-2.4.124
mb libdrm-2.4.124 -Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled -Dvmwgfx=disabled -Dtests=false -Dman-pages=disabled -Dvalgrind=disabled -Dcairo-tests=disabled
get https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.4.303.tar.gz Vulkan-Headers-1.4.303
[ -d $SYS/include/vulkan ] || cp -r Vulkan-Headers-1.4.303/include/vulkan Vulkan-Headers-1.4.303/include/vk_video $SYS/include/
get https://code.videolan.org/videolan/libplacebo/-/archive/v7.349.0/libplacebo-v7.349.0.tar.gz libplacebo-v7.349.0
mb libplacebo-v7.349.0 -Dvulkan=disabled -Dopengl=disabled -Dd3d11=disabled -Dglslang=disabled -Dshaderc=disabled -Dlcms=disabled -Ddemos=false -Dtests=false -Dxxhash=disabled -Dlibdovi=disabled -Dunwind=disabled
grep -q stdc++ $SYS/lib/pkgconfig/libplacebo.pc || sed -i "s/^Libs: .*/& -lstdc++/" $SYS/lib/pkgconfig/libplacebo.pc
get https://gitlab.freedesktop.org/emersion/libdisplay-info/-/archive/0.2.0/libdisplay-info-0.2.0.tar.gz libdisplay-info-0.2.0
mb libdisplay-info-0.2.0
get https://github.com/mpv-player/mpv/archive/refs/tags/v0.41.0.tar.gz mpv-0.41.0
mb mpv-0.41.0 -Dsysconfdir=/etc -Dlibmpv=false -Dcplayer=true -Dlua=disabled -Djavascript=disabled -Dlibarchive=disabled -Dlibbluray=disabled -Ddvdnav=disabled \
  -Dcdda=disabled -Dalsa=enabled -Dpulse=disabled -Dpipewire=disabled -Djack=disabled -Dsdl2-audio=disabled -Dopenal=disabled \
  -Dx11=disabled -Dwayland=disabled -Dgl=disabled -Dvulkan=disabled -Degl=disabled -Ddrm=enabled -Dgbm=disabled -Dcaca=disabled \
  -Dsixel=disabled -Diconv=disabled -Duchardet=disabled -Drubberband=disabled -Dzimg=disabled -Dlcms2=disabled -Dmanpage-build=disabled -Dhtml-build=disabled
unset CC AR RANLIB CXX CFLAGS CXXFLAGS LDFLAGS PKG_CONFIG_PATH PKG_CONFIG_LIBDIR

# 3. GNU Linux-libre kernel (GPL-2.0, no blobs)
if [ ! -d linux-$KERNEL ]; then
  curl -LO https://linux-libre.fsfla.org/pub/linux-libre/releases/$KERNEL-gnu/linux-libre-$KERNEL-gnu.tar.xz
  echo "$KERNEL_SHA256  linux-libre-$KERNEL-gnu.tar.xz" | sha256sum -c
  tar xJf linux-libre-$KERNEL-gnu.tar.xz
fi
cd linux-$KERNEL
make defconfig
./scripts/config --set-str LOCALVERSION "-catgirls" --set-str DEFAULT_HOSTNAME notlfs --set-str EXTRA_FIRMWARE "" --disable DRM_I915 --disable WERROR \
  --enable SND_HDA_GENERIC --enable DRM_FBDEV_EMULATION --enable FB --enable FRAMEBUFFER_CONSOLE
make olddefconfig
make -j$JOBS bzImage
cp arch/x86/boot/bzImage "$TOP/out/"
cd ..

# 4. rootfs
rm -rf rootfs && mkdir -p rootfs/bin rootfs/sbin rootfs/etc rootfs/dev rootfs/proc rootfs/sys rootfs/tmp
cp busybox-$BUSYBOX/busybox rootfs/bin/
mkdir -p rootfs/usr/bin rootfs/root rootfs/etc/ssl rootfs/etc/w3m rootfs/usr/share/udhcpc rootfs/usr/share/terminfo
cp fastfetch-build/fastfetch tmux-3.5a/tmux w3m-0.5.3-git20230121/w3m vis-0.9/vis rootfs/usr/bin/
mkdir -p rootfs/usr/share/vis && cp -r vis-0.9/lua/. rootfs/usr/share/vis/
tic -x -o rootfs/usr/share/terminfo -e linux,vt102,xterm,xterm-256color,screen,tmux,tmux-256color ncurses-6.5/misc/terminfo.src
cp cacert.pem rootfs/etc/ssl/cert.pem
cp busybox-$BUSYBOX/examples/udhcp/simple.script rootfs/usr/share/udhcpc/default.script
cp "$TOP/files/tmux.conf" "$TOP/files/profile" rootfs/etc/
cp "$TOP/files/w3m-config" rootfs/etc/w3m/config
cp "$TOP/files/tui" rootfs/bin/tui
# audio (ALSA config), fonts (fontconfig + DejaVu Sans Mono), mpv defaults
mkdir -p rootfs/usr/share/alsa rootfs/usr/share/fonts rootfs/etc/mpv rootfs/var/cache/fontconfig
cp -r stage-alsa/usr/share/alsa/. rootfs/usr/share/alsa/
cp -r stage-fc/etc/fonts rootfs/etc/ && cp -r stage-fc/usr/share/fontconfig rootfs/usr/share/
[ -d dejavu-fonts-ttf-2.37 ] || curl -L --retry 3 https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2 | tar xj
cp dejavu-fonts-ttf-2.37/ttf/DejaVuSansMono.ttf dejavu-fonts-ttf-2.37/LICENSE rootfs/usr/share/fonts/
cp "$TOP/files/mpv.conf" rootfs/etc/mpv/mpv.conf
chmod +x rootfs/bin/tui rootfs/usr/share/udhcpc/default.script
echo 'root:x:0:0:root:/root:/bin/sh' > rootfs/etc/passwd
echo 'root:*:0:0:99999:7:::' > rootfs/etc/shadow
printf 'root:x:0:\ntty:x:5:\naudio:x:29:root\nvideo:x:44:root\n' > rootfs/etc/group
# extras: ssh, git, irc, mail, video
cp dropbear-2026.94/dropbearmulti rootfs/usr/bin/
for p in dropbear dbclient dropbearkey scp ssh; do ln -sf dropbearmulti rootfs/usr/bin/$p; done
ln -sf dbclient rootfs/usr/bin/ssh
cp -a git-install/usr/. rootfs/usr/
rm -f rootfs/usr/bin/scalar rootfs/usr/libexec/git-core/scalar
for f in rootfs/usr/libexec/git-core/*; do  # dedupe git's builtin copies into symlinks
  if cmp -s "$f" rootfs/usr/bin/git; then ln -sf /usr/bin/git "$f"
  elif cmp -s "$f" rootfs/usr/libexec/git-core/git-remote-http && [ "${f##*/}" != git-remote-http ]; then ln -sf git-remote-http "$f"; fi
done
cp irssi-1.4.5/_b/src/fe-text/irssi aerc-0.20.1/aerc mpv-0.41.0/_b/mpv alsa-utils-1.2.13/amixer/amixer rootfs/usr/bin/
mkdir -p rootfs/usr/share/aerc && cp -r aerc-0.20.1/config/*.conf aerc-0.20.1/stylesets aerc-0.20.1/templates rootfs/usr/share/aerc/
mkdir -p rootfs/etc/dropbear rootfs/root/.ssh && chmod 700 rootfs/root/.ssh
find rootfs/usr -type f -perm -u+x -exec ${CROSS}strip -s {} + 2>/dev/null || true
for app in $(rootfs/bin/busybox --list-full); do ln -sf /bin/busybox "rootfs/$app" 2>/dev/null || true; done
ln -sf bin/busybox rootfs/init
cat > rootfs/etc/inittab <<'TAB'
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sys /sys
::sysinit:/bin/mount -t devtmpfs dev /dev
::sysinit:/bin/mkdir -p /dev/pts
::sysinit:/bin/mount -t devpts devpts /dev/pts
::sysinit:/bin/echo "Welcome to notlfs"
::sysinit:/bin/hostname notlfs
::sysinit:/sbin/ip link set lo up
::sysinit:/sbin/udhcpc -i eth0 -q -n -t 5
::sysinit:/usr/bin/dropbear -R -s
::sysinit:/bin/sh -c "amixer -q sset Master 80% unmute; amixer -q sset PCM 80% unmute" >/dev/null 2>&1
::respawn:-/bin/tui
tty1::respawn:-/bin/tui
tty2::respawn:/sbin/getty -n -l /bin/sh 0 tty2
::ctrlaltdel:/sbin/reboot
TAB

mkdir -p rootfs/etc/fastfetch rootfs/etc/xdg/fastfetch
cp "$TOP/files/logo.txt" rootfs/etc/fastfetch/
cp "$TOP/files/config.jsonc" rootfs/etc/xdg/fastfetch/
echo notlfs > rootfs/etc/hostname
cat > rootfs/etc/os-release <<'OS'
NAME=notlfs
ID=notlfs
PRETTY_NAME="notlfs (not Linux From Scratch)"
OS

# 5. initramfs
cd rootfs
rm -f "$TOP/out/initramfs.cpio.gz"
find . | cpio -o -H newc -R 0:0 | xz -9e --check=crc32 > "$TOP/out/initramfs.cpio.xz"
echo "Done: out/bzImage out/initramfs.cpio.xz"
