# Project Contract

This document defines what `webpopt` and the `webp-optimizer` Skill do, what
they must never do, and how the project is developed. Changes that break a rule
here require changing this file in the same commit and a major version bump.

## 1. Purpose and scope

Convert JPEG and PNG images to optimized WebP for websites, from the command
line and through a portable Agent Skill.

In scope: single files and batches, optional shrink-to-fit resize, a
project-level preference file, a Fedora installer, the Skill.

Out of scope: other input or output formats (AVIF, GIF, SVG, animation),
cropping or art direction, editing HTML/CSS, watch mode, daemons, GUIs,
network access, telemetry, parallel job scheduling.

## 2. Behavior

1. **Defaults**: quality 80, effort 6 (`cwebp -q 80 -m 6`), ICC profile kept,
   other metadata dropped, output next to the source as `<stem>.webp`.
   Output naming is defined in section 3.
2. **Precedence**: command line > `.webpopt.conf` > built-in defaults. The
   config key `output_dir` is a relative path (no `..`) resolved against the
   config file's directory; `-o` overrides it. `--init` writes a starter
   `.webpopt.conf` in the current directory and never overwrites one.
3. **Input detection** is by file content (`file --mime-type`), not extension.
   Directory scans consider `*.jpg`, `*.jpeg`, `*.png` (any case), skip `.git`
   and `node_modules`, do not follow symlinks, and recurse only with `-r`.
4. **Resize** only shrinks, to fit inside `max_width` × `max_height`, keeping
   the aspect ratio. No cropping, no upscaling. If the dimensions cannot be
   read while a limit is set, the file fails rather than being resized blindly.
5. **Transparency** is preserved (cwebp alpha).
6. **Orientation**: a JPEG EXIF orientation other than "normal" is applied to
   the pixels with a perfect lossless `jpegtran` transform before encoding.
   If a perfect transform is impossible (size not a multiple of the JPEG block
   size) the image is skipped. Pixels are never trimmed, and an image is never
   written un-rotated. If `jpegtran` is missing, that file fails.
7. **Skips** (not errors): not a JPEG/PNG, animated PNG, output up to date
   (output exists and source is not newer), orientation cannot be applied
   losslessly, WebP not smaller than the source by at least `min_savings` %.
   Every skip except "up to date" means no WebP exists for that source and
   the original stays in use. `--force` bypasses only the up-to-date check.
8. **Exit status**: 0 ok (skips included), 1 at least one file failed,
   2 usage/config error, 3 missing dependency.
9. **Output lines** start with `ok`, `skip`, `would` or `FAILED`, followed by
   a one-line summary. Errors go to stderr.

## 3. Output names

1. The output keeps the source's stem: `<stem>.webp`. If that name is not
   available the first free name of `<stem>-1.webp`, `<stem>-2.webp`, … is used.
2. Every output is recorded in `<output dir>/.webpopt-names` as
   `name<TAB>source`, the source path being relative to that directory. A
   source with a record always maps to its recorded name, in every later run,
   regardless of argument order, `--force` or changes to the source.
3. A name is unavailable when it is recorded for another source, when a file
   of that name exists without a record, or (for suffixed names) when a source
   with exactly that stem exists next to the source being converted.
4. Exception to 3, for upgrades and hand-made outputs: an unrecorded plain
   `<stem>.webp` that is not older than the source is adopted and recorded. It
   is up to date at that moment, so adoption itself rewrites nothing.
5. Within one run names are assigned in processing order: arguments left to
   right, directory contents sorted bytewise.
6. Only recorded outputs are ever replaced. An existing file without a record
   is never overwritten, with or without `--force`.
7. The record is plain text, appended to, never executed. File names
   containing a tab or newline cannot be recorded and are rejected.

## 4. Safety rules

1. Source files are opened read-only. They are never modified, renamed, moved
   or deleted, by the CLI or by the Skill.
2. Output is written to a temporary file in the destination directory and
   moved into place only after `cwebp` succeeded and the size check passed. A
   failed or rejected run leaves no partial `.webp` and no temp files.
3. A WebP that is not smaller than its source is discarded.
4. An existing `.webp` is replaced only by a successful, smaller re-encode of
   a newer source, or with `--force`.
5. The config file is parsed, never sourced or evaluated. Only known keys with
   validated values are accepted; anything else aborts with exit 2.
6. All paths are quoted and passed after `--` or with a `./` prefix; file
   names with spaces or leading dashes must work.
7. No network access, no `sudo`, no `eval`, no writes outside the destination
   directory and `$TMPDIR`. Only `install.sh` may call `sudo dnf`, and only for
   missing packages.
8. The Skill never deletes originals, never bulk-converts beyond the task, and
   never installs system packages on its own. After any skip other than
   "up to date" it keeps using the original image and does not try to obtain
   a WebP by other means.

## 5. Boundaries

- Runtime dependencies: `bash` ≥ 4.4, coreutils/findutils, `cwebp`, `file`;
  `jpegtran` only for rotated JPEGs. Adding a dependency needs a strong reason
  and an update here. ImageMagick, GraphicsMagick, ffmpeg, Python, Node are
  not acceptable runtime dependencies.
- The CLI is one file: `skills/webp-optimizer/scripts/webpopt`.
  `bin/webpopt` is a symlink to it so the Skill stays self-contained.
- The Skill is agent-neutral: no project-specific or vendor-specific
  assumptions in `SKILL.md` beyond the standard `name`/`description` front
  matter. User preferences belong in `.webpopt.conf`, not in the Skill.
- Fedora is the reference platform. Other Linux distributions should work but
  are not tested.

## 6. Development conventions

- Keep it small. Prefer deleting to adding; no feature without a test.
- Bash style: `set -u`, `[[ ]]`, arrays for argument lists, quoted expansions,
  two-space indent, ShellCheck-clean (enforced in CI).
- Every behavior change updates `tests/run.sh`, `README.md`, `SKILL.md` and
  this contract as needed, in the same commit.
- `tests/run.sh` and ShellCheck must pass before every commit and release;
  `.github/workflows/tests.yml` runs both in a Fedora container.
- Versioning: SemVer. The single source of truth is `VERSION=` in the script.
  Release = bump version, update `PROJECT_STATUS.md`, tag `vX.Y.Z`,
  `tools/package.sh`, publish the tarball and its `.sha256` as a GitHub Release.
- English for code, comments, commits and documentation.
- Never commit credentials, private data or machine-specific paths.
