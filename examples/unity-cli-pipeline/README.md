# Example: Unity CLI / Pipeline workflow

Reference evidence for Production OS **0.3** Unity tooling abstraction (CLI Direct, Pipeline, legacy MCP coexistence).  
**Not** a mandate that every project must install Unity CLI or Pipeline.

| Item | Value |
|---|---|
| Context | Anonymized pilot on a Unity title with experimental CLI/Pipeline |
| Unity Editor | `6000.3.10f1` |
| Unity CLI | `1.0.0-beta.8` (experimental) |
| Unity Pipeline | `com.unity.pipeline` `0.9.1-exp.1` |
| Legacy MCP | `com.unity.ai.assistant` preserved |
| Date | 2026-10-27 |

## Findings index

| Doc | Focus | Verification |
|---|---|---|
| [cli-pilot-findings.md](cli-pilot-findings.md) | Connectivity, UTF via CLI, controlled mutation, lifecycle | **Proven** with **conditional** limits |

## Do not copy blindly

- Absolute machine paths from the pilot host  
- Assuming `unity test` works while the Editor is open  
- Treating tooling smoke tests as gameplay proof  
- Auto-migrating Cursor MCP to `unity mcp`  
- Requiring Pipeline on projects that already work with legacy MCP only  

Extract **capability-based backend selection and safety policy**, not that game’s scene or layout.
