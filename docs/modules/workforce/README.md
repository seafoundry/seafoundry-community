# Workforce Module

Workforce management for members, roles, certifications, and training access.

## Entry Points
- `lib/screens/admin/workforce_screen.dart` (drawer: Workforce)
- Tabs live under `lib/widgets/admin/`.

## Key Capabilities
- Member invitations and role management.
- Role definitions and permission gating.
- Certification workflows and training gates.
- SOP administration for workforce training.

## Data and Services
- Repositories: `UserRepository`, `InvitationRepository`,
  `CertificationRepository`.
- Supporting: `RecordRepository` for cross-record lookups.
- Uses `CurrentUser` for org and user context.

## Critical Patterns
- Construct repositories with Firestore from `FirebaseService`.
- Use `ProGate`/`ScaleGate` for tiered features.
- Keep membership updates aligned with UID-based identity
  (`docs/architecture/AUTH_ARCHITECTURE.md`).
- Capture providers before dialogs as per `SafeDialogMixin`.

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Validate staffing/role flows align with training requirements and task assignment.
- Coordinate staffing manifest data with Field Work Kit workflows.

## Related Docs
- `docs/architecture/AUTH_ARCHITECTURE.md`
- `docs/architecture/firestore_collections.md`
- `lib/widgets/dialogs/components/README.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
