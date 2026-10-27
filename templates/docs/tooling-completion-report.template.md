# Tooling operation completion report

> Copy into a feature note or PR description after Unity Editor tooling work.  
> Fill only what was actually performed. Prefer [docs/unity-tooling.md](../../docs/unity-tooling.md) vocabulary.

## Task

- Task / revision: `TODO`
- Game / project path (canonical): `TODO`
- Backend used: `cli_direct` | `cli_mcp` | `legacy_mcp` | `none`
- Capability detect run?: yes/no — result summary: `TODO`

## Identity

- Git root: `TODO`
- Editor / MCP project path: `TODO`
- Exact match?: yes / no / unverified
- Active scene: `TODO`
- Editor state (Edit/Play, compiling): `TODO`
- Exclusive writer confirmed?: yes / no

## Permission

- Level used: `READ` | `CONTROLLED_WRITE` | `ARBITRARY_EXECUTION`
- Approval bound to this task revision + scope?: yes / no / n/a
- Arbitrary execution separately approved?: yes / no / n/a

## Operations

| Step | Capability | Result |
|---|---|---|
| Discover / identity | | |
| Inspect (scene/console/state) | | |
| Mutation (named command + before→after) | | |
| Save | | |
| Tests (UTF route A or B) | | |
| Captures | | |
| Serialized diff review | | |

## Evidence

| Type | Path / summary | Strength notes |
|---|---|---|
| Property readback | | |
| Console | | |
| NUnit/JUnit | | |
| Git / scene YAML diff | | |
| Scene View capture | | does **not** prove Main Camera |
| Game View capture | | comparable before/after? |
| Human Play Mode | | |

## Outcomes

- Succeeded / failed / **not Play Mode–verified**
- Backend fallback used for mutation?: **no** (must remain no) / explain if refused
- Editor closed?: no / yes (**explicit human approval** required)
- MCP reconnect needed afterward?: yes / no / unknown
- Capture paths remapped into `Assets/`?: yes / no — final evidence location: `TODO`

## Honesty checklist

- [ ] Did not claim gameplay proof from tooling success alone  
- [ ] Did not treat tooling smoke tests as gameplay regression  
- [ ] Did not auto-install packages or rewrite MCP config  
- [ ] Unsupported capabilities reported as UNAVAILABLE / UNKNOWN / BLOCKED  

## Human approvals still needed

- `TODO`
