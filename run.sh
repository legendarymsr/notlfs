#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
exec qemu-system-x86_64 -m 256M -nographic \
  -kernel out/bzImage -initrd out/initramfs.cpio.gz \
  -append "console=ttyS0 rdinit=/init"
