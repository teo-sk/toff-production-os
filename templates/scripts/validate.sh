#!/usr/bin/env bash
# Portable Unity Edit Mode validation (TOFF Production OS template).
# Never claims pass without executing Unity Test Framework Edit Mode in this
# invocation (except --self-test, which only validates this script).
#
# Exit codes:
#   0 — PASS
#   1 — FAIL
#   2 — BLOCKED (Editor holds project; Edit Mode not run)
#   3 — script self-test failed
#
# Optional game config (sourced if present): scripts/validate.config.sh
#   UTF_TEST_FILTER   — passed to Unity -testFilter if set
#   RESULTS_XML_NAME  — default editmode-results.xml
#
# Env:
#   UNITY_PATH     — absolute path to Unity binary (must match project pin)
#   UNITY_VERSION  — if set, must equal ProjectSettings pin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${ROOT}/Logs"
PROJECT_VERSION_FILE="${ROOT}/ProjectSettings/ProjectVersion.txt"
CONFIG_FILE="${SCRIPT_DIR}/validate.config.sh"

RESULTS_XML_NAME="editmode-results.xml"
UTF_TEST_FILTER="${UTF_TEST_FILTER:-}"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

RESULTS_XML="${RESULTS_DIR}/${RESULTS_XML_NAME}"
LOG_FILE="${RESULTS_DIR}/editmode-tests.log"
MARKER_FILE="${RESULTS_DIR}/.validate-run-id"

PASSED_CHECKS=()
FAILED_CHECKS=()
SKIPPED_CHECKS=()
UNVERIFIED_CHECKS=()
PINNED_EDITOR_VERSION=""

note_pass() { PASSED_CHECKS+=("$1"); }
note_fail() { FAILED_CHECKS+=("$1"); }
note_skip() { SKIPPED_CHECKS+=("$1"); }
note_unverified() { UNVERIFIED_CHECKS+=("$1"); }

reset_notes() {
  PASSED_CHECKS=()
  FAILED_CHECKS=()
  SKIPPED_CHECKS=()
  UNVERIFIED_CHECKS=()
}

