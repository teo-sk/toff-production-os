#!/usr/bin/env bash
# Automated tests for scripts/unity-capability-detect.sh
# Disposable fixtures + mocked CLI only — never touches real game repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OS_ROOT="$(cd "${SCRIPTS_DIR}/.." && pwd)"
DETECT="${SCRIPTS_DIR}/unity-capability-detect.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/toff-cap-detect-tests.XXXXXX")"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "======== unity-capability-detect regression tests ========"
echo "workdir: ${WORKDIR}"
echo "detect:  ${DETECT}"
echo ""

pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("$1")
  printf 'FAIL  %s\n' "$1"
  if [[ $# -gt 1 ]]; then printf '      %s\n' "$2"; fi
}

make_unity_project() {
  local dest="$1"
  local version="${2:-6000.3.10f1}"
  local pipeline="${3:-}"   # empty | version string
  local assistant="${4:-}"  # empty | version string
  mkdir -p "${dest}/ProjectSettings" "${dest}/Assets" "${dest}/Packages"
  cat > "${dest}/ProjectSettings/ProjectVersion.txt" <<EOF
m_EditorVersion: ${version}
m_EditorVersionWithRevision: ${version} (deadbeef)
EOF
  # manifest
  python3 - "${dest}" "${pipeline}" "${assistant}" <<'PY'
import json, sys
from pathlib import Path
dest, pipeline, assistant = sys.argv[1], sys.argv[2], sys.argv[3]
deps = {"com.unity.test-framework": "1.6.0"}
if pipeline:
    deps["com.unity.pipeline"] = pipeline
if assistant:
    deps["com.unity.ai.assistant"] = assistant
manifest = {"dependencies": deps}
lock_deps = {}
for k, v in deps.items():
    lock_deps[k] = {"version": v, "depth": 0, "source": "registry", "dependencies": {}, "url": "https://packages.unity.com"}
Path(dest, "Packages", "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
Path(dest, "Packages", "packages-lock.json").write_text(json.dumps({"dependencies": lock_deps}, indent=2) + "\n")
PY
  git -C "${dest}" init -q
  git -C "${dest}" config user.email "test@example.com"
  git -C "${dest}" config user.name "CapDetect Test"
  git -C "${dest}" add ProjectSettings Assets Packages
  git -C "${dest}" commit -q -m "fixture"
}

# Mock unity CLI written per case
write_mock_unity() {
  local bin="$1"
  local mode="$2"  # missing handled by not creating; else: version_only|no_pipeline_status|unreachable|reachable|mismatch|malformed|bad_exit
  local project_path="${3:-}"
  mkdir -p "$(dirname "${bin}")"
  cat > "${bin}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
MODE="${mode}"
PROJECT_PATH="${project_path}"
cmd="\${1:-}"
# strip global flags loosely
args=("\$@")
if [[ "\$cmd" == "--version" || "\$cmd" == "-V" ]]; then
  echo "1.0.0-beta.8-mock"
  exit 0
fi
# find primary command token
primary=""
for a in "\${args[@]}"; do
  case "\$a" in
    --*|-) continue ;;
    *) primary="\$a"; break ;;
  esac
done
# handle \`unity --format json status\` style — commander usually puts command first
for a in "\${args[@]}"; do
  case "\$a" in
    status|pipeline|command|test|mcp) primary="\$a"; break ;;
  esac
done

