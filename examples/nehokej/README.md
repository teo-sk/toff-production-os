# Example: Nehokej (Paper Football) pilot

Reference implementation for Production OS extraction. **Not** a mandatory architecture for other TOFF games.

| Item | Value |
|---|---|
| Repo (pilot) | `project-nhk` / Nehokej |
| Game | Paper Football — deterministic graph football, portrait mobile |
| Unity (at pilot) | `6000.6.0f1` |
| OS draft origin | `docs/studio/TOFF_Games_Production_OS_v0.1.md` inside the game repo |

## Findings index

| Doc | Focus | Verification level |
|---|---|---|
| [onboarding-findings.md](onboarding-findings.md) | Fresh agent orientation | **Proven** on Nehokej |
| [code-workflow-findings.md](code-workflow-findings.md) | GAME-E2E-001 feature loop | **Proven** on Nehokej |
| [unity-mcp-findings.md](unity-mcp-findings.md) | GAME-E2E-002 MCP scene edit | **Proven** with **partial** limits on Nehokej |

## Do not copy blindly

- Pure domain assemblies / graph board model  
- ImGui prototype UI  
- Specific scene name `Pitch.unity`  
- Hardcoded Hub paths from developer machines  

Extract **process and safety**, not Nehokej folder names.
