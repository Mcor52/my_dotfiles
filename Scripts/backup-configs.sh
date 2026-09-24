#!/usr/bin/env bash
# =============================================================================
#  backup-configs.sh — Safe dotfiles backup & sync utility
# =============================================================================
#  Syncs application configurations from your system into $DOT/Configs
#  while strictly protecting sensitive data (tokens, passwords, keys, cookies).
#
#  Usage:
#    ./backup-configs.sh [options]
#
#  Options:
#    -n, --dry-run        Show what would be copied without writing files
#    -s, --check-secrets  Scan Dotfiles for potential secrets/credentials
#    -h, --help           Display this help message
# =============================================================================

set -euo pipefail

DOTDIR="${DOT:-$HOME/Dotfiles}"
CONFIGS_DIR="$DOTDIR/Configs"

# Colors
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  CYAN=''
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

DRY_RUN=0
CHECK_SECRETS_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -s|--check-secrets)
      CHECK_SECRETS_ONLY=1
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

# -----------------------------------------------------------------------------
#  Security audit: scan for accidental secret leakage
# -----------------------------------------------------------------------------
scan_for_secrets() {
  log_info "Auditing $DOTDIR for sensitive files or secrets..."
  local findings=0

  # Prefer the dedicated scanner (same rules the pre-commit hook uses).
  if [[ -f "$DOTDIR/Scripts/leak-guard.py" ]]; then
    if python3 "$DOTDIR/Scripts/leak-guard.py" --tree; then
      log_ok "Security check passed: no blocking secrets found."
    else
      log_warn "leak-guard found blocking issue(s). Review before pushing to public GitHub."
      findings=$((findings + 1))
    fi
    return $findings
  fi

  # Fallback: coarse filename + content heuristics.
  while IFS= read -r match; do
    if [[ -n "$match" ]]; then
      log_warn "Potential sensitive file detected: $match"
      ((findings++))
    fi
  done < <(find "$DOTDIR" -type f \( \
    -name "*.key" -o -name "*.pem" -o -name "*.p12" -o -name "*.pfx" \
    -o -name "*id_rsa*" -o -name "*id_ed25519*" \
    -o -name "*.env" -o -name ".env.*" \
    -o -name "*secrets*" -o -name "*credential*" \
    -o -name "userstate.cbor" -o -name "*history*" \
    -o -name "hosts.yml" \) ! -path "*/.git/*" 2>/dev/null || true)

  while IFS= read -r match; do
    if [[ -n "$match" ]]; then
      log_err "Potential credential found inside file: $match"
      ((findings++))
    fi
  done < <(grep -rnE "(PRIVATE KEY|BEGIN OPENSSH PRIVATE|ghp_[A-Za-z0-9]{36}|glpat-[A-Za-z0-9_-]{20})" \
    "$DOTDIR" --exclude-dir=".git" --exclude="backup-configs.sh" 2>/dev/null || true)

  if [[ $findings -eq 0 ]]; then
    log_ok "Security check passed: No sensitive files or credentials found."
  else
    log_warn "Found $findings potential sensitive item(s). Please review before pushing to public GitHub."
  fi
  return $findings
}

if [[ $CHECK_SECRETS_ONLY -eq 1 ]]; then
  scan_for_secrets || true
  exit 0
fi

# -----------------------------------------------------------------------------
#  Safe sync function: copy file only if target is not a symlink pointing to source
# -----------------------------------------------------------------------------
sync_file() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    return 0
  fi

  # Skip if src is already a symlink pointing to dst (already stowed)
  if [[ -L "$src" ]]; then
    local target
    target="$(readlink -f "$src" 2>/dev/null || true)"
    local real_dst
    real_dst="$(readlink -f "$dst" 2>/dev/null || true)"
    if [[ "$target" == "$real_dst" ]]; then
      log_ok "Already managed via symlink: $(basename "$src")"
      return 0
    fi
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "[Dry-Run] Would copy $src -> $dst"
    return 0
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log_ok "Synced $(basename "$src") -> $dst"
}

log_info "Synchronizing user configs into $CONFIGS_DIR..."

