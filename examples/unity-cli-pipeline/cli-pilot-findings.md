# Unity CLI / Pipeline pilot findings

**Verification:** Proven with conditional limits on a Unity game pilot (2026-10-27). Narrative anonymized for public docs.  
**Authority for policy:** [docs/unity-tooling.md](../../docs/unity-tooling.md).

This document records **what was actually demonstrated**. It does not prove production-grade unattended execution across all adopters.

## Technical setup (confirmed)

| Component | Version / note |
|---|---|
| Editor | `6000.3.10f1` from `ProjectSettings/ProjectVersion.txt` |
| Unity CLI | `1.0.0-beta.8` |
| Pipeline package | `0.9.1-exp.1` (`com.unity.pipeline`) |
| AI Assistant (legacy MCP) | Kept installed; Cursor MCP config **not** rewritten |
| UTF | Project Edit Mode smoke assembly added for tooling invariants |
| Primary scene (pilot) | A sample scene under `Assets/Scenes/` |

Preference order exercised: **CLI Direct** (preferred when verified) → CLI MCP (not configured) → legacy MCP (compatibility).

## Test A — Connectivity / identity (CONDITIONAL GO)

**Succeeded**

- Pipeline package install limited to manifest/lock (no scene/script/`ProjectSettings` churn beyond packages).  
- `unity status` / `pipeline list` / `unity command … editor status` / `scene list_open` / `console status` read-only success.  
- Exact path identity: Git root == Unity project root == CLI-reported `projectPath` == legacy MCP `GetProjectRoot`.  
- Legacy MCP still worked after Pipeline install; MCP config untouched.  
- Large Pipeline command catalog discovered (on the order of ~166 commands).

**Conditional / limits**

- CLI + Pipeline were **experimental** releases.  
- Pipeline server became reachable only after the Editor finished UPM resolve (minutes-scale delay observed).  
- No mutating commands in Test A (by design).

## Test B — Official Edit Mode UTF via `unity test` (CONDITIONAL PASS)

**Fixtures (tooling smoke, not gameplay)**

- Editor-only assembly under `Assets/Tests/Editor`  
- Three NUnit Edit Mode tests: Editor version pin, sample scene asset resolve, sample scene enabled in Build Settings  

**Succeeded**

- `unity test … --mode EditMode` exit `0` with **3/3** passed.  
- Authoritative **NUnit and JUnit** artifacts written for that run.  
- Gameplay scenes / `ProjectSettings` otherwise unchanged aside from intentional test fixtures + Pipeline packages.

**Conditional / limits**

- Batch `unity test` required **closing** the active Editor that held the project (exclusive lock).  
- Production OS policy: **never** auto-close the user’s Editor.  
- After Editor close/reopen, **legacy MCP did not automatically reconnect** (timeout until the IDE reconnected to a new relay).  
- Passing tooling smoke ≠ gameplay regression coverage.

## Test C — Controlled CLI Direct mutation (CONDITIONAL PASS)

**Approved scope**

- Object: Main Camera  
- Property: Camera field of view  
- Change: `60` → `55` (later restored to `60`)

**Succeeded**

- Named commands only (no `eval` / arbitrary C#).  
- Before/after property readback via CLI.  
- `scene save` with **clean** serialized YAML delta (FOV line only; no incidental keys in this pilot).  
- Console remained clean (0 errors / 0 warnings) for the mutation window.  
- Exact project identity reconfirmed before mutation.

**Conditional / limits**

- Scene View captures were **byte-identical** before/after — Scene View camera ≠ Main Camera FOV; **visual FOV not proven**.  
- Game View capture was Edit Mode / incomplete as a before-after pair.  
- CLI capture `save_path` was **remapped under `Assets/`**; evidence relocated outside Assets and the accidental Assets folder removed only after location confirmed.  
- Play Mode / player interaction **not** tested.  
- Successful CLI mutation ≠ gameplay correctness.

## Editor lifecycle lessons

1. Interactive CLI Direct needs a **running** Editor with Pipeline server reachable for the **exact** project.  
2. Batch `unity test` (this CLI version) needed the project **closed**.  
3. Closing/reopening breaks assumptions about long-lived MCP sessions — reconnect is **manual/operational**, not automatic.  
4. Do not silently switch backends mid-mutation if one becomes unavailable.

## Why this does **not** prove production unattended execution

- Single title, experimental CLI/Pipeline pins, human-supervised approvals.  
- No multi-project orchestrator, no CI licensing matrix, no device farm.  
- Evidence gaps on visual camera proof and MCP reconnect.  
- Command surface must be re-verified per CLI version (`unity --help` / capability detect) — do not assume stability.

## Extraction into Production OS 0.3

- Capability contract + permission levels  
- Read-only `scripts/unity-capability-detect.sh`  
- Validation + evidence policy updates  
- Cursor rule wording generalized beyond MCP-only  
- Compatibility: projects without CLI/Pipeline need **no** mandatory migration  
