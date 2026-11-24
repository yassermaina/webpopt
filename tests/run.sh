#!/usr/bin/env bash
# Test suite for webpopt. Plain Bash, no framework.
# Usage: tests/run.sh        (needs cwebp, webpinfo, dwebp, jpegtran, file)
# shellcheck disable=SC2016  # check ... eval '...' is expanded later on purpose
set -u
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(dirname "$here")
webpopt="$root/bin/webpopt"
fixtures="$here/fixtures"

for dep in cwebp webpinfo dwebp jpegtran file sha256sum; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "missing test dependency: $dep (Fedora: sudo dnf install libwebp-tools libjpeg-turbo-utils file; Arch/CachyOS: sudo pacman -S libwebp-utils libjpeg-turbo file)" >&2
    exit 3
  }
done

tmp=$(mktemp -d)
trap 'chmod -R u+rwx "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT
pass=0
failed=0
rc=0

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
run()    { "$webpopt" --no-config "$@" >"$tmp/out" 2>"$tmp/err"; rc=$?; return "$rc"; }
dims()   { webpinfo "$1" 2>/dev/null | awk '/^ *Width:/ {w=$2} /^ *Height:/ {h=$2} END {print w "x" h}'; }
size()   { stat -c %s "$1"; }
sums()   { sha256sum "$@" 2>&1; }
said()   { grep -Eq -- "$1" "$tmp/out"; }      # stdout of the last run matches
warned() { grep -Eq -- "$1" "$tmp/err"; }      # stderr of the last run matches
outputs() { find . \( -name '*.webp' -o -name '.webpopt*' \) | sort | tr '\n' ' '; }
no_temp() { ! find . -name '.webpopt.????????' | grep -q .; }
pixel()  { # pixel FILE first|last -> "R G B"
  dwebp "$1" -ppm -o "$tmp/px.ppm" >/dev/null 2>&1
  if [[ $2 == first ]]; then
    tail -c +$(($(head -n 3 "$tmp/px.ppm" | wc -c) + 1)) "$tmp/px.ppm" | head -c 3 | od -An -tu1
  else
    tail -c 3 "$tmp/px.ppm" | od -An -tu1
  fi | tr -s ' ' | sed 's/^ //'
}
is_red()  { local r b; read -r r _ b <<<"$1"; ((r > 200 && b < 60)); }
is_blue() { local r b; read -r r _ b <<<"$1"; ((b > 200 && r < 60)); }
is_color() { "is_$1" "$2"; }
set_byte() { printf '%b' "\\x$(printf '%02x' "$3")" | dd of="$1" bs=1 seek="$2" conv=notrunc 2>/dev/null; }

# --- basic conversion and source preservation ------------------------------
fresh
before=$(sums photo.jpg alpha.png)
run photo.jpg alpha.png
check "converts JPEG and PNG, exit 0" test "$rc" -eq 0
check "photo.webp created" test -s photo.webp
check "WebP is smaller than the JPEG" test "$(size photo.webp)" -lt "$(size photo.jpg)"
check "dimensions unchanged without resize" test "$(dims photo.webp)" = 320x240
check "originals untouched" test "$(sums photo.jpg alpha.png)" = "$before"
check "transparency preserved" bash -c "webpinfo alpha.webp | grep -Eq 'Alpha: *1'"
check "no temp files left behind" no_temp

# --- repeated runs ----------------------------------------------------------
made=$(sums photo.webp alpha.webp)
run photo.jpg alpha.png
check "second run skips up-to-date files" said "^skip .*photo.jpg .*up to date"
check "second run rewrites nothing" test "$(sums photo.webp alpha.webp)" = "$made"
run -r .
check "directory rerun adds no new outputs for converted files" test ! -e photo-1.webp -a ! -e alpha-1.webp
run --force photo.jpg
check "--force re-encodes" said "^ok "
touch -d '+2 seconds' photo.jpg
run -q 30 photo.jpg
check "changed source is re-encoded into the same output" \
  bash -c "test ! -e photo-1.webp && test \"\$(sha256sum photo.webp)\" != '$(printf '%s\n' "$made" | head -n 1)'"
check "originals untouched after reruns" test "$(sums alpha.png)" = "$(printf '%s\n' "$before" | tail -n 1)"
run fake.jpg
check "non-image with .jpg extension is skipped, exit 0" test "$rc" -eq 0
check "non-image skip is reported" said "not a JPEG or PNG"
check "no output for non-image" test ! -e fake.webp

# --- compression skips: an ineffective WebP is never kept --------------------
fresh
before=$(sums tiny.png)
run tiny.png
check "WebP that is not smaller: exit 0" test "$rc" -eq 0
check "WebP that is not smaller: clear skip" said "^skip .*WebP not smaller.*keep using the original"
check "WebP that is not smaller: nothing written" test -z "$(outputs)"
check "WebP that is not smaller: source untouched" test "$(sums tiny.png)" = "$before"
run --force tiny.png
check "--force does not keep an inferior WebP either" test -z "$(outputs)"
check "--force still reports the skip" said "^skip "
run tiny.png
check "compression skip is repeatable" test -z "$(outputs)"
run --min-savings 99 photo.jpg
check "--min-savings: insufficient saving is discarded" test ! -e photo.webp
check "--min-savings: reason is reported" said "saves less than 99%"
check "original still present" test -s photo.jpg
run photo.jpg
old=$(sums photo.webp)
touch -d '+2 seconds' photo.jpg
run --min-savings 99 photo.jpg
check "rejected re-encode leaves the previous output alone" test "$(sums photo.webp)" = "$old"
check "rejected re-encode flags the stale output" said "out of date"

