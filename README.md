# notlfs

notlfs (not Linux From Scratch): a dead simple Linux. Kernel "catgirls": GNU Linux-libre 6.6.160-gnu (GPL-2.0, no firmware blobs), uname -r 6.6.160-gnu-catgirls, musl, BusyBox, fastfetch with a middle-finger logo, and a TUI "WM": the console boots straight into tmux, with w3m (HTTPS via LibreSSL) for browsing and vis (with Lua syntax highlighting) as $EDITOR.

```sh
./build.sh   # -> out/bzImage, out/initramfs.cpio.gz
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
