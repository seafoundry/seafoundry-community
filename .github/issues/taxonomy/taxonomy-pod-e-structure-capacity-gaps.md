# Taxonomy – Pod E Structure Capacity Enforcement Gaps

**Status**: 🚧 Open (2026-02-22 audit)  
**Scope**: Pod E – GraphNode & Facilities  
**Priority**: P0 — Safety/compliance regression  
**Labels**: `taxonomy`, `pod-e`, `facilities`, `capacity`, `repositories`

## Overview
`StructureCapacityService` shipped with YAML defaults covering kelp longlines, oyster racks/bags, finfish pens, and crab ponds. However, production code only enforces *coral-context* child-structure limits inside `GroupRepository`, so every non-coral rule in `config/structure_capacity.defaults.yaml` is effectively dead code. Occupant-scoped rules (`scope: occupants`) are never evaluated outside of unit tests, so stocking limits and warning thresholds for bags, pens, ponds, etc. never trigger.

## Findings

1. **Capacity checks always run as coral**  
   - `GroupRepository.previewChildCapacity` builds requests using `organismContext.kind` (`lib/repositories/inventory/group_repository.dart:163-190`).  
   - In production, `RepositoriesProvider` instantiates `GroupRepository` without overriding the context, so the default remains `OrganismKind.coral` (`lib/widgets/repositories/repositories_provider.dart:228-243`).  
   - Configured rules all specify non-coral organisms (kelp/oyster/finfish/crab). Because `StructureCapacityRequest` requires an exact organism match (`lib/services/structure_capacity_service.dart:73-114`), no rule ever matches when the repository stays in coral mode. The integration tests pass only because the harness explicitly injects an oyster context.

2. **Occupant rules partially evaluated**  
   - `HoldingRepository` now evaluates occupant rules before creating or updating holdings, but `SeededLineRepository` (move flows) and CSV import paths still bypass the checks.  
   - Prior to 2026‑03‑09, cohorts also skipped the service; this is now enforced, but additional repositories (seeded-line move helpers, cohort/holding migrations) still need the same guardrails.

## Impact
- Kelp farms can add unlimited dropper lines and seeded segments, oyster racks can exceed bag limits, and pens/ponds can be overstocked without any guardrails.  
- The YAML + override plumbing provides a false sense of safety to operations teams expecting warnings or hard stops based on the documented limits.

## Recommended Next Steps
1. **Context resolution**: When enforcing child-structure rules, derive the organism from the parent site’s `supportedOrganismKinds` (or the structure type metadata) instead of relying on the repository’s default context. Alternatively, instantiate `GroupRepository` per `OrganismContext` the same way `HoldingRepository` derivatives are registered.  
2. **Occupant enforcement**: Ensure seeded-line move helpers, CSV importers, and any remaining holding/cohort flows build `StructureCapacityRequest.forOccupants` requests before writes, surfacing warnings/errors inline with the existing `CapabilityConstraintError` UX.  
3. **Validation coverage**: Extend `RepositoryTestHarness` suites to create kelp/oyster/fish sites with mixed organism lists to prove both child-structure and occupant limits trigger regardless of organization ordering.  
4. **Docs**: Update the Pod E sections in `docs/taxonomy/taxonomy_task_list.md` once enforcement work lands so operators know which flows are guarded.

## References
- Production enforcement uses coral context: `lib/repositories/inventory/group_repository.dart:163-190`  
- Repository is created without an organism override: `lib/widgets/repositories/repositories_provider.dart:228-243`  
- Request factories demand exact organism matches: `lib/services/structure_capacity_service.dart:73-114`  
- YAML limits covering non-coral organisms: `config/structure_capacity.defaults.yaml:1-60`
- Cohort enforcement landed 2026-03-09: `lib/repositories/inventory/cohort_repository.dart`, `test/unit/repositories/cohort_repository_capacity_test.dart`