# --- output name collisions -------------------------------------------------
fresh
cp alpha.png photo.png             # same stem as photo.jpg, different image
before=$(sums photo.jpg photo.png)
run photo.jpg photo.png
check "colliding sources get photo.webp and photo-1.webp" \
  test "$(outputs)" = "./.webpopt-names ./photo-1.webp ./photo.webp "
check "first source keeps the plain name" test "$(dims photo.webp)" = 320x240
check "second source gets the suffix" test "$(dims photo-1.webp)" = 200x120
check "collision sources untouched" test "$(sums photo.jpg photo.png)" = "$before"
made=$(sums photo.webp photo-1.webp)
run photo.png photo.jpg            # other order
check "rerun in another order is a no-op" test "$(sums photo.webp photo-1.webp)" = "$made"
check "rerun reports both as up to date" test "$(grep -c 'up to date' "$tmp/out")" = 2
check "rerun creates no extra names" test "$(outputs)" = "./.webpopt-names ./photo-1.webp ./photo.webp "
touch -d '+2 seconds' photo.png
run -q 30 photo.png
check "changed source is re-encoded under its own name" said "photo.png -> ./photo-1.webp"
check "the other output is not touched" \
  test "$(sums photo.webp)" = "$(printf '%s\n' "$made" | head -n 1)"
run -f .
check "--force directory run keeps the same names" \
  test ! -e photo-2.webp -a "$(dims photo.webp)" = 320x240 -a "$(dims photo-1.webp)" = 200x120

fresh
rm -f fake.jpg odd-rotated.jpg rotated.jpg tiny.png alpha.png
cp "$fixtures/alpha.png" photo.png
run .
check "directory scan names collisions deterministically (sorted)" \
  test "$(dims photo.webp)" = 320x240 -a "$(dims photo-1.webp)" = 200x120

fresh
cp alpha.png photo.png
cp photo.jpg photo-1.jpg
run photo.jpg photo.png photo-1.jpg
check "suffix never takes the name of a real photo-1 source" \
  test "$(dims photo-1.webp)" = 320x240 -a "$(dims photo-2.webp)" = 200x120

fresh
printf 'someone else made this\n' >photo.webp
touch -d '-1 hour' photo.webp
printf 'and this\n' >photo-1.webp
theirs=$(sums photo.webp photo-1.webp)
run photo.jpg
check "unrelated existing .webp files are never overwritten" test "$(sums photo.webp photo-1.webp)" = "$theirs"
check "the source gets the next free name instead" test "$(dims photo-2.webp)" = 320x240
run -f photo.jpg
check "still not overwritten with --force" test "$(sums photo.webp photo-1.webp)" = "$theirs"
check "and no further names appear" test ! -e photo-3.webp

fresh
mkdir a b out
cp photo.jpg a/photo.jpg
cp alpha.png b/photo.png
run -o out a/photo.jpg b/photo.png
check "collision across directories into one --output-dir" \
  test "$(dims out/photo.webp)" = 320x240 -a "$(dims out/photo-1.webp)" = 200x120
touch -d '+2 seconds' b/photo.png
run -o out b/photo.png
check "later single-file run still maps to its own output" \
  test "$(dims out/photo.webp)" = 320x240 -a "$(dims out/photo-1.webp)" = 200x120 -a ! -e out/photo-2.webp

fresh
run photo.jpg
rm .webpopt-names                  # e.g. outputs made by webpopt 0.1.0
made=$(sums photo.webp)
run photo.jpg
check "up-to-date output without a record is adopted" said "up to date"
check "adopted output is not duplicated or rewritten" test ! -e photo-1.webp -a "$(sums photo.webp)" = "$made"
check "adoption is recorded" grep -q "^photo.webp	photo.jpg$" .webpopt-names

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
# rotated.jpg is 32x16 (left half red, right half blue) with the EXIF
# orientation value at byte offset 30. Check all eight values.
fresh
for spec in 1:32x16:red:blue 2:32x16:blue:red 3:32x16:blue:red 4:32x16:red:blue \
            5:16x32:red:blue 6:16x32:red:blue 7:16x32:blue:red 8:16x32:blue:red; do
  IFS=: read -r o d first last <<<"$spec"
  cp rotated.jpg "o$o.jpg"
  set_byte "o$o.jpg" 30 "$o"
  run "o$o.jpg"
  check "orientation $o: size $d" test "$(dims "o$o.webp")" = "$d"
  check "orientation $o: starts $first, ends $last" \
    eval 'is_color "$first" "$(pixel "o$o.webp" first)" && is_color "$last" "$(pixel "o$o.webp" last)"'
