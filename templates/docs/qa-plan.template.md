# QA and validation — {{GAME_NAME}}

## Automated

| Suite | Focus | How to run |
|---|---|---|
| Edit Mode (UTF) | TODO | `./scripts/validate.sh` |
| Play Mode | TODO / none yet | TODO |

Script-only parser checks (**not** game tests):

```bash
./scripts/validate.sh --self-test
```

Optional binary override (must still match `ProjectSettings/ProjectVersion.txt`):

```bash
UNITY_PATH="/path/to/Unity" ./scripts/validate.sh
```

### Editor already open

If batchmode is **BLOCKED** (lockfile / open Editor):

1. Do **not** force-quit the Editor via scripts.
2. Use **Window → General → Test Runner** for the relevant suite; record results in the task report.
3. Or quit the Editor yourself and re-run `./scripts/validate.sh`.

Never claim automated tests passed unless they were executed in that session.

## Manual gates

- Core loop fun check:
- Presentation / MCP tasks: Play Mode Game view notes required or explicitly pending
- Device / store: see release plan

## Evidence policy

PASS / FAIL / BLOCKED / UNVERIFIED per Production OS validation strategy.
