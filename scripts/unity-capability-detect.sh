#!/usr/bin/env bash
# Read-only Unity tooling capability detector (TOFF Games Production OS).
#
# Discovers whether Unity CLI / Pipeline / related capabilities appear available
# for an explicit Unity project path. Never installs, upgrades, authenticates,
# starts/stops Editors, mutates projects, or rewrites MCP configuration.
#
# Exit codes:
#   0 — Detection completed; JSON written to stdout
#   1 — Invalid usage or target is not a usable Unity project path
#   2 — Unexpected failure producing a report
#
# Env (optional, for tests / overrides):
#   UNITY_CAP_DETECT_UNITY   Absolute path to unity CLI (default: search PATH)
#   UNITY_CAP_DETECT_SKIP_CLI_PROBE=1  Skip live CLI status/pipeline probes
#   UNITY_CAP_DETECT_OS_VERSION        Override reported OS version
#
# Authority: docs/unity-tooling.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OS_VERSION_FILE="${OS_ROOT}/VERSION"

usage() {
  cat <<'EOF'
Usage: unity-capability-detect.sh [options] <unity-project-path>

Read-only detection of Unity tooling backends and conceptual capabilities.
Prints a single JSON object to stdout. Never mutates the project.

Options:
  --help, -h     Show this help
  --pretty       Pretty-print JSON (default compact)

Exit: 0 report ok | 1 invalid usage/project | 2 unexpected failure
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

die_internal() {
  echo "ERROR: $*" >&2
  exit 2
}

PRETTY=0
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --pretty) PRETTY=1; shift ;;
    --) shift; break ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *)
      if [[ -n "${TARGET}" ]]; then
        die "unexpected extra argument: $1"
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

[[ -n "${TARGET}" ]] || { usage; die "unity project path required"; }

if ! command -v python3 >/dev/null 2>&1; then
  die "python3 is required"
fi

canonical_existing() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "${p}"
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${p}"
  fi
}

# Resolve path; refuse if missing.
if [[ ! -e "${TARGET}" ]]; then
  die "path does not exist: ${TARGET}"
fi
if [[ ! -d "${TARGET}" ]]; then
  die "path is not a directory: ${TARGET}"
fi

PROJECT_CANON="$(canonical_existing "${TARGET}")"

OS_VERSION="$(tr -d '[:space:]' < "${OS_VERSION_FILE}" 2>/dev/null || echo "unknown")"
if [[ -n "${UNITY_CAP_DETECT_OS_VERSION:-}" ]]; then
  OS_VERSION="${UNITY_CAP_DETECT_OS_VERSION}"
fi

# Resolve unity binary without assuming Hub paths.
resolve_unity_bin() {
  if [[ -n "${UNITY_CAP_DETECT_UNITY:-}" ]]; then
    if [[ -x "${UNITY_CAP_DETECT_UNITY}" ]]; then
      printf '%s\n' "${UNITY_CAP_DETECT_UNITY}"
      return 0
    fi
    return 1
  fi
  if command -v unity >/dev/null 2>&1; then
    command -v unity
    return 0
  fi
  return 1
}

UNITY_BIN=""
UNITY_BIN_STATE="UNAVAILABLE"
if UNITY_BIN="$(resolve_unity_bin)"; then
  UNITY_BIN_STATE="AVAILABLE"
else
  UNITY_BIN=""
  UNITY_BIN_STATE="UNAVAILABLE"
fi

# Collect CLI probe artifacts into temp files (never print secrets).
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/toff-cap-detect.XXXXXX")"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

CLI_VERSION_FILE="${WORKDIR}/cli-version.txt"
STATUS_JSON_FILE="${WORKDIR}/status.json"
STATUS_RC_FILE="${WORKDIR}/status.rc"
PIPELINE_JSON_FILE="${WORKDIR}/pipeline.json"
PIPELINE_RC_FILE="${WORKDIR}/pipeline.rc"
EDITOR_JSON_FILE="${WORKDIR}/editor.json"
EDITOR_RC_FILE="${WORKDIR}/editor.rc"

: > "${CLI_VERSION_FILE}"
echo "UNAVAILABLE" > "${STATUS_RC_FILE}"
echo "{}" > "${STATUS_JSON_FILE}"
echo "UNAVAILABLE" > "${PIPELINE_RC_FILE}"
echo "{}" > "${PIPELINE_JSON_FILE}"
echo "UNAVAILABLE" > "${EDITOR_RC_FILE}"
echo "{}" > "${EDITOR_JSON_FILE}"