# 1. Zsh
sync_file "$HOME/.zshrc" "$CONFIGS_DIR/Zsh/.zshrc"
sync_file "$HOME/.zshenv" "$CONFIGS_DIR/Zsh/.zshenv"
sync_file "$HOME/.zprofile" "$CONFIGS_DIR/Zsh/.zprofile"
sync_file "$HOME/.zsh_plugins.txt" "$CONFIGS_DIR/Zsh/.zsh_plugins.txt"

# 2. Starship
sync_file "$HOME/.config/starship.toml" "$CONFIGS_DIR/Starship/.config/starship.toml"

# 3. Kitty
if [[ -d "$HOME/.config/kitty" && ! -L "$HOME/.config/kitty" ]]; then
  mkdir -p "$CONFIGS_DIR/Kitty/.config/kitty"
  sync_file "$HOME/.config/kitty/kitty.conf" "$CONFIGS_DIR/Kitty/.config/kitty/kitty.conf"
  sync_file "$HOME/.config/kitty/quick-access-terminal.conf" "$CONFIGS_DIR/Kitty/.config/kitty/quick-access-terminal.conf"
fi

# 4. Neovim (excluding temp files/cache)
if [[ -d "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
  mkdir -p "$CONFIGS_DIR/Nvim/.config/nvim"
  rsync -av --exclude='.git' --exclude='*.log' "$HOME/.config/nvim/" "$CONFIGS_DIR/Nvim/.config/nvim/" 2>/dev/null || true
fi

# 5. Btop
sync_file "$HOME/.config/btop/btop.conf" "$CONFIGS_DIR/Btop/.config/btop/btop.conf"
sync_file "$HOME/.config/btop/themes/noctalia.theme" "$CONFIGS_DIR/Btop/.config/btop/themes/noctalia.theme"

# 6. Lazygit
sync_file "$HOME/.config/lazygit/config.yml" "$CONFIGS_DIR/Lazygit/.config/lazygit/config.yml"
sync_file "$HOME/.config/lazygit/themes/noctalia.yml" "$CONFIGS_DIR/Lazygit/.config/lazygit/themes/noctalia.yml"

# 7. Mpv
sync_file "$HOME/.config/mpv/mpv.conf" "$CONFIGS_DIR/Mpv/.config/mpv/mpv.conf"

# 8. Ncspot (ONLY config.toml - NEVER session/userstate credentials)
sync_file "$HOME/.config/ncspot/config.toml" "$CONFIGS_DIR/Ncspot/.config/ncspot/config.toml"

# 9. Desktop Entries
sync_file "$HOME/.local/share/applications/fedora-tune.desktop" "$CONFIGS_DIR/Desktop/.local/share/applications/fedora-tune.desktop"

# 10. GTK (theme + icon choices only; no personal data)
sync_file "$HOME/.gtkrc-2.0" "$CONFIGS_DIR/Gtk/.gtkrc-2.0"
sync_file "$HOME/.config/gtk-3.0/settings.ini" "$CONFIGS_DIR/Gtk/.config/gtk-3.0/settings.ini"
sync_file "$HOME/.config/gtk-4.0/settings.ini" "$CONFIGS_DIR/Gtk/.config/gtk-4.0/settings.ini"

# 11. htop
sync_file "$HOME/.config/htop/htoprc" "$CONFIGS_DIR/Htop/.config/htop/htoprc"

# 12. Git (review before committing: user.email is intentionally public here)
sync_file "$HOME/.gitconfig" "$CONFIGS_DIR/Git/.gitconfig"

# 13. Bash
sync_file "$HOME/.bashrc" "$CONFIGS_DIR/Bash/.bashrc"
sync_file "$HOME/.bash_profile" "$CONFIGS_DIR/Bash/.bash_profile"
sync_file "$HOME/.profile" "$CONFIGS_DIR/Bash/.profile"
sync_file "$HOME/.bash_logout" "$CONFIGS_DIR/Bash/.bash_logout"

echo ""
# Run security scan
scan_for_secrets || true

echo ""
log_info "Dotfiles git status summary:"
git -C "$DOTDIR" status -s
