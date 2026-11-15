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

Test: a throwaway project with the Skill installed per project and the task
"Add img/hero.jpg as the hero image and img/icon.png as a small icon to
index.html" (the Skill is not mentioned). One run per agent.

- Claude Code 2.1.325 (`.claude/skills`): Skill listed at start-up and invoked
  on its own; hero converted, icon kept as PNG after the "not smaller" skip.
- Codex CLI 0.169.0 (`.agents/skills`): Skill listed, read and used on its
  own, with the same result. Codex's skill roots also include
  `~/.codex/skills`, `~/.agents/skills` and a project's `.codex/skills`.
- Not tested: global installs (`--skill claude|codex|agents`) end to end.
  Automatic invocation remains the agent's decision and is not guaranteed.

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
