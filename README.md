# webpopt

[![tests](https://github.com/yassermaina/webpopt/actions/workflows/tests.yml/badge.svg)](https://github.com/yassermaina/webpopt/actions/workflows/tests.yml)

A small, Fedora-first command-line tool that converts JPEG and PNG images to
optimized WebP, plus a portable **Agent Skill** so coding agents (Claude Code,
Codex CLI and other skill-compatible agents) can prepare website images the
same way.

- One Bash script on top of `cwebp` (libwebp). No ImageMagick, no runtime.
- Quality **80**, compression effort **6** by default; both configurable.
- Optional shrink-to-fit resize: no cropping, aspect ratio kept, never upscales.
- Keeps transparency, applies EXIF orientation losslessly, never touches the originals.
- Skips work that is not needed and discards a WebP that is not smaller.
- Never overwrites a `.webp` it did not create; name clashes get `photo-1.webp`, `photo-2.webp`, ….

## Install (Fedora)

```sh
curl -fsSLO https://github.com/yassermaina/webpopt/releases/download/v0.1.1/webpopt-0.1.1.tar.gz
curl -fsSLO https://github.com/yassermaina/webpopt/releases/download/v0.1.1/webpopt-0.1.1.tar.gz.sha256
sha256sum -c webpopt-0.1.1.tar.gz.sha256
tar xzf webpopt-0.1.1.tar.gz && cd webpopt-0.1.1
./install.sh --skill claude        # drop --skill to install the CLI only
```

`install.sh` copies `webpopt` to `~/.local/bin` and, if `cwebp`, `jpegtran` or
`file` is missing, installs `libwebp-tools`, `libjpeg-turbo-utils` and `file`
with `sudo dnf`. Use `--no-deps` to skip that, `--bin-dir DIR` to choose another
location, and `./install.sh --help` for the rest.

From a clone it is the same: `git clone https://github.com/yassermaina/webpopt && cd webpopt && ./install.sh`.

On other distributions install the equivalent packages yourself (`webp`,
`libjpeg-turbo-progs`/`libjpeg-turbo`, `file`) and run `./install.sh --no-deps`.

## Usage

```
webpopt [options] <file|directory>...
```

| Option | Meaning |
| --- | --- |
| `-q, --quality N` | Quality 0-100 (default 80) |
| `-e, --effort N` | Compression effort 0-6 (default 6: smallest, slowest) |
| `-w, --max-width N` | Shrink to fit this width |
| `-H, --max-height N` | Shrink to fit this height |
| `-o, --output-dir DIR` | Write `.webp` files to DIR (default: next to each source) |
| `-r, --recursive` | Recurse into sub-directories |
| `--lossless` | Lossless encoding (flat-color PNG artwork) |
| `--metadata MODE` | `none`, `icc` (default) or `all` |
| `--min-savings P` | Keep the WebP only if at least P% smaller (default 0) |
| `-f, --force` | Re-encode even when the `.webp` is up to date |
| `-n, --dry-run` | Show what would happen, write nothing |
| `--config FILE` / `--no-config` | Choose or ignore the config file |
| `-Q, --quiet` | Only warnings and errors |

Examples:

```sh
webpopt photo.jpg                      # -> photo.webp next to it
webpopt -w 1600 hero.png               # at most 1600 px wide, never upscaled
webpopt -q 70 -e 4 a.jpg b.png         # custom quality and effort
webpopt -r static/img                  # whole tree, in place
webpopt -r -o public/img src/img       # mirror the tree into another directory
webpopt -n -r .                        # dry run
```

Output:

```
ok       src/img/hero.jpg -> src/img/hero.webp  412.0K -> 118.3K (-71%)
skip     src/img/logo.png (WebP not smaller: 3.1K vs 2.4K, keep using the original)
skip     src/img/team.jpg (up to date: src/img/team.webp)
converted 1, skipped 2, failed 0, saved 293.7K of 412.0K
```

A `skip` other than "up to date" means there is no WebP for that image: keep
using the original. `--force` only bypasses the up-to-date check; it never
keeps a WebP that is not smaller.

Exit status: `0` success (skips included), `1` at least one file failed,
`2` usage or config error, `3` missing dependency.

### What it guarantees

- Originals are never modified, moved or deleted.
- A file is only converted if its content is really JPEG or PNG.
- An existing `.webp` that is newer than its source is left alone (`--force` overrides).
- A WebP that is not smaller than the source is discarded and reported as `skip`.
- Images are only ever made smaller, with the aspect ratio intact.
- JPEG EXIF orientation is baked into the pixels with a lossless `jpegtran`
  transform. If that is not possible without losing edge pixels, the image is
  skipped; nothing is ever trimmed.
- EXIF/XMP metadata (including GPS) is dropped by default; the ICC color profile is kept.
- A `.webp` that webpopt did not create is never overwritten (see below).

### Output names

The output keeps the source's name: `photo.jpg` → `photo.webp`. If that name is
not available — another source such as `photo.png` already owns it, or an
unrelated `photo.webp` is in the way — the next free name is used:
`photo-1.webp`, `photo-2.webp`, …

Each output directory gets a small text file, `.webpopt-names`, listing every
output and the source it belongs to:

```
photo.webp	photo.jpg
photo-1.webp	photo.png
```

This record is what keeps names stable: re-running, in any order and after
editing a source, always updates the same file and never creates extra copies.
Keep the file with the images and commit it. Within one run the first source
gets the plain name (directories are processed in sorted order). An existing
`<name>.webp` with no record is adopted only if it is not older than the
source (so it is not rewritten at that point); otherwise it is treated as
someone else's file and left alone.

The full behavior is specified in [CONTRACT.md](CONTRACT.md).

## Project configuration: `.webpopt.conf`

Put a `.webpopt.conf` in your project root to set preferences once, for both
you and any agent using the Skill. `webpopt` looks in the current directory and
then in each parent directory. See [examples/webpopt.conf](examples/webpopt.conf).

```ini
quality = 80
effort = 6
max_width = 1920
metadata = icc
```

Precedence: command line > config file > built-in defaults. The file is parsed
as plain `key = value` lines and is never executed.

## Agent Skill

The Skill lives in [skills/webp-optimizer](skills/webp-optimizer) and is
self-contained: `SKILL.md` plus a bundled copy of the CLI in `scripts/`. It
follows the open Agent Skills layout, does not depend on any particular project
or framework, and tells the agent when optimization is appropriate (website
JPEG/PNG) and when it is not (SVG, GIF, icons, existing pipelines, …).

### Install the Skill

| Scope | Claude Code | Codex CLI / other agents |
| --- | --- | --- |
| Global (all projects) | `./install.sh --skill claude` → `~/.claude/skills/` | `./install.sh --skill codex` → `~/.codex/skills/`, or `--skill agents` → `~/.agents/skills/` |
| One project | `./install.sh --skill /path/to/project/.claude/skills` | `./install.sh --skill /path/to/project/.agents/skills` (or `.codex/skills`) |

Manual install is a plain copy: `cp -r skills/webp-optimizer <skills-dir>/`.
Skill directory locations differ between agents and versions; if yours is not
listed, check its documentation and pass the directory to `--skill`.

Verified for 0.1.1: Claude Code 2.1 discovers the Skill in a project's
`.claude/skills`; Codex CLI 0.169 discovers it in `~/.codex/skills`,
`~/.agents/skills` and a project's `.codex/skills` and `.agents/skills`.

### Encouraging automatic use

Agents decide on their own whether to load a Skill, based on its description.
**Automatic activation is not guaranteed.** To make it more likely, add a short
rule to the project instructions the agent always reads (`CLAUDE.md` for Claude
Code, `AGENTS.md` for Codex CLI and others). A ready-to-paste snippet is in
[examples/project-instructions.md](examples/project-instructions.md):

```markdown
## Images
When adding or replacing JPEG/PNG images used on web pages, use the
`webp-optimizer` skill to create WebP versions before referencing them.
Preferences are in `.webpopt.conf`. Keep the original files.
```

You can always invoke it explicitly, e.g. "use the webp-optimizer skill on
`static/img/hero.jpg`" (or `/webp-optimizer` in Claude Code).

## Tests

```sh
tests/run.sh
```

Plain Bash, no framework. Needs `cwebp`, `webpinfo`, `dwebp` (all in
`libwebp-tools`), `jpegtran` and `file`. GitHub Actions runs ShellCheck and
this suite in a Fedora container on every push.

## Uninstall

```sh
rm -f ~/.local/bin/webpopt
rm -rf ~/.claude/skills/webp-optimizer ~/.codex/skills/webp-optimizer ~/.agents/skills/webp-optimizer
# per-project copies, if any:  rm -rf <project>/.claude/skills/webp-optimizer
# optional, only if nothing else needs them:
sudo dnf remove libwebp-tools libjpeg-turbo-utils
```

`webpopt` keeps nothing outside your projects. Generated `.webp` files and the
`.webpopt-names` and `.webpopt.conf` files next to them are yours and are left alone.

## Limitations

- Input formats are JPEG and PNG only; animated PNG is skipped.
- A JPEG with an EXIF rotation whose size is not a multiple of its block size
  (8 or 16 px) cannot be rotated losslessly. It is skipped and the original
  stays in use; rotate it in an image editor first if you need a WebP.
- EXIF orientation stored inside a PNG is ignored.
- Output names depend on `.webpopt-names`. If that file is deleted, outputs
  older than their source are no longer recognized and get a new suffixed name
  on the next run (nothing is overwritten).
- Renaming or moving a source leaves its old `.webp` and record behind.
- File names containing a tab or newline are rejected.
- A source whose WebP was discarded as not smaller is re-encoded and discarded
  again on every run.
- Files are processed one at a time (cwebp itself is multi-threaded).

## License

[MIT](LICENSE)