print_report() {
  echo ""
  echo "======== validate.sh report ========"
  echo "project: ${ROOT}"
  echo "pinned:  ${PINNED_EDITOR_VERSION:-unknown}"
  if ((${#PASSED_CHECKS[@]})); then
    echo "PASSED:"
    printf '  - %s\n' "${PASSED_CHECKS[@]}"
  fi
  if ((${#FAILED_CHECKS[@]})); then
    echo "FAILED:"
    printf '  - %s\n' "${FAILED_CHECKS[@]}"
  fi
  if ((${#SKIPPED_CHECKS[@]})); then
    echo "SKIPPED:"
    printf '  - %s\n' "${SKIPPED_CHECKS[@]}"
  fi
  if ((${#UNVERIFIED_CHECKS[@]})); then
    echo "UNVERIFIED:"
    printf '  - %s\n' "${UNVERIFIED_CHECKS[@]}"
  fi
  echo "===================================="
}

usage() {
  cat <<'EOF'
Usage: ./scripts/validate.sh [--self-test] [--help]

  (default)   Run Unity Test Framework Edit Mode against this project.
  --self-test Validate XML parser / fixtures only (NOT Edit Mode).
  --help      Show this help.

Exit: 0 PASS | 1 FAIL | 2 BLOCKED | 3 self-test fail
EOF
}

die_blocked() {
  note_fail "batchmode-editmode: blocked — Editor holds this project"
  note_unverified "Edit Mode suite (not executed this run)"
  note_skip "result-xml-parse (no fresh run)"
  echo "ERROR: Unity Editor already has this project open." >&2
  echo "  Detected: $1" >&2
  echo "  Refusing to launch a competing -batchmode instance." >&2
  echo "  This script will NOT quit your Editor." >&2
  echo "  Safe alternatives:" >&2
  echo "    1) Unity Test Runner → EditMode → Run All, then record results in the task report" >&2
  echo "    2) Quit the Editor yourself, then re-run: ./scripts/validate.sh" >&2
  print_report
  exit 2
}

read_pinned_editor_version() {
  if [[ ! -f "${PROJECT_VERSION_FILE}" ]]; then
    echo "ERROR: missing ${PROJECT_VERSION_FILE}" >&2
    return 1
  fi
  local ver
  ver="$(sed -n 's/^m_EditorVersion:[[:space:]]*//p' "${PROJECT_VERSION_FILE}" | head -n 1 | tr -d '\r')"
  if [[ -z "${ver}" ]]; then
    echo "ERROR: could not parse m_EditorVersion from ${PROJECT_VERSION_FILE}" >&2
    return 1
  fi
  PINNED_EDITOR_VERSION="${ver}"
  if [[ -n "${UNITY_VERSION:-}" && "${UNITY_VERSION}" != "${PINNED_EDITOR_VERSION}" ]]; then
    echo "ERROR: UNITY_VERSION=${UNITY_VERSION} does not match ProjectSettings pin ${PINNED_EDITOR_VERSION}" >&2
    return 1
  fi
  return 0
}

canonical_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "${p}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${p}"
  else
    (cd "${p}" 2>/dev/null && pwd -P) || echo "${p}"
  fi
}

resolve_unity() {
  local pinned="${PINNED_EDITOR_VERSION}"
  if [[ -n "${UNITY_PATH:-}" ]]; then
    if [[ ! -x "${UNITY_PATH}" ]]; then
      echo "ERROR: UNITY_PATH is not executable: ${UNITY_PATH}" >&2
      return 1
    fi
    echo "${UNITY_PATH}"
    return 0
  fi

  local candidates=(
    "/Applications/Unity/Hub/Editor/${pinned}/Unity.app/Contents/MacOS/Unity"
    "${HOME}/Unity/Hub/Editor/${pinned}/Editor/Unity"
    "/opt/unity/Editor/Unity"
  )
  local c
  for c in "${candidates[@]}"; do
    if [[ -x "${c}" ]]; then
      echo "${c}"
      return 0
    fi
  done

  echo "ERROR: Unity ${pinned} executable not found." >&2
  echo "  Set UNITY_PATH to the Unity binary for ${pinned}." >&2
  return 1
}

probe_unity_reported_version() {
  local unity_bin="$1"
  local out
  out="$("${unity_bin}" -version 2>&1 || true)"
  local ver
  ver="$(printf '%s\n' "${out}" | grep -Eo '[0-9]{4}\.[0-9]+\.[0-9]+[a-zA-Z][0-9a-zA-Z]*|[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z][0-9a-zA-Z]*' | head -n 1 || true)"
  if [[ -n "${ver}" ]]; then
    echo "${ver}"
    return 0
  fi
  if [[ "${unity_bin}" =~ /Editor/([^/]+)/ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

verify_unity_binary_version() {
  local unity_bin="$1"
  local reported
  if ! reported="$(probe_unity_reported_version "${unity_bin}")"; then
    echo "ERROR: could not determine version of Unity binary: ${unity_bin}" >&2
    return 1
  fi
  if [[ "${reported}" != "${PINNED_EDITOR_VERSION}" ]]; then
    echo "ERROR: Unity binary reports '${reported}' but project pins '${PINNED_EDITOR_VERSION}'" >&2
    echo "  binary: ${unity_bin}" >&2
    return 1
  fi
  echo "${reported}"
  return 0
}

project_is_locked() {
  local lock="${ROOT}/Temp/UnityLockfile"
  if [[ -e "${lock}" ]]; then
    echo "Temp/UnityLockfile present"
    return 0
  fi

  local canon_root
  canon_root="$(canonical_path "${ROOT}")"
  if command -v pgrep >/dev/null 2>&1; then
    local procs
    procs="$(pgrep -lf "Unity" 2>/dev/null || true)"
    if echo "${procs}" | grep -F -- "-projectpath ${ROOT}" >/dev/null 2>&1 \
      || echo "${procs}" | grep -F -- "-projectPath ${ROOT}" >/dev/null 2>&1 \
      || echo "${procs}" | grep -F -- "-projectpath ${canon_root}" >/dev/null 2>&1 \
      || echo "${procs}" | grep -F -- "-projectPath ${canon_root}" >/dev/null 2>&1; then
      echo "Unity process with -projectPath matching this project"
      return 0
    fi
  fi
  return 1
}

parse_nunit_xml() {
  local xml="$1"
  local require_fresh="${2:-1}"

  if [[ ! -f "${xml}" ]]; then
    note_fail "results-xml: missing ${xml}"
    return 1
  fi

  if [[ "${require_fresh}" == "1" ]]; then
    if [[ ! -f "${MARKER_FILE}" ]]; then
      note_fail "results-xml: missing run marker (refusing stale/unknown results)"
      return 1
    fi
    if [[ "${xml}" -ot "${MARKER_FILE}" ]]; then
      note_fail "results-xml: older than run marker (stale or not overwritten)"
      return 1
    fi
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    note_fail "results-xml: python3 required for structural NUnit parse"
    return 1
  fi

  local py_out py_rc
  set +e
  py_out="$(python3 - "${xml}" <<'PY'
import sys, xml.etree.ElementTree as ET

path = sys.argv[1]
try:
    tree = ET.parse(path)
except ET.ParseError as e:
    print(f"PARSE_ERROR: {e}")
    sys.exit(10)
except OSError as e:
    print(f"IO_ERROR: {e}")
    sys.exit(10)

root = tree.getroot()
if root.tag != "test-run":
    print(f"BAD_ROOT: expected test-run, got {root.tag!r}")
    sys.exit(11)

def attr_int(name):
    if name not in root.attrib:
        print(f"MISSING_ATTR: {name}")
        sys.exit(12)
    try:
        return int(root.attrib[name])
    except ValueError:
        print(f"BAD_ATTR: {name}={root.attrib[name]!r}")
        sys.exit(12)

total = attr_int("total")
passed = attr_int("passed")
failed = attr_int("failed")
skipped = attr_int("skipped")
inconclusive = attr_int("inconclusive") if "inconclusive" in root.attrib else 0
result = root.attrib.get("result")
if not result:
    print("MISSING_ATTR: result")
    sys.exit(12)

sum_parts = passed + failed + skipped + inconclusive
if sum_parts != total:
    print(f"COUNT_MISMATCH: passed+failed+skipped+inconclusive={sum_parts} total={total}")
    sys.exit(13)

testcasecount = root.attrib.get("testcasecount")
if testcasecount is not None:
    try:
        tc = int(testcasecount)
    except ValueError:
        print(f"BAD_ATTR: testcasecount={testcasecount!r}")
        sys.exit(12)
    if tc != total:
        print(f"TESTCASECOUNT_MISMATCH: testcasecount={tc} total={total}")
        sys.exit(13)

print(f"SUMMARY result={result} total={total} passed={passed} failed={failed} skipped={skipped} inconclusive={inconclusive}")

if total < 1 or passed < 1:
    print("INSUFFICIENT: need at least one executed passed test")
    sys.exit(14)

if failed != 0:
    print(f"FAILURES: failed={failed}")
    sys.exit(15)

if inconclusive != 0:
    print(f"INCONCLUSIVE: inconclusive={inconclusive}")
    sys.exit(16)

if result != "Passed":
    print(f"BAD_RESULT: {result}")
    sys.exit(17)

sys.exit(0)
PY
)"
  py_rc=$?
  set -e

  echo "NUnit: ${py_out}"

  case "${py_rc}" in
    0)
      local skipped_n
      skipped_n="$(echo "${py_out}" | sed -n 's/.*skipped=\([0-9]*\).*/\1/p' | head -n 1)"
      if [[ -n "${skipped_n}" && "${skipped_n}" -gt 0 ]]; then
        note_skip "editmode-tests: skipped=${skipped_n} (suite still Passed)"
      fi
      note_pass "editmode-tests: ${py_out}"
      note_pass "results-xml: structurally valid${require_fresh:+ and fresh}"
      return 0
      ;;
    10) note_fail "results-xml: malformed XML (${py_out})" ;;
    11) note_fail "results-xml: bad root (${py_out})" ;;
    12) note_fail "results-xml: missing/invalid attributes (${py_out})" ;;
    13) note_fail "results-xml: count inconsistency (${py_out})" ;;
    14) note_fail "results-xml: no passed tests (${py_out})" ;;
    15) note_fail "editmode-tests: failures (${py_out})" ;;
    16) note_fail "editmode-tests: inconclusive (${py_out})" ;;
    17) note_fail "editmode-tests: bad result (${py_out})" ;;
    *) note_fail "results-xml: parser exit ${py_rc} (${py_out})" ;;
  esac
  return 1
}

write_fixture_xml() {
  local path="$1"
  local body="$2"
  printf '%s\n' "${body}" > "${path}"
}

assert_parse_rc() {
  local label="$1"
  local xml="$2"
  local expect_rc="$3"
  reset_notes
  set +e
  parse_nunit_xml "${xml}" 0
  local rc=$?
  set -e
  if [[ "${rc}" -eq "${expect_rc}" ]]; then
    echo "  OK  ${label} (parse rc=${rc})"
    return 0
  fi
  echo "  FAIL ${label}: expected parse rc=${expect_rc}, got ${rc}" >&2
  return 1
}

run_self_test() {
  echo "validate.sh --self-test (script parsers only; NOT Unity Edit Mode)"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/toff-validate-selftest.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp}'" EXIT

  local failures=0
  local xml

  xml="${tmp}/good.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="3" result="Passed" total="3" passed="3" failed="0" inconclusive="0" skipped="0"></test-run>'
  assert_parse_rc "good suite" "${xml}" 0 || failures=$((failures + 1))

  xml="${tmp}/failed.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="2" result="Failed" total="2" passed="1" failed="1" inconclusive="0" skipped="0"></test-run>'
  assert_parse_rc "failed suite" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/inconclusive.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="2" result="Passed" total="2" passed="1" failed="0" inconclusive="1" skipped="0"></test-run>'
  assert_parse_rc "inconclusive rejected" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/zero.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="0" result="Passed" total="0" passed="0" failed="0" inconclusive="0" skipped="0"></test-run>'
  assert_parse_rc "zero tests rejected" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/mismatch.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="3" result="Passed" total="3" passed="2" failed="0" inconclusive="0" skipped="0"></test-run>'
  assert_parse_rc "count mismatch rejected" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/badroot.xml"
  write_fixture_xml "${xml}" '<not-a-run total="1" passed="1" failed="0" skipped="0" result="Passed"></not-a-run>'
  assert_parse_rc "bad root rejected" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/malformed.xml"
  write_fixture_xml "${xml}" '<test-run total="1" passed="1"'
  assert_parse_rc "malformed rejected" "${xml}" 1 || failures=$((failures + 1))

  xml="${tmp}/skipped_ok.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="3" result="Passed" total="3" passed="2" failed="0" inconclusive="0" skipped="1"></test-run>'
  assert_parse_rc "passed with skips allowed" "${xml}" 0 || failures=$((failures + 1))

  xml="${tmp}/stale.xml"
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="1" result="Passed" total="1" passed="1" failed="0" inconclusive="0" skipped="0"></test-run>'
  MARKER_FILE="${tmp}/marker"
  echo "marker" > "${MARKER_FILE}"
  sleep 1
  touch "${MARKER_FILE}"
  reset_notes
  set +e
  parse_nunit_xml "${xml}" 1
  local stale_rc=$?
  set -e
  if [[ "${stale_rc}" -eq 1 ]]; then
    echo "  OK  stale xml rejected (parse rc=1)"
  else
    echo "  FAIL stale xml: expected rc=1 got ${stale_rc}" >&2
    failures=$((failures + 1))
  fi

  echo "marker2" > "${MARKER_FILE}"
  sleep 1
  write_fixture_xml "${xml}" '<test-run id="2" testcasecount="1" result="Passed" total="1" passed="1" failed="0" inconclusive="0" skipped="0"></test-run>'
  reset_notes
  set +e
  parse_nunit_xml "${xml}" 1
  local fresh_rc=$?
  set -e
  if [[ "${fresh_rc}" -eq 0 ]]; then
    echo "  OK  fresh xml accepted"
  else
    echo "  FAIL fresh xml: expected rc=0 got ${fresh_rc}" >&2
    failures=$((failures + 1))
  fi

  # Pin read only if this tree is a Unity project (template self-test may run from installed game)
  if [[ -f "${PROJECT_VERSION_FILE}" ]]; then
    if read_pinned_editor_version; then
      echo "  OK  pinned editor version=${PINNED_EDITOR_VERSION}"
    else
      echo "  FAIL read_pinned_editor_version" >&2
      failures=$((failures + 1))
    fi
  else
    echo "  SKIP pinned version (no ProjectSettings/ProjectVersion.txt in this tree)"
  fi

  if [[ "${failures}" -ne 0 ]]; then
    echo "SELF-TEST FAILED (${failures} case(s)) — this is not an Edit Mode result"
    exit 3
  fi
  echo "SELF-TEST PASSED (script only; Unity Edit Mode was NOT executed)"
  exit 0
}

main() {
  cd "${ROOT}"
  mkdir -p "${RESULTS_DIR}"

  echo "validate.sh — Unity Edit Mode (Production OS template)"
  echo "  root: ${ROOT}"

  if ! read_pinned_editor_version; then
    exit 1
  fi
  note_pass "project-pin: ${PINNED_EDITOR_VERSION} (ProjectSettings/ProjectVersion.txt)"

  local lock_reason
  if lock_reason="$(project_is_locked)"; then
    die_blocked "${lock_reason}"
  fi
  note_pass "editor-lock: clear"

  local unity
  if ! unity="$(resolve_unity)"; then
    exit 1
  fi
  note_pass "unity-binary: ${unity}"

  local verified
  if ! verified="$(verify_unity_binary_version "${unity}")"; then
    note_fail "unity-binary-version: does not match project pin"
    print_report
    exit 1
  fi
  note_pass "unity-binary-version: ${verified} matches pin"

  rm -f "${RESULTS_XML}"
  MARKER_FILE="${RESULTS_DIR}/.validate-run-id"
  date -u +"run_id=%Y%m%dT%H%M%SZ%nroot=${ROOT}%npinned=${PINNED_EDITOR_VERSION}" > "${MARKER_FILE}"
  sleep 1

  echo "Running Edit Mode tests (batchmode)…"
  local -a unity_args=(
    -batchmode
    -nographics
    -projectPath "${ROOT}"
    -runTests
    -testPlatform EditMode
    -testResults "${RESULTS_XML}"
    -logFile "${LOG_FILE}"
    -quit
  )
  if [[ -n "${UTF_TEST_FILTER}" ]]; then
    unity_args+=(-testFilter "${UTF_TEST_FILTER}")
    echo "  filter: ${UTF_TEST_FILTER}"
  fi

  set +e
  "${unity}" "${unity_args[@]}"
  local unity_rc=$?
  set -e

  if [[ "${unity_rc}" -ne 0 ]]; then
    note_fail "unity-exit-code: ${unity_rc} (see ${LOG_FILE})"
  else
    note_pass "unity-exit-code: 0"
  fi

  set +e
  parse_nunit_xml "${RESULTS_XML}" 1
  local parse_rc=$?
  set -e

  print_report

  if [[ "${unity_rc}" -ne 0 || "${parse_rc}" -ne 0 ]]; then
    echo "VALIDATION FAILED"
    exit 1
  fi

  echo "VALIDATION PASSED"
  exit 0
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  --self-test) run_self_test ;;
  "") main ;;
  *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
esac
