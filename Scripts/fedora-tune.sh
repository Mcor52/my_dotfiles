#!/usr/bin/env bash
# =============================================================================
#  fedora-tune.sh — the all-in-one Fedora update + cleanup + health-check script
# =============================================================================
#  Works with dnf4 (Fedora <= 40) and dnf5 (Fedora 41+).
#  Run as your normal user with sudo, or directly as root.
#
#  Usage:  sudo ./fedora-tune.sh [options]
#
#  Options:
#    -n, --dry-run        Show what would be done, change nothing
#    -d, --deep           Deeper cleanup (dnf clean all, btrfs scrub, big caches)
#    -c, --containers     Prune podman/docker (unused images, stopped containers)
#    -D, --dev-caches     Clear pip / npm / cargo / gradle / go build caches
#    -r, --reboot         Automatically reboot at the end if one is needed
#        --no-flatpak     Skip Flatpak steps
#        --no-firmware    Skip fwupd firmware check/update
#        --no-cleanup     Only update, don't clean
#        --no-update      Only clean, don't update
#    -h, --help           Show this help
# =============================================================================

set -uo pipefail

# ---------- defaults ----------------------------------------------------------
DRY_RUN=0
DEEP=0
CONTAINERS=0
DEV_CACHES=0
AUTO_REBOOT=0
DO_FLATPAK=1
DO_FIRMWARE=1
DO_CLEANUP=1
DO_UPDATE=1
LOG_FILE="/var/log/fedora-tune.log"
LOCK_FILE="/var/lock/fedora-tune.lock"
JOURNAL_KEEP_TIME="2weeks"
JOURNAL_KEEP_SIZE="500M"
TRASH_DAYS=30
VARTMP_DAYS=30
COREDUMP_DAYS=7

# ---------- colours -----------------------------------------------------------
if [[ -t 1 ]]; then
  R=$'\e[31m'
  G=$'\e[32m'
  Y=$'\e[33m'
  B=$'\e[34m'
  C=$'\e[36m'
  BD=$'\e[1m'
  N=$'\e[0m'
else
  R=""
  G=""
  Y=""
  B=""
  C=""
  BD=""
  N=""
fi

# ---------- arg parsing -------------------------------------------------------
usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  -d | --deep) DEEP=1 ;;
  -c | --containers) CONTAINERS=1 ;;
  -D | --dev-caches) DEV_CACHES=1 ;;
  -r | --reboot) AUTO_REBOOT=1 ;;
  --no-flatpak) DO_FLATPAK=0 ;;
  --no-firmware) DO_FIRMWARE=0 ;;
  --no-cleanup) DO_CLEANUP=0 ;;
  --no-update) DO_UPDATE=0 ;;
  -h | --help) usage ;;
  *)
    echo "Unknown option: $1"
    usage
    ;;
  esac
  shift
done

# ---------- self-elevate ------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
REAL_UID="$(id -u "$REAL_USER")"

# ---------- logging + helpers -------------------------------------------------
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
exec > >(tee -a "$LOG_FILE") 2>&1

STEP=0
ERRORS=()
WARNINGS=()

hr() { printf '%s\n' "${B}────────────────────────────────────────────────────────────${N}"; }
step() {
  STEP=$((STEP + 1))
  echo
  hr
  echo "${BD}${C}[$STEP] $*${N}"
  hr
}
info() { echo "${G}✔${N} $*"; }
warn() {
  echo "${Y}⚠${N} $*"
  WARNINGS+=("$*")
}
fail() {
  echo "${R}✘${N} $*"
  ERRORS+=("$*")
}
have() { command -v "$1" &>/dev/null; }

# run a command (or just print it in dry-run mode)
run() {
  if ((DRY_RUN)); then
    echo "${Y}[dry-run]${N} $*"
    return 0
  fi
  "$@"
}

# run a command as the real (non-root) user
as_user() {
  run sudo -u "$REAL_USER" -H env XDG_RUNTIME_DIR="/run/user/$REAL_UID" "$@"
}

# used disk space on / in KiB
used_kib() { df --output=used -k / | tail -1 | tr -d ' '; }
human() { numfmt --to=iec --from-unit=1024 "$1" 2>/dev/null || echo "${1}K"; }

# ---------- single instance lock ---------------------------------------------
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "${R}Another instance of fedora-tune is already running. Bailing.${N}"
  exit 1
fi

