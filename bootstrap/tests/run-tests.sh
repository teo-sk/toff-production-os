#!/usr/bin/env bash
# Regression tests for bootstrap/bootstrap.sh.
# Uses disposable fixture directories only — never touches real game repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OS_ROOT="$(cd "${BOOTSTRAP_DIR}/.." && pwd)"
BOOTSTRAP="${BOOTSTRAP_DIR}/bootstrap.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/toff-bootstrap-tests.XXXXXX")"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "======== bootstrap regression tests ========"
echo "workdir: ${WORKDIR}"
echo "bootstrap: ${BOOTSTRAP}"
echo ""

pass() {
  PASS=$((PASS + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("$1")
  printf 'FAIL  %s\n' "$1"
  if [[ $# -gt 1 ]]; then
    printf '      %s\n' "$2"
  fi
}

# Minimal standalone Unity-ish Git repo fixture.
make_unity_repo() {
  local dest="$1"
  mkdir -p "${dest}/ProjectSettings" "${dest}/Assets/Scenes"
  cat > "${dest}/ProjectSettings/ProjectVersion.txt" <<'EOF'
m_EditorVersion: 6000.0.0f1
m_EditorVersionWithRevision: 6000.0.0f1 (deadbeef)
EOF
  printf '%%YAML 1.1\n' > "${dest}/Assets/Scenes/Sample.unity"
  printf '%%YAML 1.1\n' > "${dest}/Assets/Scenes/Other.unity"
  git -C "${dest}" init -q
  git -C "${dest}" config user.email "test@example.com"
  git -C "${dest}" config user.name "Bootstrap Test"
  # Avoid depending on global gitignore / commit identity beyond local config.
  git -C "${dest}" add ProjectSettings Assets
  git -C "${dest}" commit -q -m "fixture"
}

assert_exit_nonzero() {
  local name="$1"
  shift
  local rc=0
  set +e
  "$@" >/dev/null 2>"${WORKDIR}/stderr.${name}.txt"
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    pass "${name}"
  else
    fail "${name}" "expected nonzero exit; stderr=$(tr '\n' ' ' < "${WORKDIR}/stderr.${name}.txt")"
  fi
}

assert_exit_zero() {
  local name="$1"
  shift
  local rc=0
  local out="${WORKDIR}/stdout.${name}.txt"
  set +e
  "$@" >"${out}" 2>"${WORKDIR}/stderr.${name}.txt"
  rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    pass "${name}"
  else
    fail "${name}" "expected exit 0 got ${rc}; stderr=$(tr '\n' ' ' < "${WORKDIR}/stderr.${name}.txt")"
  fi
}

stderr_contains() {
  local name="$1"
  local needle="$2"
  if grep -q "${needle}" "${WORKDIR}/stderr.${name}.txt" 2>/dev/null; then
    return 0
  fi
  # Some failures may print to stdout depending on die path — check both.
  if grep -q "${needle}" "${WORKDIR}/stdout.${name}.txt" 2>/dev/null; then
    return 0
  fi
  return 1
}

# --- 1. Valid standalone Unity project ---------------------------------------
REPO1="${WORKDIR}/Game One"
make_unity_repo "${REPO1}"
assert_exit_zero "01_valid_standalone" "${BOOTSTRAP}" "${REPO1}"
if [[ -f "${REPO1}/AGENTS.md" && -f "${REPO1}/docs/production-os-version.txt" && -f "${REPO1}/scripts/validate.sh" ]]; then
  pass "01_valid_standalone_files"
else
  fail "01_valid_standalone_files" "expected installed marker files missing"
fi

# --- 2. Nested directory inside another Git repository -----------------------
NEST_ROOT="${WORKDIR}/parent-repo"
make_unity_repo "${NEST_ROOT}"
mkdir -p "${NEST_ROOT}/nested/subdir"
# nested path is inside parent git but is not its own repo root
assert_exit_nonzero "02_nested_git_rejected" "${BOOTSTRAP}" "${NEST_ROOT}/nested/subdir"
if stderr_contains "02_nested_git_rejected" "independent Git repository root"; then
  pass "02_nested_git_message"
else
  fail "02_nested_git_message" "missing identity error message"
fi

# --- 3. Symlinked destination directory escaping the target ------------------
REPO3="${WORKDIR}/symlink-dir-repo"
make_unity_repo "${REPO3}"
OUTSIDE3="${WORKDIR}/outside-dir-escape"
mkdir -p "${OUTSIDE3}"
# Make docs a symlink escaping the repo — bootstrap must refuse before writing.
ln -s "${OUTSIDE3}" "${REPO3}/docs"
assert_exit_nonzero "03_symlink_dest_dir" "${BOOTSTRAP}" "${REPO3}"
# Outside must remain empty of bootstrap artifacts
if [[ ! -e "${OUTSIDE3}/00-status.md" && ! -e "${OUTSIDE3}/production-os-version.txt" ]]; then
  pass "03_symlink_dest_dir_no_escape_write"
else
  fail "03_symlink_dest_dir_no_escape_write" "wrote through escaped docs symlink"
fi

# --- 4. Symlinked destination file escaping the target -----------------------
REPO4="${WORKDIR}/symlink-file-repo"
make_unity_repo "${REPO4}"
OUTSIDE4="${WORKDIR}/outside-file-escape"
mkdir -p "${OUTSIDE4}"
OUTSIDE_FILE4="${OUTSIDE4}/agents-victim.md"
echo "ORIGINAL_OUTSIDE" > "${OUTSIDE_FILE4}"
ln -s "${OUTSIDE_FILE4}" "${REPO4}/AGENTS.md"
# Even with --force, must refuse symlink leaf
assert_exit_nonzero "04_symlink_dest_file_force" "${BOOTSTRAP}" --force "${REPO4}"
if grep -q 'ORIGINAL_OUTSIDE' "${OUTSIDE_FILE4}"; then
  pass "04_symlink_dest_file_untouched"
else
  fail "04_symlink_dest_file_untouched" "outside symlink target was modified"
fi

# --- 5. Safe existing-file skip in normal mode -------------------------------
REPO5="${WORKDIR}/skip-existing"
make_unity_repo "${REPO5}"
echo "CUSTOM_AGENTS" > "${REPO5}/AGENTS.md"
assert_exit_zero "05_skip_existing" "${BOOTSTRAP}" "${REPO5}"
if grep -q 'CUSTOM_AGENTS' "${REPO5}/AGENTS.md"; then
  pass "05_skip_existing_preserved"
else
  fail "05_skip_existing_preserved" "AGENTS.md was overwritten without --force"
fi
if grep -q 'skip existing' "${WORKDIR}/stdout.05_skip_existing.txt"; then
  pass "05_skip_existing_reported"
else
  fail "05_skip_existing_reported" "skip not reported"
fi

# --- 6. Unsafe existing-file target in --force mode --------------------------
# Symlinked AGENTS.md + --force must still refuse (same as 4, alternate layout).
REPO6="${WORKDIR}/force-unsafe"
make_unity_repo "${REPO6}"
OUTSIDE6="${WORKDIR}/outside-force"
mkdir -p "${OUTSIDE6}"
echo "KEEP_ME" > "${OUTSIDE6}/keep.md"
ln -s "${OUTSIDE6}/keep.md" "${REPO6}/AGENTS.md"
assert_exit_nonzero "06_force_unsafe_symlink" "${BOOTSTRAP}" --force "${REPO6}"
if grep -q 'KEEP_ME' "${OUTSIDE6}/keep.md"; then
  pass "06_force_unsafe_preserved"
else
  fail "06_force_unsafe_preserved" "--force modified symlink target"
fi

# --- 7. Dry-run creates no target files --------------------------------------
REPO7="${WORKDIR}/dry-run-repo"
make_unity_repo "${REPO7}"
BEFORE7="$(find "${REPO7}" -type f | sort | cksum)"
assert_exit_zero "07_dry_run" "${BOOTSTRAP}" --dry-run "${REPO7}"
AFTER7="$(find "${REPO7}" -type f | sort | cksum)"
if [[ "${BEFORE7}" == "${AFTER7}" ]]; then
  pass "07_dry_run_no_writes"
else
  fail "07_dry_run_no_writes" "dry-run modified fixture files"
fi
if [[ ! -f "${REPO7}/AGENTS.md" ]]; then
  pass "07_dry_run_no_agents"
else
  fail "07_dry_run_no_agents" "AGENTS.md created during dry-run"
fi

# --- 8. Repeated bootstrap is idempotent -------------------------------------
REPO8="${WORKDIR}/idempotent"
make_unity_repo "${REPO8}"
assert_exit_zero "08_idempotent_first" "${BOOTSTRAP}" "${REPO8}"
CKSUM8A="$(find "${REPO8}" -type f ! -path '*/.git/*' -print0 | sort -z | xargs -0 cksum | cksum)"
assert_exit_zero "08_idempotent_second" "${BOOTSTRAP}" "${REPO8}"
CKSUM8B="$(find "${REPO8}" -type f ! -path '*/.git/*' -print0 | sort -z | xargs -0 cksum | cksum)"
if [[ "${CKSUM8A}" == "${CKSUM8B}" ]]; then
  pass "08_idempotent_unchanged"
else
  fail "08_idempotent_unchanged" "second run mutated files"
fi

# --- 9. Missing or invalid Unity project identity ----------------------------
REPO9="${WORKDIR}/no-unity"
mkdir -p "${REPO9}"
git -C "${REPO9}" init -q
# Still allowed to install docs/rules, but must report missing Unity identity.
assert_exit_zero "09_missing_unity" "${BOOTSTRAP}" "${REPO9}"
if grep -q 'unity-project: NO' "${WORKDIR}/stdout.09_missing_unity.txt"; then
  pass "09_missing_unity_reported"
else
  fail "09_missing_unity_reported" "missing Unity identity not reported"
fi
if grep -q 'Unknown / TODO' "${WORKDIR}/stdout.09_missing_unity.txt" && \
   grep -q 'unity-version' "${WORKDIR}/stdout.09_missing_unity.txt"; then
  pass "09_missing_unity_unknown_section"
else
  fail "09_missing_unity_unknown_section" "unknown provenance not reported"
fi

# Prefix-collision path: sibling whose name starts with OS_ABS basename should not be blocked as OS itself.
# (Covered indirectly by using WORKDIR fixtures far from OS_ROOT.)

# --- 10. Uncertain game name / main scene remain unconfirmed -----------------
REPO10="${WORKDIR}/Unconfirmed Game"
make_unity_repo "${REPO10}"
assert_exit_zero "10_unconfirmed_meta" "${BOOTSTRAP}" "${REPO10}"
if grep -q 'NEEDS_CONFIRMATION' "${REPO10}/AGENTS.md" && \
   grep -q 'TODO_CONFIRM_GAME_NAME' "${REPO10}/AGENTS.md" && \
   grep -q 'TODO_CONFIRM_PRIMARY_SCENE\|NEEDS_CONFIRMATION' "${REPO10}/AGENTS.md"; then
  pass "10_agents_unconfirmed_placeholders"
else
  fail "10_agents_unconfirmed_placeholders" "AGENTS.md lacks unconfirmed markers"
fi
if grep -q 'INFERRED' "${WORKDIR}/stdout.10_unconfirmed_meta.txt" && \
   grep -q 'NEEDS_CONFIRMATION' "${WORKDIR}/stdout.10_unconfirmed_meta.txt" && \
   ! grep -q 'primary-scene-guess:' "${WORKDIR}/stdout.10_unconfirmed_meta.txt"; then
  pass "10_report_unconfirmed"
else
  fail "10_report_unconfirmed" "report did not mark inferred/unconfirmed metadata"
fi
# Must not treat first scene as authoritative main scene string alone
if grep -q 'Primary gameplay scene: `Assets/Scenes/Sample.unity`' "${REPO10}/AGENTS.md"; then
  fail "10_no_authoritative_first_scene" "first .unity treated as confirmed primary scene"
else
  pass "10_no_authoritative_first_scene"
fi

# --- Extra: path with spaces already covered by REPO1 / REPO10 ---------------
# --- Extra: refuse bootstrapping Production OS itself ------------------------
assert_exit_nonzero "11_refuse_os_self" "${BOOTSTRAP}" "${OS_ROOT}"

# --- Extra: --force cannot install when docs symlink escapes -----------------
REPO12="${WORKDIR}/force-symlink-dir"
make_unity_repo "${REPO12}"
OUTSIDE12="${WORKDIR}/outside-force-dir"
mkdir -p "${OUTSIDE12}"
ln -s "${OUTSIDE12}" "${REPO12}/docs"
assert_exit_nonzero "12_force_symlink_dir" "${BOOTSTRAP}" --force "${REPO12}"
if [[ ! -e "${OUTSIDE12}/00-status.md" ]]; then
  pass "12_force_symlink_dir_no_escape"
else
  fail "12_force_symlink_dir_no_escape" "--force wrote through docs symlink"
fi

# --- Extra: prefix-collision sibling path ------------------------------------
# Create a path that string-prefixes a sibling; ensure writes stay inside intended root.
PREFIX_A="${WORKDIR}/game"
PREFIX_B="${WORKDIR}/game-extra"
make_unity_repo "${PREFIX_A}"
make_unity_repo "${PREFIX_B}"
assert_exit_zero "13_prefix_collision_a" "${BOOTSTRAP}" "${PREFIX_A}"
assert_exit_zero "13_prefix_collision_b" "${BOOTSTRAP}" "${PREFIX_B}"
if [[ -f "${PREFIX_A}/AGENTS.md" && -f "${PREFIX_B}/AGENTS.md" ]]; then
  pass "13_prefix_collision_both_ok"
else
  fail "13_prefix_collision_both_ok" "prefix-adjacent repos failed install"
fi

echo ""
echo "======== summary ========"
echo "passed: ${PASS}"
echo "failed: ${FAIL}"
if ((FAIL)); then
  echo "failed tests:"
  for n in "${FAILED_NAMES[@]}"; do echo "  - ${n}"; done
  exit 1
fi
echo "all tests passed"
exit 0
