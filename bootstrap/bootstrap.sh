#!/usr/bin/env bash
# Install TOFF Games Production OS templates into a Unity game repository.
# Default: non-destructive (skip existing files). Never writes outside TARGET.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OS_VERSION="$(tr -d '[:space:]' < "${OS_ROOT}/VERSION" 2>/dev/null || echo "unknown")"
TEMPLATES="${OS_ROOT}/templates"

DRY_RUN=0
FORCE=0
TARGET=""

usage() {
  cat <<EOF
Usage: bootstrap.sh [options] <target-game-repo>

Install Production OS templates into an existing or new Unity game Git repo.

Options:
  --dry-run   Print actions only; write nothing
  --force     Overwrite existing managed files (destructive for those paths)
  --help      Show this help

Defaults are non-destructive: existing files are skipped unless --force.

Does not: create remotes, commit, install Unity packages, or modify gameplay code.
Does not write outside <target-game-repo>.
EOF
}

log() { printf '%s\n' "$*"; }
action() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "DRY-RUN: $*"
  else
    log "DO: $*"
  fi
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

die() { echo "ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
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

[[ -n "${TARGET}" ]] || { usage; die "target path required"; }

OS_ABS="$(canonical_path "${OS_ROOT}")"

# Resolve target absolute path without writing (dry-run may target a missing dir).
if [[ -e "${TARGET}" ]]; then
  TARGET_ABS="$(canonical_path "${TARGET}")"
else
  parent_dir="$(dirname "${TARGET}")"
  base_name="$(basename "${TARGET}")"
  if [[ -d "${parent_dir}" ]]; then
    TARGET_ABS="$(canonical_path "${parent_dir}")/${base_name}"
  else
    # Last resort: absolute-ize via pwd if relative
    if [[ "${TARGET}" = /* ]]; then
      TARGET_ABS="${TARGET}"
    else
      TARGET_ABS="$(pwd -P)/${TARGET}"
    fi
  fi
  log "NOTE: target does not exist yet: ${TARGET_ABS}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mkdir -p "${TARGET_ABS}"
    TARGET_ABS="$(canonical_path "${TARGET_ABS}")"
  fi
fi

if [[ "${TARGET_ABS}" == "${OS_ABS}" || "${TARGET_ABS}" == "${OS_ABS}/"* ]]; then
  die "refusing to bootstrap into the Production OS repository itself (${OS_ABS})"
fi

# Ensure all writes stay under TARGET_ABS (string-prefix check; works before dest exists).
assert_under_target() {
  local dest="$1"
  case "${dest}" in
    "${TARGET_ABS}"|"${TARGET_ABS}/"*) ;;
    *) die "refusing path outside target: ${dest} (target=${TARGET_ABS})" ;;
  esac
}

INSTALLED=()
SKIPPED=()
WOULD_OVERWRITE=()
DISCOVERED=()

record_install() { INSTALLED+=("$1"); }
record_skip() { SKIPPED+=("$1"); }
record_overwrite() { WOULD_OVERWRITE+=("$1"); }

discover() {
  DISCOVERED+=("$1")
}

GAME_NAME="TODO_GAME_NAME"
GAME_ONE_LINER="TODO one-line description"
UNITY_VERSION="TODO"
PRIMARY_SCENE="TODO Assets/Scenes/Main.unity"
PROJECT_LAYOUT="TODO describe Assets/ layout"
NAMESPACES="TODO"
ARCHITECTURE_CONSTRAINTS="TODO document architecture constraints for this game"
TARGET_PLATFORMS="TODO"

if [[ -d "${TARGET_ABS}/.git" ]] || git -C "${TARGET_ABS}" rev-parse --show-toplevel >/dev/null 2>&1; then
  discover "git: yes ($(git -C "${TARGET_ABS}" rev-parse --show-toplevel 2>/dev/null || echo "${TARGET_ABS}"))"
else
  discover "git: NO — initialize a Git repo before relying on agent workflows"
fi

if [[ -f "${TARGET_ABS}/ProjectSettings/ProjectVersion.txt" ]]; then
  discover "unity-project: yes"
  UNITY_VERSION="$(sed -n 's/^m_EditorVersion:[[:space:]]*//p' "${TARGET_ABS}/ProjectSettings/ProjectVersion.txt" | head -n 1 | tr -d '\r')"
  discover "unity-version: ${UNITY_VERSION}"
else
  discover "unity-project: NO ProjectSettings/ProjectVersion.txt (still installing docs/rules templates)"
fi

if [[ -f "${TARGET_ABS}/AGENTS.md" ]]; then
  discover "existing AGENTS.md: yes"
fi
if [[ -d "${TARGET_ABS}/.cursor/rules" ]]; then
  discover "existing .cursor/rules: yes"
fi

# Guess game name from directory
GAME_NAME="$(basename "${TARGET_ABS}")"

# Prefer first .unity under Assets/Scenes if present
if [[ -d "${TARGET_ABS}/Assets/Scenes" ]]; then
  local_scene=""
  local_scene="$(find "${TARGET_ABS}/Assets/Scenes" -maxdepth 2 -name '*.unity' 2>/dev/null | head -n 1 || true)"
  if [[ -n "${local_scene}" ]]; then
    PRIMARY_SCENE="${local_scene#"${TARGET_ABS}/"}"
    discover "primary-scene-guess: ${PRIMARY_SCENE}"
  fi
fi

render_agents() {
  local src="${TEMPLATES}/AGENTS.template.md"
  local out="$1"
  sed \
    -e "s/{{GAME_NAME}}/${GAME_NAME//\//\\/}/g" \
    -e "s/{{GAME_ONE_LINER}}/${GAME_ONE_LINER//\//\\/}/g" \
    -e "s/{{OS_VERSION}}/${OS_VERSION//\//\\/}/g" \
    -e "s/{{UNITY_VERSION}}/${UNITY_VERSION//\//\\/}/g" \
    -e "s|{{PRIMARY_SCENE}}|${PRIMARY_SCENE}|g" \
    -e "s|{{PROJECT_LAYOUT}}|${PROJECT_LAYOUT}|g" \
    -e "s|{{NAMESPACES_OR_TODO}}|${NAMESPACES}|g" \
    -e "s|{{ARCHITECTURE_CONSTRAINTS_OR_TODO}}|${ARCHITECTURE_CONSTRAINTS}|g" \
    "${src}" > "${out}"
}

install_file() {
  local src="$1"
  local dest="$2"
  local mode="${3:-copy}" # copy | agents

  assert_under_target "${dest}"

  if [[ -e "${dest}" ]]; then
    if [[ "${FORCE}" -eq 1 ]]; then
      record_overwrite "${dest}"
      action "overwrite ${dest}"
      if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "$(dirname "${dest}")"
        if [[ "${mode}" == "agents" ]]; then
          render_agents "${dest}"
        else
          cp "${src}" "${dest}"
        fi
        if [[ "${dest}" == *.sh ]]; then
          chmod +x "${dest}"
        fi
      fi
      record_install "${dest} (overwritten)"
    else
      record_skip "${dest} (exists; use --force to overwrite)"
      action "skip existing ${dest}"
    fi
    return 0
  fi

  action "install ${dest}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mkdir -p "$(dirname "${dest}")"
    if [[ "${mode}" == "agents" ]]; then
      render_agents "${dest}"
    else
      cp "${src}" "${dest}"
    fi
    if [[ "${dest}" == *.sh ]]; then
      chmod +x "${dest}"
    fi
  fi
  record_install "${dest}"
}

# --- Install plan ------------------------------------------------------------

install_file "${TEMPLATES}/AGENTS.template.md" "${TARGET_ABS}/AGENTS.md" agents

install_file "${TEMPLATES}/cursor/rules/task-delivery.mdc" "${TARGET_ABS}/.cursor/rules/task-delivery.mdc"
install_file "${TEMPLATES}/cursor/rules/unity-mcp-safety.mdc" "${TARGET_ABS}/.cursor/rules/unity-mcp-safety.mdc"
install_file "${TEMPLATES}/cursor/rules/unity-architecture.mdc" "${TARGET_ABS}/.cursor/rules/unity-architecture.mdc"
install_file "${TEMPLATES}/cursor/rules/coding-and-tests.mdc" "${TARGET_ABS}/.cursor/rules/coding-and-tests.mdc"
install_file "${TEMPLATES}/cursor/rules/assets-and-scenes.mdc" "${TARGET_ABS}/.cursor/rules/assets-and-scenes.mdc"

# Docs — only if missing (selective)
render_placeholders_to() {
  local src="$1"
  local dest="$2"
  sed \
    -e "s/{{GAME_NAME}}/${GAME_NAME//\//\\/}/g" \
    -e "s/{{UNITY_VERSION}}/${UNITY_VERSION//\//\\/}/g" \
    -e "s/{{OS_VERSION}}/${OS_VERSION//\//\\/}/g" \
    -e "s|{{PRIMARY_SCENE}}|${PRIMARY_SCENE}|g" \
    -e "s|{{PROJECT_LAYOUT}}|${PROJECT_LAYOUT}|g" \
    -e "s|{{TARGET_PLATFORMS}}|${TARGET_PLATFORMS}|g" \
    "${src}" > "${dest}"
}

install_rendered_doc() {
  local src="$1"
  local dest="$2"
  assert_under_target "${dest}"
  if [[ -e "${dest}" ]]; then
    if [[ "${FORCE}" -eq 1 ]]; then
      record_overwrite "${dest}"
      action "overwrite ${dest}"
      if [[ "${DRY_RUN}" -eq 0 ]]; then
        mkdir -p "$(dirname "${dest}")"
        render_placeholders_to "${src}" "${dest}"
      fi
      record_install "${dest} (overwritten)"
    else
      record_skip "${dest} (exists; use --force to overwrite)"
      action "skip existing ${dest}"
    fi
    return 0
  fi
  action "install ${dest}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mkdir -p "$(dirname "${dest}")"
    render_placeholders_to "${src}" "${dest}"
  fi
  record_install "${dest}"
}

install_rendered_doc "${TEMPLATES}/docs/status.template.md" "${TARGET_ABS}/docs/00-status.md"
install_rendered_doc "${TEMPLATES}/docs/gdd.template.md" "${TARGET_ABS}/docs/GDD.md"
install_rendered_doc "${TEMPLATES}/docs/architecture.template.md" "${TARGET_ABS}/docs/ARCHITECTURE.md"
install_rendered_doc "${TEMPLATES}/docs/art-direction.template.md" "${TARGET_ABS}/docs/03-art-direction.md"
install_rendered_doc "${TEMPLATES}/docs/qa-plan.template.md" "${TARGET_ABS}/docs/05-qa-plan.md"
install_rendered_doc "${TEMPLATES}/docs/release-plan.template.md" "${TARGET_ABS}/docs/06-release-plan.md"
install_file "${TEMPLATES}/docs/feature.template.md" "${TARGET_ABS}/docs/features/_template.md"
install_file "${TEMPLATES}/docs/adr.template.md" "${TARGET_ABS}/docs/decisions/ADR-000-template.md"

install_file "${TEMPLATES}/scripts/validate.sh" "${TARGET_ABS}/scripts/validate.sh"
install_file "${TEMPLATES}/scripts/validate.config.sh.example" "${TARGET_ABS}/scripts/validate.config.sh.example"

# Marker file recording OS version (do not overwrite without force)
MARKER="${TARGET_ABS}/docs/production-os-version.txt"
if [[ -e "${MARKER}" && "${FORCE}" -ne 1 ]]; then
  record_skip "${MARKER} (exists)"
else
  action "write ${MARKER}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    assert_under_target "${MARKER}"
    mkdir -p "$(dirname "${MARKER}")"
    printf 'toff-production-os %s\nbootstrapped_utc %s\n' "${OS_VERSION}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${MARKER}"
  fi
  record_install "${MARKER}"
fi

# --- Report ------------------------------------------------------------------

echo ""
echo "======== Production OS bootstrap report ========"
echo "os_root:     ${OS_ABS}"
echo "os_version:  ${OS_VERSION}"
echo "target:      ${TARGET_ABS}"
echo "dry_run:     ${DRY_RUN}"
echo "force:       ${FORCE}"
echo ""
echo "Discovered:"
for d in "${DISCOVERED[@]}"; do echo "  - ${d}"; done
echo ""
echo "Installed / would install:"
if ((${#INSTALLED[@]})); then printf '  - %s\n' "${INSTALLED[@]}"; else echo "  (none)"; fi
echo ""
echo "Skipped:"
if ((${#SKIPPED[@]})); then printf '  - %s\n' "${SKIPPED[@]}"; else echo "  (none)"; fi
echo ""
echo "Next steps:"
echo "  1. Fill TODO / {{…}} placeholders in AGENTS.md and docs."
echo "  2. Customize .cursor/rules/unity-architecture.mdc for this game."
echo "  3. Review scripts/validate.sh; add validate.config.sh if filters needed."
echo "  4. Do not commit until a human reviews the diff."
echo "================================================"