case "\$MODE" in
  version_only)
    if [[ "\$primary" == "status" ]]; then
      echo '{"success":false,"command":"status","data":{"count":0,"instances":[]},"errors":[{"code":"STATUS_NO_INSTANCES","message":"No Unity Editor instances"}],"warnings":[]}'
      exit 1
    fi
    if [[ "\$primary" == "pipeline" ]]; then
      echo '{"success":true,"command":"pipeline list","data":{"instances":[],"summary":{"totalInstances":0}}}'
      exit 0
    fi
    if [[ "\$primary" == "command" ]]; then
      echo '{"success":false,"errors":[{"message":"no instance"}]}'
      exit 1
    fi
    echo "unexpected: \$*" >&2; exit 99
    ;;
  unreachable)
    if [[ "\$primary" == "status" ]]; then
      echo '{"success":false,"command":"status","data":{"count":0,"instances":[]},"errors":[{"code":"STATUS_NO_INSTANCES","message":"No instances"}],"warnings":[]}'
      exit 1
    fi
    if [[ "\$primary" == "pipeline" ]]; then
      echo "{\"success\":true,\"command\":\"pipeline list\",\"data\":{\"instances\":[{\"projectName\":\"X\",\"projectPath\":\"\${PROJECT_PATH}\",\"pid\":1,\"isRunning\":false,\"hasPipelinePackage\":true,\"pipelineVersion\":\"0.9.1-exp.1\",\"pipelineServer\":{\"port\":7800,\"isReachable\":false}}],\"summary\":{\"totalInstances\":1,\"reachableServers\":0}}}"
      exit 0
    fi
    if [[ "\$primary" == "command" ]]; then
      echo '{"success":false,"errors":[{"message":"unreachable"}]}'
      exit 1
    fi
    exit 99
    ;;
  reachable)
    if [[ "\$primary" == "status" ]]; then
      echo "{\"success\":true,\"command\":\"status\",\"data\":{\"count\":1,\"instances\":[{\"port\":7800,\"project\":\"\${PROJECT_PATH}\",\"version\":\"6000.3.10f1\",\"pid\":123,\"state\":\"ready\"}]},\"errors\":[],\"warnings\":[]}"
      exit 0
    fi
    if [[ "\$primary" == "pipeline" ]]; then
      echo "{\"success\":true,\"command\":\"pipeline list\",\"data\":{\"instances\":[{\"projectName\":\"Game\",\"projectPath\":\"\${PROJECT_PATH}\",\"pid\":123,\"isRunning\":true,\"hasPipelinePackage\":true,\"pipelineVersion\":\"0.9.1-exp.1\",\"pipelineServer\":{\"port\":7800,\"isReachable\":true}}],\"summary\":{\"totalInstances\":1,\"reachableServers\":1}}}"
      exit 0
    fi
    if [[ "\$primary" == "command" ]]; then
      echo "{\"success\":true,\"command\":\"command editor\",\"data\":{\"command\":\"editor\",\"parameters\":{},\"result\":{\"status\":\"ready\",\"compiling\":false,\"playMode\":\"stopped\",\"projectPath\":\"\${PROJECT_PATH}\",\"unityVersion\":\"6000.3.10f1\"},\"success\":true},\"errors\":[],\"warnings\":[]}"
      exit 0
    fi
    exit 99
    ;;
  mismatch)
    OTHER="/tmp/other-unity-project-mock"
    if [[ "\$primary" == "status" ]]; then
      echo "{\"success\":true,\"command\":\"status\",\"data\":{\"count\":1,\"instances\":[{\"port\":7800,\"project\":\"\${OTHER}\",\"version\":\"6000.3.10f1\",\"pid\":9,\"state\":\"ready\"}]},\"errors\":[],\"warnings\":[]}"
      exit 0
    fi
    if [[ "\$primary" == "pipeline" ]]; then
      echo "{\"success\":true,\"command\":\"pipeline list\",\"data\":{\"instances\":[{\"projectPath\":\"\${OTHER}\",\"pid\":9,\"isRunning\":true,\"hasPipelinePackage\":true,\"pipelineVersion\":\"0.9.1-exp.1\",\"pipelineServer\":{\"isReachable\":true,\"port\":7800}}],\"summary\":{\"totalInstances\":1}}}"
      exit 0
    fi
    if [[ "\$primary" == "command" ]]; then
      echo "{\"success\":true,\"data\":{\"result\":{\"projectPath\":\"\${OTHER}\",\"playMode\":\"stopped\",\"status\":\"ready\"}}}"
      exit 0
    fi
    exit 99
    ;;
  malformed)
    if [[ "\$primary" == "status" ]]; then
      echo 'NOT-JSON{'
      exit 0
    fi
    if [[ "\$primary" == "pipeline" ]]; then
      echo 'ALSO-BAD'
      exit 0
    fi
    if [[ "\$primary" == "command" ]]; then
      echo '{'
      exit 0
    fi
    exit 99
    ;;
  bad_exit)
    echo "boom" >&2
    exit 42
    ;;
  *)
    echo "unknown mock mode \$MODE" >&2
    exit 98
    ;;
esac
EOF
  chmod +x "${bin}"
}

jq_field() {
  # Extract nested fields. Use '/' separators so package ids with dots work
  # e.g. packages/com.unity.pipeline/state
  local json_file="$1"
  local expr="$2"
  python3 - "$json_file" "$expr" <<'PY'
import json,sys
doc=json.load(open(sys.argv[1]))
expr=sys.argv[2]
cur=doc
for part in expr.split("/"):
    if not part:
        continue
    if part.endswith("]") and "[" in part:
        name, idx = part[:-1].split("[")
        cur = cur[name][int(idx)]
    else:
        cur = cur[part]
if isinstance(cur, (dict, list)):
    print(json.dumps(cur))
else:
    print(cur)
PY
}

