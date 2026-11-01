# Overview

notlfs is a complete Linux system built from source, from the kernel up, with
every package compiled against musl and linked statically. There is no package
manager, no glibc, no GNU coreutils, no systemd, and no graphical environment —
and all of that is deliberate.

## The kernel: "catgirls"

- **GNU Linux-libre 6.6.160-gnu** (GPL-2.0-only, no non-free firmware blobs).
- `uname -r` reports `6.6.160-gnu-catgirls`.
- Built from the `x86_64` defconfig with no built-in firmware and **no loadable
  modules** at all. Everything the system needs is compiled directly into the
  kernel image.
- The source is downloaded from `linux-libre.fsfla.org` and pinned by sha256.

## The pieces

| Layer | notlfs uses | Instead of |
| --- | --- | --- |
| C library | musl | glibc |
| Core userland | BusyBox | GNU coreutils / util-linux / etc. |
| Init + supervision | s6 (skalibs, execline, s6, s6-linux-init) | systemd / OpenRC / SysV |
| Kernel | GNU Linux-libre 6.6 | mainline + firmware blobs |
| "Desktop" | tmux on the TTY | X11/Wayland + a WM/DE |
| Editor | vis | vim / nano / emacs |
| Bootloader | extlinux / isolinux (syslinux) | GRUB |
| Media formats | VP9 / Opus / WebM | H.264 / AAC / MP4 |

## The shape of the system

- **Static musl binaries.** Everything is linked statically; there is no dynamic
  loader shipped in the image. `build.sh` even fails the build if any ELF in the
  rootfs has a program interpreter (`PT_INTERP`).
- **Root-only.** There is one account: root, with no password (`*` in
  `/etc/shadow`). The local consoles log straight into a root shell.
- **TTY-only.** No X11, no Wayland, no display server. The console boots into
  tmux, which is configured as a small tiling window manager. w3m (HTTPS via
  LibreSSL) handles web browsing in the terminal; mpv can play video to the
  framebuffer (`--vo=drm`) or inline in the terminal (`--vo=tct`).
- **Tokyo Night themed.** Every TUI tool is themed with the Tokyo Night palette.
  A dark theme is the default; a Tokyo Night Day light theme can be switched to
  live with `theme day` / `theme night`.
- **Reproducible and hardened.** The build is bit-for-bit reproducible (see
  [building](building.md)) and both the kernel and the userland are hardened (see
  [hardening](hardening.md)).

## Distribution

`build.sh` produces three artifacts in `out/`:

- `out/bzImage` — the kernel.
- `out/initramfs.cpio.xz` — the xz-compressed initramfs (the whole userland).
- `out/notlfs.iso` — a hybrid ISO (isolinux 6.03) that boots from CD or from a
  USB stick you `dd` it to. **BIOS boot only** (no UEFI yet).

From a booted ISO you can install to disk with `notlfs-install /dev/sda`, which
writes an ext4 root, installs extlinux + the syslinux MBR, and boots from the
disk thereafter.

## Licensing

- The build scripts are GPL-3.0-or-later.
- The kernel (Linux-libre) is GPL-2.0-only.
- Each bundled package keeps its own upstream license.
