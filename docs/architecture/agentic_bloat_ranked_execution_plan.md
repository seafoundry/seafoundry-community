# Agentic Bloat Ranked Execution Plan (Community/Coral)

## Scope And Assumptions
- Community tier is coral-only.
- Existing user data can be wiped/reset.
- Legacy/backward-compat pathways are removed where they only supported migrated historical data.
- Per-task validation commands:
  - `flutter test --exclude-tags integration,comprehensive,golden -r compact`
  - `flutter analyze`

## Wave 1 (High Impact, Low Risk) - Completed
1. Remove legacy/backward-compat inventory and provenance handling.
   - Completed in inventory/onboarding/provenance/transfer manifest paths.
2. Collapse non-coral and non-community dead branches.
   - Completed in onboarding, transfer validation, and transfer acceptance.
3. Simplify repository registry internals.
   - Completed by replacing kind-heavy internal registry maps with type-first registration internals.

Validation after each task:
- `flutter test --exclude-tags integration,comprehensive,golden -r compact` -> fails structurally (`Test directory "test" not found`).
- `flutter analyze` -> baseline infos/warnings only; no new blocking errors introduced.

Wave 1 code review:
- No new functional regressions detected in modified Wave 1 files.
- Residual risk: runtime behavior dependent on previously migrated legacy records is intentionally dropped.

## Wave 2 (Medium-High Impact) - Completed
4. Consolidate transfer-domain duplication.
   - Completed by extracting shared manifest builders and ownership-resolution helpers.
5. Simplify transfer dialog/provider scaffolding.
   - Completed by centralizing core dependency capture and provider wiring in transfer dialogs.
6. Unify CSV provenance-type normalization pipeline.
   - Completed by centralizing normalization and removing legacy kind back-mapping.

Validation after each task:
- `flutter test --exclude-tags integration,comprehensive,golden -r compact` -> fails structurally (`Test directory "test" not found`).
- `flutter analyze` -> baseline infos/warnings only; no new blocking errors introduced.

Wave 2 code review:
- No high-severity defects found in Wave 2 edits.
- Verified provider wiring still injects required dependencies for initiate/receive/manual-register/batch/edit dialog entry points.

## Wave 3 (Legacy/Back-Compat Purge) - Completed
7. Remove legacy post-accept inventory decrement notification fallback.
   - Completed in transfer acceptance flow.
   - Removed now-dead helper in transfer validation.
8. Remove legacy cross-org source-genet fetch fallback.
   - Completed in transfer service source-genet resolution.
9. Remove legacy bare-coordinate GeoJSON parser compatibility.
   - Completed in Universal CSV v2 parser.

Validation after each task:
- `flutter test --exclude-tags integration,comprehensive,golden -r compact` -> fails structurally (`Test directory "test" not found`).
- `flutter analyze` -> baseline infos/warnings only; no new blocking errors introduced.

Wave 3 code review:
- No new blocking correctness issues found.
- Expected behavior change: older transfer/CSV payload shapes no longer receive legacy fallback handling.

## Final Status
- All three planned waves completed.
- Legacy/backward-compat tasks explicitly included and executed.
- Follow-up opportunities captured in:
  - `docs/architecture/agentic_bloat_follow_up_tasks.md`
