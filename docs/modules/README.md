# Module Documentation Index

This directory contains module-level README and CLAUDE docs.
Community tier only, coral-only, web-only.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Each module README/CLAUDE file should include a "Release Readiness" section
  for module-specific checks.

## Administration
- Organization: [README](organization/README.md) | [CLAUDE](organization/CLAUDE.md)

## Core Modules
- Inventory: [README](inventory/README.md) | [CLAUDE](inventory/CLAUDE.md)
- Outplanting: [README](outplanting/README.md) | [CLAUDE](outplanting/CLAUDE.md)

## Additional Screens
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
