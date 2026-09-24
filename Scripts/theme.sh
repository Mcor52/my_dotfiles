#!/usr/bin/env bash
# =============================================================================
#  theme.sh — Switch the whole desktop between dark and light themes
# =============================================================================
#  Applies a consistent theme across KDE Plasma, GTK, Qt, Kitty, Starship,
#  btop, nvim and the cursor.
#
#  Usage:
#    ./theme.sh dark          Set dark theme
#    ./theme.sh light         Set light theme
#    ./theme.sh toggle        Flip to the opposite theme
#    ./theme.sh status        Show which theme is currently active
#    ./theme.sh -n dark       Preview changes without applying
#    ./theme.sh -h            Display this help message
# =============================================================================

set -euo pipefail

DOT="${DOT:-$HOME/Dotfiles}"
THEMES="$DOT/Themes"
CONFIGS="$HOME/.config"
STATE="$CONFIGS/theme.current"

DRY_RUN=0

# Colors
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
  BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BLUE=''; BOLD=''; NC=''
fi

log_info() { echo -e "${BLUE}==>${NC} ${BOLD}$1${NC}"; }
log_ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_err()  { echo -e "  ${RED}✖${NC} $1"; }

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

current_theme() {
  if [[ -f "$STATE" ]]; then
    cat "$STATE"
  else
    echo "unknown"
  fi
}

# Write $3 into the repo source of truth, then mirror onto $2 unless $2 already
# resolves to the repo file (i.e. it is stowed).
apply_file() {
  local repo_src="$1" home_dst="$2" source="$3"
  mkdir -p "$(dirname "$repo_src")"
  cp "$source" "$repo_src"
  if [[ "$(readlink -f "$home_dst" 2>/dev/null)" == "$(readlink -f "$repo_src" 2>/dev/null)" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$home_dst")"
  cp "$repo_src" "$home_dst"
}

ACTION=""
case "${1:-}" in
  dark|light)
    ACTION="$1"
    ;;
  toggle)
    ACTION="$([[ "$(current_theme)" == dark ]] && echo light || echo dark)"
    ;;
  status)
    echo "Current theme: $(current_theme)"
    exit 0
    ;;
  -n|--dry-run)
    DRY_RUN=1
    shift
    ACTION="${1:-}"
    [[ "$ACTION" =~ ^(dark|light)$ ]] || { log_err "Need 'dark' or 'light' after -n"; usage; }
    ;;
  -h|--help|"")
    usage
    ;;
  *)
    log_err "Unknown option: $1"
    usage
    ;;
esac

current_theme() {
  [[ -f "$STATE" ]] && cat "$STATE" || echo "unknown"
}

# --- per-application theme setters -------------------------------------------

set_kitty() {
  local variant="$1"
  local src="$THEMES/Kitty/kitty-$variant.conf"
  local repo="$DOT/Configs/Kitty/.config/kitty/kitty-theme.conf"
  if [[ ! -f "$src" ]]; then
    log_warn "Missing kitty theme: $src"
    return 0
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "  [dry-run] kitty-theme.conf <- $variant"
    return 0
  fi
  apply_file "$repo" "$CONFIGS/kitty/kitty-theme.conf" "$src"
  # Ask a running kitty to reload; harmless if none is running.
  killall -SIGUSR1 kitty 2>/dev/null || true
  log_ok "Kitty theme -> $variant"
}

set_starship() {
  local variant="$1"
  local src="$THEMES/Starship/starship-$variant.toml"
  local repo="$DOT/Configs/Starship/.config/starship.toml"
  [[ -f "$src" ]] || { log_warn "Missing starship theme: $src"; return 0; }
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "  [dry-run] starship.toml <- $variant"
    return 0
  fi
  apply_file "$repo" "$CONFIGS/starship.toml" "$src"
  log_ok "Starship theme -> $variant"
}

set_btop() {
  local variant="$1"
  local theme="noctalia"
  local bg="false"
  if [[ "$variant" == light ]]; then
    theme="catppuccin-latte"
    bg="true"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "  [dry-run] btop color_theme <- $theme"
    return 0
  fi
  local repo="$DOT/Configs/Btop/.config/btop/btop.conf"
  local home="$CONFIGS/btop/btop.conf"
  if [[ -f "$repo" ]]; then
    sed -i "s/^color_theme = .*/color_theme = \"$theme\"/" "$repo"
    sed -i "s/^theme_background = .*/theme_background = $bg/" "$repo"
    [[ -L "$home" ]] || cp "$repo" "$home"
    log_ok "btop theme -> $theme"
  else
    log_warn "btop.conf not found, skipping"
  fi
}

set_kde() {
  local variant="$1"
  local scheme look cursor
  if [[ "$variant" == dark ]]; then
    scheme="BreezeDark"
    look="org.kde.breezedark.desktop"
    cursor="breeze_cursors"
  else
    scheme="BreezeLight"
    look="org.kde.breezelight.desktop"
    cursor="Breeze_Light"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "  [dry-run] KDE scheme <- $scheme, cursor <- $cursor"
    return 0
  fi
  if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 \
      && log_ok "KDE colour scheme -> $scheme" \
      || log_warn "Could not apply KDE scheme $scheme"
    plasma-apply-cursortheme "$cursor" >/dev/null 2>&1 || true
    if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
      plasma-apply-lookandfeel -a "$look" >/dev/null 2>&1 || true
    fi
  else
    log_warn "plasma-apply-colorscheme not found, skipping KDE"
  fi
}

set_gtk() {
  local variant="$1"
  local gtktheme icon datk
  if [[ "$variant" == dark ]]; then
    gtktheme="Catppuccin-Dark"; icon="Papirus-Dark"; datk="prefer-dark"
  else
    gtktheme="Catppuccin-Light"; icon="Papirus-Light"; datk="prefer-light"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "  [dry-run] GTK theme <- $gtktheme, icons <- $icon"
    return 0
  fi
  # GTK settings.ini lives in the repo Gtk package (mirrored to $HOME when not stowed).
  local gtk3_repo="$DOT/Configs/Gtk/.config/gtk-3.0/settings.ini"
  local gtk3_home="$CONFIGS/gtk-3.0/settings.ini"
  if [[ -f "$gtk3_repo" ]]; then
    sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$gtktheme/" "$gtk3_repo"
    sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=$icon/" "$gtk3_repo"
    [[ -L "$gtk3_home" ]] || { mkdir -p "$(dirname "$gtk3_home")"; cp "$gtk3_repo" "$gtk3_home"; }
    log_ok "GTK3 theme -> $gtktheme"
  fi
  command -v gsettings >/dev/null 2>&1 && \
    gsettings set org.gnome.desktop.interface color-scheme "$datk" 2>/dev/null || true
}

# --- run ---------------------------------------------------------------------

log_info "Applying '$ACTION' theme"
[[ $DRY_RUN -eq 1 ]] && log_warn "Dry run: no changes will be written"

set_kitty "$ACTION"
set_starship "$ACTION"
set_btop "$ACTION"
set_gtk "$ACTION"
set_kde "$ACTION"

if [[ $DRY_RUN -eq 0 ]]; then
  echo "$ACTION" > "$STATE"
  log_ok "Saved theme state: $ACTION"
fi

echo ""
log_ok "Done. Open a new terminal (or run 'sz') to see the shell changes."
