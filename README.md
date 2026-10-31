# notlfs

notlfs (not Linux From Scratch): a dead simple Linux. Kernel "catgirls": GNU Linux-libre 6.6.160-gnu (GPL-2.0, no firmware blobs), uname -r 6.6.160-gnu-catgirls, musl, BusyBox, fastfetch with a middle-finger logo, and a TUI "WM": the console boots straight into tmux, with w3m (HTTPS via LibreSSL) for browsing and vis (with Lua syntax highlighting) as $EDITOR.

```sh
./build.sh   # -> out/bzImage, out/initramfs.cpio.xz, out/notlfs.iso
./run.sh     # boots in QEMU on the serial console with user-mode networking (Ctrl-A X quits QEMU)
```

Needs: cmake, curl, tar, bzip2, xz, gcc, make, flex, bison, bc, libelf-dev, cpio, gzip, qemu-system-x86_64.

What `build.sh` does:
1. Grabs the prebuilt musl cross toolchain from musl.cc
2. Builds static BusyBox, fastfetch, ncurses, libevent, tmux 3.5a, LibreSSL 3.9.2, bdwgc 8.2.8 and w3m 0.5.3+git20230121, Lua 5.4.7, LPeg 1.1.0, libtermkey 0.22 vis 0.9, dropbear 2026.94, zlib, curl 8.11.1, git 2.47.1, glib 2.82.4, irssi 1.4.5, FFmpeg 7.1, freetype, fribidi, harfbuzz, libass, libdrm, libplacebo and mpv 0.41.0 against musl; aerc 0.20.1, lf r42 and fzf 0.74.5 are built with Go (CGO off)
3. Downloads GNU Linux-libre from linux-libre.fsfla.org (sha256-pinned), builds x86_64 defconfig with no built-in firmware
4. Makes a rootfs with BusyBox symlinks and s6 as init (s6-linux-init)
5. Adds terminfo, a CA bundle, DHCP (udhcpc on eth0), /etc/tmux.conf, /etc/os-release, hostname notlfs and the fastfetch logo (files/)
6. Packs it into an initramfs and a hybrid ISO (isolinux)

License: build scripts GPL-3.0-or-later. The kernel (Linux-libre) is GPL-2.0-only.

