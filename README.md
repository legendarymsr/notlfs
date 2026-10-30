# minimal-linux

A dead simple Linux: a kernel, musl, BusyBox, and nothing else.

```sh
./build.sh   # -> out/bzImage, out/initramfs.cpio.gz
./run.sh     # boots in QEMU on the serial console (Ctrl-A X to quit)
```

Needs: cmake, curl, tar, bzip2, xz, gcc, make, flex, bison, bc, libelf-dev, cpio, gzip, qemu-system-x86_64.

What `build.sh` does:
1. Grabs the prebuilt musl cross toolchain from musl.cc
2. Builds static BusyBox and fastfetch against musl
3. Builds Linux (x86_64 defconfig)
4. Makes a rootfs with BusyBox symlinks and an `/etc/inittab`
5. Packs it into an initramfs

License: GPL-3.0-or-later.
