# Project Status

**Version:** 0.1.1 (2026-11-15) — final maintenance release.
**State:** complete and released; no work in progress.

## Releases

- **0.1.1** — EXIF rotation is lossless-only (images that cannot be rotated
  without losing pixels are skipped, never trimmed); name clashes get
  `-1`, `-2`, … suffixes recorded in `.webpopt-names`; unrelated `.webp`
  files are never overwritten; clearer skip messages; larger regression
  suite; ShellCheck and GitHub Actions CI.
- **0.1.0** — first release: CLI, Agent Skill, installer, tests, docs.

## Skill integration checks (0.1.1)

- Claude Code 2.1.325: Skill discovered from a project's `.claude/skills`,
  and invoked on its own for an "add these images to the page" task that did
  not mention it. One run; automatic invocation is not guaranteed.
- Codex CLI 0.169.0: Skill discovered from a project's `.agents/skills`; the
  same listing shows Codex also reads `~/.codex/skills`, `~/.agents/skills`
  and a project's `.codex/skills`.

## Resume from a fresh clone

```sh
git clone https://github.com/yassermaina/webpopt && cd webpopt
sudo dnf install libwebp-tools libjpeg-turbo-utils file ShellCheck
tests/run.sh
```

Publishing needs the GitHub CLI authenticated as the repository owner
(`gh auth login`). Nothing else is machine-specific.

## Known limitations

See "Limitations" in `README.md`.

## Ideas, not commitments

- Parallel batch processing (`-j`).
- Pixel-exact rotation for JPEGs whose size is not a multiple of the block size.
- A `--prune` mode to drop records and outputs of deleted sources.
