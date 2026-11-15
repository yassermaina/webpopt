#!/usr/bin/env bash
# Test suite for webpopt. Plain Bash, no framework.
# Usage: tests/run.sh        (needs cwebp, webpinfo, dwebp, jpegtran, file)
set -u
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(dirname "$here")
webpopt="$root/bin/webpopt"
fixtures="$here/fixtures"

for dep in cwebp webpinfo dwebp jpegtran file sha256sum; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "missing test dependency: $dep (sudo dnf install libwebp-tools libjpeg-turbo-utils file)" >&2
    exit 3
  }
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
failed=0

ok()  { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
bad() { failed=$((failed + 1)); printf 'FAIL - %s\n' "$1"; }
check() { # check DESCRIPTION COMMAND...
  local d=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi
}

fresh() { # new working directory with pristine fixtures; cd into it
  w=$(mktemp -d "$tmp/case.XXXXXX")
  cp "$fixtures"/* "$w/"
  cd "$w" || exit 1
}
run()    { "$webpopt" --no-config "$@" >"$tmp/out" 2>"$tmp/err"; }
dims()   { webpinfo "$1" | awk '/^ *Width:/ {w=$2} /^ *Height:/ {h=$2} END {print w "x" h}'; }
size()   { stat -c %s "$1"; }
pixel()  { # pixel FILE first|last -> "R G B"
  dwebp "$1" -ppm -o "$tmp/px.ppm" >/dev/null 2>&1
  if [[ $2 == first ]]; then
    tail -c +$(($(head -n 3 "$tmp/px.ppm" | wc -c) + 1)) "$tmp/px.ppm" | head -c 3 | od -An -tu1
  else
    tail -c 3 "$tmp/px.ppm" | od -An -tu1
  fi | tr -s ' ' | sed 's/^ //'
}
is_red()  { local r g b; read -r r g b <<<"$1"; ((r > 200 && b < 60)); }
is_blue() { local r g b; read -r r g b <<<"$1"; ((b > 200 && r < 60)); }

# --- basic conversion -------------------------------------------------------
fresh
before=$(sha256sum photo.jpg alpha.png)
run photo.jpg alpha.png
check "converts JPEG and PNG, exit 0" test $? -eq 0
check "photo.webp created" test -s photo.webp
check "WebP is smaller than the JPEG" test "$(size photo.webp)" -lt "$(size photo.jpg)"
check "dimensions unchanged without resize" test "$(dims photo.webp)" = 320x240
check "originals untouched" test "$(sha256sum photo.jpg alpha.png)" = "$before"
check "transparency preserved" bash -c "webpinfo alpha.webp | grep -Eq 'Alpha: *1'"
check "no temp files left behind" bash -c '! ls -A | grep -q "^\.webpopt"'

# --- skip logic -------------------------------------------------------------
run photo.jpg
check "second run skips up-to-date file" grep -q "up to date" "$tmp/out"
run --force photo.jpg
check "--force re-encodes" grep -q "^ok " "$tmp/out"
run fake.jpg
check "non-image with .jpg extension is skipped, exit 0" bash -c "test $? -eq 0 && grep -q 'not a JPEG or PNG' '$tmp/out'"
check "no output for non-image" test ! -e fake.webp

fresh
run --min-savings 99 photo.jpg
check "output that is not small enough is discarded" bash -c "test ! -e photo.webp && grep -q 'not small enough' '$tmp/out'"
check "original still present" test -s photo.jpg

fresh
cp photo.jpg photo.png   # same stem, different extension (content is JPEG)
run .
check "output name collision is skipped" grep -q "output name already used" "$tmp/out"

# --- resize -----------------------------------------------------------------
fresh
run -w 100 photo.jpg
check "resize to max width keeps aspect ratio" test "$(dims photo.webp)" = 100x75
run -f -H 60 photo.jpg
check "resize to max height keeps aspect ratio" test "$(dims photo.webp)" = 80x60
run -f -w 100 -H 30 photo.jpg
check "tighter of width/height limit wins" test "$(dims photo.webp)" = 40x30
run -f -w 5000 -H 5000 photo.jpg
check "never upscales" test "$(dims photo.webp)" = 320x240

# --- orientation ------------------------------------------------------------
fresh
run rotated.jpg
check "EXIF orientation applied to pixels (32x16 -> 16x32)" test "$(dims rotated.webp)" = 16x32
check "rotated image: top is red" is_red "$(pixel rotated.webp first)"
check "rotated image: bottom is blue" is_blue "$(pixel rotated.webp last)"
run -f -w 8 rotated.jpg
check "resize uses the rotated dimensions" test "$(dims rotated.webp)" = 8x16

# --- quality / effort / config ---------------------------------------------
fresh
run -q 80 photo.jpg; s80=$(size photo.webp)
run -f -q 20 -e 2 photo.jpg; s20=$(size photo.webp)
check "lower quality gives a smaller file" test "$s20" -lt "$s80"
run -q 101 photo.jpg
check "invalid quality is a usage error (exit 2)" test $? -eq 2
run -e 7 photo.jpg
check "invalid effort is a usage error (exit 2)" test $? -eq 2
run --bogus photo.jpg
check "unknown option is a usage error (exit 2)" test $? -eq 2

fresh
printf '# project prefs\nquality = 20\nmax_width=100   # cap\n' >.webpopt.conf
"$webpopt" photo.jpg >"$tmp/out" 2>&1
check "config file is discovered and applied" test "$(dims photo.webp)" = 100x75
mkdir sub && cp photo.jpg sub/deep.jpg
(cd sub && "$webpopt" deep.jpg >/dev/null 2>&1)
check "config file is found from a sub-directory" test "$(dims sub/deep.webp)" = 100x75
"$webpopt" -f -w 50 photo.jpg >/dev/null 2>&1
check "command line overrides config" test "$(dims photo.webp)" = 50x38
"$webpopt" -f --no-config photo.jpg >/dev/null 2>&1
check "--no-config ignores the config file" test "$(dims photo.webp)" = 320x240

printf 'quality = $(touch %s/pwned)\n' "$tmp" >.webpopt.conf
"$webpopt" -f photo.jpg >/dev/null 2>&1
check "malformed config is rejected (exit 2)" test $? -eq 2
check "config file is never executed" test ! -e "$tmp/pwned"
printf 'colour = 3\n' >.webpopt.conf
"$webpopt" -f photo.jpg >/dev/null 2>&1
check "unknown config key is rejected (exit 2)" test $? -eq 2

# --- batch / output dir / odd names ----------------------------------------
fresh
mkdir -p "site/img/sub dir" out
cp photo.jpg "site/img/hero image.jpg"
cp alpha.png "site/img/sub dir/-logo.PNG"
cp photo.jpg "site/img/sub dir/shot.jpeg"
run site/img
check "non-recursive batch converts only the top level" bash -c "test -s 'site/img/hero image.webp' && test ! -e 'site/img/sub dir/shot.webp'"
run -r site/img
check "recursive batch handles spaces, dashes and upper-case extensions" \
  bash -c "test -s 'site/img/sub dir/shot.webp' && test -s 'site/img/sub dir/-logo.webp'"
run -r -o out site/img
check "--output-dir mirrors the directory structure" \
  bash -c "test -s 'out/hero image.webp' && test -s 'out/sub dir/shot.webp'"
cp photo.jpg ./-dash.jpg
run -- -dash.jpg
check "file name starting with a dash" test -s ./-dash.webp

fresh
run -n -r .
check "--dry-run writes nothing" bash -c '! ls | grep -q "\.webp$"'
check "--dry-run reports planned work" grep -q "^would " "$tmp/out"

run nope.jpg
check "missing input fails with exit 1" test $? -eq 1
run
check "no input is a usage error (exit 2)" test $? -eq 2

# --- packaging sanity -------------------------------------------------------
check "bin/webpopt and the skill script are the same file" \
  test "$root/bin/webpopt" -ef "$root/skills/webp-optimizer/scripts/webpopt"
check "SKILL.md has name and description front matter" \
  bash -c "head -n 5 '$root/skills/webp-optimizer/SKILL.md' | grep -q '^name: webp-optimizer$' && grep -q '^description: ' '$root/skills/webp-optimizer/SKILL.md'"
check "--version prints the version" bash -c "'$webpopt' --version | grep -Eq '^webpopt [0-9]+\.[0-9]+\.[0-9]+$'"

printf '\n%d passed, %d failed\n' "$pass" "$failed"
((failed == 0))
