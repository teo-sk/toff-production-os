# Example: SOWA Game — Unity CLI / Pipeline pilot

Reference evidence for Production OS **0.3.0** Unity tooling abstraction.  
**Not** a mandate that every TOFF title must install Unity CLI or Pipeline.

| Item | Value |
|---|---|
| Pilot project | SOWA Game (`sowagame/SOWA`) |
| Unity Editor | `6000.3.10f1` |
| Unity CLI | `1.0.0-beta.8` (experimental) |
| Unity Pipeline | `com.unity.pipeline` `0.9.1-exp.1` |
| Legacy MCP | `com.unity.ai.assistant` preserved |
| Branch (pilot) | `experiment/unity-pipeline-cli` |
| Date | 2026-10-27 |

## Findings index

| Doc | Focus | Verification |
|---|---|---|
| [cli-pilot-findings.md](cli-pilot-findings.md) | Tests A/B/C, lifecycle, evidence limits | **Proven** with **conditional** limits on SOWA |

## Do not copy blindly

- Absolute machine paths from the pilot host  
- Assuming `unity test` works while the Editor is open  
- Treating tooling smoke tests as gameplay proof  
- Auto-migrating Cursor MCP to `unity mcp`  
- Requiring Pipeline on Nehokej / WheelDraw  

Extract **capability-based backend selection and safety policy**, not SOWA’s scene/layout.
