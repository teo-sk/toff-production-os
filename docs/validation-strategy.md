# Validation strategy

## Outcomes

| Result | Meaning |
|---|---|
| **PASS** | Required checks executed this run and succeeded |
| **FAIL** | Checks executed and found defects |
| **BLOCKED** | Could not run (e.g. Editor lock); suite **not** executed |
| **UNVERIFIED** | Not run; must not be reported as pass |

`--self-test` on `validate.sh` validates **script parsers only**. It is **not** Unity Test Framework evidence.

## Principles

1. Prefer **Unity Test Framework** Edit Mode for rules and pure logic.  
2. Do **not** treat ad-hoc reflection or custom runners as equivalent to UTF.  
3. Never claim tests passed without execution evidence from this session.  
4. Refuse competing batchmode when the Editor already holds the project; **never force-quit** the user’s Editor without explicit approval.  
5. Parse machine-readable results structurally; reject stale/malformed/incomplete XML.  
6. Document an in-Editor Test Runner route when batchmode is blocked.  
7. Play Mode / device / store QA are separate gates — mark them pending when not run.  
8. Distinguish **tooling smoke**, **Editor/project tests**, and **gameplay regression** suites when reporting.

## Official UTF routes

### A. In-Editor UTF execution

- Useful for active interactive sessions that already own the project.  
- Must use the official Unity **Test Runner** / Test Framework APIs.  
- Never use direct reflection as a substitute for UTF evidence.  
- Record what was run (filter/assembly) and the outcome in the task report.

### B. CLI / batchmode UTF execution

- Prefer isolated validation workspaces when practical.  
- Detect existing Editor locks (`Temp/UnityLockfile`, matching `-projectPath`, or CLI status for the exact project).  
- **Never** close the user’s Editor without explicit approval.  
- Verify **CLI/Unity exit code and** complete NUnit/JUnit (or documented) results from **this** run.  
- Portable template: `templates/scripts/validate.sh` (Unity binary `-runTests`).  
- Optional alternate on CLI-enabled machines: `unity test` (version-specific behavior — re-check with `unity test --help`).  

**Verified fact (Unity CLI `1.0.0-beta.8` pilot):** `unity test` required the active Editor to release the project. Do **not** claim all CLI versions can run tests while the Editor is open.

See also [unity-tooling.md](unity-tooling.md).

## Portable validate.sh contract

The template script:

- Reads Unity version from `ProjectSettings/ProjectVersion.txt` (no hardcoded version).  
- Resolves the Unity binary via `UNITY_PATH` or Hub discovery for the **pinned** version.  
- Verifies binary-reported version matches the pin.  
- Detects `Temp/UnityLockfile` / matching `-projectPath` processes → exit **BLOCKED** (code 2).  
- Runs UTF Edit Mode with `-testResults` XML.  
- Optionally applies `UTF_TEST_FILTER` / `scripts/validate.config.sh` (game-specific).  
- Structurally parses NUnit-style `test-run` XML (Python 3 stdlib).  
- Reports PASSED / FAILED / SKIPPED / UNVERIFIED buckets.

### Adapter requirements (game-specific)

Document in the game repo if needed:

- Custom test platform (Play Mode)  
- Assembly filters  
- CI license activation  
- Alternate result formats (`unity test` NUnit/JUnit paths)  

Do not pretend generic support exists when it does not.

## Evidence for Editor tooling / presentation tasks

Minimum:

- Identity comparison logged (exact paths)  
- Backend used (cli_direct / cli_mcp / legacy_mcp) — no silent mutation fallback  
- Property before/after (if mutated)  
- Console summary  
- Serialized diff summary  
- Play Mode Game view notes **or** explicit “not Play Mode–verified”  
- Interaction tests only if actually performed  

Evidence strength and capture-path rules: [unity-tooling.md](unity-tooling.md).  
Reusable report: `templates/docs/tooling-completion-report.template.md`.
