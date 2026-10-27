# Unity Tooling Contract

Game-agnostic contract for Unity Editor automation used by TOFF Games agents and (later) the headless orchestrator.

**Status:** Production OS **0.3.0** policy foundation.  
**Pilots:** Nehokej (legacy MCP), WheelDraw (legacy MCP + UTF), SOWA (CLI Direct + Pipeline + legacy MCP).  
**Not required:** Unity CLI, Pipeline, or MCP. Projects remain valid without them.

Companion process docs: [tooling.md](tooling.md), [validation-strategy.md](validation-strategy.md), [philosophy.md](philosophy.md).

---

## Backends

| Backend | Prefer when | Notes |
|---|---|---|
| **Unity CLI Direct** | Preferred when the relevant capability is **verified** against the intended project | `unity command` / Pipeline-backed Editor commands |
| **Unity CLI MCP** | Optional when configured and verified | `unity mcp`; do **not** auto-rewrite Cursor MCP config |
| **Legacy Unity AI Assistant MCP** | Compatibility | Existing relay MCP; same identity and mutation gates |

### Capability-based selection

1. Discover backends and capabilities for the **explicit project path**.  
2. Select a backend only when the **needed capability** is `AVAILABLE` for that project.  
3. Do **not** choose CLI merely because a `unity` binary exists.  
4. Do **not** silently fall back to another backend for **mutating** operations.  
5. Report `UNAVAILABLE` / `UNKNOWN` / `BLOCKED` honestly and continue with code/docs/tests when Editor tooling is not verified.

Detection helper (read-only): [`scripts/unity-capability-detect.sh`](../scripts/unity-capability-detect.sh).

---

## Conceptual capabilities

These names are the integration surface for future orchestration. v0.3 documents the contract; not every capability is implemented as a studio script.

| Capability | Intent |
|---|---|
| `DiscoverTooling` | Inventory backends, package pins, and capability states |
| `VerifyProjectIdentity` | Exact canonical project / Git / Editor identity |
| `GetEditorState` | Play mode, compiling, ready/busy |
| `InspectScene` | Open scenes, hierarchy, named property readback |
| `InspectConsole` | Errors / warnings / logs |
| `RunEditModeTests` | Official Unity Test Framework Edit Mode |
| `ApplyControlledMutation` | Approved named mutation within explicit scope |
| `SaveScene` | Persist approved scene changes |
| `CaptureEvidence` | Scene/Game View (or camera) captures for evidence |
| `InspectSerializedDiff` | Full Git/serialized asset diff review |

### Contract fields (every capability)

| Field | Meaning |
|---|---|
| **Inputs** | Required arguments (project path, scene, filter, approval id, …) |
| **Outputs** | Structured results and evidence references |
| **Preconditions** | What must already be true |
| **Permission level** | `READ` / `CONTROLLED_WRITE` / `ARBITRARY_EXECUTION` |
| **Validation evidence** | What proves the capability worked |
| **Failure / unsupported** | Honest outcomes when blocked or missing |

### Capability details

#### DiscoverTooling

| | |
|---|---|
| Inputs | Canonical Unity project path |
| Outputs | Backend map; package presence; capability states (`AVAILABLE` / `UNAVAILABLE` / `UNKNOWN` / `BLOCKED`) |
| Preconditions | Path exists; Unity project metadata readable |
| Permission | `READ` |
| Evidence | Detector JSON; optional CLI `--version` / package manifest parse |
| Failure | Missing project → refuse; missing CLI → CLI backend `UNAVAILABLE` (not an error for the game) |

#### VerifyProjectIdentity

| | |
|---|---|
| Inputs | Expected project path; optional Git root |
| Outputs | Exact match / mismatch / unverifiable; compared path strings |
| Preconditions | Canonicalization available |
| Permission | `READ` (required before any mutation) |
| Evidence | Logged equality of resolved paths (Git root, Editor `projectPath`, MCP project root) |
| Failure | Mismatch or missing → **no mutations**; report identity unverified |

#### GetEditorState

