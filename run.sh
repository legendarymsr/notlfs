#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# ./run.sh          serial console in this terminal (tmux), no window
# ./run.sh gfx      also open a QEMU window: tmux on tty1, a shell on tty2 (Ctrl-Alt-F2)
# AUDIO=pa|pipewire|alsa|wav  host audio backend for the guest's HDA sound card (default: none)
# Tokyo Night VT palette (same as the ISO/extlinux cmdline)
VT="vt.default_red=26,247,158,224,122,187,125,192,86,247,158,224,122,187,125,192 vt.default_grn=27,118,206,175,162,154,207,202,95,118,206,175,162,154,207,202 vt.default_blu=38,142,106,104,247,247,255,245,137,142,106,104,247,247,255,245"
GFX=-nographic APPEND="console=ttyS0 rdinit=/init loglevel=4 $VT"
if [ "${1:-}" = gfx ]; then shift; GFX="-serial mon:stdio"; APPEND="console=tty1 console=ttyS0 rdinit=/init loglevel=4 $VT"; fi
case ${AUDIO:-none} in wav) AD="wav,id=snd0,path=${WAV:-notlfs-audio.wav}";; *) AD="${AUDIO:-none},id=snd0";; esac
exec qemu-system-x86_64 -m 512M $GFX -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 -vga none -device virtio-gpu-pci \
  -audiodev $AD -device intel-hda -device hda-duplex,audiodev=snd0 \
  -kernel out/bzImage -initrd out/initramfs.cpio.xz -append "$APPEND" "$@"
