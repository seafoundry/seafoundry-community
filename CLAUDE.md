# SeaFoundry Community App

Coral restoration platform for genetics, inventory, outplanting, and inter-org transfers. Community (open-source) tier only, coral-only, web-only.

## Documentation Standard

Maintain CLAUDE.md files in each major module/subfolder. Document what a successor needs to know - key patterns, gotchas, integration points. Keep it concise.
Module docs live in `docs/modules/` with an index at `docs/modules/README.md`. Keep the list in sync with the app drawer plus non-drawer surfaces (settings, field work kit, public screens).

## Release Readiness
- Audit tracker: `.github/issues/release/pre-release-audit.md`.
- Post-audit verification: run module smoke flows and log regressions in `.github/issues/release/pre-release-audit.md`.
- Module README/CLAUDE docs should include a "Release Readiness" section with
  module-specific checks.

## Module Docs

- Index: `docs/modules/README.md`
- Organization: `docs/modules/organization/README.md`, `docs/modules/organization/CLAUDE.md`
- Inventory: `docs/modules/inventory/README.md`, `docs/modules/inventory/CLAUDE.md`
- Outplanting: `docs/modules/outplanting/README.md`, `docs/modules/outplanting/CLAUDE.md`
- Settings: `docs/modules/settings/README.md`, `docs/modules/settings/CLAUDE.md`
- Field Work Kit: `docs/modules/field_work_kit/README.md`, `docs/modules/field_work_kit/CLAUDE.md`
- Navigation: `docs/modules/navigation/README.md`, `docs/modules/navigation/CLAUDE.md`
- Permissions and Firebase: `docs/modules/permissions_firebase/README.md`, `docs/modules/permissions_firebase/CLAUDE.md`

## Architecture

- `lib/cubits/` - State management (preferred over blocs/)
- `lib/repositories/` - Firestore data access
- `lib/services/` - Business logic
- `lib/screens/` - Top-level screens
- `lib/widgets/` - Reusable components
- `lib/widgets/repositories/registry/repository_registry.dart` - Provider registry for navigation

## Critical Patterns

**Providers**: `ChangeNotifier` subclasses MUST use `ChangeNotifierProvider`, never plain `Provider` or `RepositoryProvider`.

**Dialogs**: `showDialog` creates new context without parent providers. Capture needed providers BEFORE calling `showDialog`, then re-provide them to the dialog. This includes repositories, cubits, and ChangeNotifiers. Never access `context.read<T>()` inside the dialog builder — capture it outside first.

**User Identity**: All user documents live at `/users/{uid}` (Firebase Auth UID). Never use email as a document ID. Membership subcollection: `organizations/{orgId}/members/{uid}`. The `authorUid` field (not `authorEmail`) stores the comment/post author's UID.

**Organism Record Identity** (Critical - Never Confuse These):
- `localGenetId`: The genet identifier (e.g., "ACER-001"). Maps to PID, clonalID, alias, accession. Shared by all records in the same genet. (Was `localId` prior to seafoundry_app naming-parity rename.)
- `tagId`: User-friendly distinguishing adjective (e.g., "Fluffy"). Unique per record instance. Should ALWAYS differ from localGenetId. (Was `recordName` prior to rename.)
- `outplantTagId`: Per-organism outplant tag (distinct from `tagId`). Optional. (Was the previous community `tagId` prior to rename.)
- `genetRecordId`: Foreign-key reference to a Genet document. (Was `genetId` prior to rename. Resolver class name is unchanged: `GenetIdResolver`.)
- `id` (UUID): Immutable database record ID. Display last 8 chars when "show number" toggle is on.
See `docs/modules/inventory/CLAUDE.md` for full details.

**Transfer Ownership Types**: Use `TransferOwnershipType` enum for inter-org transfers:
- `fullTransfer`: Receiver becomes owner + manager (default)
- `retainedOwnership`: Sender keeps ownership, receiver manages (custody transfer)
- `thirdPartyTransfer`: Auto-detected when `organism.ownerOrganizationId != currentOrgId`
Custody detection via `OrganismRecordEditState.isCustodian`. Custodians can edit location/quantity but NOT identity fields. See `docs/modules/inventory/CLAUDE.md` for implementation details.

**Enums over Strings**: Use `CommentTargetType.event.id` (not `'event'`), `EventType.observation.id` (not `'event_observation'`). All enums with Firestore IDs follow the `const EnumType(this.id); final String id;` pattern.

