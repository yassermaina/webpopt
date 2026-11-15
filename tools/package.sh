#!/usr/bin/env bash
# Build dist/webpopt-<version>.tar.gz and its SHA-256 checksum from HEAD.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

version=$(sed -n 's/^VERSION="\(.*\)"$/\1/p' skills/webp-optimizer/scripts/webpopt)
[[ -n $version ]] || { echo "cannot read VERSION" >&2; exit 1; }

name="webpopt-$version"
mkdir -p dist
git archive --format=tar.gz --prefix="$name/" -o "dist/$name.tar.gz" HEAD
(cd dist && sha256sum "$name.tar.gz" >"$name.tar.gz.sha256")
echo "dist/$name.tar.gz"
cat "dist/$name.tar.gz.sha256"
