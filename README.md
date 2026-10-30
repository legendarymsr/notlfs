# notlfs

notlfs (not Linux From Scratch): a dead simple Linux. Kernel "catgirls": GNU Linux-libre 6.6.160-gnu (GPL-2.0, no firmware blobs), uname -r 6.6.160-gnu-catgirls, musl, BusyBox, fastfetch with a middle-finger logo, and a TUI "WM": the console boots straight into tmux, with w3m (HTTPS via LibreSSL) for browsing and vis (with Lua syntax highlighting) as $EDITOR.

```sh
./build.sh   # -> out/bzImage, out/initramfs.cpio.xz
./run.sh     # boots in QEMU on the serial console with user-mode networking (Ctrl-A X quits QEMU)
```

Needs: cmake, curl, tar, bzip2, xz, gcc, make, flex, bison, bc, libelf-dev, cpio, gzip, qemu-system-x86_64.

What `build.sh` does:
1. Grabs the prebuilt musl cross toolchain from musl.cc
2. Builds static BusyBox, fastfetch, ncurses, libevent, tmux 3.5a, LibreSSL 3.9.2, bdwgc 8.2.8 and w3m 0.5.3+git20230121, Lua 5.4.7, LPeg 1.1.0, libtermkey 0.22 vis 0.9, dropbear 2026.94, zlib, curl 8.11.1, git 2.47.1, glib 2.82.4, irssi 1.4.5, FFmpeg 7.1, freetype, fribidi, harfbuzz, libass, libdrm, libplacebo and mpv 0.41.0 against musl; aerc 0.20.1 is built with Go (CGO off)
3. Downloads GNU Linux-libre from linux-libre.fsfla.org (sha256-pinned), builds x86_64 defconfig with no built-in firmware
4. Makes a rootfs with BusyBox symlinks and an `/etc/inittab`
5. Adds terminfo, a CA bundle, DHCP (udhcpc on eth0), /etc/tmux.conf, /etc/os-release, hostname notlfs and the fastfetch logo (files/)
6. Packs it into an initramfs

License: build scripts GPL-3.0-or-later. The kernel (Linux-libre) is GPL-2.0-only.

tmux prefix is Ctrl-B (Ctrl-A is QEMU's escape key): `Ctrl-B %` splits side by side, `Ctrl-B "` splits top/bottom, mouse works. Try `w3m https://example.com`.

Extras:
- `ssh root@127.0.0.1 -p 2223` from the host (run.sh forwards it). Root has no password: put your key in `/root/.ssh/authorized_keys`. Host keys are generated on first connect.
- `git clone https://...` works (curl + LibreSSL).
- `irssi`, `aerc` (starts the account wizard).
- `mpv --vo=drm file` plays video on the virtio-gpu display (QEMU window/screendump), e.g. `mpv --vo=drm av://lavfi:testsrc`. `--vo=tct` plays it in the terminal. No audio output.

## v0.8 notes

- **Audio:** static alsa-lib + amixer, mpv built with ALSA; kernel has HDA Intel + generic codec. QEMU gets `intel-hda` + `hda-duplex`.
  `AUDIO=pa ./run.sh` (or `pipewire`, `alsa`) plays on the host; `AUDIO=wav WAV=out.wav ./run.sh` records the guest audio to a file. Default is `none`.
- **Fonts/OSD:** fontconfig + DejaVu Sans Mono in `/usr/share/fonts`, so libass and the mpv OSD work.
- **mpv:** `/etc/mpv/mpv.conf` sets `vo=drm,tct`, `ao=alsa`, `hwdec=no`. DRM needs a real VT: run it from tty1/tty2 in `./run.sh gfx`,
  or from serial with `openvt -c 3 -s -w -- mpv FILE`. In a terminal (serial/ssh/tmux) use `mpv --vo=tct FILE`.
- **run.sh:** `./run.sh` = serial console + tmux (default). `./run.sh gfx` also opens a QEMU window: tmux on tty1, a root shell on tty2 (Ctrl-Alt-F2).
- **Root login:** root has no password (`*` in /etc/shadow). SSH (port 2223 on the host) is **key-only**: put your key in
  `/root/.ssh/authorized_keys`. The local consoles (serial, tty1, tty2) give a root shell with no login, as before.
- **Size:** initramfs is now xz, ffmpeg built with `--disable-everything` plus a short list of common decoders/demuxers/parsers.
  initramfs 38,180,692 B (v0.7, gzip) -> 18,187,460 B (v0.8, xz); mpv binary 24 MB -> 16 MB.

## Build host

`build.sh` checks these first and stops if any are missing:
curl tar bzip2 xz gzip cpio make gcc flex bison bc perl python3 tic (ncurses) cmake meson ninja pkg-config (pkgconf) go gperf,
plus hwdata, libelf-dev and libssl-dev. On Debian/Ubuntu:
`apt install curl bzip2 xz-utils cpio build-essential flex bison bc perl python3 ncurses-bin cmake meson ninja-build pkgconf golang gperf hwdata libelf-dev libssl-dev`
