# Design decisions & rationale

Every choice in notlfs is here on purpose. This is the reasoning behind each one,
with an honest comparison to the mainstream alternative.

## musl vs glibc

**notlfs uses musl.**

glibc is big, sprawling, and full of history: it carries decades of GNU
extensions, loadable NSS modules, `dlopen`-based plugins, and a large dynamic
runtime. musl is a clean, small, standards-focused libc designed for static
linking. Everything in notlfs links statically against musl, which means each
binary is self-contained — no shared-library version juggling, no `ld.so`, no
"works on my machine" dynamic-linker surprises. The whole image is simpler to
reason about and smaller.

The trade-off is real and notlfs embraces it: a few programs that rely on
glibc-only behavior or on `dlopen`-ing plugins at runtime simply cannot be built
as static musl binaries. That's why, for example, cmus and weechat are *not*
included — their core functionality loads as shared-object plugins, which a static
musl binary can't do. We pick tools that work statically instead.

## BusyBox vs GNU coreutils

**notlfs uses BusyBox.**

The GNU userland is dozens of separate packages (coreutils, util-linux,
findutils, grep, sed, tar, …), each a full-featured program with every option
anyone ever wanted. BusyBox is a single static binary that provides `sh`, `ls`,
`cp`, `grep`, `tar`, `fdisk`, `udhcpc`, `setfont`, `loadkmap`, and hundreds of
other applets through symlinks. One binary, one source, a tiny footprint, and
enough of every tool to run a real system.

The trade-off: BusyBox applets implement the common subset, not every obscure
flag. In practice that's fine for notlfs, and where a BusyBox applet genuinely
isn't enough, we add a dedicated tool (see "minimal / no duplicate tools" below).

## s6 vs systemd

**notlfs uses s6** (skalibs, execline, s6, s6-linux-init).

systemd is an enormous, tightly-coupled init that absorbs logging, device
management, networking, name resolution, timers, and more into one project.
s6 is the opposite philosophy: a tiny, composable process supervisor. Each
service runs in its own process, s6 keeps it alive and restarts it if it dies,
and logging goes through `s6-log`. There's no monolith — just small programs that
do one thing.

In notlfs, s6-linux-init is PID 1. One-shot boot steps (mounts, hostname,
`mount -a`, unmuting audio) live in `rc.init`; long-running services are plain s6
service directories: `tty1` (tmux), `tty2` (a root shell), `serial` (tmux on
ttyS0), `udhcpc`, `dropbear`, `mpd`, `iwd`, `dbus`, and `syslogd`
(`s6-socklog` + `s6-log`). You manage them with the usual `s6-svstat`,
`s6-svc -r`, `poweroff`, `reboot`.

Compared to BusyBox's own init (classic SysV-style `/etc/inittab`): BusyBox init
has no real supervision — if a service dies, nothing restarts it. s6 gives you
genuine supervision and clean logging without dragging in systemd.

## Linux-libre vs the mainline kernel

**notlfs uses GNU Linux-libre 6.6 (the "catgirls" build).**

The mainline kernel ships with non-free firmware blobs ("deblobbing" is left to
you). Linux-libre is the same kernel with all non-free firmware removed, so the
system is entirely free software out of the box. notlfs builds it from the
`x86_64` defconfig with no built-in firmware and no loadable modules — everything
needed is compiled directly into the image, which also removes the module-signing
and module-loading attack surface entirely (see [hardening](hardening.md)).

## TTY-only vs a GUI

**notlfs is TTY-only.**

A GUI means a display server (X11 or Wayland), a compositor or window manager, a
toolkit stack, fonts, themes, and drivers — a huge amount of code and complexity
for a system that is otherwise tiny. notlfs skips all of it. The console boots
straight into a working environment, everything is keyboard-driven, it runs over
a serial line or SSH identically to a local console, and there's far less to
build, break, or attack.

The terminal still does real work: w3m browses the web, mpv plays video (to the
DRM framebuffer or inline in the terminal with `--vo=tct`), and the full suite of
TUI tools covers mail, IRC, music, files, feeds, calendars, and spreadsheets.

## tmux as the WM vs a tiling WM

**notlfs uses tmux as its window manager.**

A tiling WM like dwm, i3, or sway needs a display server underneath it. Since
notlfs has no GUI, tmux fills the role on the console instead. It's configured to
behave like a small tiling WM: Alt-key binds (no prefix) for creating, focusing,
swapping, resizing, and zooming panes, workspaces on `Alt+1..9`, auto-tiling
master/stack layouts like dwm, and an fzf launcher popup. It works the same over
serial and SSH as it does locally, persists sessions, and needs zero graphics
stack. (The classic tmux prefix, `Ctrl-B`, still works too.)

## Root-only

**notlfs has exactly one account: root, with no password.**

This is a single-user, minimal system, not a multi-tenant server. Adding users,
`sudo`/`doas`, PAM, and the rest would be complexity for a problem notlfs doesn't
have. The local consoles (serial, tty1, tty2) give a root shell directly.
Remote access is *not* an open door, though: SSH via dropbear is key-only (no
password logins at all) and the firewall only opens port 22 while dropbear is
enabled. See [hardening](hardening.md).

## extlinux vs GRUB

**notlfs boots with extlinux/isolinux (syslinux).**

GRUB is a large, capable bootloader with its own scripting language, modules, and
configuration machinery. notlfs doesn't need any of that. syslinux's isolinux
boots the hybrid ISO, and extlinux boots a disk install from a simple
`extlinux.conf`. The installer uses a static `extlinux` (rebuilt against musl) and
writes the syslinux MBR. It's BIOS-only and intentionally minimal; there is no
GRUB and no UEFI yet.

## vis (the editor)

**notlfs ships vis as `$EDITOR`.**

vis is a small, modal (vi-like) editor with structural regular expressions and
Lua-based syntax highlighting (LPeg). It gives you a modern vi editing experience
in a compact, statically-linkable package — a better fit for notlfs's philosophy
than a full vim build or the heavier emacs, while being friendlier than plain
BusyBox `vi`.

## Free media formats

**notlfs prefers free formats: VP9 video, Opus audio, WebM containers.**

Formats like H.264 and AAC are patent-encumbered. VP9, Opus, and WebM are
royalty-free and openly specified, which keeps the whole system free software all
the way down to the media it produces and plays. FFmpeg is built with VP9/Opus
and TLS support to match.

## "Minimal / no duplicate tools" philosophy

notlfs aims to include **one** good tool per job and no more. BusyBox already
covers the common core utilities, so a dedicated tool is only added when BusyBox
genuinely isn't enough. Where overlaps remain, they're acknowledged honestly
rather than hidden — e.g. ripgrep vs BusyBox `grep`, ncdu vs BusyBox `du`, lf vs
fzf for files, and mpd/ncmpcpp vs mpv for audio. Tools that duplicated existing
functionality have been removed (for instance nnn was dropped because lf + fzf
already cover file management, and btop was dropped in favor of htop). Keeping the
set minimal keeps the image small and the system easy to understand.
