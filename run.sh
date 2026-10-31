#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# ./run.sh          serial console in this terminal (tmux), no window
# ./run.sh gfx      also open a QEMU window: tmux on tty1, a shell on tty2 (Ctrl-Alt-F2)
# DAY=1 ./run.sh   boot with the Tokyo Night Day (light) palette
# AUDIO=pa|pipewire|alsa|wav  host audio backend for the guest's HDA sound card (default: none)
# Tokyo Night VT palette (same as the ISO/extlinux cmdline)
VT="vt.default_red=26,247,158,224,122,187,125,192,86,247,158,224,122,187,125,192 vt.default_grn=27,118,206,175,162,154,207,202,95,118,206,175,162,154,207,202 vt.default_blu=38,142,106,104,247,247,255,245,137,142,106,104,247,247,255,245"
[ -n "${DAY:-}" ] && VT="vt.default_red=225,245,88,140,46,152,0,55,161,255,92,162,53,164,0,55 vt.default_grn=226,42,117,108,125,84,113,96,166,71,133,118,138,99,126,96 vt.default_blu=231,101,57,62,233,241,151,191,197,116,36,41,255,255,168,191 notlfs.theme=day"
GFX=-nographic APPEND="console=ttyS0 rdinit=/init loglevel=4 $VT"
if [ "${1:-}" = gfx ]; then shift; GFX="-serial mon:stdio"; APPEND="console=tty1 console=ttyS0 rdinit=/init loglevel=4 $VT"; fi
case ${AUDIO:-none} in wav) AD="wav,id=snd0,path=${WAV:-notlfs-audio.wav}";; *) AD="${AUDIO:-none},id=snd0";; esac
exec qemu-system-x86_64 -m 512M $GFX -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 -vga none -device virtio-gpu-pci \
  -audiodev $AD -device intel-hda -device hda-duplex,audiodev=snd0 \
  -kernel out/bzImage -initrd out/initramfs.cpio.xz -append "$APPEND" "$@"