done
run -f -w 8 rotated.jpg
check "resize uses the rotated dimensions" test "$(dims rotated.webp)" = 8x16

# odd-rotated.jpg is 40x20 with orientation 6: 20 is not a multiple of the JPEG
# block size, so it cannot be rotated without dropping edge pixels. It must be
# skipped, never trimmed.
fresh
before=$(sums odd-rotated.jpg)
run odd-rotated.jpg
check "non-lossless rotation: exit 0" test "$rc" -eq 0
check "non-lossless rotation: clear skip" said "^skip .*without losing edge pixels.*keep using the original"
check "non-lossless rotation: nothing written" test -z "$(outputs)"
check "non-lossless rotation: source untouched" test "$(sums odd-rotated.jpg)" = "$before"
run -n odd-rotated.jpg
check "--dry-run predicts the rotation skip" said "^skip .*without losing edge pixels"
run -f -w 10 odd-rotated.jpg
check "still skipped with --force and resize" test -z "$(outputs)"
cp odd-rotated.jpg plain.jpg
set_byte plain.jpg 31 1            # big-endian EXIF: value byte at offset 31
run plain.jpg
check "same image without rotation converts at full size" test "$(dims plain.webp)" = 40x20

# --- quality / effort / config ---------------------------------------------
fresh
run -q 80 photo.jpg; s80=$(size photo.webp)
run -f -q 20 -e 2 photo.jpg; s20=$(size photo.webp)
check "lower quality gives a smaller file" test "$s20" -lt "$s80"
run -q 101 photo.jpg
check "invalid quality is a usage error (exit 2)" test "$rc" -eq 2
run -e 7 photo.jpg
check "invalid effort is a usage error (exit 2)" test "$rc" -eq 2
run --bogus photo.jpg
check "unknown option is a usage error (exit 2)" test "$rc" -eq 2
run -q
check "option without a value is a usage error (exit 2)" test "$rc" -eq 2

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
check "non-recursive batch converts only the top level" \
  test -s "site/img/hero image.webp" -a ! -e "site/img/sub dir/shot.webp"
run -r site/img
check "recursive batch handles spaces, dashes and upper-case extensions" \
  test -s "site/img/sub dir/shot.webp" -a -s "site/img/sub dir/-logo.webp"
run -r -o out site/img
check "--output-dir mirrors the directory structure" \
  test -s "out/hero image.webp" -a -s "out/sub dir/shot.webp"
cp photo.jpg ./-dash.jpg
run -- -dash.jpg
check "file name starting with a dash" test -s ./-dash.webp

fresh
run -n -r .
check "--dry-run writes nothing" test -z "$(outputs)"
check "--dry-run reports planned work" said "^would "

# --- error handling ---------------------------------------------------------
fresh
run nope.jpg
check "missing input fails with exit 1" test "$rc" -eq 1
run nope.jpg photo.jpg
check "a failure does not stop the remaining files" test "$rc" -eq 1 -a -s photo.webp
head -c 2000 photo.jpg >broken.jpg
run broken.jpg
check "corrupt JPEG fails with exit 1" test "$rc" -eq 1
check "corrupt JPEG is reported and leaves no output" eval 'warned "FAILED .*broken.jpg" && test ! -e broken.webp'
check "failed run leaves no temp files" no_temp
tabbed=$(printf 'tab\tname.jpg')
cp photo.jpg "$tabbed"
run "$tabbed"
check "file name with a tab is rejected (exit 1), nothing written" \
  eval 'test "$rc" -eq 1 && warned "tabs or newlines" && test ! -e "${tabbed%.jpg}.webp"'
if [[ $(id -u) -ne 0 ]]; then
  mkdir ro && cp alpha.png ro/ && chmod 555 ro
  run ro/alpha.png
  check "unwritable directory fails with exit 1" test "$rc" -eq 1
  chmod 755 ro
  cp alpha.png secret.png && chmod 000 secret.png
  run secret.png
  check "unreadable file fails with exit 1" test "$rc" -eq 1
fi
PATH=/nonexistent "$BASH" "$webpopt" --no-config photo.jpg >/dev/null 2>&1
check "missing cwebp is reported with exit 3" test $? -eq 3
run
check "no input is a usage error (exit 2)" test "$rc" -eq 2

# --- packaging sanity -------------------------------------------------------
check "bin/webpopt and the skill script are the same file" \
  test "$root/bin/webpopt" -ef "$root/skills/webp-optimizer/scripts/webpopt"
check "SKILL.md has a name in its front matter" \
  eval 'head -n 5 "$root/skills/webp-optimizer/SKILL.md" | grep -q "^name: webp-optimizer$"'
check "SKILL.md has a description in its front matter" \
  grep -q '^description: ' "$root/skills/webp-optimizer/SKILL.md"
check "--version prints the version" \
  eval '"$webpopt" --version | grep -Eq "^webpopt [0-9]+\.[0-9]+\.[0-9]+$"'

printf '\n%d passed, %d failed\n' "$pass" "$failed"
((failed == 0))
