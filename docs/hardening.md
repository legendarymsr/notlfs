# Hardening

notlfs is hardened at both the kernel and the userland level. None of this is
bolted on at runtime — it's baked into the build.

## Kernel

- **Lockdown in confidentiality mode** — the kernel is built with integrity
  lockdown forced on, and every boot entry adds `lockdown=confidentiality`, which
  also stops root from reading kernel memory.
- **Boot command line** (ISO, disk installs, `run.sh`): `lockdown=confidentiality
  slab_nomerge init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 pti=on
  randomize_kstack_offset=on vsyscall=none debugfs=off`.
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

## Disk encryption (`notlfs-install`, default)

`notlfs-install /dev/sdX` (encrypted unless you pass `-n`) makes a 128 MiB plain `/boot` partition and puts the
root filesystem in a LUKS2 container (argon2id, aes-xts-plain64, 512-bit key).
`/boot` holds the kernel and a ~1 MB unlock initrd (BusyBox + `cryptsetup` + a
30-line `/init`, `files/unlock-init`) that asks for the passphrase, opens the root
as `/dev/mapper/notlfs-root` and switches to it. Unencrypted installs stay the same
and need no initrd. `notlfs-chroot` also accepts a LUKS partition: it unlocks it,
chroots in, and closes it again on exit.

`cryptsetup` uses the kernel's crypto API (AF_ALG) instead of OpenSSL, and only
the device-mapper library from LVM2 is built; no LVM tools, token plugins or docs.
The kernel `/boot` is not encrypted, so this protects data at rest, not against
someone tampering with the kernel on a stolen-and-returned laptop.

## Encryption extras

- **Swap:** `files/notlfs-cryptswap`: plain dm-crypt, aes-xts-plain64/512, key read from `/dev/urandom` at every boot and never
  written anywhere. Skipped on amnesic boots.
- **Vaults:** `files/notlfs-vault`: LUKS2/argon2id containers on a loop device, mounted nodev,nosuid.
- **Panic:** `files/panic` (Alt+Shift+x). Order: copy busybox + cryptsetup into a private tmpfs and re-exec from there, swapoff,
  unmount and `cryptsetup close` every non-root mapping, remount / ro, `luksSuspend` the root (dm-crypt drops the key), drop caches,
  `poweroff -f -n` (`-n`: a sync would block forever on the suspended root). Takes ~3 s in QEMU. Keys of a *running* root must be
  suspended, not closed, since it is still mounted; suspend wipes the key all the same. Cold-boot attacks on RAM right after power-off are out of scope.
- **Amnesic boot:** `notlfs.amnesic` on the cmdline: rc.init skips `mount -a` and swap, and a 2-second loop sets every
  non-loop/dm block device read-only (`blockdev --setro`). Mounting a disk then fails; writes give EPERM.
- **Updates:** `files/notlfs-update` + `files/src/sigverify.c`. Download only through Tor (`torsocks curl`), signature checked
  before anything is unpacked, tarball rejected if it has absolute or `..` paths.

## Intel ME / AMD PSP

Linux cannot turn off Intel ME or AMD PSP: they are separate processors that run
their own firmware before and alongside the OS. What notlfs does is leave out
every driver Linux uses to talk to them, so nothing on the system can reach them:

- Intel: `INTEL_MEI` and all `MEI_*` drivers (ME, TXE, GSC, HDCP, PXP, GSC proxy,
  watchdog), and `INTEL_TXT`.
- AMD: `CRYPTO_DEV_CCP` (CCP/PSP/SEV driver), `KVM_AMD_SEV`, `AMD_MEM_ENCRYPT`,
  `AMDTEE`/`TEE`.
- TPM: `TCG_CRB` (the interface firmware TPMs inside ME/PSP use) is off; in
  practice no TPM driver is built at all.

`build.sh` fails if any of these get turned back on. There are no loadable
modules, so there is nothing to blacklist in `/etc/modprobe.d`.

What this does **not** do: the ME/PSP firmware still runs, still has its own
access to memory and (on some boards) the network. To actually cut it down you
need firmware work: `me_cleaner` on supported Intel boards, or Libreboot/Canoeboot
on the old ThinkPads and other boards they support.

## SSH (dropbear)

- **Key-only logins.** Password logins are disabled entirely.
- Root has no password (`*` in `/etc/shadow`); put your public key in
  `/root/.ssh/authorized_keys`.
- Host keys are generated on first connect.

## Logging

Every service logs through **`s6-log`** to `/var/log/<svc>`. The `syslogd`
service is `s6-socklog` + `s6-log` writing into `/var/log/syslog/current`.

## Kernel trim

The kernel starts from `defconfig` and then drops what notlfs never uses:
ftrace, kprobes, profiling, BPF, magic SysRq, audit, cgroups, IKCONFIG and the
SLUB/scheduler debug extras; NUMA, PCMCIA, AGP, EISA/ISA, FireWire, InfiniBand,
parport, CAN and ham radio; old PATA controllers (PIIX stays for QEMU and old
ThinkPads in IDE mode); NFS and other network filesystems, traffic shaping,
IPVS and bridging; Xen, Hyper-V, Jailhouse and ACRN guests (KVM and virtio
stay for testing); joysticks, tablets and touchscreens.

It adds what real laptops need: NVMe, USB Attached SCSI, ThinkPad ACPI, Apple
gmux/SMC and the bcm5974 MacBook touchpad, the common HDA codecs (Realtek,
Conexant, Cirrus, IDT/Sigmatel, Analog, HDMI), USB audio, and simpledrm so
GPUs without a driver (i915 is off) still get a KMS console from the firmware
framebuffer. The image is XZ-compressed. Everything is built in, since loadable
modules are disabled.

`build.sh` fails if any of the kept essentials (dm-crypt, nftables, loop, the
Wi-Fi stack, ath9k/ath5k, HDA, NVMe, AHCI, USB storage, virtio, simpledrm, swap
or the hardening options) goes missing.