run_cli_probes() {
  local rc=0
  if [[ "${UNITY_BIN_STATE}" != "AVAILABLE" ]]; then
    return 0
  fi
  if [[ "${UNITY_CAP_DETECT_SKIP_CLI_PROBE:-0}" == "1" ]]; then
    return 0
  fi

  set +e
  "${UNITY_BIN}" --version >"${CLI_VERSION_FILE}" 2>/dev/null
  rc=$?
  set -e
  if [[ "${rc}" -ne 0 ]]; then
    echo "" > "${CLI_VERSION_FILE}"
  fi

  # Global status (exact path match enforced in Python — do not trust substring filters alone).
  set +e
  "${UNITY_BIN}" status --format json --non-interactive --no-banner \
    >"${STATUS_JSON_FILE}" 2>"${WORKDIR}/status.err"
  rc=$?
  set -e
  echo "${rc}" > "${STATUS_RC_FILE}"

  set +e
  "${UNITY_BIN}" pipeline list --format json --non-interactive --no-banner \
    >"${PIPELINE_JSON_FILE}" 2>"${WORKDIR}/pipeline.err"
  rc=$?
  set -e
  echo "${rc}" > "${PIPELINE_RC_FILE}"

  # Editor status only when we already expect a matching instance; still safe/read-only.
  # Pass --project-path for routing; Python still verifies exact identity.
  set +e
  "${UNITY_BIN}" command --project-path "${PROJECT_CANON}" --format json --non-interactive --no-banner \
    editor status >"${EDITOR_JSON_FILE}" 2>"${WORKDIR}/editor.err"
  rc=$?
  set -e
  echo "${rc}" > "${EDITOR_RC_FILE}"
}

run_cli_probes

# Build final JSON via Python (safe parse of untrusted CLI output).
export PROJECT_CANON
export OS_VERSION
export UNITY_BIN
export UNITY_BIN_STATE
export CLI_VERSION_FILE
export STATUS_JSON_FILE
export STATUS_RC_FILE
export PIPELINE_JSON_FILE
export PIPELINE_RC_FILE
export EDITOR_JSON_FILE
export EDITOR_RC_FILE
export PRETTY
export SKIP_PROBE="${UNITY_CAP_DETECT_SKIP_CLI_PROBE:-0}"

set +e
python3 - <<'PY'
import json, os, re, sys
from pathlib import Path

STATES = ("AVAILABLE", "UNAVAILABLE", "UNKNOWN", "BLOCKED")

def state(x: str) -> str:
    x = (x or "UNKNOWN").upper()
    return x if x in STATES else "UNKNOWN"

def read_text(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""

def load_json_file(path: str):
    raw = read_text(path)
    if not raw:
        return None, "empty"
    try:
        return json.loads(raw), None
    except json.JSONDecodeError as e:
        return None, f"malformed_json: {e}"

def canonicalize(p: str) -> str:
    if not p:
        return ""
    try:
        return str(Path(p).resolve())
    except OSError:
        return os.path.normpath(p)

project = canonicalize(os.environ["PROJECT_CANON"])
os_version = os.environ.get("OS_VERSION", "unknown")
unity_bin = os.environ.get("UNITY_BIN") or ""
unity_bin_state = state(os.environ.get("UNITY_BIN_STATE", "UNAVAILABLE"))
pretty = os.environ.get("PRETTY", "0") == "1"
skip_probe = os.environ.get("SKIP_PROBE", "0") == "1"

proj_path = Path(project)
version_file = proj_path / "ProjectSettings" / "ProjectVersion.txt"
assets_dir = proj_path / "Assets"
manifest_path = proj_path / "Packages" / "manifest.json"
lock_path = proj_path / "Packages" / "packages-lock.json"

is_unity = version_file.is_file() and assets_dir.is_dir()
if not version_file.is_file():
    # Hard fail for non-projects — bash already validated directory existence.
    print("ERROR: not a Unity project (missing ProjectSettings/ProjectVersion.txt)", file=sys.stderr)
    sys.exit(1)
if not assets_dir.is_dir():
    print("ERROR: not a Unity project (missing Assets/ directory)", file=sys.stderr)
    sys.exit(1)

pinned = ""
try:
    for line in version_file.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"^m_EditorVersion:\s*(.+?)\s*$", line)
        if m:
            pinned = m.group(1).strip()
            break
except OSError:
    pinned = ""

