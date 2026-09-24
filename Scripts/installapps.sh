#!/usr/bin/env bash
# =============================================================================
#  installapps.sh — Bootstrap package & environment installer for Fedora
# =============================================================================
#  Installs essential CLI utilities, terminal tools, Flatpaks, Starship,
#  and Antidote for a complete workstation setup.
#
#  Usage:
#    ./installapps.sh [options]
#
#  Options:
#    --cli-only       Install only CLI / core packages (skip Flatpaks)
#    --flatpaks-only  Install only Flatpak applications
#    -n, --dry-run    Preview what would be installed
#    -h, --help       Display this help message
# =============================================================================

set -euo pipefail

# Colors
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
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

CLI_ONLY=0
FLATPAKS_ONLY=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cli-only)
      CLI_ONLY=1
      ;;
    --flatpaks-only)
      FLATPAKS_ONLY=1
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      ;;
    *)
      log_err "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# DNF Packages to install
CORE_PKGS=(
  git
  zsh
  stow
  curl
  wget
  neovim
  kitty
  bat
  fzf
  btop
  mpv
  ripgrep
  fd-find
  eza
  fastfetch
  util-linux-user
)

# Flatpaks to install
FLATPAK_APPS=(
  io.github.hrkfdn.ncspot
  com.spotify.Client
  md.obsidian.Obsidian
  com.github.tchx84.Flatseal
)

# Step 1: DNF Packages
if [[ $FLATPAKS_ONLY -eq 0 ]]; then
  log_info "Checking Fedora DNF packages..."
  pkgs_to_install=()
  for pkg in "${CORE_PKGS[@]}"; do
    if ! rpm -q "$pkg" >/dev/null 2>&1; then
      pkgs_to_install+=("$pkg")
    fi
  done

  if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
    log_info "Packages to install: ${pkgs_to_install[*]}"
    if [[ $DRY_RUN -eq 1 ]]; then
      log_warn "[Dry-Run] Would run: sudo dnf install -y ${pkgs_to_install[*]}"
    else
      sudo dnf install -y "${pkgs_to_install[@]}"
      log_ok "DNF packages installed successfully."
    fi
  else
    log_ok "All core DNF packages are already installed."
  fi

  # Starship prompt installer
  if ! command -v starship >/dev/null 2>&1; then
    log_info "Installing Starship prompt..."
    if [[ $DRY_RUN -eq 1 ]]; then
      log_warn "[Dry-Run] Would run starship install script"
    else
      curl -sS https://starship.rs/install.sh | sh -s -- -y
      log_ok "Starship prompt installed."
    fi
  else
    log_ok "Starship prompt is already installed."
  fi

  # Antidote Zsh plugin manager
  ANTIDOTE_DIR="${ZDOTDIR:-$HOME}/.antidote"
  if [[ ! -d "$ANTIDOTE_DIR" ]]; then
    log_info "Cloning Antidote plugin manager to $ANTIDOTE_DIR..."
    if [[ $DRY_RUN -eq 1 ]]; then
      log_warn "[Dry-Run] Would clone antidote to $ANTIDOTE_DIR"
    else
      git clone --depth=1 https://github.com/mattmc3/antidote.git "$ANTIDOTE_DIR"
      log_ok "Antidote installed successfully."
    fi
  else
    log_ok "Antidote is already installed at $ANTIDOTE_DIR."
  fi
fi

# Step 2: Flatpak Applications
if [[ $CLI_ONLY -eq 0 ]]; then
  if command -v flatpak >/dev/null 2>&1; then
    log_info "Checking Flatpak applications..."
    # Ensure Flathub remote is configured
    if [[ $DRY_RUN -eq 0 ]]; then
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    fi

    for app in "${FLATPAK_APPS[@]}"; do
      if ! flatpak info "$app" >/dev/null 2>&1; then
        log_info "Installing Flatpak: $app..."
        if [[ $DRY_RUN -eq 1 ]]; then
          log_warn "[Dry-Run] Would run: flatpak install -y flathub $app"
        else
          flatpak install -y flathub "$app" || log_warn "Could not install $app (skipping)"
        fi
      else
        log_ok "Flatpak $app is already installed."
      fi
    done
  else
    log_warn "Flatpak is not installed. Skipping Flatpak applications."
  fi
fi

# Step 3: Default Shell
if [[ "$SHELL" != *"zsh"* ]]; then
  ZSH_PATH="$(which zsh 2>/dev/null || true)"
  if [[ -n "$ZSH_PATH" ]]; then
    log_info "Current shell is $SHELL. Changing default shell to $ZSH_PATH..."
    if [[ $DRY_RUN -eq 1 ]]; then
      log_warn "[Dry-Run] Would run: chsh -s $ZSH_PATH"
    else
      chsh -s "$ZSH_PATH" || log_warn "chsh failed. You may change it manually with: chsh -s $ZSH_PATH"
    fi
  fi
else
  log_ok "Default shell is already zsh."
fi

echo ""
log_ok "Environment bootstrap completed!"
echo "Next steps:"
echo "    1. Run: $HOME/Dotfiles/Scripts/stow.zsh"
echo "    2. Run: $HOME/Dotfiles/Scripts/setup-fedora-tune.sh"
echo "    3. Start a new zsh session: exec zsh"
