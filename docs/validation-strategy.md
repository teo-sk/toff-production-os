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
4. Refuse competing batchmode when the Editor already holds the project; **never force-quit** the user’s Editor.  
5. Parse machine-readable results structurally; reject stale/malformed/incomplete XML.  
6. Document an in-Editor Test Runner route when batchmode is blocked.  
7. Play Mode / device / store QA are separate gates — mark them pending when not run.

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
- Alternate result formats  

Do not pretend generic support exists when it does not.

## Evidence for MCP / presentation tasks

Minimum:

- Identity comparison logged  
- Property before/after (if mutated)  
- Console summary  
- Serialized diff summary  
- Play Mode Game view notes **or** explicit “not Play Mode–verified”  
- Interaction tests only if actually performed  
