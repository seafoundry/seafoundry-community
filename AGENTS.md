# SeaFoundry AGENTS Guide

This file summarizes the core guidance for contributors and coding agents.
It is distilled from `.claude/CLAUDE.md` and `README.md`.

## Project Overview
SeaFoundry Community is a Flutter + Firebase platform for coral restoration
(genetics, inventory, outplanting, and inter-org transfers). Community
(open-source) tier only, coral-only, web-only.

## Architecture Principles
- Clean architecture layers: Presentation, Business Logic, Domain, Data.
  Firestore access is restricted to the data layer.
- State management: Use BLoC for complex features, Cubit for simple ones.
  Avoid StreamBuilder. Do not use StatefulWidget for feature flows.
- Graph system: Use GraphNode objects and Uri-based navigation internally.
  Use urlPath for deep links and external URLs.
- Repository pattern: PathRecordRepository for org-scoped hierarchical data,
  RecordRepository for non-hierarchical lookups. Prefer BehaviorSubject streams
  and rely on Firestore cache for offline-first behavior.
- Form handling: Use FormZ for validation with dedicated input/state classes.

## Widget Architecture
- Display widgets: pure UI, only domain models/GraphNodes, no logic.
- Container widgets: connect to BLoCs/Cubits, provide data to displays.
- Screen widgets: top-level routes, compose containers and displays.
- Naming: {Feature}Display, {Feature}Container, {Feature}Screen.

## Graph Loading Rules
- GraphRepository inputs/outputs must be GraphNode objects, never raw records.
- Load streams for IDs referenced by a record or its createdEvent.
- Only load immediate descendants (org -> sites -> groups -> corals).
- Unload descendants when navigating laterally or upward.

## Data Models
- Record types (domain) are immutable and extend Record/PathRecord.
- RecordData types are DTOs for Firebase serialization.
- EventRecord embeds an immutable createdEvent and is used for hierarchical
  organization data.

## Code Style and Conventions
- Keep files around 200 lines; decompose to stay DRY and reusable.
- Use custom enums instead of string or int constants.
- Never reference bloc/cubit state directly in widgets; use BlocBuilder.
- Avoid setState in widgets connected to BLoCs.
- Use LoggingService for logging.
- Do not use MaterialColor.withOpacity; use withValues(alpha:).
- Imports order: Dart, Flutter, Package, Project. Use relative imports for
  project files. Prefer barrel exports for feature folders.
- Class member order: static, constructors, properties, overrides, methods.
- Naming: in-app variables, identifiers, map keys, and user-facing names use
  camelCase (hard rule); file and directory names prefer snake_case when
  creating/renaming; PascalCase for classes; leading underscore for private
  members.
- If you find unused code or files, suggest removal.

## Dialog and Async Safety
- Prefer SafeDialogMixin or SafeDialog wrapper for dialogs.
- Capture providers before showing dialogs.
- Check mounted before setState or navigation after async work.

## Performance and Reliability
- Use const constructors where possible.
- Dispose controllers/subscriptions and cancel timers/animations.
- Avoid custom caching when Firestore cache suffices.

## Testing Strategy
- Test tiers: smoke, unit, widget, integration, comprehensive, golden.
- Add @Tags to tests and use bounded pumpAndSettle timeouts.
- Recommended commands:
  - flutter test --tags smoke
  - flutter test --tags unit
  - flutter test --exclude-tags integration,comprehensive,golden

## Operational References
- Active work: TODO.md
- Completed work: WORK_LOG.md
- Release readiness audit: `.github/issues/release/pre-release-audit.md`
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Architecture index: docs/architecture/README.md
- CSV v2 is canonical for imports/exports; keep adapters and schemas aligned.

## Module Documentation
- Index: docs/modules/README.md
- Organization: docs/modules/organization/README.md + docs/modules/organization/CLAUDE.md
- Inventory: docs/modules/inventory/README.md + docs/modules/inventory/CLAUDE.md
- Outplanting: docs/modules/outplanting/README.md + docs/modules/outplanting/CLAUDE.md
- Settings: docs/modules/settings/README.md + docs/modules/settings/CLAUDE.md
- Field Work Kit: docs/modules/field_work_kit/README.md + docs/modules/field_work_kit/CLAUDE.md
- Public Screens: docs/modules/public/README.md + docs/modules/public/CLAUDE.md
- Navigation: docs/modules/navigation/README.md + docs/modules/navigation/CLAUDE.md
- Permissions and Firebase: docs/modules/permissions_firebase/README.md + docs/modules/permissions_firebase/CLAUDE.md

## Demo Seeding

Community tier only:

| Tier | Org ID | Primary Email | Team Limit | Activity Types |
|------|--------|---------------|------------|----------------|
| Community | `demo_org_community` | community@provenance.app | 2 | comment |

All demo users share password: `demo123`

- Seed: `node scripts/seed-demo.js --reset`
- Optional flags: `--seed`, `--seed-date`, `--seed-holdings`, `--skip-inventory`.
- Inventory seeding runs `dart run scripts/reset_and_seed_inventory.dart` and expects taxonomy to be seeded first (`npm run seed:taxonomy`).
- Team members follow incrementing pattern: `community1@provenance.app`, `community2@provenance.app`, etc.

## Agent Preferences
- Be skeptical of existing code, prioritize maintainability and reuse.
- Favor reusable patterns over one-off code.
- If you leave TODOs in code, add them to TODO.md and do not claim the task is
  complete until they are tracked.
- When spawning subagents, use opus unless the task is simple exploration
  (haiku only for quick exploration).

## Allowed Command Classes (from CLAUDE.md)
- File ops: Write/Edit/MultiEdit/NotebookEdit
- Search: Grep/Glob/Read
- Git: git *
- Flutter/Dart: flutter *, dart *
- File system: ls/find/wc/cat/head/tail/mkdir/rm/mv/cp
- Process: pgrep/ps/kill
- Package: npm *, yarn *, pub *
