# Production pipeline

Shared lifecycle for Unity game projects using Production OS. Use lightweight gates for experiments; require full evidence for production and release.

## Stage gates

| Phase | Inputs | Deliverables | Gate |
|---|---|---|---|
| 0. Intake | Pitch / inspiration | Concept brief, owner, platform | Lead: pursue / park / reject |
| 1. Design | Approved brief | GDD, art direction, constraints, first QA notes | Design lock for prototype |
| 2. Prototype | GDD + prioritized slice | Playable slice, capture, risks | Human playtest: worth continuing |
| 3. Production | Validated prototype | Small PRs, tests, updated docs | Feature DoD + review |
| 4. Release candidate | Feature-complete build | Automated + manual QA, changelog | Human RC approval |
| 5. Release | Approved RC | Signed build, store assets | Human-controlled publish |
| 6. Live ops | Analytics + feedback | Experiments, follow-up builds | Product review |

Stages may loop backwards. Kill criteria belong in the concept/GDD.

## Standard task workflow

1. **Intake** — player outcome; link references.  
2. **Spec** — bounded feature contract (see feature template).  
3. **Plan** — inspect real codebase; list files, risks, tests; do not invent facts.  
4. **Implement** — feature branch; focused diff.  
5. **Editor work** (if needed) — verified Unity tooling backend or manual Editor with identity + exclusivity rules.  
6. **Validate** — compile/tests/manual notes per [validation-strategy.md](validation-strategy.md).  
7. **Review** — diff vs spec; human for feel/architecture/release.  
8. **Merge & record** — update status docs/ADRs when behavior changes.

## Definition of Done (default)

- [ ] Acceptance criteria met or exceptions listed  
- [ ] Compiles on the **project’s pinned** Unity version  
- [ ] Relevant automated tests executed **or** blocked reason + manual alternative recorded  
- [ ] Scene/prefab diffs reviewed if assets changed (full serialized diff)  
- [ ] Relevant gameplay observed or explicitly marked unverified  
- [ ] No accidental package/settings/meta churn, secrets, or broken references  
- [ ] Docs/ADRs updated when behavior or architecture changes  
- [ ] Completion report with evidence and remaining approvals  

## Human approval required (default)

- Core gameplay / feel changes  
- Unity or package upgrades  
- Release / store actions  
- Bulk scene rewrites  
- New third-party dependencies  
- Changes to Production OS safety rules themselves (in this repo)