**camelCase Canonical**: In-app variable names, map keys, Firestore field names, and user-facing names must use camelCase (hard rule). No snake_case in map literals, spreadsheet column keys, or serialized data.

**snake_case Files**: File and directory names should be snake_case when creating or renaming, but internal naming consistency is the priority.

**Tiers**: This is the community-only fork. Tier handling is normalized through the `Tier` enum and targeted guards (for example `SiteLimitsService`).

**Community Tier Features**:
| Feature | Available |
|---------|-----------|
| Inventory (coral holdings, transfers, mortality) | Yes |
| Outplanting (basic outplant events) | Yes |
| Genetics (provenance, fragging) | Yes |
| CSV Import/Export (inventory, outplanting) | Yes |
| Public Holdings Map, Visual Engagement | No (removed) |
| Site limits: 1 nursery + 1 outplanting | Yes |
| Monitoring, Husbandry, Tasks, Sebastian AI, Offline Sync | No |

**Firestore Web Map Handling**: Web Firestore SDK returns nested maps as `Map<dynamic, dynamic>` due to Dart's JS type erasure. All Firestore data is normalized at `RecordFactory.recordFromJson()` using `deepNormalizeMap()` from `lib/models/utils/json_casts.dart`. This ensures all nested maps are `Map<String, dynamic>` before model parsing. DO NOT add individual `safeMapCast()` calls in model `fromJson` methods - normalization happens centrally.

**Physical Form Chain (Coral-Only)**:
The size/volume system uses a 4-level chain: `Organism Kind -> Life Stage -> Physical Form -> Size Band`.

Key components:
- `PhysicalFormRegistry` (`lib/services/physical_form_registry.dart`) — loads coral physical forms from hardcoded Dart constants in `lib/services/physical_form_data.dart` (converted from the former YAML config)
Access pattern: `organism.physicalForm?.formId` (primary).
- `GenetIdResolver` (`lib/services/genet_id_resolver.dart`) — canonical genet ID resolution: `record.genetRecordId ?? record.foreignKeys['genetRecordId']?.id`. MUST be used for all business-logic genet ID resolution. Never access `foreignKeys['genetRecordId']?.id` directly — always use `GenetIdResolver.resolve(record)`.

## Demo Seeding

Community tier only. Demo seeding is available for local development.

**Security philosophy**: Firestore rules are maximally permissive — just enough to keep organization data separate. All feature gating, tier checks, and role-based access are handled at the app layer and cloud functions, NOT in Firestore rules. The only rules-level check is org membership via `isOrgMemberOf(orgId)`.

## Version Bumping (Required for PRs)

**Every PR must increment the build number in `pubspec.yaml` before merging.**

Format: `major.minor.patch+build` (e.g., `1.1.1+13`)

```yaml
# pubspec.yaml
version: 1.1.1+14  # Increment +build for each PR
```

**Rules:**
- **Build number (+N)**: Increment for every PR (required)
- **Patch (x.x.N)**: Increment for bug fixes
- **Minor (x.N.x)**: Increment for new features (reset patch to 0)
- **Major (N.x.x)**: Increment for breaking changes (reset minor and patch to 0)

**Before creating PR:**
```bash
# Check current version
grep "^version:" pubspec.yaml

# Update version (increment build number at minimum)
# Edit pubspec.yaml manually or use sed:
# sed -i '' 's/version: 1.1.1+13/version: 1.1.1+14/' pubspec.yaml
```

## Commands

```
flutter analyze    # Run after changes
flutter test       # Full restart needed for provider changes
```

## Bug Fixing Workflow

When a bug is reported, do NOT start by trying to fix it. Follow this process:

1. **Write a failing test first** - Create a test that reproduces the bug
2. **Dispatch subagents** - Have subagents attempt fixes and prove them with passing tests
3. **Verify** - The fix is only complete when the test passes

This ensures bugs are properly understood before fixing and prevents regressions.

## Local Firebase Emulators

- Run `./dev-emulator.sh` to start emulators, seed demo data, and launch with `USE_FIREBASE_EMULATOR=true`.
- Emulator usage is opt-in via `USE_FIREBASE_EMULATOR=true` (production is default).
- Optional overrides: `FIREBASE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_PORT`, `FIREBASE_FIRESTORE_EMULATOR_PORT`, `FIREBASE_STORAGE_EMULATOR_PORT`.