run_detect() {
  local name="$1"
  local project="$2"
  local mock_bin="${3:-}"
  local out="${WORKDIR}/out.${name}.json"
  local err="${WORKDIR}/err.${name}.txt"
  local rc=0
  set +e
  if [[ -n "${mock_bin}" ]]; then
    UNITY_CAP_DETECT_UNITY="${mock_bin}" UNITY_CAP_DETECT_OS_VERSION="0.3.0-test" \
      "${DETECT}" --pretty "${project}" >"${out}" 2>"${err}"
  else
    # Force missing CLI
    UNITY_CAP_DETECT_UNITY="${WORKDIR}/no-such-unity-binary" UNITY_CAP_DETECT_OS_VERSION="0.3.0-test" \
      "${DETECT}" --pretty "${project}" >"${out}" 2>"${err}"
  fi
  rc=$?
  set -e
  echo "${rc}" > "${WORKDIR}/rc.${name}.txt"
  return 0
}

expect_rc() {
  local name="$1"
  local want="$2"
  local got
  got="$(cat "${WORKDIR}/rc.${name}.txt")"
  if [[ "${got}" == "${want}" ]]; then
    pass "${name}_exit_${want}"
  else
    fail "${name}_exit_${want}" "got ${got}; stderr=$(tr '\n' ' ' < "${WORKDIR}/err.${name}.txt")"
  fi
}

expect_json_eq() {
  local name="$1"
  local field="$2"
  local want="$3"
  local got
  if ! got="$(jq_field "${WORKDIR}/out.${name}.json" "${field}" 2>/dev/null)"; then
    fail "${name}_${field}" "cannot read field; stderr=$(tr '\n' ' ' < "${WORKDIR}/err.${name}.txt")"
    return
  fi
  if [[ "${got}" == "${want}" ]]; then
    pass "${name}_${field}"
  else
    fail "${name}_${field}" "want=${want} got=${got}"
  fi
}

# --- syntax ---
if bash -n "${DETECT}"; then
  pass "bash_n_detect"
else
  fail "bash_n_detect"
fi

# --- 1. Missing CLI ---
P1="${WORKDIR}/missing-cli-proj"
make_unity_project "${P1}" "6000.3.10f1" "" ""
run_detect "missing_cli" "${P1}" ""
expect_rc "missing_cli" 0
expect_json_eq "missing_cli" "cli/state" "UNAVAILABLE"
expect_json_eq "missing_cli" "backends/cli_direct/state" "UNAVAILABLE"
expect_json_eq "missing_cli" "capabilities/DiscoverTooling/state" "AVAILABLE"

# --- 2. CLI installed, Pipeline absent ---
P2="${WORKDIR}/cli-no-pipeline"
make_unity_project "${P2}" "6000.3.10f1" "" ""
M2="${WORKDIR}/mock-unity-version-only"
write_mock_unity "${M2}" "version_only" "${P2}"
run_detect "cli_no_pipeline" "${P2}" "${M2}"
expect_rc "cli_no_pipeline" 0
expect_json_eq "cli_no_pipeline" "cli/state" "AVAILABLE"
expect_json_eq "cli_no_pipeline" "cli/version" "1.0.0-beta.8-mock"
expect_json_eq "cli_no_pipeline" "packages/com.unity.pipeline/state" "UNAVAILABLE"
expect_json_eq "cli_no_pipeline" "backends/cli_direct/state" "UNAVAILABLE"

# --- 3. Pipeline installed, service unreachable ---
P3="${WORKDIR}/pipeline-unreachable"
make_unity_project "${P3}" "6000.3.10f1" "0.9.1-exp.1" ""
M3="${WORKDIR}/mock-unity-unreachable"
write_mock_unity "${M3}" "unreachable" "${P3}"
run_detect "pipeline_unreachable" "${P3}" "${M3}"
expect_rc "pipeline_unreachable" 0
expect_json_eq "pipeline_unreachable" "packages/com.unity.pipeline/state" "AVAILABLE"
expect_json_eq "pipeline_unreachable" "services/pipeline_server/state" "UNAVAILABLE"
expect_json_eq "pipeline_unreachable" "backends/cli_direct/state" "UNAVAILABLE"

# --- 4. Valid reachable CLI project ---
P4="${WORKDIR}/reachable Game"
make_unity_project "${P4}" "6000.3.10f1" "0.9.1-exp.1" "2.18.0-pre.2"
# canonicalize for mock embedded path
P4_CANON="$(cd "${P4}" && pwd -P)"
M4="${WORKDIR}/mock-unity-reachable"
write_mock_unity "${M4}" "reachable" "${P4_CANON}"
run_detect "reachable" "${P4}" "${M4}"
expect_rc "reachable" 0
expect_json_eq "reachable" "services/pipeline_server/state" "AVAILABLE"
expect_json_eq "reachable" "backends/cli_direct/state" "AVAILABLE"
expect_json_eq "reachable" "project/editor_identity" "MATCH"
expect_json_eq "reachable" "capabilities/GetEditorState/state" "AVAILABLE"
expect_json_eq "reachable" "capabilities/ApplyControlledMutation/state" "AVAILABLE"
# With reachable service, RunEditModeTests should be BLOCKED (don't auto-close)
expect_json_eq "reachable" "capabilities/RunEditModeTests/state" "BLOCKED"

