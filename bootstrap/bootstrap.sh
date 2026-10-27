#!/usr/bin/env bash
# Install TOFF Games Production OS templates into a Unity game repository.
# Default: non-destructive (skip existing files). Never writes outside TARGET.
#
# Safety policy (conservative):
# - Target must resolve to a canonical directory; writes stay physically inside it.
# - Managed destination paths must not contain symlink components (including the
#   leaf). Symlinks are rejected rather than followed.
# - If Git is present for the target path, the Git toplevel must equal the
#   canonical target exactly (nested paths in a parent repo are rejected).
# - Directory-name / first-scene heuristics are suggestions only (NEEDS_CONFIRMATION).
#
# TOCTOU: checks happen before each write; a concurrent process could still
# replace a path component with a symlink between check and write. Run against
# trusted local directories; do not race the bootstrap.
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

Safety:
  - Refuses the Production OS repository itself.
  - Requires Git toplevel == canonical target when Git applies to the path.
  - Rejects destination paths with symlink components (never follows them).
  - --force cannot bypass destination safety checks.

Does not: create remotes, commit, init Git, install Unity packages, modify
gameplay code/scenes/assets, or launch Unity.
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

die() { echo "ERROR: $*" >&2; exit 1; }

# Resolve an existing path to its physical (symlink-free) absolute form.
canonical_existing() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "${p}"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${p}"
  else
    (cd "${p}" && pwd -P)
  fi
}

