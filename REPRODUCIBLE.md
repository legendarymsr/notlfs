# Reproducible builds

Every download is pinned by sha256 in `files/sources.sha256`; `build.sh` aborts on mismatch.
Go (go1.27.3) and Rust (1.85.1) are pinned. `SOURCE_DATE_EPOCH` = last commit time.
The build re-execs inside `unshare -rm` with the tree bind-mounted at `/mnt/notlfs`, so
paths are identical regardless of checkout location. cpio is sorted/`--reproducible`,
mtimes clamped, `xz -T1`; xorriso uses a fixed modification date. Kernel uses fixed
`KBUILD_BUILD_*` and no modules (no random signing key).

Verify: `./verify-repro.sh` builds two clones in different directories and compares
`out/SHA256SUMS` (runs diffoscope on mismatch).

Last verified pair (two trees in different directories, identical output):

    670f6a0f18d24a0c3a231eb2b78f992537bad2ab757dc49d88ee9e24cbeb81ae  bzImage
    c1de263eeeea902f818252d04f55562b86ecb5234ca9ae5d273c16bf26ddbb6e  initramfs.cpio.xz
    feeaba41923664adcd208815c920864664a4ca5fd53d85d616b221bf257d2e74  notlfs.iso

Hashes change with each commit (SOURCE_DATE_EPOCH); rerun verify-repro.sh to get current ones.
