# Hardening

notlfs is hardened at both the kernel and the userland level. None of this is
bolted on at runtime — it's baked into the build.

## Kernel

- **Lockdown in integrity mode** — blocks the usual ways userspace could modify
  the running kernel.
- **Yama** — restricts `ptrace` (see `ptrace_scope` below).
- **Landlock** — unprivileged sandboxing LSM available for programs that use it.
- **No loadable modules.** Everything is built in; there is no module loading and
  therefore no module-signing key and no module-loading attack surface.
- **No `/dev/mem`, `/dev/port`, `/proc/kcore`**, hardened usercopy,
  `init_on_alloc`/`init_on_free`, and similar hardening options compiled in.
- The `bpf()` syscall is not built into the kernel at all.

## sysctl (`files/sysctl.conf`)

Applied by the early `/init` before any service starts. Highlights:

- `kernel.kptr_restrict = 2`, `kernel.dmesg_restrict = 1` — hide kernel pointers
  and restrict dmesg.
- `kernel.yama.ptrace_scope = 2` — admin-only ptrace.
- `kernel.perf_event_paranoid = 2`, `dev.tty.ldisc_autoload = 0`.
- `fs.protected_symlinks/hardlinks/fifos/regular`, `fs.suid_dumpable = 0`.
- `kernel.randomize_va_space = 2`, `vm.mmap_rnd_bits = 32` — full ASLR.
- Network: `tcp_syncookies`, `tcp_rfc1337`, `rp_filter`, no ICMP redirects
  (accept/secure/send off), no source routing, `log_martians`, ignore broadcast
  pings — for both IPv4 and IPv6.

## Userland: the `hardcc` compiler wrapper (`files/hardcc`)

Every C/C++ compile in the build goes through `hardcc`, which adds:

- `-fstack-protector-strong`
- `-fstack-clash-protection`
- `-D_FORTIFY_SOURCE=2` (musl has no fortify of its own, so fortify-headers
  provides it)
- `-fPIE`
- Full RELRO on links (`-Wl,-z,relro,-z,now`).
- **Static links become static-PIE.** A link that can't be static-PIE (non-PIC
  objects) falls back to plain `-static` (still RELRO) and is noted in
  `build/hardcc-fallback.log`.

It also maps the build-tree path to `/notlfs` in debug info, `__FILE__`, and
`assert()` for reproducibility. (A known gotcha it handles: some configure scripts
add a bare `-pie` that would turn a static-PIE link back into a dynamic PIE needing
`/lib/ld-musl`, which notlfs doesn't ship — `hardcc` strips that `-pie`.)

## Early boot (`files/init`)

A hardened `/init` runs before s6 starts any service (as `rdinit=/init` on the live
ISO and `init=/init` on a disk install). It:

- Mounts `dev`, `proc`, `sys`, `securityfs`, `devpts` with `nosuid`/`nodev`/
  `noexec` where appropriate.
- Mounts **`/tmp` and `/dev/shm` as `nosuid,nodev,noexec`** tmpfs.
- Applies the sysctl hardening.
- Loads the firewall, then hands off to s6.

## Firewall (`files/nftables.conf`)

nftables with a **default-deny** policy on both the `input` and `forward` chains
(output is open). Inbound, it allows only: established/related connections,
loopback, DHCP replies, and rate-limited ICMP. **Port 22 is opened only while the
dropbear service is enabled** — the early `/init` adds the `tcp dport 22 accept`
rule only if dropbear isn't marked `down`.

## SSH (dropbear)

- **Key-only logins.** Password logins are disabled entirely.
- Root has no password (`*` in `/etc/shadow`); put your public key in
  `/root/.ssh/authorized_keys`.
- Host keys are generated on first connect.

## Logging

Every service logs through **`s6-log`** to `/var/log/<svc>`. The `syslogd`
service is `s6-socklog` + `s6-log` writing into `/var/log/syslog/current`.
