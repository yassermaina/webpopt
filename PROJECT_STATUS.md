# Project Status

**Version:** 0.1.0 (first release, 2026-11-15)
**State:** complete and released; no work in progress.

## Done

- `webpopt` CLI: JPEG/PNG → WebP, batch and recursive modes, shrink-to-fit
  resize, EXIF orientation, skip logic, `.webpopt.conf`, dry run.
- `webp-optimizer` Agent Skill with bundled CLI.
- Fedora installer, release packaging script, test suite (`tests/run.sh`).
- Documentation: README, CONTRACT, AGENTS.

## Resume from a fresh clone

```sh
git clone https://github.com/yassermaina/webpopt && cd webpopt
sudo dnf install libwebp-tools libjpeg-turbo-utils file
tests/run.sh
```

Publishing needs the GitHub CLI authenticated as the repository owner
(`gh auth login`). Nothing else is machine-specific.

## Known limitations

See "Limitations" in `README.md`.

## Ideas, not commitments

- CI workflow running `tests/run.sh` and `shellcheck` in a Fedora container.
- Parallel batch processing (`-j`).
- Pixel-exact rotation for JPEGs whose size is not a multiple of the block size.

`shellcheck` was not available when 0.1.0 was built; run it once it is installed.
