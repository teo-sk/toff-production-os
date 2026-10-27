# Philosophy

## Purpose

TOFF Games builds multiple Unity titles with humans directing creative and release decisions, and AI agents proposing/implementing within explicit scope. Production OS makes that loop **repeatable, auditable, and safe** without forcing every experiment into heavyweight process.

## Principles

1. **One studio standard, many independent game repos.**  
2. **Design intent is separate from implementation status.** Approved GDD/architecture/feature acceptance are not silently rewritten to match code.  
3. **The repository is the durable source of truth;** chat is ephemeral. Persist decisions in docs/ADRs.  
4. **Agents propose and implement; humans approve** creative, architectural, package, and release decisions.  
5. **Every task has acceptance criteria and verification evidence.** Compilation alone is not proof.  
6. **Unity CLI, Pipeline, and MCP are optional assistive tooling**, never hard dependencies of the OS or of domain correctness. Select backends by **verified capability**, not by binary presence alone.  
7. **Automation privileges are minimal.** No autonomous store publish, secret handling, destructive bulk scene rewrites, competing Editor writers, automatic package installs, or unapproved Editor force-quit.  
8. **Reuse process; preserve game identity.** Architecture recommendations are defaults, not mandatory refactors.

## Verification honesty

Label claims clearly:

| Label | Meaning |
|---|---|
| **Proven** | Executed and observed in a named pilot with evidence |
| **Partial** | Worked with known gaps (e.g. no device play, incidental YAML) |
| **Proposed** | Designed but not yet demonstrated |

Never upgrade a conditional pilot result into a studio-wide “proven” claim.

## Minimal always-on rules

Prefer a small always-applied rule surface (task delivery, Unity tooling safety when using Editor agents). Scope architecture and coding rules with globs so agents are not flooded with irrelevant constraints.