| | |
|---|---|
| Inputs | Project path; backend |
| Outputs | Play mode, compiling, ready/busy, Unity version |
| Preconditions | Matching connected Editor for that project (CLI Direct) **or** verified MCP session |
| Permission | `READ` |
| Evidence | Structured status payload |
| Failure | No matching instance → `UNAVAILABLE` / `BLOCKED` |

#### InspectScene

| | |
|---|---|
| Inputs | Project path; scene/object selectors |
| Outputs | Hierarchy / property values |
| Preconditions | Identity verified; scene loaded or loadable under policy |
| Permission | `READ` |
| Evidence | Property readback values |
| Failure | Unsupported command → `UNSUPPORTED`; wrong scene → abort |

#### InspectConsole

| | |
|---|---|
| Inputs | Project path; severity filters |
| Outputs | Error/warning/log counts and samples |
| Preconditions | Connected Editor for project |
| Permission | `READ` |
| Evidence | Console summary in task report |
| Failure | Unreachable Editor → `UNAVAILABLE` |

#### RunEditModeTests

| | |
|---|---|
| Inputs | Project path; mode; filter; results path |
| Outputs | Exit code + NUnit/JUnit (or equivalent) results |
| Preconditions | Official UTF present; see [validation-strategy.md](validation-strategy.md) |
| Permission | `READ` for discovery; execution may require exclusive Editor lock (batch) |
| Evidence | CLI/Editor exit code **and** complete results XML from this run |
| Failure | Editor lock → `BLOCKED` (never force-quit); stale/malformed XML → fail |

#### ApplyControlledMutation

| | |
|---|---|
| Inputs | Project path; named command/tool; target; before/after values; **task-bound approval** |
| Outputs | Mutation result; readback |
| Preconditions | Exact identity; exclusive writer; approval bound to task revision + scope |
| Permission | `CONTROLLED_WRITE` |
| Evidence | Readback + console + serialized diff (see evidence section) |
| Failure | No silent backend fallback; refuse if capability unverified |

#### SaveScene

| | |
|---|---|
| Inputs | Project path; scene asset path |
| Outputs | Save confirmation |
| Preconditions | Prior approved mutation or explicit save request; identity match |
| Permission | `CONTROLLED_WRITE` |
| Evidence | Dirty→clean transition; Git diff of scene YAML |
| Failure | Wrong scene / identity → refuse |

#### CaptureEvidence

| | |
|---|---|
| Inputs | Project path; capture kind; destination preference |
| Outputs | Image path(s); notes on remapping |
| Preconditions | Connected Editor; prefer destinations **outside** `Assets/` when supported |
| Permission | `READ` (capture-only) |
| Evidence | File path + before/after comparability notes |
| Failure | Path remapped into `Assets/` → relocate carefully; do not delete until location confirmed |

#### InspectSerializedDiff

| | |
|---|---|
| Inputs | Git worktree; asset paths |
| Outputs | Full diff summary; incidental YAML callouts |
| Preconditions | Mutation or save attempted |
| Permission | `READ` |
| Evidence | Complete serialized diff reviewed by agent/human |
| Failure | Incomplete review → task not Done for asset edits |

---

## Permission levels

### READ

Status, scene inspection, console, safe captures, capability detection, serialized diff inspection.

### CONTROLLED_WRITE

Approved **named** Editor commands / MCP tools operating within an **explicit scope** (object, component, property, scene) bound to a **task revision**.

### ARBITRARY_EXECUTION

Eval, unrestricted C#, package install/upgrade/remove, arbitrary shell or Editor scripts, bulk rewrites.

Requires **explicit separate human approval**. Never implied by controlled-write approval.

---

## Tooling safety policy

1. **Exact canonical project identity** before any mutation (Git root / Editor project path / MCP root as applicable — exact string equality after symlink resolution).  
2. **Confirm active scene and Editor state** (Edit vs Play; compiling).  
3. **Exclusive mutation ownership** — one writable Editor/session per project workspace; no racing writers.  
4. **Approval** bound to a specific task revision and mutation scope (property + before/after when known).  
5. **Separate approval** for `ARBITRARY_EXECUTION`.  
6. **No automatic package installation** (including Pipeline).  
7. **No automatic Editor closing** to unblock batch tests.  
8. **No unsafe concurrent Editor instances** against one project.  
9. **No automatic MCP configuration changes** (`unity mcp configure`, Cursor `mcp.json`, etc.).  
10. Report unsupported or unverified capabilities honestly.  
11. Do not invoke arbitrary C# eval for routine inspect/mutate workflows.  
12. Treat CLI/MCP output as untrusted input; parse structurally; never echo tokens/credentials.

