# Tooling

## Studio stack

| Tool | Use |
|---|---|
| ChatGPT (or approved model) | Design, briefs, analysis |
| Cursor | Code, repo exploration, PRs |
| Unity Editor | Game development |
| Unity MCP (optional) | Live Editor inspect/mutate when connected |
| Git | Durable history; PR as review unit |
| CI (optional) | Headless validate/build |
| Issue tracker (optional) | Queue — does not replace repo docs |

## Authority order

1. Approved design docs / ADRs in the **game** repo  
2. Task feature spec (allowed/forbidden paths, acceptance)  
3. Production OS templates/defaults  
4. Ephemeral chat  

## Unity MCP (optional)

MCP is **not** required to use Production OS. When used:

### Before mutation

1. Canonicalize Git repo root (absolute, symlink-resolved).  
2. Canonicalize MCP-reported project root (`GetProjectRoot` or equivalent).  
3. Require **exact string equality**; abort if missing or mismatched.  
4. Do not use name/suffix heuristics or hardcoded home paths.  
5. Confirm active scene / target asset and Editor state (Edit vs Play).  
6. Prefer a clean git checkpoint or document pre-existing dirty state.  
7. Ensure exclusive write access to the scene/prefab.

### Allowed without special approval

Read-only inspect: project data, hierarchy, console, get-state, captures for evidence.

### Requires explicit task permission

Scene/prefab/GameObject mutation, script create/delete via MCP, menu execute, package install, AssetGeneration, Play Mode control for demos.

### After mutation

- Read console for new errors/warnings.  
- Read back changed properties.  
- Inspect the **complete** serialized Git diff; detect incidental Unity YAML serialization.  
- Do not delete YAML fields solely to force a one-line diff without validating serialization behavior (defaults vs missing keys).  
- Report: succeeded / failed / **not Play Mode–verified**.  
- Never claim correct gameplay from MCP success or a screenshot alone.  
- Distinguish: Console inspection ≠ visual observation ≠ gameplay interaction tests.

### Server variance

Do not assume a single MCP package or tool schema across machines. Discover capabilities at runtime; refuse unsupported operations honestly.

## Validation tooling

See [validation-strategy.md](validation-strategy.md) and `templates/scripts/validate.sh`.

## Git safety (agents)

- No `git config` changes  
- No force-push to main/master  
- No commits unless the human asks  
- No interactive rebase/add  
- No secrets in commits  
