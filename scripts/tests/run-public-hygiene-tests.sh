#!/usr/bin/env bash
# Public hygiene: forbid internal portfolio names / private absolute paths
# in active docs, templates, bootstrap, and scripts.
# Does not scan Git history. Allows legitimate "TOFF" / "TOFF Production OS" branding.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0
FAILED_NAMES=()

pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("$1")
  printf 'FAIL  %s\n' "$1"
  if [[ $# -gt 1 ]]; then printf '      %s\n' "$2"; fi
}

echo "======== public hygiene regression tests ========"
echo "root: ${OS_ROOT}"
echo ""

# Scan roots (active framework surface only).
SCAN_PATHS=(
  "${OS_ROOT}/README.md"
  "${OS_ROOT}/AGENTS.md"
  "${OS_ROOT}/CONTRIBUTING.md"
  "${OS_ROOT}/SECURITY.md"
  "${OS_ROOT}/LICENSE"
  "${OS_ROOT}/VERSION"
  "${OS_ROOT}/CHANGELOG.md"
  "${OS_ROOT}/docs"
  "${OS_ROOT}/examples"
  "${OS_ROOT}/templates"
  "${OS_ROOT}/bootstrap"
  "${OS_ROOT}/scripts"
)

# Forbidden portfolio / private-repo strings (word-ish; case-insensitive where noted).
FORBIDDEN_PATTERNS=(
  'Nehokej'
  'WheelDraw'
  'SOWA Game'
  'sowagame'
  'Zuma Roguelike'
  'Fishpond Hockey'
  'project-nhk'
  'GAME-E2E-001'
  'GAME-E2E-002'
  'Paper Football'
  'Pitch\.unity'
  'PitchDebugView'
  '/Users/matejzilak'
  'Not published as a product'
)

# Collect matches excluding this test script (documents the forbidden list).
HYGIENE_SCRIPT="${SCRIPT_DIR}/run-public-hygiene-tests.sh"

found_any=0
match_report="${TMPDIR:-/tmp}/toff-hygiene-matches.$$.txt"
: > "${match_report}"

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  # ripgrep if available; else grep -R
  if command -v rg >/dev/null 2>&1; then
    set +e
    rg -n --hidden --glob '!.git/**' -e "${pattern}" "${SCAN_PATHS[@]}" 2>/dev/null \
      | grep -v "run-public-hygiene-tests.sh" >> "${match_report}"
    set -e
  else
    set +e
    grep -RIn --exclude='run-public-hygiene-tests.sh' -E "${pattern}" "${SCAN_PATHS[@]}" 2>/dev/null \
      >> "${match_report}"
    set -e
  fi
done

if [[ -s "${match_report}" ]]; then
  found_any=1
  fail "no_forbidden_portfolio_strings" "matches:"$'\n'"$(sort -u "${match_report}" | head -40)"
else
  pass "no_forbidden_portfolio_strings"
fi
rm -f "${match_report}"

# Private absolute home paths more generally (except documentation saying not to use them).
# Flag /Users/<name> or /home/<name> in templates and generated-marker language.
path_hits=""
if command -v rg >/dev/null 2>&1; then
  set +e
  path_hits="$(rg -n -e '/Users/[A-Za-z0-9._-]+/' -e '/home/[A-Za-z0-9._-]+/' \
    "${OS_ROOT}/templates" "${OS_ROOT}/examples" "${OS_ROOT}/bootstrap" "${OS_ROOT}/scripts" \
    --glob '!**/run-public-hygiene-tests.sh' 2>/dev/null | grep -v 'hardcoded home' | grep -v 'absolute machine paths' | grep -v 'Hardcoded absolute' || true)"
  set -e
fi
if [[ -n "${path_hits}" ]]; then
  fail "no_private_absolute_paths" "${path_hits}"
else
  pass "no_private_absolute_paths"
fi

# Example dirs must use public names.
if [[ -d "${OS_ROOT}/examples/legacy-mcp-workflow" && -d "${OS_ROOT}/examples/unity-cli-pipeline" ]]; then
  pass "example_dirs_public_names"
else
  fail "example_dirs_public_names" "expected examples/legacy-mcp-workflow and examples/unity-cli-pipeline"
fi

if [[ -d "${OS_ROOT}/examples/nehokej" || -d "${OS_ROOT}/examples/sowa-game" ]]; then
  fail "old_example_dirs_removed" "legacy named example directories still present"
else
  pass "old_example_dirs_removed"
fi

# LICENSE present and looks like MIT
if [[ -f "${OS_ROOT}/LICENSE" ]] && grep -q 'MIT License' "${OS_ROOT}/LICENSE"; then
  pass "mit_license_present"
else
  fail "mit_license_present" "LICENSE missing or not MIT"
fi

# VERSION
ver="$(tr -d '[:space:]' < "${OS_ROOT}/VERSION")"
if [[ "${ver}" == "0.3.1" ]]; then
  pass "version_0_3_1"
else
  fail "version_0_3_1" "VERSION=${ver}"
fi

# Bootstrap dry-run generated AGENTS must not contain portfolio names
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/toff-hygiene-bootstrap.XXXXXX")"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

mkdir -p "${WORKDIR}/game/ProjectSettings" "${WORKDIR}/game/Assets/Scenes"
cat > "${WORKDIR}/game/ProjectSettings/ProjectVersion.txt" <<'EOF'
m_EditorVersion: 6000.0.0f1
m_EditorVersionWithRevision: 6000.0.0f1 (deadbeef)
EOF
printf '%%YAML 1.1\n' > "${WORKDIR}/game/Assets/Scenes/Sample.unity"
git -C "${WORKDIR}/game" init -q
git -C "${WORKDIR}/game" config user.email "test@example.com"
git -C "${WORKDIR}/game" config user.name "Hygiene Test"
git -C "${WORKDIR}/game" add ProjectSettings Assets
git -C "${WORKDIR}/game" commit -q -m "fixture"

"${OS_ROOT}/bootstrap/bootstrap.sh" "${WORKDIR}/game" >/dev/null

boot_scan="$(grep -RIn -E 'Nehokej|WheelDraw|SOWA|Zuma|Fishpond|project-nhk|sowagame|GAME-E2E' "${WORKDIR}/game" || true)"
if [[ -n "${boot_scan}" ]]; then
  fail "bootstrap_output_clean" "${boot_scan}"
else
  pass "bootstrap_output_clean"
fi

# Generated AGENTS should mention TOFF Production OS (branding OK)
if grep -q 'TOFF Production OS' "${WORKDIR}/game/AGENTS.md"; then
  pass "bootstrap_agents_branding"
else
  fail "bootstrap_agents_branding" "expected TOFF Production OS in generated AGENTS.md"
fi

echo ""
echo "======== summary ========"
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
if [[ "${FAIL}" -gt 0 ]]; then
  printf 'Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
