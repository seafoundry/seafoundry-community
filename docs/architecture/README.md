# SeaFoundry Architecture Documentation

This directory contains essential architectural reference documents for the SeaFoundry platform.

**Last Updated**: 2026-01-16

## Core Architecture

| Document | Description |
|----------|-------------|
| [firestore_collections.md](firestore_collections.md) | Firestore collection schemas, nested vs root, demo mode behavior |
| [event_field_conventions.md](event_field_conventions.md) | Event model field naming and structure standards |
| [graph_node_system.md](graph_node_system.md) | Hierarchical graph node system for inventory navigation |
| [identity_scheme.md](identity_scheme.md) | Email-based user identity scheme and migration notes |
| [AUTH_ARCHITECTURE.md](AUTH_ARCHITECTURE.md) | Firebase Auth + Firestore security rules patterns |

## Feature Architecture

| Document | Description |
|----------|-------------|
| [MANAGEMENT_DIALOG_ARCHITECTURE.md](MANAGEMENT_DIALOG_ARCHITECTURE.md) | Management dialog pattern with mode enum delegation |
| [EVENT_STREAM_PAGINATION.md](EVENT_STREAM_PAGINATION.md) | Event stream limits and pagination strategy |
| [sebastian_ai.md](sebastian_ai.md) | Sebastian AI assistant architecture (Gemini integration) |
| [taxonomy/README.md](taxonomy/README.md) | Multi-organism taxonomy architecture and five-axis model |

## Tier Strategy

| Document | Description |
|----------|-------------|
| [community_vs_pro_rfc.md](community_vs_pro_rfc.md) | RFC for Community/Pro/Scale tier strategy, entitlements, CI/CD |

## Related Documentation

- **Module docs**: `docs/modules/README.md`
- **Test Helpers**: `test/helpers/README.md`
- **Dialog Safety Patterns**: `lib/widgets/dialogs/components/README.md`
- **CSV Schema**: `docs/csv/csv_v2_migration.md`
- **Work Log**: `WORK_LOG.md`
- **TODO**: `TODO.md`

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