# --- 5. Identity mismatch ---
P5="${WORKDIR}/mismatch-proj"
make_unity_project "${P5}" "6000.3.10f1" "0.9.1-exp.1" ""
P5_CANON="$(cd "${P5}" && pwd -P)"
M5="${WORKDIR}/mock-unity-mismatch"
write_mock_unity "${M5}" "mismatch" "${P5_CANON}"
run_detect "mismatch" "${P5}" "${M5}"
expect_rc "mismatch" 0
expect_json_eq "mismatch" "project/editor_identity" "MISMATCH"
expect_json_eq "mismatch" "capabilities/VerifyProjectIdentity/state" "BLOCKED"
expect_json_eq "mismatch" "capabilities/ApplyControlledMutation/state" "BLOCKED"

# --- 6. Malformed CLI JSON ---
P6="${WORKDIR}/malformed-json"
make_unity_project "${P6}" "6000.3.10f1" "0.9.1-exp.1" ""
M6="${WORKDIR}/mock-unity-malformed"
write_mock_unity "${M6}" "malformed" "${P6}"
run_detect "malformed" "${P6}" "${M6}"
expect_rc "malformed" 0
# Should not crash; service unknown
expect_json_eq "malformed" "capabilities/DiscoverTooling/state" "AVAILABLE"
if grep -q 'malformed_json' "${WORKDIR}/out.malformed.json"; then
  pass "malformed_parse_error_reported"
else
  # status_parse_error field
  if python3 -c 'import json;d=json.load(open("'"${WORKDIR}/out.malformed.json"'")); assert d["cli"]["status_parse_error"]' 2>/dev/null; then
    pass "malformed_parse_error_reported"
  else
    fail "malformed_parse_error_reported" "expected parse error in report"
  fi
fi

# --- 7. Paths containing spaces (P4 already has spaces) ---
if [[ -f "${WORKDIR}/out.reachable.json" ]]; then
  got_path="$(jq_field "${WORKDIR}/out.reachable.json" "project/canonical_path")"
  if [[ "${got_path}" == *" "* ]]; then
    pass "spaces_in_path"
  else
    fail "spaces_in_path" "path=${got_path}"
  fi
fi

# --- 8. Missing / invalid Unity project metadata ---
P8="${WORKDIR}/not-unity"
mkdir -p "${P8}/somewhere"
set +e
UNITY_CAP_DETECT_UNITY="${WORKDIR}/no-such-unity-binary" "${DETECT}" "${P8}" >"${WORKDIR}/out.not_unity.json" 2>"${WORKDIR}/err.not_unity.txt"
rc8=$?
set -e
echo "${rc8}" > "${WORKDIR}/rc.not_unity.txt"
expect_rc "not_unity" 1

P8b="${WORKDIR}/version-only-no-assets"
mkdir -p "${P8b}/ProjectSettings"
echo "m_EditorVersion: 6000.0.0f1" > "${P8b}/ProjectSettings/ProjectVersion.txt"
set +e
UNITY_CAP_DETECT_UNITY="${WORKDIR}/no-such-unity-binary" "${DETECT}" "${P8b}" >"${WORKDIR}/out.no_assets.json" 2>"${WORKDIR}/err.no_assets.txt"
rc8b=$?
set -e
echo "${rc8b}" > "${WORKDIR}/rc.no_assets.txt"
expect_rc "no_assets" 1

# --- 9. Unexpected CLI exit code ---
P9="${WORKDIR}/bad-exit"
make_unity_project "${P9}" "6000.3.10f1" "0.9.1-exp.1" ""
M9="${WORKDIR}/mock-unity-bad-exit"
write_mock_unity "${M9}" "bad_exit" "${P9}"
run_detect "bad_exit" "${P9}" "${M9}"
expect_rc "bad_exit" 0
# Detector should still emit JSON; CLI version may be empty and services unavailable/unknown
expect_json_eq "bad_exit" "capabilities/DiscoverTooling/state" "AVAILABLE"
if [[ -s "${WORKDIR}/out.bad_exit.json" ]] && python3 -c 'import json; json.load(open("'"${WORKDIR}/out.bad_exit.json"'"))'; then
  pass "bad_exit_json_emitted"
else
  fail "bad_exit_json_emitted" "missing/invalid JSON"
fi

# --- 10. help works ---
set +e
"${DETECT}" --help >/dev/null 2>&1
rc_help=$?
set -e
if [[ "${rc_help}" -eq 0 ]]; then pass "help_exit_0"; else fail "help_exit_0" "rc=${rc_help}"; fi

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
