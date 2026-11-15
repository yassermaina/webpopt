---
name: webp-optimizer
description: Convert JPEG/PNG images to optimized WebP for websites with the bundled webpopt CLI (Bash + cwebp), optionally shrinking oversized images. Use when adding, replacing or preparing raster images (photos, hero images, screenshots, thumbnails, PNG graphics) for a web page or site, or when asked to optimize, compress, resize or convert site images. Do not use for SVG, GIF or animated images, favicons and app icons, files that are already WebP/AVIF, or images whose format must stay unchanged (email, Open Graph, print, downloads).
---

# WebP Optimizer

Turn JPEG/PNG website images into smaller WebP files using `webpopt`, a small
Bash wrapper around `cwebp`. Originals are never modified or deleted.

## When to optimize

Optimize when all of these hold:

- The image is a JPEG or PNG that will be served on a web page.
- The page can reference a `.webp` file (you are writing or may edit the markup,
  CSS or content that points at it).
- The user has not asked to keep the original format.

Do not optimize — and say why in one line if it is relevant — when:

- The file is SVG, GIF, animated PNG, ICO, already WebP/AVIF, or not an image.
- It is a favicon, app icon, Open Graph/Twitter card image, email image, print
  asset or a file offered for download (these often need PNG/JPEG).
- It lives in a vendored, generated or third-party directory (`node_modules`,
  build output, a theme or plugin you do not own).
- The project already has an image pipeline that produces WebP/AVIF (framework
  image component, build plugin, CDN). Use that pipeline instead.

If unsure whether optimization is wanted, ask once instead of guessing.

## How to run it

1. Locate the CLI: use `webpopt` if it is on `PATH`, otherwise the copy bundled
   with this skill at `scripts/webpopt` (relative to this file).
   It needs `cwebp` and `file`; `jpegtran` is needed only for rotated JPEGs.
   If `cwebp` is missing, tell the user to install it
   (Fedora: `sudo dnf install libwebp-tools libjpeg-turbo-utils`) — do not
   install system packages yourself and do not fall back to another tool.
2. Respect project preferences: `webpopt` automatically reads `.webpopt.conf`
   from the working directory or a parent. Run from inside the project and do
   not repeat or override its values unless the user asks for something else.
3. Preview, then convert only the images involved in the current task:

   ```sh
   webpopt --dry-run path/to/image.jpg          # preview
   webpopt path/to/image.jpg                    # -> path/to/image.webp
   webpopt -w 1600 path/to/hero.png             # cap width, never upscales
   webpopt -r -o public/img src/img             # batch into another directory
   ```

   Without a config file the defaults are quality 80 and effort 6. Choose a
   `--max-width` only when you know the largest size the image is displayed at
   (use about twice the CSS width for high-density screens). Use `--lossless`
   for flat-color PNG artwork if the lossy result shows artifacts.
4. Read the output. Each file is reported as `ok`, `skip` (with the reason) or
   `FAILED`. A `skip ... not small enough` means the original is already the
   better file: keep referencing the original and move on.
5. Point the page at the new `.webp` only for files reported `ok`, and only in
   files that belong to the current task. Keep `width`/`height` attributes in
   sync with the real dimensions if the image was resized.
6. Report briefly: which files were converted, the size change, and anything
   skipped or failed.

Run `webpopt --help` for the full option list.

## Rules

- Never delete, move, overwrite or re-compress the original JPEG/PNG. Removing
  originals is the user's decision.
- Never bulk-convert a whole repository unprompted; stay within the images the
  task touches unless the user asks for a wider pass.
- Do not edit `.webpopt.conf` unless asked; it holds the user's preferences.
- Do not rewrite references in files outside the task's scope.
- Do not substitute ImageMagick, ffmpeg or online services for `webpopt`.

## Project preferences (`.webpopt.conf`)

Optional file at the project root, plain `key = value` lines (never executed):

```ini
quality = 80        # 0-100
effort = 6          # 0-6, 6 = smallest output
max_width = 1920    # 0 = no limit
max_height = 0
lossless = false
metadata = icc      # none | icc | all
min_savings = 0     # keep the WebP only if at least this % smaller
recursive = false
```

Command-line options override the file; the file overrides built-in defaults.
