#!/usr/bin/env bash
# =============================================================================
#  bootstrap.sh — Set up the dotfiles repo on a fresh machine
# =============================================================================
#  Clones the repo to ~/Dotfiles (or pulls an existing checkout), enables the
#  leak-guard pre-commit hook, and stows every package.
#
#  Usage:
#    ./Scripts/bootstrap.sh                 # full setup, stow everything
#    ./Scripts/bootstrap.sh --dry-run       # preview, change nothing
#    ./Scripts/bootstrap.sh --no-stow       # clone + hook only
#    ./Scripts/bootstrap.sh --packages Zsh Kitty
#    ./Scripts/bootstrap.sh --no-install    # do not run installapps.sh
#
#  Runs from inside an existing checkout, or one-liner from a fresh machine:
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mcor52/my_dotfiles/main/Scripts/bootstrap.sh)"
# =============================================================================
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/Mcor52/my_dotfiles.git}"
DOTDIR="${DOT:-$HOME/Dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"

DRY_RUN=0
DO_STOW=1
DO_INSTALL=1
PACKAGES=()

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
if [[ ! -t 1 ]]; then RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''; fi
info() { echo "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
ok()   { echo "  ${GREEN}✔${NC} $1"; }
warn() { echo "  ${YELLOW}⚠${NC} $1"; }
err()  { echo "  ${RED}✖${NC} $1" >&2; }

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    --no-stow)    DO_STOW=0 ;;
    --no-install) DO_INSTALL=0 ;;
    --packages)   shift; while [[ $# -gt 0 && "$1" != -* ]]; do PACKAGES+=("$1"); shift; done; continue ;;
    -h|--help)    usage ;;
    *) err "Unknown option: $1"; usage ;;
  esac
  shift
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  ${YELLOW}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

# --- 1. obtain the repo -----------------------------------------------------
info "Dotfiles location: $DOTDIR"

if [[ -d "$DOTDIR/.git" ]]; then
  ok "existing checkout found"
  if [[ $(git -C "$DOTDIR" rev-parse --abbrev-ref HEAD) != "$BRANCH" ]]; then
    warn "on branch $(git -C "$DOTDIR" rev-parse --abbrev-ref HEAD), not $BRANCH"
  fi
  if [[ $DRY_RUN -eq 0 ]] && [[ -n "$(git -C "$DOTDIR" status --porcelain)" ]]; then
    warn "checkout has uncommitted changes; skipping pull"
  else
    info "Pulling latest $BRANCH"
    run git -C "$DOTDIR" pull --ff-only origin "$BRANCH" || warn "pull failed (offline or diverged); continuing"
  fi
else
  if [[ -e "$DOTDIR" ]]; then
    err "$DOTDIR exists but is not a git checkout. Move it aside and re-run."
    exit 1
  fi
  info "Cloning $REPO_URL -> $DOTDIR"
  run git clone --branch "$BRANCH" "$REPO_URL" "$DOTDIR"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo ""
  info "Dry run complete. No changes were made."
  exit 0
fi

# --- 2. enable the leak-guard pre-commit hook -------------------------------
info "Enabling pre-commit secret scanner"
git -C "$DOTDIR" config core.hooksPath .githooks
ok "core.hooksPath = .githooks"

# --- 3. dependencies --------------------------------------------------------
if ! command -v stow >/dev/null 2>&1; then
  warn "GNU Stow is not installed."
  if command -v dnf >/dev/null 2>&1; then
    echo "      install with: sudo dnf install -y stow"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "      install with: sudo apt-get install -y stow"
  elif command -v pacman >/dev/null 2>&1; then
    echo "      install with: sudo pacman -S stow"
  fi
  DO_STOW=0
fi

# --- 4. optional package install --------------------------------------------
if [[ $DO_INSTALL -eq 1 && -x "$DOTDIR/Scripts/installapps.sh" ]]; then
  warn "installapps.sh installs system packages and may sudo."
  # Under `curl | bash` stdin is the script itself, so a read would hit EOF and
  # set -e would abort mid-bootstrap. Only prompt on a real terminal.
  if [[ ! -t 0 ]]; then
    echo "  stdin is not a terminal; skipping (run later: ./Scripts/installapps.sh)"
  else
    read -r -p "  Run it now? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      "$DOTDIR/Scripts/installapps.sh" || warn "installapps.sh reported errors; continuing"
    else
      echo "  skipped (run later: ./Scripts/installapps.sh)"
    fi
  fi
fi

# --- 5. stow ----------------------------------------------------------------
if [[ $DO_STOW -eq 1 ]]; then
  info "Stowing packages"
  STOW_ARGS=(-R)
  if [[ ${#PACKAGES[@]} -gt 0 ]]; then
    STOW_ARGS+=("${PACKAGES[@]}")
  fi
  if ! DOT="$DOTDIR" DOTCONF="$DOTDIR/Configs" "$DOTDIR/Scripts/stow.zsh" "${STOW_ARGS[@]}"; then
    err "stow failed. Inspect output above; backups are in ~/.dotfiles_backup/"
    exit 1
  fi
fi

echo ""
info "Bootstrap complete"
echo "  Next: restart your shell (exec zsh) and check ./Scripts/theme.sh status"
echo "  Never commit machine-specific values; keep them in an untracked"
echo "  ~/.dotfiles.local and source it from the relevant dotfile."