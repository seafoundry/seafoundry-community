# Workforce Module (Claude Notes)

## Guardrails
- Always resolve organization and user from `CurrentUser` state.
- Use `InvitationRepository` for invites, not ad-hoc writes.
- Role and certification UI must be behind `ProGate` or `ScaleGate` as appropriate.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Validate staffing/role flows align with training requirements and task assignment.
- Coordinate staffing manifest data with Field Work Kit workflows.

## Touchpoints
- Screen: `lib/screens/admin/workforce_screen.dart`
- Tabs: `lib/widgets/admin/members_tab.dart`,
  `lib/widgets/admin/role_definitions_tab.dart`,
  `lib/widgets/admin/certification_management_tab.dart`,
  `lib/widgets/admin/sop/sop_admin_tab.dart`

## When Updating
- Update security rules and membership schema docs for new role or invite fields.

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
