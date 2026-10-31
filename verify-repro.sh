#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Build notlfs twice from clean, in two different directories, and compare the results.
#   ./verify-repro.sh [workdir]      (default: /tmp/notlfs-repro; needs ~25 GB and a few hours)
# Both builds share the verified download cache ($NOTLFS_DL, default ./dl). On a mismatch it runs
# diffoscope (if installed) and writes the report to workdir/diffoscope.txt.
set -eu
W=${1:-/tmp/notlfs-repro}
SRC=$(cd "$(dirname "$0")" && pwd)
export NOTLFS_DL=${NOTLFS_DL:-$SRC/dl} SOURCE_DATE_EPOCH=$(git -C "$SRC" log -1 --format=%ct)
rm -rf "$W" && mkdir -p "$W"
for d in one two/deeper/path; do
  git clone -q "$SRC" "$W/$d"
  (cd "$W/$d" && sh ./build.sh > "$W/build-${d%%/*}.log" 2>&1) || { echo "build in $W/$d failed, see $W/build-${d%%/*}.log"; exit 1; }
done
A="$W/one/out" B="$W/two/deeper/path/out"
cat "$A/SHA256SUMS"
if cmp -s "$A/SHA256SUMS" "$B/SHA256SUMS"; then echo "REPRODUCIBLE: both builds are bit-for-bit identical"; exit 0; fi
echo "NOT REPRODUCIBLE:"; diff "$A/SHA256SUMS" "$B/SHA256SUMS" || :
command -v diffoscope >/dev/null && diffoscope --text "$W/diffoscope.txt" "$A/notlfs.iso" "$B/notlfs.iso" || :
exit 1