# ---------- sanity checks -----------------------------------------------------
if ! have dnf; then
  echo "${R}dnf not found. This script is for Fedora.${N}"
  exit 1
fi

DNF_VER="dnf4"
dnf --version 2>/dev/null | head -1 | grep -qi "dnf5" && DNF_VER="dnf5"

START_TS=$(date +%s)
START_USED=$(used_kib)
FEDORA_REL=$(rpm -E %fedora)

echo "${BD}"
echo "  ______        _                    _______"
echo " |  ____|      | |                  |__   __|"
echo " | |__ ___  ___| | ___  _ __ __ _      | |_   _ _ __   ___"
echo " |  __/ _ \\/ _ \\ |/ _ \\| '__/ _\` |     | | | | | '_ \\ / _ \\"
echo " | | |  __/  __/ | (_) | | | (_| |     | | |_| | | | |  __/"
echo " |_|  \\___|\\___|_|\\___/|_|  \\__,_|     |_|\\__,_|_| |_|\\___|"
echo "${N}"
echo "  Fedora $FEDORA_REL | $DNF_VER | kernel $(uname -r) | user: $REAL_USER"
((DRY_RUN)) && echo "  ${Y}DRY RUN MODE — nothing will be changed${N}"
echo "  Log: $LOG_FILE"

# =============================================================================
#  PRE-FLIGHT
# =============================================================================
step "Pre-flight checks"

# Network
if ping -c1 -W3 fedoraproject.org &>/dev/null || ping -c1 -W3 1.1.1.1 &>/dev/null; then
  info "Network is up"
else
  fail "No network connectivity — updates will fail"
fi

# Disk space
ROOT_FREE_MIB=$(df --output=avail -m / | tail -1 | tr -d ' ')
if ((ROOT_FREE_MIB < 2048)); then
  warn "Less than 2 GiB free on / (${ROOT_FREE_MIB} MiB) — updates may fail"
else
  info "Free space on /: ${ROOT_FREE_MIB} MiB"
fi

# Running on battery?
for ps in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
  if [[ -r "$ps" && "$(cat "$ps")" == "0" ]]; then
    warn "Running on battery — consider plugging in before a big update"
    break
  fi
done

# Failed units baseline
FAILED_BEFORE=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
info "Failed systemd units before: $FAILED_BEFORE"

# Filesystem type (for btrfs extras)
ROOT_FSTYPE=$(findmnt -no FSTYPE /)
info "Root filesystem: $ROOT_FSTYPE"

# =============================================================================
#  UPDATES
# =============================================================================
if ((DO_UPDATE)); then

  step "DNF: refresh metadata and upgrade all packages"
  if run dnf upgrade --refresh -y; then
    info "System packages up to date"
  else
    fail "dnf upgrade failed"
  fi

  step "DNF: check for pending distro-sync problems"
  if ((DEEP)); then
    run dnf distro-sync -y || warn "distro-sync reported issues"
  else
    echo "Skipping (only in --deep mode)"
  fi

  if ((DO_FLATPAK)) && have flatpak; then
    step "Flatpak: update apps and runtimes"
    run flatpak update --system -y --noninteractive || warn "system flatpak update had issues"
    [[ "$REAL_USER" != "root" ]] &&
      as_user flatpak update --user -y --noninteractive || true
    info "Flatpak updated"
  fi

  if ((DO_FIRMWARE)) && have fwupdmgr; then
    step "Firmware: check for updates via fwupd"
    run fwupdmgr refresh --force 2>&1 | tail -3 || true
    if fwupdmgr get-updates --no-unreported-check 2>/dev/null | grep -q "Devices with"; then
      warn "Firmware updates are available — run: sudo fwupdmgr update"
    else
      info "No firmware updates pending"
    fi
  fi

  step "Extras: user-space updaters"
  if have rustup && [[ "$REAL_USER" != "root" ]]; then
    as_user rustup update 2>&1 | tail -3 || true
  fi
  if have pipx && [[ "$REAL_USER" != "root" ]]; then
    as_user pipx upgrade-all 2>&1 | tail -3 || true
  fi
  if have toolbox || have distrobox; then
    have distrobox && [[ "$REAL_USER" != "root" ]] &&
      as_user distrobox upgrade --all 2>&1 | tail -5 || true
  fi
  info "User-space updaters done"
fi

