#!/usr/bin/env bash
# =============================================================================
#  ci-validate-stow.sh — Stow packages must apply cleanly and be idempotent
# =============================================================================
#  Stows every package in Configs/ into a throwaway HOME and fails if:
#    * two packages provide the same path (intra-repo conflict)
#    * stow refuses to link (would clobber a real file)
#    * a second run is not a no-op (non-idempotent package)
#    * a created symlink points at a target that does not exist
#
#  Usage: ./Scripts/ci-validate-stow.sh
# =============================================================================
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTCONFDIR="$REPO_ROOT/Configs"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; NC=$'\033[0m'
if [[ ! -t 1 ]]; then RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''; fi

fail=0
err()  { echo "${RED}✖${NC} $1"; fail=1; }
ok()   { echo "  ${GREEN}✔${NC} $1"; }
warn() { echo "  ${YELLOW}⚠${NC} $1"; }
info() { echo "${BOLD}==>${NC} $1"; }

if ! command -v stow >/dev/null 2>&1; then
  err "GNU Stow is not installed (dnf install stow / apt-get install stow)"
  exit 1
fi

if [[ ! -d "$DOTCONFDIR" ]]; then
  err "No Configs/ directory at $DOTCONFDIR"
  exit 1
fi

mapfile -t PACKAGES < <(find "$DOTCONFDIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  err "No packages found in $DOTCONFDIR"
  exit 1
fi

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

info "Validating ${#PACKAGES[@]} package(s) against a throwaway HOME"
echo "    packages: ${PACKAGES[*]}"
echo "    target:   $TMP_HOME"
echo ""

# 1. Every package must contain at least one trackable file.
for pkg in "${PACKAGES[@]}"; do
  count="$(find "$DOTCONFDIR/$pkg" -type f | wc -l)"
  if [[ "$count" -eq 0 ]]; then
    err "Package '$pkg' contains no files"
  fi
done

# 2. Dry run of everything at once: catches conflicts between packages.
info "Dry run (stow --simulate)"
if ! stow --dir="$DOTCONFDIR" --target="$TMP_HOME" --simulate "${PACKAGES[@]}" >/dev/null 2>"$TMP_HOME/.stow.err"; then
  err "stow --simulate failed; conflicting paths between packages:"
  sed 's/^/      /' "$TMP_HOME/.stow.err"
else
  # Would-apply plan must not be empty (stow prints LINK lines on stderr).
  links="$(stow --dir="$DOTCONFDIR" --target="$TMP_HOME" --simulate -v "${PACKAGES[@]}" 2>&1 | grep -c '^LINK:')"
  if [[ "$links" -eq 0 ]]; then
    err "Dry run produced no symlinks (packages are empty or misplaced)"
  else
    ok "plan is clean ($links symlink(s) would be created)"
  fi
fi

# 3. Apply for real, then assert every link resolves.
info "Apply"
if ! stow --dir="$DOTCONFDIR" --target="$TMP_HOME" "${PACKAGES[@]}"; then
  err "stow failed while applying packages"
fi

info "Verifying symlink targets"
broken=0
created=0
while IFS= read -r link; do
  created=$((created + 1))
  if [[ ! -e "$link" ]]; then
    err "Broken symlink: ${link#"$TMP_HOME"/} -> $(readlink "$link")"
    broken=$((broken + 1))
  fi
done < <(find "$TMP_HOME" -type l)
if [[ "$broken" -eq 0 ]]; then
  ok "all $created symlink(s) resolve to existing targets"
fi

# 4. Re-stowing must be a no-op: stow exits 0 and changes nothing.
info "Idempotency (re-stow)"
before="$(find "$TMP_HOME" -type l | sort)"
if ! stow --dir="$DOTCONFDIR" --target="$TMP_HOME" "${PACKAGES[@]}" 2>"$TMP_HOME/.stow.err2"; then
  err "Re-running stow is not idempotent:"
  sed 's/^/      /' "$TMP_HOME/.stow.err2"
else
  after="$(find "$TMP_HOME" -type l | sort)"
  if [[ "$before" != "$after" ]]; then
    err "Re-running stow changed the symlink set"
  else
    ok "second run is a clean no-op"
  fi
fi

# 5. Restow (-R) must also succeed, since that is what the docs recommend.
info "Restow (-R)"
if ! stow --dir="$DOTCONFDIR" --target="$TMP_HOME" -R "${PACKAGES[@]}" 2>"$TMP_HOME/.stow.err3"; then
  err "stow -R failed:"
  sed 's/^/      /' "$TMP_HOME/.stow.err3"
else
  ok "restow is clean"
fi

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo "${GREEN}${BOLD}Stow validation passed.${NC}"
else
  echo "${RED}${BOLD}Stow validation failed.${NC}"
fi
exit "$fail"