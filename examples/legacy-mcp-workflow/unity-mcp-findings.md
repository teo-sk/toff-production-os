# Unity MCP findings — controlled mutation

**Verification:** Proven with partial limits on a Unity game pilot (2026-10-27). Narrative anonymized for public docs.

## Intent

Prove safe MCP loop: identity → approval → single property mutation → readback → console → Play Mode observe → serialized diff → rollback docs (not auto-run).

## Proven

- Exact canonical Git root == MCP `GetProjectRoot` before mutation.
- Abort/refuse when identity unverifiable (rule exercised as gate; mismatch not forced in pilot).
- Active scene confirmation against the pilot’s primary gameplay scene asset.
- Human approval of exact property + before/after values (camera orthographic size reduced by a small approved delta).
- Property readback after set; console error check; Play Mode camera capture showed expected scene content.
- Full Git diff review after Save.
- Incidental YAML serialization detected (component fields matching C# defaults written on Save).
- Safe minimization: removed incidental YAML keys only after confirming defaults apply when keys are absent; reload kept scene clean and values correct; did not `git checkout` the whole scene.

## Partial / not claimed

- Edit Mode camera capture showed clear color only (runtime meshes) — zoom before/after not comparable in Edit Mode.
- Player input / aim interaction **not** exercised via MCP.
- Device play **not** verified.
- MCP tool success ≠ gameplay correctness (explicitly reported).
- Next intentional Save may re-emit default fields — expected Unity behavior.

## Extracted mandatory rules

- Exact path identity; exclusive writers; approval for design-altering edits.
- Full serialized diff inspection; incidental YAML handling; no blind one-line forcing.
- Verification taxonomy: console ≠ visual ≠ interaction.
- MCP optional for Production OS consumers.
