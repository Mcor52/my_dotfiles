#!/usr/bin/env zsh
# =============================================================================
#  stow.zsh — Safe GNU Stow Manager for Dotfiles
# =============================================================================
#  Usage:
#    ./stow.zsh [options] [package ...]
#
#  Options:
#    -R, --restow    Re-stow packages (prunes dead symlinks and updates new ones)
#    -D, --delete    Un-stow (remove) symlinks for packages
#    -n, --dry-run   Simulate actions without making filesystem changes
#    -h, --help      Display this help message
#
#  If no packages are specified, all available packages in Configs/ are stowed.
# =============================================================================

set -eo pipefail

DOTDIR="${DOT:-$HOME/Dotfiles}"
DOTCONFDIR="${DOTCONF:-$DOTDIR/Configs}"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Colors for friendly terminal output
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  BOLD=''
  NC=''
fi

log_info() { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
log_ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_err()  { echo -e "  ${RED}✖${NC} $1"; }

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# Verify GNU Stow is installed
if ! command -v stow >/dev/null 2>&1; then
  log_err "GNU Stow is not installed. Please install it first:"
  echo "    sudo dnf install stow"
  exit 1
fi

ACTION="stow"
DRY_RUN=0
TARGET_PACKAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -R|--restow)
      ACTION="restow"
      ;;
    -D|--delete)
      ACTION="delete"
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      ;;
    -*)
      log_err "Unknown option: $1"
      usage
      ;;
    *)
      TARGET_PACKAGES+=("$1")
      ;;
  esac
  shift
done

# If no packages specified, discover all packages in Configs directory
if [[ ${#TARGET_PACKAGES[@]} -eq 0 ]]; then
  for dir in "$DOTCONFDIR"/*(/N); do
    TARGET_PACKAGES+=("${dir:t}")
  done
fi

log_info "Managing dotfiles with GNU Stow (Action: $ACTION)"
echo "Dotfiles Config directory: $DOTCONFDIR"
echo "Target directory:          $HOME"
echo "Packages:                  ${TARGET_PACKAGES[*]}"
echo ""

# Helper to safely back up existing non-symlink file or directory before stowing
safe_backup_conflict() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      log_warn "[Dry-Run] Would back up real file/dir: $target -> $BACKUP_DIR"
      return 0
    fi
    mkdir -p "$BACKUP_DIR"
    log_warn "Backing up real file/dir: $target -> $BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
  fi
}

# Known conflict targets to safeguard
for pkg in "${TARGET_PACKAGES[@]}"; do
  case "$pkg" in
    Zsh)
      safe_backup_conflict "$HOME/.zshrc"
      safe_backup_conflict "$HOME/.zshenv"
      safe_backup_conflict "$HOME/.zprofile"
      safe_backup_conflict "$HOME/.zsh_plugins.txt"
      ;;
    Starship)
      safe_backup_conflict "$HOME/.config/starship.toml"
      ;;
    Kitty)
      safe_backup_conflict "$HOME/.config/kitty"
      ;;
    Nvim)
      safe_backup_conflict "$HOME/.config/nvim"
      ;;
    Btop)
      safe_backup_conflict "$HOME/.config/btop"
      ;;
    Lazygit)
      safe_backup_conflict "$HOME/.config/lazygit"
      ;;
    Mpv)
      safe_backup_conflict "$HOME/.config/mpv"
      ;;
    Ncspot)
      safe_backup_conflict "$HOME/.config/ncspot/config.toml"
      ;;
    Desktop)
      safe_backup_conflict "$HOME/.local/share/applications/fedora-tune.desktop"
      ;;
    Gtk)
      safe_backup_conflict "$HOME/.gtkrc-2.0"
      safe_backup_conflict "$HOME/.config/gtk-3.0/settings.ini"
      safe_backup_conflict "$HOME/.config/gtk-4.0/settings.ini"
      ;;
    Htop)
      safe_backup_conflict "$HOME/.config/htop/htoprc"
      ;;
    Git)
      safe_backup_conflict "$HOME/.gitconfig"
      ;;
    Bash)
      safe_backup_conflict "$HOME/.bashrc"
      safe_backup_conflict "$HOME/.bash_profile"
      safe_backup_conflict "$HOME/.profile"
      safe_backup_conflict "$HOME/.bash_logout"
      ;;
  esac
done

# Execute stow for each package
cd "$DOTCONFDIR"

STOW_FLAGS=("-t" "$HOME")
[[ $DRY_RUN -eq 1 ]] && STOW_FLAGS+=("-n" "-v")

case "$ACTION" in
  restow)
    STOW_FLAGS+=("-R")
    ;;
  delete)
    STOW_FLAGS+=("-D")
    ;;
  *)
    STOW_FLAGS+=("-S")
    ;;
esac

for pkg in "${TARGET_PACKAGES[@]}"; do
  if [[ ! -d "$DOTCONFDIR/$pkg" ]]; then
    log_warn "Package directory does not exist: $DOTCONFDIR/$pkg (skipping)"
    continue
  fi

  log_info "Processing package: $pkg"
  if stow "${STOW_FLAGS[@]}" "$pkg"; then
    log_ok "Successfully processed $pkg"
  else
    log_err "Failed to process $pkg"
  fi
done

echo ""
if [[ -d "$BACKUP_DIR" ]]; then
  log_info "Original files were backed up safely to: $BACKUP_DIR"
fi
log_ok "GNU Stow operation completed!"