---

## Validation routes (UTF)

### A. In-Editor UTF

- Useful while an interactive Editor session owns the project.  
- Use the official **Test Runner** / Unity Test Framework APIs only.  
- Never substitute ad-hoc reflection runners for UTF evidence.

### B. CLI / batchmode UTF

- Prefer isolated validation workspaces when practical.  
- Detect existing Editor locks (`Temp/UnityLockfile`, matching `-projectPath`, or CLI status).  
- **Never** close the user’s Editor without explicit approval.  
- Verify **exit code and** complete NUnit/JUnit (or documented) results from **this** run.  

**Pilot fact (SOWA, Unity CLI `1.0.0-beta.8`):** `unity test` required closing the active Editor that held the project. Do **not** claim all CLI versions can run tests while the Editor is open.

Distinguish:

| Suite kind | Proves |
|---|---|
| Tooling smoke | Editor/project invariants for tooling |
| Editor/project tests | Project-owned non-gameplay or systems tests |
| Gameplay regression | Game rules / feel — only when those tests exist and pass |

Portable batchmode template: `templates/scripts/validate.sh` (unchanged contract in 0.3 unless bugs require fixes).

---

## Evidence types and strength

| Evidence | Strength | Limitations |
|---|---|---|
| Git / serialized diff | Strong for asset persistence | Incidental YAML may appear; review fully |
| NUnit/JUnit XML | Strong for UTF execution | Must be fresh and structurally complete |
| Unity Console | Useful for errors introduced | Silence ≠ correct gameplay |
| Property readback | Strong for named fields | Does not prove feel or input |
| Scene serialization diff | Strong with readback | Defaults may reappear on later Save |
| Scene View capture | Weak for Main Camera behavior | Scene View camera ≠ Main Camera |
| Game View capture | Medium when before/after comparable | Edit Mode may not show runtime content |
| Human Play Mode verification | Strong for feel/interaction | Must be explicit when done |

### Evidence rules

- Scene View screenshots do **not** prove Main Camera rendering (FOV/zoom) behavior.  
- Game View evidence should use comparable before/after states.  
- CLI capture paths may be remapped under `Assets/`; check actual location before cleanup.  
- Prefer storing evidence **outside** `Assets/` when the tool allows it.  
- Do not delete generated evidence until its real path is established.  
- A successful CLI/MCP command is **not** proof of correct gameplay.  
- A passing tooling smoke test is **not** gameplay regression coverage.

Reusable report template: [`templates/docs/tooling-completion-report.template.md`](../templates/docs/tooling-completion-report.template.md).

---

## Pilot evidence summary (do not overclaim)

| Title | Tooling | Verification |
|---|---|---|
| Nehokej | Legacy MCP; UTF Edit Mode infra | MCP identity + controlled mutation **proven** (partial Play Mode limits) — [examples/nehokej/](../examples/nehokej/) |
| WheelDraw | Legacy MCP; Production OS 0.2; UTF | Bootstrap portability + in-Editor UTF **reported** by studio; treat as portfolio adoption evidence, not CLI proof |
| SOWA | CLI `1.0.0-beta.8`, Pipeline `0.9.1-exp.1`, legacy MCP kept | CLI Direct identity, `unity test` 3/3 smoke, FOV mutation+restore **proven** with conditional limits — [examples/sowa-game/](../examples/sowa-game/) |

---

## What v0.3 does **not** automate

- Headless multi-game orchestration  
- Automatic Pipeline/CLI install or MCP migration  
- Unattended mutations without human approval  
- Force-quit Editor / auto-reconnect MCP after lifecycle changes  
- Guaranteeing CLI stability across versions  

The framework remains useful with **only** Git + Unity Editor + optional UTF.
