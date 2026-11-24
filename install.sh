#!/usr/bin/env bash
# Install webpopt and, optionally, the webp-optimizer Agent Skill. Fedora and Arch/CachyOS.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bin_dir="${HOME}/.local/bin"
install_deps=1
skill_dirs=()

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  --bin-dir DIR     Where to install the webpopt command (default: ~/.local/bin)
  --skill TARGET    Also install the Agent Skill. TARGET is one of:
                      claude   -> ~/.claude/skills
                      codex    -> ~/.codex/skills
                      agents   -> ~/.agents/skills
                      DIR      -> any skills directory, e.g. ./.claude/skills
                    May be given more than once.
  --no-deps         Do not install missing system packages (dnf or pacman)
  -h, --help        Show this help

Nothing is installed outside the directories above. System packages
are installed only if a required command is missing: with "sudo dnf"
(libwebp-tools, libjpeg-turbo-utils, file) on Fedora, or with "sudo pacman"
(libwebp-utils, libjpeg-turbo, file) on Arch/CachyOS.
EOF
}

while (($# > 0)); do
  case $1 in
    --bin-dir) bin_dir=${2:?--bin-dir needs a value}; shift ;;
    --skill)
      case ${2:?--skill needs a value} in
        claude) skill_dirs+=("$HOME/.claude/skills") ;;
        codex)  skill_dirs+=("$HOME/.codex/skills") ;;
        agents) skill_dirs+=("$HOME/.agents/skills") ;;
        *)      skill_dirs+=("$2") ;;
      esac
      shift ;;
    --no-deps) install_deps=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# Package names differ by distribution.
if command -v pacman >/dev/null 2>&1; then
  pkg_mgr=pacman
  pkg_webp=libwebp-utils; pkg_jpeg=libjpeg-turbo; pkg_file=file
else
  pkg_mgr=dnf
  pkg_webp=libwebp-tools; pkg_jpeg=libjpeg-turbo-utils; pkg_file=file
fi

missing=()
command -v cwebp >/dev/null 2>&1    || missing+=("$pkg_webp")
command -v jpegtran >/dev/null 2>&1 || missing+=("$pkg_jpeg")
command -v file >/dev/null 2>&1     || missing+=("$pkg_file")

if ((${#missing[@]} > 0)); then
  if ((install_deps)) && command -v "$pkg_mgr" >/dev/null 2>&1; then
    echo "Installing system packages: ${missing[*]}"
    if [[ $pkg_mgr == pacman ]]; then
      sudo pacman -S --needed "${missing[@]}"
    else
      sudo dnf install -y "${missing[@]}"
    fi
  else
    echo "Missing packages: ${missing[*]}" >&2
    if [[ $pkg_mgr == pacman ]]; then
      echo "Install them first (Arch/CachyOS: sudo pacman -S ${missing[*]})." >&2
    else
      echo "Install them first (Fedora: sudo dnf install ${missing[*]})." >&2
    fi
    exit 3
  fi
fi

src="$here/skills/webp-optimizer"

mkdir -p "$bin_dir"
install -m 755 "$src/scripts/webpopt" "$bin_dir/webpopt"
echo "Installed $bin_dir/webpopt"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo "Note: $bin_dir is not on your PATH." ;;
esac

for d in "${skill_dirs[@]}"; do
  dest="$d/webp-optimizer"
  mkdir -p "$dest/scripts"
  install -m 644 "$src/SKILL.md" "$dest/SKILL.md"
  install -m 755 "$src/scripts/webpopt" "$dest/scripts/webpopt"
  echo "Installed skill in $dest"
done

"$bin_dir/webpopt" --version
