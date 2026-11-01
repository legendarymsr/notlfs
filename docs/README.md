# notlfs documentation

notlfs (**not** Linux From Scratch) is a from-scratch, dead-simple Linux built
entirely against [musl](https://musl.libc.org/) with a [BusyBox](https://busybox.net/)
userland, [s6](https://skarnet.org/software/s6/) for init and supervision, and a
[GNU Linux-libre](https://linux-libre.fsfla.org/) kernel (the "catgirls" build).
It is TTY-only — the console boots straight into [tmux](https://github.com/tmux/tmux)
used as the window manager — Tokyo Night themed (dark by default, with a Tokyo
Night Day light option), root-only, shipped as static musl binaries, booted with
extlinux/isolinux, and built reproducibly with a hardened toolchain and kernel.

If you want the one-paragraph pitch and the quick-start, read the
[top-level README](../README.md). These docs go deeper.

## Contents

- **[Overview](overview.md)** — what notlfs is, the kernel, the big pieces, the shape of the system.
- **[Design decisions & rationale](design-decisions.md)** — the *why* behind every choice (musl vs glibc, BusyBox vs GNU coreutils, s6 vs systemd, Linux-libre vs mainline, TTY vs GUI, tmux vs a tiling WM, root-only, extlinux vs GRUB, vis, free media formats, and the "minimal / no duplicate tools" philosophy).
- **[Building](building.md)** — running `build.sh`, what you get, and the reproducible-build story.
- **[Hardening](hardening.md)** — kernel lockdown, Yama, Landlock, sysctl, the `hardcc` wrapper, nftables, dropbear, noexec mounts, s6-log.
- **[Installed packages & tools](packages.md)** — the real list of what's in the image, pulled from the repo.
- **[Usage basics](usage.md)** — booting, tmux as a WM, theme switching, the YouTube script, email/IRC/SSH.

> notlfs is small on purpose. If something here claims a feature, it's in the
> repo; if it's not here, it probably isn't in notlfs (and that's the point).
