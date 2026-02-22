# Module Documentation Index

This directory contains module-level README and CLAUDE docs.
Keep it in sync with drawer modules in `lib/widgets/app_drawer.dart` and
`lib/widgets/community_app_drawer.dart`, plus cross-cutting surfaces like
community feed, settings, field work kit, and public screens.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Each module README/CLAUDE file should include a "Release Readiness" section
  for module-specific checks.

## Administration
- Organization: [README](organization/README.md) | [CLAUDE](organization/CLAUDE.md)
- Workforce: [README](workforce/README.md) | [CLAUDE](workforce/CLAUDE.md)
- Reporting: [README](reporting/README.md) | [CLAUDE](reporting/CLAUDE.md)

## Core Modules
- Inventory: [README](inventory/README.md) | [CLAUDE](inventory/CLAUDE.md)
- Genetics: [README](genetics/README.md) | [CLAUDE](genetics/CLAUDE.md)
- Outplanting: [README](outplanting/README.md) | [CLAUDE](outplanting/CLAUDE.md)
- Monitoring: [README](monitoring/README.md) | [CLAUDE](monitoring/CLAUDE.md)

## Pro and Scale Modules
- Husbandry and Observations: [README](husbandry/README.md) | [CLAUDE](husbandry/CLAUDE.md)
- Operations Hub: [README](operations/README.md) | [CLAUDE](operations/CLAUDE.md)
- Training Library: [README](training/README.md) | [CLAUDE](training/CLAUDE.md)
- SOP Builder: [README](sop_builder/README.md) | [CLAUDE](sop_builder/CLAUDE.md)
- Sebastian AI: [README](sebastian_ai/README.md) | [CLAUDE](sebastian_ai/CLAUDE.md)
- Sync Conflicts: [README](sync_conflicts/README.md) | [CLAUDE](sync_conflicts/CLAUDE.md)

## Additional Screens
- Community Feed: [README](community_feed/README.md) | [CLAUDE](community_feed/CLAUDE.md)
- Settings: [README](settings/README.md) | [CLAUDE](settings/CLAUDE.md)
- Field Work Kit: [README](field_work_kit/README.md) | [CLAUDE](field_work_kit/CLAUDE.md)
- Public Screens: [README](public/README.md) | [CLAUDE](public/CLAUDE.md)

## Platform
- Navigation: [README](navigation/README.md) | [CLAUDE](navigation/CLAUDE.md)
- Permissions and Firebase: [README](permissions_firebase/README.md) | [CLAUDE](permissions_firebase/CLAUDE.md)

## Related References
- Architecture index: `docs/architecture/README.md`
- Dialog safety: `lib/widgets/dialogs/components/README.md`
- Tour system: `lib/widgets/tour/README.md`
- API guide: `docs/api/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
