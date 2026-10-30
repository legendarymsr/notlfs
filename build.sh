#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Build notlfs, a tiny musl + BusyBox Linux: out/bzImage + out/initramfs.cpio.gz
set -eu
# needs: ncurses (host tic) cmake curl tar bzip2 xz gcc make flex bison bc libelf-dev cpio gzip

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
get() { [ -d "$2" ] || { curl -L "$1" | tar xz; }; }
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

# 3. GNU Linux-libre kernel (GPL-2.0, no blobs)
if [ ! -d linux-$KERNEL ]; then
  curl -LO https://linux-libre.fsfla.org/pub/linux-libre/releases/$KERNEL-gnu/linux-libre-$KERNEL-gnu.tar.xz
  echo "$KERNEL_SHA256  linux-libre-$KERNEL-gnu.tar.xz" | sha256sum -c
  tar xJf linux-libre-$KERNEL-gnu.tar.xz
fi
cd linux-$KERNEL
make defconfig
./scripts/config --set-str LOCALVERSION "-catgirls" --set-str DEFAULT_HOSTNAME notlfs --set-str EXTRA_FIRMWARE "" --disable DRM_I915 --disable WERROR
make olddefconfig
make -j$JOBS bzImage
cp arch/x86/boot/bzImage "$TOP/out/"
cd ..

# 4. rootfs
rm -rf rootfs && mkdir -p rootfs/bin rootfs/sbin rootfs/etc rootfs/dev rootfs/proc rootfs/sys rootfs/tmp
cp busybox-$BUSYBOX/busybox rootfs/bin/
mkdir -p rootfs/usr/bin rootfs/root rootfs/etc/ssl rootfs/etc/w3m rootfs/usr/share/udhcpc rootfs/usr/share/terminfo
cp fastfetch-build/fastfetch tmux-3.5a/tmux w3m-0.5.3-git20230121/w3m rootfs/usr/bin/
tic -x -o rootfs/usr/share/terminfo -e linux,vt102,xterm,xterm-256color,screen,tmux,tmux-256color ncurses-6.5/misc/terminfo.src
cp cacert.pem rootfs/etc/ssl/cert.pem
cp busybox-$BUSYBOX/examples/udhcp/simple.script rootfs/usr/share/udhcpc/default.script
cp "$TOP/files/tmux.conf" "$TOP/files/profile" rootfs/etc/
cp "$TOP/files/w3m-config" rootfs/etc/w3m/config
cp "$TOP/files/tui" rootfs/bin/tui
chmod +x rootfs/bin/tui rootfs/usr/share/udhcpc/default.script
echo 'root:x:0:0:root:/root:/bin/sh' > rootfs/etc/passwd
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
::respawn:-/bin/tui
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
find . | cpio -o -H newc | gzip -9 > "$TOP/out/initramfs.cpio.gz"
echo "Done: out/bzImage out/initramfs.cpio.gz"
