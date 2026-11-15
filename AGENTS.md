# AGENTS.md

Instructions for coding agents (and humans) working **on this repository**.
To *use* the optimizer in another project, see the README instead.

## Read first

1. `CONTRACT.md` — binding behavior, safety rules and boundaries.
2. `PROJECT_STATUS.md` — current state and what is next.

## Layout

```
skills/webp-optimizer/SKILL.md          the Agent Skill
skills/webp-optimizer/scripts/webpopt   the CLI (single source of truth)
bin/webpopt                             symlink to the CLI
install.sh                              Fedora installer (CLI + optional Skill)
tools/package.sh                        builds dist/webpopt-<version>.tar.gz + .sha256
tests/run.sh, tests/fixtures/           test suite and its tiny images
.github/workflows/tests.yml             CI: ShellCheck + tests in a Fedora container
examples/                               sample .webpopt.conf and project instructions
```

## Setup and commands

```sh
sudo dnf install libwebp-tools libjpeg-turbo-utils file ShellCheck   # once
tests/run.sh                                              # must pass before committing
shellcheck skills/webp-optimizer/scripts/webpopt install.sh tools/package.sh tests/run.sh
bin/webpopt --help
tools/package.sh                                          # release tarball in dist/
```

## Rules

- Stay inside the scope in `CONTRACT.md`. Do not add dependencies, formats or
  features that are listed as out of scope.
- Edit the CLI only at `skills/webp-optimizer/scripts/webpopt`; never replace
  the `bin/webpopt` symlink with a copy.
- A behavior change needs a test and matching updates to `README.md`,
  `SKILL.md` and `CONTRACT.md`.
- Keep `SKILL.md` short and agent-neutral.
- Test fixtures are small generated images; regenerate rather than adding
  large or personal photos.
- No credentials, private data or absolute machine paths in the repository.
- Commits, comments and docs in English. Update `PROJECT_STATUS.md` when the
  state of the project changes.

## Release checklist

1. Bump `VERSION=` in the CLI; update `README.md` install URLs and `PROJECT_STATUS.md`.
2. `tests/run.sh` and ShellCheck
3. Commit, push, wait for CI to pass, then `git tag vX.Y.Z` and push the tag.
4. `tools/package.sh`
5. `gh release create vX.Y.Z dist/webpopt-X.Y.Z.tar.gz dist/webpopt-X.Y.Z.tar.gz.sha256`
6. Download the published assets and check them with `sha256sum -c`.

Never move or re-create an existing tag or replace the assets of a published
release; fix forward with a new version.
