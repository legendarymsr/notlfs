# Building notlfs

Everything is driven by a single script, `build.sh`, which builds the entire
system from source: the cross toolchain, every userland package, the kernel, the
rootfs, the initramfs, and the ISO.

## Quick start

```sh
./build.sh   # -> out/bzImage, out/initramfs.cpio.xz, out/notlfs.iso
./run.sh     # boots in QEMU on the serial console with user-mode networking
             # (Ctrl-A X quits QEMU)
```

## What `build.sh` does

1. Grabs the prebuilt musl cross toolchain from musl.cc.
2. Builds the static musl userland: BusyBox, fastfetch, ncurses, libevent,
   tmux, LibreSSL, bdwgc, w3m, Lua + LPeg, libtermkey, vis, dropbear, zlib,
   curl, git, glib, irssi, FFmpeg, the mpv media stack (freetype, fribidi,
   harfbuzz, libass, libdrm, libplacebo, mpv), and the rest. A handful of tools
   are built with Go (CGO off): aerc, lf, fzf. newsboat is built with Rust
   against the musl target. See [packages](packages.md) for the full list and
   versions.
3. Downloads GNU Linux-libre (sha256-pinned), and builds the `x86_64` defconfig
   with no built-in firmware and no loadable modules.
4. Builds the rootfs: BusyBox symlinks and s6 as init (s6-linux-init), the s6
   service directories, terminfo, a CA bundle, DHCP (udhcpc on eth0), the tmux
   config, `/etc/os-release`, hostname `notlfs`, the Tokyo Night theming, and the
   fastfetch logo.
5. Packs it into an initramfs (xz) and a hybrid ISO (isolinux).

`build.sh` runs every C/C++ compile through the `hardcc` wrapper (see
[hardening](hardening.md)) and **fails the build** if any ELF in the finished
rootfs still has a program interpreter (`PT_INTERP`) — i.e. if anything came out
dynamically linked.

## Build-host requirements

`build.sh` checks these up front and stops if any are missing:

> curl tar bzip2 xz gzip cpio make gcc flex bison bc perl python3 tic (ncurses)
> cmake meson ninja pkg-config (pkgconf) go gperf xorriso autoreconf cargo, plus
> hwdata, libelf-dev and libssl-dev.

On Debian/Ubuntu:

```sh
apt install curl bzip2 xz-utils cpio build-essential flex bison bc perl \
  python3 ncurses-bin cmake meson ninja-build pkgconf golang gperf hwdata \
  libelf-dev libssl-dev xorriso autoconf automake libtool
# Rust with the musl target (for newsboat):
rustup target add x86_64-unknown-linux-musl
```

## What you get

- **`out/bzImage`** — the kernel.
- **`out/initramfs.cpio.xz`** — the userland as an xz-compressed initramfs.
- **`out/notlfs.iso`** — a hybrid ISO (isolinux 6.03). Boot it from CD or `dd` it
  to a USB stick. **BIOS boot only** (no UEFI yet):

  ```sh
  qemu-system-x86_64 -m 1G -cdrom out/notlfs.iso
  ```

### Installing to disk

Boot the ISO, then:

```sh
notlfs-install /dev/sda      # asks you to type "yes"; -y skips the prompt
```

It wipes the disk, makes one MBR partition with ext4, copies the running system,
puts the kernel in `/boot`, writes `/etc/fstab` (by PARTUUID), and installs
extlinux + the syslinux MBR. BIOS boot only, no GRUB. The image ships the tools
it needs for this: a static `mke2fs` (e2fsprogs) and `extlinux` (syslinux, rebuilt
static against musl), plus BusyBox `fdisk`.

Test the whole cycle in QEMU:

```sh
qemu-img create -f raw disk.img 2G
# install:
qemu-system-x86_64 -m 1G -cdrom out/notlfs.iso \
  -drive file=disk.img,format=raw -boot d
# then boot from the disk:
qemu-system-x86_64 -m 1G -drive file=disk.img,format=raw
```

## Reproducible builds

notlfs is built to be bit-for-bit reproducible. The short version (full details in
[`REPRODUCIBLE.md`](../REPRODUCIBLE.md)):

- **Every download is pinned by sha256** in `files/sources.sha256`; `build.sh`
  refuses anything not listed or not matching.
- **Toolchains are pinned:** Go (go1.27.3) and Rust (1.85.1).
- **`SOURCE_DATE_EPOCH`** is set to the last commit time, so timestamps baked into
  the output are fixed rather than "now".
- **The build re-execs inside `unshare -rm`** with the tree bind-mounted at a
  fixed path (`/mnt/notlfs`), so build paths are identical no matter where you
  checked the repo out.
- The initramfs cpio is sorted and packed with `--reproducible`, mtimes are
  clamped, `xz -T1`; xorriso uses a fixed modification date; the kernel uses fixed
  `KBUILD_BUILD_*` values. Modules are off, so there's no random module-signing
  key to make builds differ.

> Because the output embeds `SOURCE_DATE_EPOCH` (the last commit time), the output
> hashes change from commit to commit. That's why no fixed hashes are listed in
> the repo — you verify the *current* commit instead.

### Verifying

```sh
./verify-repro.sh [workdir]   # default workdir: /tmp/notlfs-repro
```

It clones the repo into two different directories, builds both from clean (sharing
the verified download cache), and compares `out/SHA256SUMS`. On a match it prints
`REPRODUCIBLE: both builds are bit-for-bit identical`. On a mismatch it diffs the
sums and, if `diffoscope` is installed, writes a `diffoscope.txt` report. Expect it
to need a lot of disk (~25 GB) and a few hours — it's a full double build.
