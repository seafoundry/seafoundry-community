# Taxonomy – Pod C Sync Conflict Dashboard & Resolution

**Status**: 🚧 In Progress  
**Priority**: P1 — Offline data integrity  
**Labels**: `taxonomy`, `pod-c`, `offline`, `sync-manager`

## Overview
`SyncManager` now captures every replay conflict as a `SyncConflictEntry`, writes it to the on-device cache, and mirrors the payload to `sync_conflicts/{operationId}` in Firestore. We still lack a user-facing way to surface, filter, or resolve those entries, so conflicted operations quietly pile up until someone inspects Firestore manually. We also have no tooling to requeue/replay safe operations after the underlying record is reconciled.

## Required Work
1. **Taxonomy Admin surfacing**
   - Add a tab/card that lists `sync_conflicts` rows for the active organization with filters by `modelType`, `recordId`, date range, and status.
   - Show queued vs. server timestamps, actor metadata, and a “copy payload” button so ops can reproduce the pending write.
   - Persist “notes”/“resolution state” back to `sync_conflicts/{id}` when an entry is acknowledged.

2. **Resolution tooling**
   - CLI helper (or admin actions) that can download the queued payload, validate against the latest record, and either requeue or permanently drop it while appending resolution metadata (who resolved it, why, follow-up event id).
   - Hook into `OfflineQueue` so resolved entries don’t resurface, and provide telemetry so we can measure conflict frequency per release.

3. **Docs & Playbooks**
   - Update `docs/taxonomy/taxonomy_task_list.md` + README with operator guidance for triaging conflicts.
   - Capture example workflows (move vs. update) with suggested merge strategies so field teams know how to recover data safely.

## References
- `lib/services/sync_manager.dart`
- `lib/services/local_storage_service.dart`
- `lib/models/sync/sync_conflict_entry.dart`
- `docs/taxonomy/{README.md,taxonomy_task_list.md}`

## Verification
- Widget tests for the admin tab (pagination, filters, empty states).
- Integration test/CLI harness that creates a synthetic conflict and exercises the resolution flow.
