# Example: Legacy MCP workflow

Reference evidence for Production OS agent onboarding, code + Unity Test Framework loops, and controlled legacy MCP scene mutation.  
**Not** a mandatory architecture for other Unity games.

| Item | Value |
|---|---|
| Context | Anonymized pilot on a mobile Unity title |
| Unity (at verification) | `6000.6.0f1` |
| Tooling | Legacy Unity AI Assistant MCP; official UTF Edit Mode |

## Findings index

| Doc | Focus | Verification level |
|---|---|---|
| [onboarding-findings.md](onboarding-findings.md) | Fresh agent orientation | **Proven** (named pilot; process extracted) |
| [code-workflow-findings.md](code-workflow-findings.md) | Feature loop: spec → code → UTF | **Proven** |
| [unity-mcp-findings.md](unity-mcp-findings.md) | Controlled MCP scene edit | **Proven** with **partial** limits |

## Do not copy blindly

- Pure domain assemblies or a specific board/graph model  
- Prototype UI stacks used in that pilot  
- Specific scene asset names from the pilot project  
- Hardcoded absolute paths from developer machines  

Extract **process and safety**, not that game’s folder names or product identity.
