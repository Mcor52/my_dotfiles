#!/usr/bin/env bash
# =============================================================================
#  setup-fedora-tune.sh — Automated Installer for Fedora Tune
# =============================================================================
#  Integrates fedora-tune with Fedora KDE, zsh, and system PATH.
#
#  Usage:
#    ./setup-fedora-tune.sh [options]
#
#  Options:
#    --sudoers       Configure scoped passwordless sudo (/etc/sudoers.d/fedora-tune)
#    --timer         Set up weekly automated systemd timer (Sun 03:00)
#    --all           Install binary, desktop launcher, sudoers rule, and timer
#    -h, --help      Display this help message
# =============================================================================

set -euo pipefail

DOTDIR="${DOT:-$HOME/Dotfiles}"
SRC="$DOTDIR/Scripts/fedora-tune.sh"
DST="/usr/local/bin/fedora-tune"
DESKTOP_SRC="$DOTDIR/Configs/Desktop/.local/share/applications/fedora-tune.desktop"
DESKTOP_DST="$HOME/.local/share/applications/fedora-tune.desktop"

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

DO_SUDOERS=0
DO_TIMER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sudoers)
      DO_SUDOERS=1
      ;;
    --timer)
      DO_TIMER=1
      ;;
    --all)
      DO_SUDOERS=1
      DO_TIMER=1
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

# Step 0: Sanity checks
log_info "Step 0: Checking source script..."
if [[ ! -f "$SRC" ]]; then
  log_err "Cannot find $SRC"
  exit 1
fi

chmod +x "$SRC"
if grep -q 'exec sudo -E' "$SRC"; then
  log_warn "Detected 'exec sudo -E' in $SRC — updating to 'exec sudo'..."
  sed -i 's/exec sudo -E/exec sudo/' "$SRC"
fi
log_ok "Sanity checks passed: $SRC is executable and configured for plain sudo"

# Step 1: Install system-wide
log_info "Step 1: Installing root-owned binary to $DST..."
sudo install -m 755 "$SRC" "$DST"
if command -v restorecon >/dev/null 2>&1; then
  sudo restorecon -v "$DST" || true
fi
log_ok "Installed $DST"

# Step 2: Desktop Launcher for KDE
log_info "Step 2: Installing KDE Desktop Launcher..."
mkdir -p "$(dirname "$DESKTOP_DST")"
if [[ -f "$DESKTOP_SRC" ]]; then
  cp "$DESKTOP_SRC" "$DESKTOP_DST"
else
  cat <<'EOF' > "$DESKTOP_DST"
[Desktop Entry]
Type=Application
Name=Fedora Tune
Comment=Update and clean up Fedora
Exec=konsole --hold -e sudo /usr/local/bin/fedora-tune
Terminal=false
Categories=System;
Actions=dry;deep;

[Desktop Action dry]
Name=Dry run (preview only)
Exec=konsole --hold -e sudo /usr/local/bin/fedora-tune --dry-run

[Desktop Action deep]
Name=Deep clean
Exec=konsole --hold -e sudo /usr/local/bin/fedora-tune --deep --containers --dev-caches
EOF
fi

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 >/dev/null 2>&1 || true
  log_ok "Updated KDE application menu cache"
fi
log_ok "Desktop launcher installed at $DESKTOP_DST"

# Step 3: Scoped Passwordless Sudo (Optional)
if [[ $DO_SUDOERS -eq 1 ]]; then
  log_info "Step 3: Configuring scoped passwordless sudo for $USER..."
  SUDOERS_FILE="/etc/sudoers.d/fedora-tune"
  TMP_SUDOERS="$(mktemp)"
  echo "$USER ALL=(root) NOPASSWD: $DST" > "$TMP_SUDOERS"
  sudo cp "$TMP_SUDOERS" "$SUDOERS_FILE"
  sudo chmod 440 "$SUDOERS_FILE"
  rm -f "$TMP_SUDOERS"

  if sudo visudo -cf "$SUDOERS_FILE"; then
    log_ok "Scoped sudoers rule validated and active at $SUDOERS_FILE"
  else
    log_err "visudo validation failed! Removing invalid sudoers file for safety."
    sudo rm -f "$SUDOERS_FILE"
    exit 1
  fi
fi

# Step 4: Systemd Weekly Timer (Optional)
if [[ $DO_TIMER -eq 1 ]]; then
  log_info "Step 4: Setting up systemd weekly maintenance timer..."
  SERVICE_FILE="/etc/systemd/system/fedora-tune.service"
  TIMER_FILE="/etc/systemd/system/fedora-tune.timer"

  sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Fedora Tune update and cleanup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$DST --no-firmware
Nice=10
IOSchedulingClass=idle
EOF

  sudo tee "$TIMER_FILE" >/dev/null <<EOF
[Unit]
Description=Weekly Fedora Tune update and cleanup

[Timer]
OnCalendar=Sun 03:00
Persistent=true
RandomizedDelaySec=30min

[Install]
WantedBy=timers.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now fedora-tune.timer
  log_ok "Weekly timer scheduled (Sun 03:00, randomized 30min delay)"
fi

echo ""
log_ok "Fedora Tune setup complete!"
echo "Commands available in zsh:"
echo "    up          # Regular update & cleanup"
echo "    up-dry      # Dry-run preview"
echo "    up-deep     # Deep clean (containers + dev caches)"
echo "    up-quick    # Package updates only"
echo "    up-clean    # Cleanup only"
