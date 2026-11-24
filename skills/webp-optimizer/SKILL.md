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
- The site can use a `.webp` file: in a WordPress/NativePress site you can import
  it into the Media Library as an attachment; in another project you may edit
  the code that serves its images.
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
   (Fedora: `sudo dnf install libwebp-tools libjpeg-turbo-utils`; Arch/CachyOS:
   `sudo pacman -S libwebp-utils libjpeg-turbo`) — do not
   install system packages yourself and do not fall back to another tool.
2. Respect project preferences: `webpopt` automatically reads `.webpopt.conf`
   from the working directory or a parent. Run from inside the project and do
   not repeat or override its values unless the user asks for something else.
3. WordPress/NativePress layout: keep the originals, the converted `.webp`
   files and `.webpopt-names` in a **source-assets folder outside the theme**
   (for example `<site>/source-assets/img/`, never under `wp-content/themes/`).
   Convert with the output next to the originals or with
   `-o <site>/source-assets/webp`; `webpopt` warns if a path is inside a theme.
   If the site has no `.webpopt.conf`, create one with
   `webpopt --init -w <width> -o source-assets/webp` (see "Choosing max_width").
4. Preview, then convert only the images involved in the current task:

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
5. Read the output, one line per file:

   ```
   ok       img/hero.jpg -> img/hero.webp  412.0K -> 118.3K (-71%)
   ok       img/logo.png -> img/logo-1.webp  ...
   skip     img/icon.png (WebP not smaller: 1.1K vs 792B, keep using the original)
   FAILED   img/broken.jpg: cwebp failed (exit 1)
   ```

   - `ok`: the WebP exists at the path printed after `->`. Use exactly that
     path; it can carry a suffix (`logo-1.webp`) when another image already
     owns `logo.webp`. Never guess the output name.
   - `skip ... up to date: <path>`: a current WebP already exists at `<path>`;
     use it.
   - any other `skip` (not smaller, cannot be rotated without losing pixels,
     not a JPEG/PNG, animated): there is **no** WebP for this image. Keep
     referencing the original file. Do not retry with `--force`, lower quality
     or another tool to get a WebP anyway.
   - `FAILED`: keep the original and report the error.
6. Use the new `.webp` only for `ok` / `up to date` files, and only for the
   current task. In WordPress/NativePress, import the `.webp` into the
   WordPress Media Library as an attachment and use the attachment ID in the
   theme/templates (for example through `npf_image` or
   `wp_get_attachment_image`); never copy the `.webp` into the theme directory
   and never hard-code a file path. In a non-WordPress project, put the file
   where that project serves images and update the code that shows it, keeping
   `width`/`height` in sync if the image was resized.
7. Report briefly: which files were converted, the size change, and anything
   skipped or failed (with the reason).

Run `webpopt --help` for the full option list.

## Rules

- Never delete, move, overwrite or re-compress the original JPEG/PNG. Removing
  originals is the user's decision.
- Never bulk-convert a whole repository unprompted; stay within the images the
  task touches unless the user asks for a wider pass.
- Do not edit `.webpopt.conf` unless asked; it holds the user's preferences.
- Leave `.webpopt-names` files alone and keep them with the images in the
  source-assets folder (commit them there, not in a theme): they record which
  source each `.webp` belongs to.
- Do not rewrite references in files outside the task's scope.
- Do not substitute ImageMagick, ffmpeg or online services for `webpopt`.

## Project preferences (`.webpopt.conf`)

Optional file at the project root, plain `key = value` lines (never executed):

```ini
quality = 80        # 0-100
effort = 6          # 0-6, 6 = smallest output
max_width = 1920    # 0 = no limit; choose per site, see below
max_height = 0
lossless = false
metadata = icc      # none | icc | all
min_savings = 0     # keep the WebP only if at least this % smaller
recursive = false
output_dir = source-assets/webp   # relative to this file; -o overrides
```

Command-line options override the file (so `-w 800` beats `max_width`); the
file overrides built-in defaults. Each site has its own `.webpopt.conf` at its
project root; `webpopt` finds the nearest one above the working directory.

## Choosing max_width

WordPress builds its sub-sizes (thumbnail, medium, large, and the theme's own)
from the uploaded original, so the original's width should be the largest size
the site ever shows, not the camera size. Choose it per site: about 1920 for
full-width heroes, 1200 for content images, 600-800 for product thumbnails and
cards. Check the site's registered sizes (theme `add_image_size` calls, or
`wp media image-size`) and use about twice the largest CSS width for
high-density screens. `webpopt` never upscales.
