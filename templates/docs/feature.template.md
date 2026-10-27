# Feature template

Copy to `docs/features/<id>-<slug>.md`. Keep specs measurable. Link from the task/PR.

```yaml
id: GAME-000
title: "Short title"
owner: implementation-agent  # or human | unity-editor-agent
phase: production | prototype | release
status: proposed | approved | in-progress | done | cancelled
spec: docs/features/GAME-000-slug.md
scope:
  allowed:
    - "Assets/.../**"
    - "docs/**"
  forbidden:
    - "Packages/manifest.json"
    - "ProjectSettings/**"
acceptance:
  - "Observable / testable criterion"
verification:
  - "./scripts/validate.sh  # or Editor Test Runner if batchmode blocked"
  - "Manual Play Mode notes if presentation / MCP changes"
requires_approval:
  - "Core rules / feel"
  - "Package upgrades"
evidence:
  - "Paths to logs, screenshots, or PR checklist"
```

## Narrative

### Intent

Player-facing outcome in one paragraph.

### Plan notes

Impacted types/scenes; risks; out of scope.

### Acceptance criteria

Numbered, binary where possible.

### Evidence required

What proves done. Never equate “compiled” with “tested.” For MCP/scene work: identity check, property readback, full serialized diff, console, Play Mode notes or explicit unverified.
