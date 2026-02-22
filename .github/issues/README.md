# GitHub Issues Documentation Index

Active tracking documents for work-in-progress issues. Historical/completed work is tracked in git history and WORK_LOG.md.

## Active Directories

| Category | Description | Key Documents |
|----------|-------------|---------------|
| [Architecture](./architecture/) | Dialog provider pattern fixes, record/local ID normalization, data field unification | [Dialog Provider Pattern](./architecture/dialog-provider-pattern-january-2026.md), [RecordName + LocalId Normalization](./architecture/recordname-localid-normalization.md), [Data Field Unification (SOT)](./architecture/data-field-unification-sot.md), [Internal Naming Consistency](./architecture/internal-naming-consistency.md) |
| [Release](./release/) | Release readiness audits and cross-cutting remediation tracking | [Pre-Release Audit](./release/pre-release-audit.md) |
| [Navigation](./navigation/) | Navigation and routing issues | [Grey Screen Investigation](./navigation/genetics-module-grey-screen-investigation.md) |
| [Taxonomy](./taxonomy/) | Multi-organism taxonomy issues | [Registry ID Collisions](./taxonomy/taxonomy-pod-c-registry-id-collisions.md), [Structure Capacity Gaps](./taxonomy/taxonomy-pod-e-structure-capacity-gaps.md) |

## Active Issues

### Architecture (4 files)
- **Dialog Provider Pattern** - In Progress: Fixing "Provider not found" errors in dialogs
- **RecordName + LocalId Normalization** - In Progress: Data model + CSV + UI + auth alignment
- **Data Field Unification (SOT)** - Planning: Single source of truth for ID fields, dialogs, and CSV handling
- **Internal Naming Consistency** - Planned: Enforce camelCase for in-app identifiers and serialized keys

### Release (1 file)
- **Pre-Release Audit** - Triage: Release readiness across gating, payments, workflows, tests, and refactors

### Navigation (1 file)
- **Grey Screen Investigation** - In Progress: Genetics module grey screen after navigation

### Taxonomy (3 files)
- **Registry ID Collisions** - Code fixed, migrations pending
- **Sync Conflict Dashboard** - In Progress: UI for surfacing sync conflicts
- **Structure Capacity Gaps** - P0: Capacity enforcement not working for non-coral organisms

## Related Documentation

- **Architecture Docs**: [`/docs/architecture/`](../../docs/architecture/)
- **Work Log**: [`/WORK_LOG.md`](../../WORK_LOG.md)
- **Demo Setup**: [`/docs/DEMO_RESEED.md`](../../docs/DEMO_RESEED.md)
- **Claude Instructions**: [`/.claude/CLAUDE.md`](../../.claude/CLAUDE.md)

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
