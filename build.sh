#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Build a tiny musl + BusyBox Linux: out/bzImage + out/initramfs.cpio.gz
set -eu
# needs: curl tar bzip2 xz gcc make flex bison bc libelf-dev cpio gzip

KERNEL=6.6.58
BUSYBOX=1.36.1
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

# 3. Linux kernel
[ -d linux-$KERNEL ] || curl -L https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL.tar.xz | tar xJ
cd linux-$KERNEL
make defconfig
make -j$JOBS bzImage
cp arch/x86/boot/bzImage "$TOP/out/"
cd ..

# 4. rootfs
rm -rf rootfs && mkdir -p rootfs/bin rootfs/sbin rootfs/etc rootfs/dev rootfs/proc rootfs/sys rootfs/tmp
cp busybox-$BUSYBOX/busybox rootfs/bin/
for app in $(rootfs/bin/busybox --list-full); do ln -sf /bin/busybox "rootfs/$app" 2>/dev/null || true; done
ln -sf bin/busybox rootfs/init
cat > rootfs/etc/inittab <<'TAB'
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sys /sys
::sysinit:/bin/mount -t devtmpfs dev /dev
::sysinit:/bin/echo "Welcome to minimal-linux"
::respawn:-/bin/sh
::ctrlaltdel:/sbin/reboot
TAB

# 5. initramfs
cd rootfs
find . | cpio -o -H newc | gzip -9 > "$TOP/out/initramfs.cpio.gz"
echo "Done: out/bzImage out/initramfs.cpio.gz"
