# Project instruction snippet

Paste this into the instruction file your agent always reads — `CLAUDE.md` for
Claude Code, `AGENTS.md` for Codex CLI and most other agents. It makes it more
likely, but does not guarantee, that the agent uses the Skill on its own.

```markdown
## Images

- When adding or replacing JPEG/PNG images used on web pages, use the
  `webp-optimizer` skill to create WebP versions. In WordPress/NativePress sites,
  keep originals outside the theme, import the `.webp` into the Media Library as
  an attachment and use the attachment ID.
- Optimization preferences are in `.webpopt.conf`; do not override them unless asked.
- Keep the original files. Do not convert SVG, GIF, favicons or social-card images.
```