# =============================================================================
#  CLEANUP
# =============================================================================
if ((DO_CLEANUP)); then

  step "DNF: remove orphaned dependencies"
  run dnf autoremove -y || warn "autoremove had issues"

  step "DNF: remove old kernels (keeping the running one and the newest)"
  RUNNING_KVER="$(uname -r)"
  OLD_KERNELS=$(dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null |
    grep -v "$RUNNING_KVER" || true)
  if [[ -n "$OLD_KERNELS" ]]; then
    echo "Old kernel packages found:"
    echo "$OLD_KERNELS" | sed 's/^/   /'
    # shellcheck disable=SC2086
    run dnf remove -y $OLD_KERNELS || warn "kernel removal had issues"
  else
    info "No old kernels to remove"
  fi

  step "DNF: clean package cache"
  if ((DEEP)); then
    run dnf clean all
  else
    run dnf clean packages
  fi
  info "DNF cache cleaned"

  step "DNF: retired packages"
  if have remove-retired-packages; then
    run remove-retired-packages || true
  else
    echo "Tip: 'sudo dnf install remove-retired-packages' to auto-detect packages retired from Fedora"
  fi

  step "DNF: packages installed but not in any enabled repo (report only)"
  dnf list --extras 2>/dev/null | tail -n +2 | head -25 || true

  if ((DO_FLATPAK)) && have flatpak; then
    step "Flatpak: remove unused runtimes and repair"
    run flatpak uninstall --unused --system -y --noninteractive || true
    [[ "$REAL_USER" != "root" ]] &&
      as_user flatpak uninstall --unused --user -y --noninteractive || true
    run flatpak repair --system 2>&1 | tail -3 || true
    info "Flatpak tidy"
  fi

  step "systemd journal: vacuum"
  run journalctl --vacuum-time="$JOURNAL_KEEP_TIME" --vacuum-size="$JOURNAL_KEEP_SIZE" 2>&1 | tail -3
  info "Journal limited to $JOURNAL_KEEP_TIME / $JOURNAL_KEEP_SIZE"

  step "Core dumps and crash reports"
  if [[ -d /var/lib/systemd/coredump ]]; then
    run find /var/lib/systemd/coredump -type f -mtime +"$COREDUMP_DAYS" -delete
  fi
  if [[ -d /var/spool/abrt ]]; then
    run find /var/spool/abrt -mindepth 1 -maxdepth 1 -mtime +"$COREDUMP_DAYS" -exec rm -rf {} +
  fi
  info "Old crash data removed (>${COREDUMP_DAYS}d)"

  step "Temp files"
  run find /var/tmp -type f -atime +"$VARTMP_DAYS" -delete 2>/dev/null
  info "Removed files in /var/tmp untouched for ${VARTMP_DAYS}+ days"

  step "User caches and trash ($REAL_USER)"
  if [[ "$REAL_USER" != "root" && -d "$REAL_HOME" ]]; then
    # thumbnails
    [[ -d "$REAL_HOME/.cache/thumbnails" ]] && run rm -rf "$REAL_HOME/.cache/thumbnails"/*
    # trash older than N days
    if [[ -d "$REAL_HOME/.local/share/Trash/files" ]]; then
      run find "$REAL_HOME/.local/share/Trash/files" -mindepth 1 -maxdepth 1 -mtime +"$TRASH_DAYS" -exec rm -rf {} +
      run find "$REAL_HOME/.local/share/Trash/info" -mindepth 1 -maxdepth 1 -mtime +"$TRASH_DAYS" -delete
    fi
    # old stale files in ~/.cache (not touched in 60 days)
    run find "$REAL_HOME/.cache" -type f -atime +60 -delete 2>/dev/null
    # empty dirs left behind
    run find "$REAL_HOME/.cache" -mindepth 1 -type d -empty -delete 2>/dev/null
    info "User caches trimmed"
  fi

  if ((DEV_CACHES)) && [[ "$REAL_USER" != "root" ]]; then
    step "Developer caches"
    have pip && as_user pip cache purge 2>/dev/null
    have npm && as_user npm cache clean --force 2>/dev/null
    have yarn && as_user yarn cache clean 2>/dev/null
    have cargo-cache && as_user cargo cache -a 2>/dev/null
    have go && as_user go clean -cache 2>/dev/null
    have gradle && [[ -d "$REAL_HOME/.gradle/caches" ]] &&
      run find "$REAL_HOME/.gradle/caches" -type f -atime +30 -delete 2>/dev/null
    info "Dev caches cleared"
  fi

  if ((CONTAINERS)); then
    step "Containers: prune unused images and stopped containers"
    if have podman; then
      run podman system prune -af --volumes=false 2>&1 | tail -3
      [[ "$REAL_USER" != "root" ]] && as_user podman system prune -af 2>&1 | tail -3
    fi
    if have docker && systemctl is-active --quiet docker; then
      run docker system prune -af 2>&1 | tail -3
    fi
    info "Container prune complete"
  fi

  step "SSD TRIM"
  run fstrim -av 2>&1 | sed 's/^/   /'

  if [[ "$ROOT_FSTYPE" == "btrfs" ]] && ((DEEP)); then
    step "Btrfs: scrub root filesystem"
    run btrfs scrub start -B / 2>&1 | tail -8
  fi

fi

# =============================================================================
#  HEALTH REPORT
# =============================================================================
step "Health report"

# Failed units
FAILED_NOW=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if ((FAILED_NOW > 0)); then
  warn "$FAILED_NOW failed systemd unit(s):"
  systemctl --failed --no-legend | sed 's/^/     /'
else
  info "No failed systemd units"
fi

# .rpmnew / .rpmsave leftovers
RPMNEW=$(find /etc -xdev \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null)
if [[ -n "$RPMNEW" ]]; then
  warn "Config files need merging (.rpmnew/.rpmsave):"
  echo "$RPMNEW" | sed 's/^/     /'
  echo "     Tip: sudo dnf install rpmconf && sudo rpmconf -a"
else
  info "No .rpmnew/.rpmsave files to merge"
fi

# SELinux
if have getenforce; then
  SEL_MODE=$(getenforce)
  if [[ "$SEL_MODE" != "Enforcing" ]]; then
    warn "SELinux is $SEL_MODE (not Enforcing)"
  else
    info "SELinux: Enforcing"
  fi
  if have ausearch; then
    AVC_COUNT=$(ausearch -m avc -ts recent 2>/dev/null | grep -c '^type=AVC' || true)
    ((AVC_COUNT > 0)) && warn "$AVC_COUNT recent SELinux AVC denial(s) — check: sudo ausearch -m avc -ts recent"
  fi
fi

# dnf problems
if ! dnf check 2>&1 | tail -5 | grep -qiE "error|problem"; then
  info "dnf check: package database healthy"
else
  warn "dnf check reported problems — run: sudo dnf check"
fi

# Firewall
if have firewall-cmd && systemctl is-active --quiet firewalld; then
  info "firewalld is active"
else
  warn "firewalld is not running"
fi

# Reboot / service restart needed?
NEED_REBOOT=0
if dnf needs-restarting -r &>/dev/null; then
  info "No reboot required"
else
  NEED_REBOOT=1
  warn "Reboot recommended (kernel/core libs updated)"
fi
SVC_RESTART=$(dnf needs-restarting -s 2>/dev/null | head -15 || true)
if [[ -n "$SVC_RESTART" ]]; then
  echo "   Services running old libraries (restart them or reboot):"
  echo "$SVC_RESTART" | sed 's/^/     /'
fi

# =============================================================================
#  SUMMARY
# =============================================================================
END_USED=$(used_kib)
FREED=$((START_USED - END_USED))
ELAPSED=$(($(date +%s) - START_TS))

echo
hr
echo "${BD}${G}  ALL DONE${N}  (${ELAPSED}s)"
hr
if ((FREED > 0)); then
  echo "  Disk space reclaimed: ${BD}$(human $FREED)${N}"
else
  echo "  Net disk change: $(human ${FREED#-}) more used (new updates take space too)"
fi
echo "  Root usage now: $(df -h / | awk 'NR==2{print $3" used of "$2" ("$5")"}')"
echo "  Warnings: ${#WARNINGS[@]}   Errors: ${#ERRORS[@]}"
if ((${#ERRORS[@]} > 0)); then
  echo "${R}  Errors:${N}"
  printf '     - %s\n' "${ERRORS[@]}"
fi
echo "  Full log: $LOG_FILE"

if ((NEED_REBOOT)); then
  echo
  if ((AUTO_REBOOT && !DRY_RUN)); then
    echo "${Y}Rebooting in 30 seconds... (Ctrl+C to cancel)${N}"
    sleep 30
    systemctl reboot
  else
    echo "${Y}A reboot is recommended. Run: systemctl reboot${N}"
  fi
fi

exit $((${#ERRORS[@]} > 0 ? 1 : 0))
