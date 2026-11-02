# Reproducible builds

Every download is pinned by sha256 in `files/sources.sha256`; `build.sh` aborts on mismatch.
Go (go1.27.3) and Rust (1.85.1) are pinned. `SOURCE_DATE_EPOCH` = last commit time.
The build re-execs inside `unshare -rm` with the tree bind-mounted at `/mnt/notlfs`, so
paths are identical regardless of checkout location. cpio is sorted/`--reproducible`,
mtimes clamped, `xz -T1`; xorriso uses a fixed modification date. Kernel uses fixed
`KBUILD_BUILD_*` and no modules (no random signing key).

Verify: `./verify-repro.sh` builds two clones in different directories and compares
`out/SHA256SUMS` (runs diffoscope on mismatch).

Output hashes change with each commit (SOURCE_DATE_EPOCH), so none are listed here;
run `./verify-repro.sh` to check the current commit.
