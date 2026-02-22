# Internal Naming Consistency: camelCase for In-App Usage

**Status**: 🧭 Planned
**Priority**: P1 - Consistency + Data Integrity
**Labels**: `naming`, `code-quality`, `data-model`, `csv`, `firebase`

## Summary

Enforce camelCase for all in-app identifiers: variable names, import aliases, map keys, Firestore field names, and user-facing names. File naming is secondary and out of scope for this effort.

## Scope

**In scope**
- Import aliases and in-app identifiers
- Map literal keys and serialized data keys
- Firestore field names
- CSV column keys in import/export pipelines

**Out of scope**
- File/directory renames (handled separately, if at all)
- Third-party/vendor/platform code and generated files

## Audit Findings (Initial)

**Snake_case import aliases (non-exhaustive list)**
- `fb_auth` in Firebase auth imports
- `domain_errors` in error imports
- `loss_types`, `form_events`, `file_loader`, `js_util`, `observation_schema`, `firebase_core_messages`

**Non-camelCase internal names**
- Double-underscore fields in `lib/cubits/deliverable_form/deliverable_form_cubit.dart` (e.g., `__userRepository`, `__organizationId`)
- Sentinel keys/values using underscores (e.g., `__missing__`, `__example`, `__add_custom__`)

## Decisions / Rules

- **Hard rule**: All in-app identifiers and serialized keys use camelCase.
- Import aliases must be camelCase unless an external API requires otherwise (document any exceptions).
- Sentinel keys must be either migrated to camelCase or explicitly allowlisted and guaranteed to never persist to Firestore or CSV exports.

## Plan of Work

**Phase 0: Confirm scope + allowlist**
- Re-scan `lib/` + `test/` for snake_case identifiers and aliases.
- Produce a strict allowlist for any sentinel values that must remain.

**Phase 1: Import aliases**
- Rename all snake_case import aliases to camelCase.
- Update usages in `lib/` and `test/`.

**Phase 2: Internal identifiers**
- Replace `__*` fields with single-underscore camelCase (e.g., `_userRepository`).
- Update getters and constructor assignments.

**Phase 3: Sentinel keys**
- Decide between (a) migrating to camelCase or (b) formal allowlist with explicit no-persist guarantees.
- Update call sites and validators accordingly.

## Data Migration Plan

Even though the focus is internal naming, we must ensure persisted data and CSV payloads are clean.

1. **Audit Firestore** for snake_case keys across org-scoped collections.
2. **Define mapping** from legacy snake_case keys to camelCase equivalents.
3. **Migration script**: copy values to camelCase keys, remove legacy keys, and log diffs.
4. **CSV import compatibility**: temporarily map legacy snake_case columns to camelCase with a deprecation window.
5. **Post-migration validation**: re-scan Firestore and CSV exports to confirm zero snake_case keys.

## Test Plan Revision

Add a naming compliance step to the standard test workflow:

- New audit command (to be implemented) that fails on snake_case identifiers/keys in `lib/` and `test/`, except allowlisted sentinel values.
- Add to CI and local verification:
  - `flutter analyze`
  - `dart run tool/naming_audit.dart` (or `node scripts/audit-naming.js`)
  - `flutter test --tags unit`
- Add a regression test to ensure CSV import maps legacy snake_case columns to camelCase during the deprecation window.

## Acceptance Criteria

- No snake_case import aliases or internal identifiers in `lib/` and `test/` outside the allowlist.
- No snake_case keys in Firestore writes or CSV exports.
- Naming audit passes in CI.

## Related Docs

- `CLAUDE.md` (Naming rules)
- `AGENTS.md` (Naming rules)
- `.github/issues/architecture/data-field-unification-sot.md`