tmux prefix is Ctrl-B (Ctrl-A is QEMU's escape key): `Ctrl-B %` splits side by side, `Ctrl-B "` splits top/bottom, mouse works. Try `w3m https://example.com`.

### Tiling tmux (Alt keys, no prefix)
tmux on the console acts like a small tiling WM (Tokyo Night themed; `Alt+?` shows this list from `/etc/motd`):
`Alt+Enter` new pane (auto-tiles master/stack like dwm) · `Alt+h/j/k/l` focus · `Alt+Shift+h/j/k/l` swap ·
`Alt+Ctrl+h/j/k/l` or `Alt+r` then hjkl resize · `Alt+1..9` workspace · `Alt+Shift+1..9` send pane to workspace ·
`Alt+q` close · `Alt+f` fullscreen · `Alt+Space` next layout · `Alt+t` re-tile · `Alt+d` fzf launcher · `Alt+e` lf · `Alt+b` w3m.

Extras:
- `ssh root@127.0.0.1 -p 2223` from the host (run.sh forwards it). Root has no password: put your key in `/root/.ssh/authorized_keys`. Host keys are generated on first connect.
- `git clone https://...` works (curl + LibreSSL).
- `irssi`, `aerc` (starts the account wizard).
- `mpv --vo=drm file` plays video on the virtio-gpu display (QEMU window/screendump), e.g. `mpv --vo=drm av://lavfi:testsrc`. `--vo=tct` plays it in the terminal. No audio output.

## v0.11: fixes, a few small tools

- **Added** (static musl): fzf 0.74.5 (Go), ripgrep (`rg`), jq 1.7.1, ncdu 1.20, calcurse 4.8.1, sc-im 0.8.4 (no Lua/xlsx),
  tcpdump 4.99.5 (libpcap 1.10.5).
- **Removed:** nnn (lf + fzf cover files) and btop (htop stays). lf updated to r42.
- **Fixes:** newsboat showed `3632-dirty` (its build.rs ran `git describe` on this repo); now built with `GIT_DIR=/nonexistent`
  so it reports 2.41. The leftover `/persist` test file is gone (fresh install). The fastfetch screenshot glitch was the typed
  command left on screen; screenshots now run `clear` first.
- **Overlaps left:** ripgrep vs BusyBox `grep`, ncdu vs BusyBox `du`, lf vs fzf for files, mpd/ncmpcpp vs mpv for audio.

## v0.10: s6, disk install, more TUI tools

- **Init is s6** (skalibs 2.14.4, execline 2.9.7, s6 2.13.2, s6-linux-init 1.1.3). No s6-rc: one-shots (mounts, hostname, `mount -a`,
  amixer unmute) live in `/etc/s6-linux-init/current/scripts/rc.init`, and services are plain s6 service dirs in `/run/service`:
  `tty1` (tmux), `tty2` (root shell), `serial` (tmux on ttyS0), `udhcpc`, `dropbear`, `mpd`, `syslogd` (`s6-socklog` + `s6-log` into
  `/var/log/syslog/current`). `s6-svstat /run/service/dropbear`, `s6-svc -r /run/service/udhcpc`, `poweroff`/`reboot` work as usual.
  Root only, no other users. Source: `files/s6/`.
- **ISO:** `out/notlfs.iso` is a hybrid ISO (isolinux 6.03), boots from CD or `dd` to a USB stick. **BIOS only** (no UEFI yet).
  `qemu-system-x86_64 -m 1G -cdrom out/notlfs.iso`
- **Disk install:** boot the ISO, then `notlfs-install /dev/sda` (asks you to type `yes`; `-y` skips that). It wipes the disk, makes one
  MBR partition with ext4, copies the running system, puts the kernel in `/boot`, writes `/etc/fstab` (by PARTUUID) and installs
  extlinux + the syslinux MBR. BIOS boot only. No GRUB. Tools in the image: static `mke2fs` (e2fsprogs 1.47.1) and `extlinux`
  (syslinux 6.03, rebuilt static against musl), BusyBox `fdisk`.
  Test in QEMU: `qemu-img create -f raw disk.img 2G`, boot with `-cdrom out/notlfs.iso -drive file=disk.img,format=raw -boot d`,
  install, then boot with just `-drive file=disk.img,format=raw`.
- **TUI tools** (all static musl): htop 3.3.0, lf r42 (Go), mpd 0.23.17 (ALSA, runs as an s6 service,
  music goes in `/root/music`) + ncmpcpp 0.10.1 (static boost 1.83), newsboat 2.41 (Rust, musl target; `/root/.newsboat/urls`
  has your GitHub feed).
- **Not included:** cmus and weechat. Both load their core functionality (cmus: every input/output backend; weechat: IRC, relay,
  everything) as shared-object plugins via `dlopen()`, which a static musl binary cannot do. irssi already covers IRC and
  mpd + ncmpcpp cover music.
- **w3m on GitHub:** GitHub answers w3m's HTTP/1.0 requests with chunked bodies but no `Transfer-Encoding` header, so the first chunk
  size (`8000`) shows up at the top of the page. w3m has no chunked decoder, so fixing it means patching w3m; not done yet.

## v0.8 notes

- **Audio:** static alsa-lib + amixer + aplay, mpv built with ALSA; kernel has HDA Intel + generic codec. QEMU gets `intel-hda` + `hda-duplex`.
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
curl tar bzip2 xz gzip cpio make gcc flex bison bc perl python3 tic (ncurses) cmake meson ninja pkg-config (pkgconf) go gperf xorriso autoreconf cargo,
plus hwdata, libelf-dev and libssl-dev. On Debian/Ubuntu:
`apt install curl bzip2 xz-utils cpio build-essential flex bison bc perl python3 ncurses-bin cmake meson ninja-build pkgconf golang gperf hwdata libelf-dev libssl-dev xorriso autoconf automake libtool`
and Rust with the musl target for newsboat: `rustup target add x86_64-unknown-linux-musl`