# Absolute path without requiring the leaf to exist; does not resolve leaf symlinks.
absolute_path() {
  local p="$1"
  if [[ "${p}" = /* ]]; then
    printf '%s\n' "${p}"
  else
    printf '%s/%s\n' "$(pwd -P)" "${p}"
  fi
}

# Collapse . and .. without resolving symlinks (lexical only).
lexical_normalize() {
  local p="$1"
  python3 -c '
import os, sys
print(os.path.normpath(sys.argv[1]))
' "${p}"
}

is_physically_inside() {
  local candidate="$1"
  local root="$2"
  [[ "${candidate}" == "${root}" || "${candidate}" == "${root}/"* ]]
}

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

# Prefer python3 for portable path logic; fall back carefully.
if ! command -v python3 >/dev/null 2>&1 && ! command -v realpath >/dev/null 2>&1; then
  die "need python3 or realpath for safe path resolution"
fi

OS_ABS="$(canonical_existing "${OS_ROOT}")"

# Resolve target absolute path without writing (dry-run may target a missing dir).
if [[ -e "${TARGET}" || -L "${TARGET}" ]]; then
  if [[ -L "${TARGET}" ]]; then
    die "refusing symlinked target path: ${TARGET} (pass the real repository directory)"
  fi
  if [[ ! -d "${TARGET}" ]]; then
    die "target must be a directory: ${TARGET}"
  fi
  TARGET_ABS="$(canonical_existing "${TARGET}")"
else
  parent_dir="$(dirname "${TARGET}")"
  base_name="$(basename "${TARGET}")"
  if [[ -d "${parent_dir}" ]]; then
    parent_phys="$(canonical_existing "${parent_dir}")"
    TARGET_ABS="$(lexical_normalize "${parent_phys}/${base_name}")"
  else
    TARGET_ABS="$(lexical_normalize "$(absolute_path "${TARGET}")")"
  fi
  log "NOTE: target does not exist yet: ${TARGET_ABS}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mkdir -p "${TARGET_ABS}"
    TARGET_ABS="$(canonical_existing "${TARGET_ABS}")"
  fi
fi

TARGET_PHYS="${TARGET_ABS}"
if [[ -d "${TARGET_ABS}" ]]; then
  TARGET_PHYS="$(canonical_existing "${TARGET_ABS}")"
  TARGET_ABS="${TARGET_PHYS}"
fi

if [[ "${TARGET_ABS}" == "${OS_ABS}" ]] || is_physically_inside "${TARGET_ABS}" "${OS_ABS}"; then
  die "refusing to bootstrap into the Production OS repository itself (${OS_ABS})"
fi

INSTALLED=()
SKIPPED=()
WOULD_OVERWRITE=()
DISCOVERED=()
VERIFIED=()
INFERRED=()
UNKNOWN=()

record_install() { INSTALLED+=("$1"); }
record_skip() { SKIPPED+=("$1"); }
record_overwrite() { WOULD_OVERWRITE+=("$1"); }
discover() { DISCOVERED+=("$1"); }
note_verified() { VERIFIED+=("$1"); }
note_inferred() { INFERRED+=("$1"); }
note_unknown() { UNKNOWN+=("$1"); }

# Exact Git repository identity: if Git applies to this path, toplevel must equal target.
enforce_git_identity() {
  local top=""
  if [[ ! -d "${TARGET_ABS}" ]]; then
    # Dry-run against a not-yet-created path: no Git identity to enforce yet.
    discover "git: unknown (target does not exist yet)"
    discover "git-identity: unverified (target missing)"
    return 0
  fi

  if top="$(git -C "${TARGET_ABS}" rev-parse --show-toplevel 2>/dev/null)"; then
    top="$(canonical_existing "${top}")"
    if [[ "${top}" != "${TARGET_ABS}" ]]; then
      die "target is not an independent Git repository root (target=${TARGET_ABS}, git-toplevel=${top}). Bootstrap only accepts the repository root, not a nested directory."
    fi
    discover "git: yes (toplevel=${top})"
    discover "git-identity: VERIFIED (exact match)"
    note_verified "git-identity: ${top}"
  else
    discover "git: NO — initialize a Git repo at the target root before relying on agent workflows (bootstrap will not init Git)"
    discover "git-identity: none (not a Git directory)"
    note_unknown "git-identity (not a Git directory)"
  fi
}

# Reject destinations that escape TARGET or involve symlinks.
# Conservative policy: any symlink component in the destination path is an error.
assert_safe_destination() {
  local dest="$1"
  local normalized
  local cur
  local parent
  local phys

  normalized="$(lexical_normalize "${dest}")"

  if [[ "${normalized}" != "${TARGET_ABS}" && "${normalized}" != "${TARGET_ABS}/"* ]]; then
    die "refusing path outside target: ${dest} (target=${TARGET_ABS})"
  fi

  # Walk every existing component from leaf toward root; reject symlinks.
  cur="${normalized}"
  while [[ -n "${cur}" && "${cur}" != "/" ]]; do
    if [[ -L "${cur}" ]]; then
      die "refusing destination with symlink component: ${cur} (dest=${normalized}). Bootstrap never follows destination symlinks."
    fi
    if [[ "${cur}" == "${TARGET_ABS}" ]]; then
      break
    fi
    parent="$(dirname "${cur}")"
    [[ "${parent}" == "${cur}" ]] && break
    cur="${parent}"
  done

  # If the destination already exists, require physical containment under TARGET.
  if [[ -e "${normalized}" ]]; then
    phys="$(canonical_existing "${normalized}")"
    if ! is_physically_inside "${phys}" "${TARGET_PHYS}"; then
      die "destination resolves outside target: ${normalized} -> ${phys} (target=${TARGET_PHYS})"
    fi
  else
    # Deepest existing ancestor must be physically inside TARGET.
    cur="$(dirname "${normalized}")"
    while [[ ! -e "${cur}" && "${cur}" != "/" && "${cur}" != "." ]]; do
      cur="$(dirname "${cur}")"
    done
    if [[ -e "${cur}" ]]; then
      if [[ -L "${cur}" ]]; then
        die "refusing destination under symlink ancestor: ${cur} (dest=${normalized})"
      fi
      phys="$(canonical_existing "${cur}")"
      if ! is_physically_inside "${phys}" "${TARGET_PHYS}"; then
        die "destination ancestor resolves outside target: ${cur} -> ${phys} (dest=${normalized}, target=${TARGET_PHYS})"
      fi
    fi
  fi
}

# Create parent directories without following symlink escapes (re-check after mkdir).
safe_mkdir_parent() {
  local dest="$1"
  local parent
  parent="$(dirname "${dest}")"
  assert_safe_destination "${parent}"
  if [[ ! -d "${parent}" ]]; then
    mkdir -p "${parent}"
  fi
  assert_safe_destination "${dest}"
}

# --- Discovery (conservative) ------------------------------------------------

GAME_NAME="TODO_GAME_NAME"
GAME_NAME_STATUS="unknown"
GAME_ONE_LINER="TODO one-line description — NEEDS_CONFIRMATION"
UNITY_VERSION="TODO"
UNITY_VERSION_STATUS="unknown"
PRIMARY_SCENE="TODO Assets/Scenes/Main.unity — NEEDS_CONFIRMATION"
PRIMARY_SCENE_STATUS="unknown"
PROJECT_LAYOUT="TODO describe Assets/ layout — NEEDS_CONFIRMATION"
NAMESPACES="TODO — NEEDS_CONFIRMATION"
ARCHITECTURE_CONSTRAINTS="TODO document architecture constraints for this game — NEEDS_CONFIRMATION"
TARGET_PLATFORMS="TODO — NEEDS_CONFIRMATION"
SCENE_CANDIDATES=()

enforce_git_identity

if [[ -f "${TARGET_ABS}/ProjectSettings/ProjectVersion.txt" ]]; then
  discover "unity-project: yes (ProjectSettings/ProjectVersion.txt present)"
  note_verified "unity-project: ProjectSettings/ProjectVersion.txt"
  UNITY_VERSION="$(sed -n 's/^m_EditorVersion:[[:space:]]*//p' "${TARGET_ABS}/ProjectSettings/ProjectVersion.txt" | head -n 1 | tr -d '\r')"
  if [[ -n "${UNITY_VERSION}" ]]; then
    UNITY_VERSION_STATUS="verified"
    discover "unity-version: ${UNITY_VERSION} (VERIFIED from ProjectVersion.txt)"
    note_verified "unity-version: ${UNITY_VERSION}"
  else
    UNITY_VERSION="TODO"
    UNITY_VERSION_STATUS="unknown"
    discover "unity-version: unreadable in ProjectVersion.txt"
    note_unknown "unity-version"
  fi
else
  discover "unity-project: NO ProjectSettings/ProjectVersion.txt (still installing docs/rules templates)"
  note_unknown "unity-project (missing ProjectSettings/ProjectVersion.txt)"
  note_unknown "unity-version"
fi

if [[ -f "${TARGET_ABS}/AGENTS.md" ]]; then
  discover "existing AGENTS.md: yes (protected unless --force)"
fi
if [[ -d "${TARGET_ABS}/.cursor/rules" ]]; then
  discover "existing .cursor/rules: yes (protected unless --force)"
fi

# Directory basename is a suggestion only — never treated as confirmed product identity.
suggested_name="$(basename "${TARGET_ABS}")"
GAME_NAME="TODO_CONFIRM_GAME_NAME (suggested dirname: ${suggested_name})"
GAME_NAME_STATUS="inferred"
discover "game-name: INFERRED from directory basename '${suggested_name}' — NEEDS_CONFIRMATION (not product identity)"
note_inferred "game-name: ${suggested_name} (dirname suggestion only)"

# Scene files are candidates only; never assume the first .unity is the main scene.
if [[ -d "${TARGET_ABS}/Assets/Scenes" ]]; then
  while IFS= read -r -d '' scene; do
    SCENE_CANDIDATES+=("${scene#"${TARGET_ABS}/"}")
  done < <(find "${TARGET_ABS}/Assets/Scenes" -maxdepth 2 -type f -name '*.unity' -print0 2>/dev/null | sort -z || true)
fi
if ((${#SCENE_CANDIDATES[@]})); then
  PRIMARY_SCENE="TODO_CONFIRM_PRIMARY_SCENE — NEEDS_CONFIRMATION (candidates: ${SCENE_CANDIDATES[*]})"
  PRIMARY_SCENE_STATUS="inferred"
  discover "primary-scene: UNCONFIRMED — found ${#SCENE_CANDIDATES[@]} candidate(s) under Assets/Scenes (not assumed main)"
  for s in "${SCENE_CANDIDATES[@]}"; do
    discover "  scene-candidate: ${s}"
    note_inferred "scene-candidate: ${s}"
  done
  note_unknown "primary-scene (candidates listed; not authoritative)"
else
  discover "primary-scene: unknown (no .unity under Assets/Scenes)"
  note_unknown "primary-scene"
fi

note_unknown "game-one-liner"
note_unknown "project-layout"
note_unknown "namespaces"
note_unknown "architecture-constraints"
note_unknown "target-platforms"

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

  assert_safe_destination "${dest}"

  if [[ -e "${dest}" || -L "${dest}" ]]; then
    # Existing symlink destinations are never overwritten (would follow / clobber outside).
    if [[ -L "${dest}" ]]; then
      die "refusing to write through symlinked destination: ${dest}"
    fi
    if [[ "${FORCE}" -eq 1 ]]; then
      # Re-validate immediately before write (--force does not bypass safety).
      assert_safe_destination "${dest}"
      record_overwrite "${dest}"
      action "overwrite ${dest}"
      if [[ "${DRY_RUN}" -eq 0 ]]; then
        safe_mkdir_parent "${dest}"
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
    safe_mkdir_parent "${dest}"
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
  assert_safe_destination "${dest}"
  if [[ -e "${dest}" || -L "${dest}" ]]; then
    if [[ -L "${dest}" ]]; then
      die "refusing to write through symlinked destination: ${dest}"
    fi
    if [[ "${FORCE}" -eq 1 ]]; then
      assert_safe_destination "${dest}"
      record_overwrite "${dest}"
      action "overwrite ${dest}"
      if [[ "${DRY_RUN}" -eq 0 ]]; then
        safe_mkdir_parent "${dest}"
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
    safe_mkdir_parent "${dest}"
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
install_file "${TEMPLATES}/docs/tooling-completion-report.template.md" "${TARGET_ABS}/docs/features/_tooling-completion-report.md"

install_file "${TEMPLATES}/scripts/validate.sh" "${TARGET_ABS}/scripts/validate.sh"
install_file "${TEMPLATES}/scripts/validate.config.sh.example" "${TARGET_ABS}/scripts/validate.config.sh.example"

# Marker file recording OS version (do not overwrite without force)
MARKER="${TARGET_ABS}/docs/production-os-version.txt"
assert_safe_destination "${MARKER}"
if [[ -e "${MARKER}" || -L "${MARKER}" ]]; then
  if [[ -L "${MARKER}" ]]; then
    die "refusing to write through symlinked destination: ${MARKER}"
  fi
  if [[ "${FORCE}" -ne 1 ]]; then
    record_skip "${MARKER} (exists)"
  else
    assert_safe_destination "${MARKER}"
    action "overwrite ${MARKER}"
    if [[ "${DRY_RUN}" -eq 0 ]]; then
      safe_mkdir_parent "${MARKER}"
      printf 'toff-production-os %s\nbootstrapped_utc %s\n' "${OS_VERSION}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${MARKER}"
    fi
    record_install "${MARKER} (overwritten)"
  fi
else
  action "write ${MARKER}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    safe_mkdir_parent "${MARKER}"
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
echo "Configuration provenance:"
echo "  game-name:     ${GAME_NAME_STATUS}"
echo "  unity-version: ${UNITY_VERSION_STATUS}"
echo "  primary-scene: ${PRIMARY_SCENE_STATUS}"
echo ""
echo "Verified:"
if ((${#VERIFIED[@]})); then printf '  - %s\n' "${VERIFIED[@]}"; else echo "  (none)"; fi
echo ""
echo "Inferred (NEEDS_CONFIRMATION — not authoritative):"
if ((${#INFERRED[@]})); then printf '  - %s\n' "${INFERRED[@]}"; else echo "  (none)"; fi
echo ""
echo "Unknown / TODO:"
if ((${#UNKNOWN[@]})); then printf '  - %s\n' "${UNKNOWN[@]}"; else echo "  (none)"; fi
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
echo "  1. Confirm NEEDS_CONFIRMATION / TODO placeholders in AGENTS.md and docs."
echo "  2. Customize .cursor/rules/unity-architecture.mdc for this game."
echo "  3. Review scripts/validate.sh; add validate.config.sh if filters needed."
echo "  4. Optional: run Production OS scripts/unity-capability-detect.sh against this project (read-only)."
echo "  5. Do not commit until a human reviews the diff."
echo "================================================"
