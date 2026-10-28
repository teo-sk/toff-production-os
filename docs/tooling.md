# Tooling

## Recommended stack

| Tool | Use |
|---|---|
| ChatGPT (or approved model) | Design, briefs, analysis |
| Cursor | Code, repo exploration, PRs |
| Unity Editor | Game development |
| Unity CLI + Pipeline (optional) | Preferred Editor automation **when verified** for the project |
| Unity CLI MCP (optional) | MCP transport via `unity mcp` when configured |
| Legacy Unity AI Assistant MCP (optional) | Compatibility Editor assist |
| Git | Durable history; PR as review unit |
| CI (optional) | Headless validate/build |
| Issue tracker (optional) | Queue — does not replace repo docs |

**Authoritative Unity automation contract:** [unity-tooling.md](unity-tooling.md).

## Authority order

1. Approved design docs / ADRs in the **game** repo  
2. Task feature spec (allowed/forbidden paths, acceptance)  
3. Production OS templates/defaults  
4. Ephemeral chat  

## Unity Editor automation (optional)

Unity CLI, Pipeline, and MCP are **not** required to use Production OS. When used:

### Backend selection

1. Run read-only discovery: `scripts/unity-capability-detect.sh <project>`.  
2. Choose a backend only when the **needed capability** is `AVAILABLE` for that exact project.  
3. Prefer **CLI Direct** when verified; otherwise CLI MCP or legacy MCP if verified.  
4. Do **not** select CLI solely because `unity` exists on `PATH`.  
5. Do **not** silently fall back to another backend for mutating operations.  
6. Do **not** auto-install Pipeline/packages or rewrite MCP configuration.

### Before mutation

1. Canonicalize Git / Unity project root (absolute, symlink-resolved).  
2. Canonicalize tooling-reported project root (`projectPath` / `GetProjectRoot` / equivalent).  
3. Require **exact string equality**; abort if missing or mismatched.  
4. Do not use name/suffix heuristics or hardcoded home paths.  
5. Confirm active scene / target asset and Editor state (Edit vs Play).  
6. Prefer a clean git checkpoint or document pre-existing dirty state.  
7. Ensure exclusive write access to the scene/prefab.

### Permission levels

| Level | Examples |
|---|---|
| `READ` | Status, inspect, console, safe capture, capability detect |
| `CONTROLLED_WRITE` | Approved named commands within explicit scope |
| `ARBITRARY_EXECUTION` | Eval, unrestricted C#, package ops — **separate approval** |

### After mutation

- Read console for new errors/warnings.  
- Read back changed properties.  
- Inspect the **complete** serialized Git diff; detect incidental Unity YAML serialization.  
- Verify capture file locations (CLI may remap into `Assets/`).  
- Report: succeeded / failed / **not Play Mode–verified**.  
- Never claim correct gameplay from tooling success or a screenshot alone.  
- Scene View ≠ Main Camera proof.  

### Server / CLI variance

Do not assume a single MCP package or CLI schema across machines or versions. Discover capabilities at runtime (`unity --help`, capability detect); refuse unsupported operations honestly.

## Validation tooling

See [validation-strategy.md](validation-strategy.md) and `templates/scripts/validate.sh`.

## Git safety (agents)

- No `git config` changes  
- No force-push to main/master  
- No commits unless the human asks  
- No interactive rebase/add  
- No secrets in commits  
