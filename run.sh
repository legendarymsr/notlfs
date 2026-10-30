#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
exec qemu-system-x86_64 -m 512M -nographic -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 -vga none -device virtio-gpu-pci \
  -kernel out/bzImage -initrd out/initramfs.cpio.gz \
  -append "console=ttyS0 rdinit=/init" "$@"
