# Agent architecture

Roles describe **jobs**, not necessarily eight concurrent processes. One agent may wear a role via a scoped brief.

## Roles

| Role | Primary job | Typical tools | Authority |
|---|---|---|---|
| Studio Lead (human) | Priority, fun, ship/no-ship | ChatGPT, Unity, dashboards | Final approval |
| Game Design Agent | GDD, balance proposals, specs | Chat models | Recommends; no silent spec changes |
| Technical Lead Agent | Architecture plans, impact | Cursor + repo | Drafts; significant changes need approval |
| Implementation Agent | Code, tests, docs | Cursor + Git | Within task scope |
| Unity Editor Agent | Scene/prefab/inspector | Unity MCP (optional) | Scoped mutations after identity check |
| Art Direction Agent | Visual language, asset briefs | Chat + art tools | Proposes; approved guide wins |
| QA Agent | Cases, verification, blockers | UTF, validate.sh | Can block promotion on failed checks |
| Build & Release Agent | Builds, metadata | Batchmode / CI | No unapproved publish |

## Boundaries

1. **Production OS** supplies defaults and templates.  
2. **Game repo** owns GDD, architecture, version pins, overrides.  
3. **Task brief** sets immediate allowed paths and acceptance.  
4. **Conversation** is ephemeral — persist decisions in repo docs/ADRs.  
5. Images/references are inputs, not substitutes for acceptance criteria.

## Handoffs

Prefer durable artifacts over chat:

`approved feature spec → branch → validation evidence → PR → status/ADR update`

## Concurrency

- Parallelize independent C# / docs work.  
- Serialize Unity scene/prefab writers: **one writable Editor session** per project.  
- Never race two agents on the same serialized asset.