git_root = ""
git_identity = "UNKNOWN"
try:
    import subprocess
    r = subprocess.run(
        ["git", "-C", project, "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=False,
    )
    if r.returncode == 0:
        git_root = canonicalize(r.stdout.strip())
        git_identity = "MATCH" if git_root == project else "MISMATCH"
    else:
        git_identity = "NONE"
except Exception:
    git_identity = "UNKNOWN"

def package_info(name: str):
    declared = False
    version = None
    lock_version = None
    source = None
    # manifest
    man, err = load_json_file(str(manifest_path)) if manifest_path.is_file() else (None, "missing")
    if isinstance(man, dict):
        deps = man.get("dependencies") or {}
        if isinstance(deps, dict) and name in deps:
            declared = True
            version = deps.get(name)
    # lock
    lock, _ = load_json_file(str(lock_path)) if lock_path.is_file() else (None, "missing")
    if isinstance(lock, dict):
        deps = lock.get("dependencies") or {}
        if isinstance(deps, dict) and name in deps and isinstance(deps[name], dict):
            declared = True
            lock_version = deps[name].get("version")
            source = deps[name].get("source")
            if not version:
                version = lock_version
    return {
        "declared": declared,
        "version": version,
        "lock_version": lock_version,
        "source": source,
        "manifest_present": manifest_path.is_file(),
        "lock_present": lock_path.is_file(),
        "manifest_parse_error": err if manifest_path.is_file() and err and err != "empty" else None,
    }

pipeline_pkg = package_info("com.unity.pipeline")
assistant_pkg = package_info("com.unity.ai.assistant")
utf_pkg = package_info("com.unity.test-framework")

cli_version = read_text(os.environ["CLI_VERSION_FILE"])
# sanitize: first line token-like version only
cli_version_clean = ""
if cli_version:
    m = re.search(r"([0-9]+\.[0-9]+\.[0-9]+[\w\.\-+]*)", cli_version)
    cli_version_clean = m.group(1) if m else cli_version.splitlines()[0][:80]

status_rc_raw = read_text(os.environ["STATUS_RC_FILE"])
pipeline_rc_raw = read_text(os.environ["PIPELINE_RC_FILE"])
editor_rc_raw = read_text(os.environ["EDITOR_RC_FILE"])

def parse_rc(raw: str):
    if raw in ("", "UNAVAILABLE"):
        return None
    try:
        return int(raw)
    except ValueError:
        return None

status_rc = parse_rc(status_rc_raw)
pipeline_rc = parse_rc(pipeline_rc_raw)
editor_rc = parse_rc(editor_rc_raw)

status_obj, status_err = load_json_file(os.environ["STATUS_JSON_FILE"])
pipeline_obj, pipeline_err = load_json_file(os.environ["PIPELINE_JSON_FILE"])
editor_obj, editor_err = load_json_file(os.environ["EDITOR_JSON_FILE"])

def instances_from_status(obj):
    if not isinstance(obj, dict):
        return []
    data = obj.get("data")
    if isinstance(data, dict) and isinstance(data.get("instances"), list):
        return data["instances"]
    if isinstance(obj.get("instances"), list):
        return obj["instances"]
    return []

matching_status = []
other_status = []
status_malformed = bool(status_err and status_err.startswith("malformed"))
if isinstance(status_obj, dict) and not status_malformed:
    for inst in instances_from_status(status_obj):
        if not isinstance(inst, dict):
            continue
        ip = canonicalize(str(inst.get("project") or inst.get("projectPath") or ""))
        if not ip:
            continue
        row = {
            "project": ip,
            "port": inst.get("port"),
            "pid": inst.get("pid"),
            "state": inst.get("state"),
            "version": inst.get("version"),
        }
        if ip == project:
            matching_status.append(row)
        else:
            other_status.append(row)

pipeline_matching = []
pipeline_malformed = bool(pipeline_err and pipeline_err.startswith("malformed"))
if isinstance(pipeline_obj, dict) and not pipeline_malformed:
    data = pipeline_obj.get("data") if isinstance(pipeline_obj.get("data"), dict) else pipeline_obj
    insts = data.get("instances") if isinstance(data, dict) else None
    if isinstance(insts, list):
        for inst in insts:
            if not isinstance(inst, dict):
                continue
            ip = canonicalize(str(inst.get("projectPath") or ""))
            if ip != project:
                continue
            server = inst.get("pipelineServer") if isinstance(inst.get("pipelineServer"), dict) else {}
            pipeline_matching.append({
                "project": ip,
                "pid": inst.get("pid"),
                "is_running": inst.get("isRunning"),
                "has_pipeline_package": inst.get("hasPipelinePackage"),
                "pipeline_version": inst.get("pipelineVersion"),
                "server_reachable": server.get("isReachable"),
                "port": server.get("port"),
            })

editor_project = ""
editor_malformed = bool(editor_err and editor_err.startswith("malformed"))
editor_state = {}
if isinstance(editor_obj, dict) and not editor_malformed:
    data = editor_obj.get("data") if isinstance(editor_obj.get("data"), dict) else editor_obj
    # Nested shapes from `unity command editor status`
    result = None
    if isinstance(data, dict):
        if isinstance(data.get("result"), dict):
            result = data["result"]
        elif isinstance(data.get("data"), dict) and isinstance(data["data"].get("result"), dict):
            result = data["data"]["result"]
    if isinstance(result, dict):
        editor_project = canonicalize(str(result.get("projectPath") or ""))
        editor_state = {
            "status": result.get("status"),
            "play_mode": result.get("playMode"),
            "compiling": result.get("compiling"),
            "unity_version": result.get("unityVersion"),
            "project_path": editor_project,
        }

# --- Derive backend / capability states ------------------------------------

cli_installed = unity_bin_state == "AVAILABLE"
pipeline_declared = bool(pipeline_pkg["declared"])

# Package-installed vs service-reachable
pipeline_package_state = "AVAILABLE" if pipeline_declared else "UNAVAILABLE"

service_state = "UNKNOWN"
identity_vs_editor = "UNKNOWN"
if skip_probe:
    service_state = "UNKNOWN"
elif not cli_installed:
    service_state = "UNAVAILABLE"
elif status_malformed or pipeline_malformed:
    service_state = "UNKNOWN"
elif matching_status or pipeline_matching:
    # Reachable for this exact project
    reachable = False
    if pipeline_matching:
        reachable = any(p.get("server_reachable") is True or p.get("is_running") for p in pipeline_matching)
    if matching_status:
        reachable = True
    service_state = "AVAILABLE" if reachable else "UNAVAILABLE"
    identity_vs_editor = "MATCH"
elif other_status and not matching_status:
    # Editors exist but not for this project
    service_state = "UNAVAILABLE"
    identity_vs_editor = "MISMATCH"
elif status_rc is not None and status_rc != 0 and not matching_status:
    # Common: STATUS_NO_INSTANCES
    service_state = "UNAVAILABLE"
    identity_vs_editor = "NONE"
elif status_rc == 0 and not matching_status:
    service_state = "UNAVAILABLE"
    identity_vs_editor = "NONE"
else:
    service_state = "UNKNOWN"

# Editor command identity
if editor_project:
    if editor_project == project:
        identity_vs_editor = "MATCH"
        if service_state == "UNAVAILABLE":
            service_state = "AVAILABLE"
    else:
        identity_vs_editor = "MISMATCH"
        # Mutating capabilities blocked if wrong project routed
elif editor_rc is not None and editor_rc != 0 and service_state == "AVAILABLE":
    # Status said matching but editor status failed — keep AVAILABLE for status, mark GetEditorState carefully
    pass

# Lockfile hint (does not by itself prove correct project)
lockfile = (proj_path / "Temp" / "UnityLockfile").exists()

def cap(state_name, backend=None, notes=None, permission="READ"):
    return {
        "state": state(state_name),
        "backend": backend,
        "permission": permission,
        "notes": notes or "",
    }

# Backend availability (capability-oriented)
cli_direct_backend = "UNAVAILABLE"
if not cli_installed:
    cli_direct_backend = "UNAVAILABLE"
elif not pipeline_declared and service_state != "AVAILABLE":
    # Binary alone is insufficient
    cli_direct_backend = "UNAVAILABLE"
elif pipeline_declared and service_state == "AVAILABLE" and identity_vs_editor in ("MATCH", "UNKNOWN"):
    if identity_vs_editor == "MISMATCH":
        cli_direct_backend = "BLOCKED"
    else:
        cli_direct_backend = "AVAILABLE"
elif pipeline_declared and service_state == "UNAVAILABLE":
    cli_direct_backend = "UNAVAILABLE"
elif pipeline_declared and service_state == "UNKNOWN":
    cli_direct_backend = "UNKNOWN"
elif identity_vs_editor == "MISMATCH":
    cli_direct_backend = "BLOCKED"
else:
    cli_direct_backend = "UNKNOWN"

# CLI MCP: binary may expose `unity mcp`, but config/reachability not probed (would risk config writes).
cli_mcp_backend = "UNKNOWN" if cli_installed else "UNAVAILABLE"

# Legacy MCP: package presence ≠ service reachability
legacy_mcp_backend = "UNKNOWN"
if assistant_pkg["declared"]:
    legacy_mcp_backend = "UNKNOWN"  # installed but service not probed from this script
else:
    legacy_mcp_backend = "UNAVAILABLE"

# Identity capability
if identity_vs_editor == "MATCH" and (git_identity in ("MATCH", "NONE") or git_root == project):
    verify_identity = cap("AVAILABLE", "cli_direct" if cli_direct_backend == "AVAILABLE" else None,
                          "Exact canonical path match for Editor project")
elif identity_vs_editor == "MISMATCH":
    verify_identity = cap("BLOCKED", None, "Connected Editor project path does not exactly match target")
elif not cli_installed:
    verify_identity = cap("UNKNOWN", None, "CLI absent; verify via MCP GetProjectRoot or manual Editor when mutating")
else:
    verify_identity = cap("UNAVAILABLE" if service_state == "UNAVAILABLE" else "UNKNOWN", None,
                          "No verified matching Editor instance for this project")

# DiscoverTooling always available as this script
discover = cap("AVAILABLE", "detector", "This detector report")

def from_cli_direct(read_ok_state="AVAILABLE"):
    if cli_direct_backend == "AVAILABLE":
        return cap(read_ok_state, "cli_direct")
    if cli_direct_backend == "BLOCKED":
        return cap("BLOCKED", "cli_direct", "Identity mismatch — no silent backend fallback for mutations")
    if cli_direct_backend == "UNKNOWN":
        return cap("UNKNOWN", "cli_direct")
    return cap("UNAVAILABLE", "cli_direct")

get_editor = from_cli_direct()
inspect_scene = from_cli_direct()
inspect_console = from_cli_direct()

# RunEditModeTests: CLI test may exist even without live Pipeline server, but Editor lock blocks.
run_tests_notes = []
run_tests_state = "UNKNOWN"
run_tests_backend = None
if not cli_installed:
    run_tests_state = "UNKNOWN"
    run_tests_notes.append("CLI absent; use in-Editor Test Runner or templates/scripts/validate.sh with Unity binary")
elif lockfile or service_state == "AVAILABLE":
    # Live Editor / lock likely blocks batch unity test (SOWA pilot)
    run_tests_state = "BLOCKED"
    run_tests_backend = "cli_direct"
    run_tests_notes.append("Editor lock or reachable Pipeline instance indicates project may be open; do not auto-close Editor")
else:
    run_tests_state = "UNKNOWN"
    run_tests_backend = "cli_direct"
    run_tests_notes.append("Batch UTF possible in principle; verify with unity test / validate.sh — not executed by detector")

run_tests = cap(run_tests_state, run_tests_backend, "; ".join(run_tests_notes))

# Mutations: never AVAILABLE from detector alone without human approval context —
# report backend readiness only.
if cli_direct_backend == "AVAILABLE" and identity_vs_editor == "MATCH":
    mutate = cap("AVAILABLE", "cli_direct",
                 "Backend reachable; CONTROLLED_WRITE still requires task-bound approval",
                 permission="CONTROLLED_WRITE")
    save_scene = cap("AVAILABLE", "cli_direct",
                     "Backend reachable; requires approved scope",
                     permission="CONTROLLED_WRITE")
    capture = cap("AVAILABLE", "cli_direct",
                  "Capture path may remap under Assets/; verify location",
                  permission="READ")
elif cli_direct_backend == "BLOCKED" or identity_vs_editor == "MISMATCH":
    mutate = cap("BLOCKED", None, "Identity mismatch — refusing mutation readiness",
                 permission="CONTROLLED_WRITE")
    save_scene = cap("BLOCKED", None, "Identity mismatch", permission="CONTROLLED_WRITE")
    capture = cap("BLOCKED", None, "Identity mismatch")
else:
    mutate = cap("UNAVAILABLE" if cli_direct_backend == "UNAVAILABLE" else "UNKNOWN",
                 "cli_direct" if cli_installed else None,
                 "Mutating backend not verified for this project",
                 permission="CONTROLLED_WRITE")
    save_scene = cap(mutate["state"], mutate["backend"], mutate["notes"], permission="CONTROLLED_WRITE")
    capture = cap("UNAVAILABLE" if cli_direct_backend == "UNAVAILABLE" else "UNKNOWN",
                  mutate["backend"])

inspect_diff = cap("AVAILABLE", "git", "Use git diff on scene/prefab YAML; always available as process capability")

# Arbitrary execution never advertised as available by detector
arbitrary = cap("UNAVAILABLE", None,
                "ARBITRARY_EXECUTION (eval/unrestricted C#/package ops) requires explicit separate human approval",
                permission="ARBITRARY_EXECUTION")

report = {
    "schema_version": "1.0",
    "os_version": os_version,
    "detector": {
        "read_only": True,
        "probes_skipped": skip_probe,
        "notes": [
            "Never installs packages, rewrites MCP config, or closes Editors.",
            "CLI binary presence alone does not make cli_direct AVAILABLE.",
            "Legacy MCP service reachability is not probed (avoids false confidence).",
        ],
    },
    "project": {
        "path": project,
        "canonical_path": project,
        "is_unity_project": True,
        "unity_version_pinned": pinned or None,
        "git_root": git_root or None,
        "git_identity": git_identity,
        "editor_identity": identity_vs_editor,
        "lockfile_present": lockfile,
    },
    "cli": {
        "state": state(unity_bin_state if cli_installed else "UNAVAILABLE"),
        "binary": unity_bin or None,
        "version": cli_version_clean or None,
        "status_exit_code": status_rc,
        "status_parse_error": status_err if status_malformed else None,
        "pipeline_list_exit_code": pipeline_rc,
        "pipeline_list_parse_error": pipeline_err if pipeline_malformed else None,
        "editor_status_exit_code": editor_rc,
        "editor_status_parse_error": editor_err if editor_malformed else None,
    },
    "packages": {
        "com.unity.pipeline": {
            "state": state(pipeline_package_state),
            **{k: pipeline_pkg[k] for k in ("declared", "version", "lock_version", "source")},
        },
        "com.unity.ai.assistant": {
            "state": state("AVAILABLE" if assistant_pkg["declared"] else "UNAVAILABLE"),
            **{k: assistant_pkg[k] for k in ("declared", "version", "lock_version", "source")},
        },
        "com.unity.test-framework": {
            "state": state("AVAILABLE" if utf_pkg["declared"] else "UNKNOWN"),
            **{k: utf_pkg[k] for k in ("declared", "version", "lock_version", "source")},
        },
    },
    "services": {
        "pipeline_server": {
            "state": state(service_state),
            "matching_instances": matching_status,
            "pipeline_instances": pipeline_matching,
            "other_editor_instances": other_status,
            "editor_state": editor_state or None,
        },
        "legacy_mcp": {
            "package_state": state("AVAILABLE" if assistant_pkg["declared"] else "UNAVAILABLE"),
            "service_state": "UNKNOWN",
            "notes": "Service reachability requires MCP session checks; not performed here.",
        },
        "cli_mcp": {
            "state": state(cli_mcp_backend),
            "notes": "Does not run unity mcp configure; configuration state unknown.",
        },
    },
    "backends": {
        "cli_direct": {
            "state": state(cli_direct_backend),
            "preferred_when": "Capability verified for this exact project",
        },
        "cli_mcp": {
            "state": state(cli_mcp_backend),
            "preferred_when": "Optional; only when configured and verified",
        },
        "legacy_mcp": {
            "state": state(legacy_mcp_backend),
            "preferred_when": "Compatibility backend when MCP identity verified",
        },
    },
    "capabilities": {
        "DiscoverTooling": discover,
        "VerifyProjectIdentity": verify_identity,
        "GetEditorState": get_editor,
        "InspectScene": inspect_scene,
        "InspectConsole": inspect_console,
        "RunEditModeTests": run_tests,
        "ApplyControlledMutation": mutate,
        "SaveScene": save_scene,
        "CaptureEvidence": capture,
        "InspectSerializedDiff": inspect_diff,
        "ArbitraryExecution": arbitrary,
    },
}

if pretty:
    json.dump(report, sys.stdout, indent=2, sort_keys=False)
    sys.stdout.write("\n")
else:
    json.dump(report, sys.stdout, separators=(",", ":"), sort_keys=False)
    sys.stdout.write("\n")
sys.exit(0)
PY
py_rc=$?
set -e

if [[ "${py_rc}" -eq 1 ]]; then
  exit 1
fi
if [[ "${py_rc}" -ne 0 ]]; then
  die_internal "failed to build capability report (python exit ${py_rc})"
fi
exit 0
