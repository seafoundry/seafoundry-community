# Taxonomy – Pod C Registry ID Collisions & Non-Determinism

**Status**: ✅ Code fix landed — migrations pending  
**Priority**: P1 — Data integrity  
**Labels**: `taxonomy`, `pod-c`, `registry`, `bug`

## Summary
- `EnvironmentalThreshold.fromMap` and `HusbandryScheduleEntry.fromMap` synthesize IDs (`organismKind_metric` / `organismKind_title`) whenever YAML rows omit an explicit `id`. Those fallbacks ignore `lifeStage`, so defining multiple stage-specific limits/tasks for the same metric/title causes every subsequent entry to overwrite the previous one inside their registries, Firestore overrides, and Supabase sync payloads.
- `MortalityCauseEntry._fallbackId` concatenates `organismKind` with `map.hashCode`, which is nondeterministic across process runs. Simply reloading YAML generates different IDs, preventing deduplication and producing noisy diffs in synced configs.

## Impact
- Stage-specific thresholds/schedules silently disappear, leaving Pods D/E without the configuration they expect and invalidating monitoring alerts.
- Mortality causes churn on every sync, making it impossible to reference a stable ID from workflows or analytics.

## Tasks
1. ✅ Derive deterministic fallback IDs that include the distinguishing dimensions (organism kind + metric/title + lifeStage + severity as needed).  
   - `lib/models/environment/environmental_threshold.dart`, `lib/models/husbandry/husbandry_schedule_entry.dart`, `lib/models/mortality/mortality_cause_entry.dart`
2. ✅ Add unit coverage proving multiple life-stage entries coexist and repeated YAML loads keep IDs stable.  
   - `test/unit/services/environmental_threshold_service_test.dart`, `test/unit/services/husbandry_schedule_service_test.dart`, `test/unit/models/mortality_cause_entry_test.dart`
3. ⏳ Write and run a Firestore/Supabase migration to rename existing documents to the new IDs and update any references/logs.  
   - Script available: `node scripts/migrate_registry_ids.js` (`--dry-run` supported). Execute per environment and rerun `npm run sync:taxonomy-configs` afterward.
4. ✅ Document the migration + new ID scheme in `docs/taxonomy/taxonomy_work_log.md` and the admin runbooks (see 2026-03-06c entry + task list updates).

## References
- `lib/models/environment/environmental_threshold.dart`
- `lib/models/husbandry/husbandry_schedule_entry.dart`
- `lib/models/mortality/mortality_cause_entry.dart`
- `docs/taxonomy/taxonomy_work_log.md` (2026-03-06b entry)
- `docs/taxonomy/taxonomy_task_list.md` (new Pod C tasks)
