# Deliverable Dialog Decomposition - Implementation Plan

## Overview

This document provides a comprehensive implementation plan for refactoring the deliverable dialog components to eliminate dual state management, convert StatefulWidgets to StatelessWidgets, and improve overall code quality.

## Dependency Graph

```
                    ┌─────────────────────────────────┐
                    │  1. Draft State Models (NEW)    │
                    │  - SpeciesTargetDraftState      │
                    │  - SiteAllocationDraftState     │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  2. DeliverableFormState        │
                    │  (Add draft lists to state)     │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  3. DeliverableFormCubit        │
                    │  (Add draft CRUD methods)       │
                    └────────────────┬────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         │                           │                           │
         ▼                           ▼                           ▼
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│  4a. Species       │   │  4b. Site          │   │  4c. Form          │
│  Targets Section   │   │  Allocations Sect  │   │  Controllers       │
│  (StatelessWidget) │   │  (StatelessWidget) │   │  (Remove drafts)   │
└────────────────────┘   └────────────────────┘   └────────────────────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  5. DeliverableFormContent      │
                    │  (Remove cubit param)           │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │  6. DeliverableCreateEditDialog │
                    │  (Remove _syncDraftsToCubit)    │
                    └─────────────────────────────────┘
```

## Work Streams

### Stream 1: Foundation (Must Complete First)
- **1.1** Create immutable draft state models
- **1.2** Add draft lists to DeliverableFormState
- **1.3** Add draft CRUD methods to cubit

### Stream 2: Section Widget Conversion (Parallel After Stream 1)
- **2a.1** Convert DeliverableSpeciesTargetsSection to StatelessWidget
- **2a.2** Convert DeliverableSiteAllocationsSection to StatelessWidget

### Stream 3: Cleanup (After Stream 2)
- **3.1** Remove draft lists from DeliverableFormControllers
- **3.2** Remove _syncDraftsToCubit from dialog
- **3.3** Remove cubit parameter from DeliverableFormContent
- **3.4** Fix duplicate exports

### Stream 4: Medium Priority (Independent)
- **4.1** Fix DropdownButtonFormField value binding
- **4.2** Fix funder deselect to clear fields
- **4.3** Load species in cubit (optional state split)

### Stream 5: Low Priority (Independent)
- **5.1** Extract common section components
- **5.2** Remove unused getter

---

## HIGH PRIORITY FIXES

### 1. Create Immutable Draft State Models

**New File:** `lib/cubits/deliverable_form/draft_state_models.dart`

```dart
// @tier: pro
part of 'deliverable_form_cubit.dart';

/// Immutable representation of a species target draft for form state.
///
/// Unlike [SpeciesTargetDraft] which holds mutable controllers, this is
/// an immutable data class suitable for inclusion in cubit state.
class SpeciesTargetDraftState extends Equatable {
  const SpeciesTargetDraftState({
    this.speciesId,
    this.targetCount,
  });

  factory SpeciesTargetDraftState.fromTarget(SpeciesTarget target) {
    return SpeciesTargetDraftState(
      speciesId: target.speciesId,
      targetCount: target.targetCount,
    );
  }

  final String? speciesId;
  final int? targetCount;

  SpeciesTargetDraftState copyWith({
    String? speciesId,
    bool clearSpeciesId = false,
    int? targetCount,
    bool clearTargetCount = false,
  }) {
    return SpeciesTargetDraftState(
      speciesId: clearSpeciesId ? null : (speciesId ?? this.speciesId),
      targetCount: clearTargetCount ? null : (targetCount ?? this.targetCount),
    );
  }

  /// Convert to immutable [SpeciesTarget] model.
  /// Returns null if speciesId is empty or target count is invalid.
  SpeciesTarget? toTarget(List<Species> options) {
    final id = speciesId?.trim();
    if (id == null || id.isEmpty) return null;
    if (targetCount == null || targetCount! <= 0) return null;

    Species? species;
    for (final option in options) {
      if (option.id == id) {
        species = option;
        break;
      }
    }
    species ??= SpeciesRegistry.globalById(id);
    final name = species?.name ?? id;

    return SpeciesTarget(
      speciesId: id,
      speciesName: name,
      targetCount: targetCount!,
    );
  }

  @override
  List<Object?> get props => [speciesId, targetCount];
}

/// Immutable representation of a site allocation draft for form state.
class SiteAllocationDraftState extends Equatable {
  const SiteAllocationDraftState({
    this.siteId,
    this.targetCount,
  });

  factory SiteAllocationDraftState.fromAllocation(SiteAllocation allocation) {
    return SiteAllocationDraftState(
      siteId: allocation.siteId,
      targetCount: allocation.targetCount,
    );
  }

  final String? siteId;
  final int? targetCount;

  SiteAllocationDraftState copyWith({
    String? siteId,
    bool clearSiteId = false,
    int? targetCount,
    bool clearTargetCount = false,
  }) {
    return SiteAllocationDraftState(
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      targetCount: clearTargetCount ? null : (targetCount ?? this.targetCount),
    );
  }

  /// Convert to immutable [SiteAllocation] model.
  /// Returns null if siteId is empty or target count is invalid.
  SiteAllocation? toAllocation(List<Site> sites) {
    final id = siteId?.trim();
    if (id == null || id.isEmpty) return null;
    if (targetCount == null || targetCount! <= 0) return null;

    Site? site;
    for (final option in sites) {
      if (option.id == id) {
        site = option;
        break;
      }
    }
    final name = site?.name ?? id;

    return SiteAllocation(
      siteId: id,
      siteName: name,
      targetCount: targetCount!,
    );
  }

  @override
  List<Object?> get props => [siteId, targetCount];
}
```

### 2. Update DeliverableFormState

**File:** `lib/cubits/deliverable_form/deliverable_form_state.dart`

**Changes:**
1. Add `speciesTargetDrafts` and `siteAllocationDrafts` lists
2. Add `availableSpecies` for species registry data
3. Update `fromDeliverable` factory to populate drafts
4. Update `copyWith` with new fields

```dart
// Add to DeliverableFormState class:

// Draft lists for form editing
final List<SpeciesTargetDraftState> speciesTargetDrafts;
final List<SiteAllocationDraftState> siteAllocationDrafts;

// Species options (loaded from registry)
final List<Species> availableSpecies;

// Update constructor to include:
this.speciesTargetDrafts = const [],
this.siteAllocationDrafts = const [],
this.availableSpecies = const [],

// Update fromDeliverable factory:
factory DeliverableFormState.fromDeliverable(Deliverable deliverable) {
  // ... existing code ...
  return DeliverableFormState(
    // ... existing fields ...
    speciesTargetDrafts: deliverable.speciesTargets
        .map(SpeciesTargetDraftState.fromTarget)
        .toList(),
    siteAllocationDrafts: deliverable.siteAllocations
        .map(SiteAllocationDraftState.fromAllocation)
        .toList(),
  );
}

// Update copyWith:
List<SpeciesTargetDraftState>? speciesTargetDrafts,
List<SiteAllocationDraftState>? siteAllocationDrafts,
List<Species>? availableSpecies,

// In copyWith body:
speciesTargetDrafts: speciesTargetDrafts ?? this.speciesTargetDrafts,
siteAllocationDrafts: siteAllocationDrafts ?? this.siteAllocationDrafts,
availableSpecies: availableSpecies ?? this.availableSpecies,

// Update props:
speciesTargetDrafts,
siteAllocationDrafts,
availableSpecies,
```

### 3. Add Draft CRUD Methods to Cubit

**File:** `lib/cubits/deliverable_form/deliverable_form_field_updates.dart`

**Add these methods to the mixin:**

```dart
// ---------------------------------------------------------------------------
// Species Target Draft Operations
// ---------------------------------------------------------------------------

void addSpeciesTargetDraft() {
  final updated = List<SpeciesTargetDraftState>.from(state.speciesTargetDrafts)
    ..add(const SpeciesTargetDraftState());
  emit(state.copyWith(speciesTargetDrafts: updated, clearErrorMessage: true));
}

void removeSpeciesTargetDraft(int index) {
  if (index < 0 || index >= state.speciesTargetDrafts.length) return;
  final updated = List<SpeciesTargetDraftState>.from(state.speciesTargetDrafts)
    ..removeAt(index);
  emit(state.copyWith(speciesTargetDrafts: updated, clearErrorMessage: true));
}

void updateSpeciesTargetDraftSpecies(int index, String? speciesId) {
  if (index < 0 || index >= state.speciesTargetDrafts.length) return;
  final updated = List<SpeciesTargetDraftState>.from(state.speciesTargetDrafts);
  updated[index] = updated[index].copyWith(
    speciesId: speciesId,
    clearSpeciesId: speciesId == null,
  );
  emit(state.copyWith(speciesTargetDrafts: updated, clearErrorMessage: true));
}

void updateSpeciesTargetDraftCount(int index, int? count) {
  if (index < 0 || index >= state.speciesTargetDrafts.length) return;
  final updated = List<SpeciesTargetDraftState>.from(state.speciesTargetDrafts);
  updated[index] = updated[index].copyWith(
    targetCount: count,
    clearTargetCount: count == null,
  );
  emit(state.copyWith(speciesTargetDrafts: updated, clearErrorMessage: true));
}

// ---------------------------------------------------------------------------
// Site Allocation Draft Operations
// ---------------------------------------------------------------------------

void addSiteAllocationDraft() {
  final updated = List<SiteAllocationDraftState>.from(state.siteAllocationDrafts)
    ..add(const SiteAllocationDraftState());
  emit(state.copyWith(siteAllocationDrafts: updated, clearErrorMessage: true));
}

void removeSiteAllocationDraft(int index) {
  if (index < 0 || index >= state.siteAllocationDrafts.length) return;
  final updated = List<SiteAllocationDraftState>.from(state.siteAllocationDrafts)
    ..removeAt(index);
  emit(state.copyWith(siteAllocationDrafts: updated, clearErrorMessage: true));
}

void updateSiteAllocationDraftSite(int index, String? siteId) {
  if (index < 0 || index >= state.siteAllocationDrafts.length) return;
  final updated = List<SiteAllocationDraftState>.from(state.siteAllocationDrafts);
  updated[index] = updated[index].copyWith(
    siteId: siteId,
    clearSiteId: siteId == null,
  );
  // Also add to selected sites if a site was selected
  Set<String>? updatedSites;
  if (siteId != null) {
    updatedSites = Set<String>.from(state.selectedSiteIds)..add(siteId);
  }
  emit(state.copyWith(
    siteAllocationDrafts: updated,
    selectedSiteIds: updatedSites,
    clearErrorMessage: true,
  ));
}

void updateSiteAllocationDraftTarget(int index, int? target) {
  if (index < 0 || index >= state.siteAllocationDrafts.length) return;
  final updated = List<SiteAllocationDraftState>.from(state.siteAllocationDrafts);
  updated[index] = updated[index].copyWith(
    targetCount: target,
    clearTargetCount: target == null,
  );
  emit(state.copyWith(siteAllocationDrafts: updated, clearErrorMessage: true));
}
```

### 4. Update Cubit to Build Final Models from Drafts

**File:** `lib/cubits/deliverable_form/deliverable_form_cubit.dart`

**Update `_buildDeliverable` method:**

```dart
Deliverable _buildDeliverable() {
  // ... existing code ...

  // Build species targets from drafts
  final speciesTargets = state.speciesTargetDrafts
      .map((draft) => draft.toTarget(state.availableSpecies))
      .whereType<SpeciesTarget>()
      .toList();

  // Build site allocations from drafts
  final siteAllocations = state.siteAllocationDrafts
      .map((draft) => draft.toAllocation(state.availableSites))
      .whereType<SiteAllocation>()
      .toList();

  return Deliverable(
    // ... existing fields ...
    speciesTargets: speciesTargets,
    siteAllocations: siteAllocations,
    // ... rest of fields ...
  );
}
```

**Add species loading to `initialize`:**

```dart
Future<void> initialize() async {
  // Load species synchronously from registry
  final species = SpeciesRegistry.globalAll();
  emit(state.copyWith(availableSpecies: species));

  await Future.wait([
    _loadMembers(),
    _loadSites(),
    _loadFunders(),
  ]);
}
```

### 5. Convert DeliverableSpeciesTargetsSection to StatelessWidget

**File:** `lib/widgets/dialogs/deliverable/deliverable_species_targets_section.dart`

```dart
// @tier: pro
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/deliverable_form/deliverable_form_cubit.dart';

/// Section widget for managing species targets in the deliverable form.
///
/// Displays a list of species target drafts with add/remove functionality.
/// Uses BlocBuilder to react to cubit state changes.
class DeliverableSpeciesTargetsSection extends StatelessWidget {
  const DeliverableSpeciesTargetsSection({
    super.key,
    required this.disabled,
  });

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliverableFormCubit, DeliverableFormState>(
      buildWhen: (prev, curr) =>
          prev.speciesTargetDrafts != curr.speciesTargetDrafts ||
          prev.availableSpecies != curr.availableSpecies,
      builder: (context, state) {
        final cubit = context.read<DeliverableFormCubit>();
        final speciesOptions = state.availableSpecies;
        final canAdd = !disabled && speciesOptions.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Species Targets',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (speciesOptions.isEmpty)
              const Text('No species available for targeting.'),
            if (state.speciesTargetDrafts.isEmpty)
              Text(
                'No species targets added.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                children: state.speciesTargetDrafts
                    .asMap()
                    .entries
                    .map((entry) => _SpeciesTargetRow(
                          index: entry.key,
                          draft: entry.value,
                          speciesOptions: speciesOptions,
                          disabled: disabled,
                          onSpeciesChanged: (speciesId) =>
                              cubit.updateSpeciesTargetDraftSpecies(
                                  entry.key, speciesId),
                          onTargetChanged: (count) =>
                              cubit.updateSpeciesTargetDraftCount(
                                  entry.key, count),
                          onRemove: () =>
                              cubit.removeSpeciesTargetDraft(entry.key),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: canAdd ? cubit.addSpeciesTargetDraft : null,
              icon: const Icon(Icons.add),
              label: const Text('Add species target'),
            ),
          ],
        );
      },
    );
  }
}

class _SpeciesTargetRow extends StatelessWidget {
  const _SpeciesTargetRow({
    required this.index,
    required this.draft,
    required this.speciesOptions,
    required this.disabled,
    required this.onSpeciesChanged,
    required this.onTargetChanged,
    required this.onRemove,
  });

  final int index;
  final SpeciesTargetDraftState draft;
  final List<Species> speciesOptions;
  final bool disabled;
  final ValueChanged<String?> onSpeciesChanged;
  final ValueChanged<int?> onTargetChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedId = speciesOptions.any((s) => s.id == draft.speciesId)
        ? draft.speciesId
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedId,
              decoration: const InputDecoration(labelText: 'Species'),
              items: speciesOptions
                  .map((species) => DropdownMenuItem<String>(
                        value: species.id,
                        child: Text('${species.code} - ${species.name}'),
                      ))
                  .toList(),
              onChanged: disabled ? null : onSpeciesChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: draft.targetCount?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Target'),
              keyboardType: TextInputType.number,
              enabled: !disabled,
              onChanged: (value) => onTargetChanged(int.tryParse(value)),
            ),
          ),
          IconButton(
            onPressed: disabled ? null : onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
```

### 6. Convert DeliverableSiteAllocationsSection to StatelessWidget

**File:** `lib/widgets/dialogs/deliverable/deliverable_site_allocations_section.dart`

```dart
// @tier: pro
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/deliverable_form/deliverable_form_cubit.dart';
import 'package:seafoundry_app/models/extensions/site_type_extensions.dart';
import 'package:seafoundry_app/models/site.dart';

/// Section widget for managing site allocations in the deliverable form.
///
/// Displays a list of site allocation drafts with add/remove functionality.
/// Uses BlocBuilder to react to cubit state changes.
class DeliverableSiteAllocationsSection extends StatelessWidget {
  const DeliverableSiteAllocationsSection({
    super.key,
    required this.disabled,
  });

  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeliverableFormCubit, DeliverableFormState>(
      buildWhen: (prev, curr) =>
          prev.siteAllocationDrafts != curr.siteAllocationDrafts ||
          prev.availableSites != curr.availableSites ||
          prev.sitesLoading != curr.sitesLoading ||
          prev.siteLoadError != curr.siteLoadError,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Allocations',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildContent(context, state),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, DeliverableFormState state) {
    if (state.sitesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (state.siteLoadError != null) {
      return Text(
        state.siteLoadError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final availableSites = state.availableSites.deliverableTargetSites.toList();

    if (availableSites.isEmpty) {
      return const Text('No sites available for allocation.');
    }

    final cubit = context.read<DeliverableFormCubit>();

    return Column(
      children: [
        if (state.siteAllocationDrafts.isEmpty)
          Text(
            'No site allocations added.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Column(
            children: state.siteAllocationDrafts
                .asMap()
                .entries
                .map((entry) => _SiteAllocationRow(
                      index: entry.key,
                      draft: entry.value,
                      availableSites: availableSites,
                      disabled: disabled,
                      onSiteChanged: (siteId) =>
                          cubit.updateSiteAllocationDraftSite(entry.key, siteId),
                      onTargetChanged: (target) =>
                          cubit.updateSiteAllocationDraftTarget(entry.key, target),
                      onRemove: () =>
                          cubit.removeSiteAllocationDraft(entry.key),
                    ))
                .toList(),
          ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: disabled ? null : cubit.addSiteAllocationDraft,
          icon: const Icon(Icons.add),
          label: const Text('Add site allocation'),
        ),
      ],
    );
  }
}

class _SiteAllocationRow extends StatelessWidget {
  const _SiteAllocationRow({
    required this.index,
    required this.draft,
    required this.availableSites,
    required this.disabled,
    required this.onSiteChanged,
    required this.onTargetChanged,
    required this.onRemove,
  });

  final int index;
  final SiteAllocationDraftState draft;
  final List<Site> availableSites;
  final bool disabled;
  final ValueChanged<String?> onSiteChanged;
  final ValueChanged<int?> onTargetChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selectedId = availableSites.any((s) => s.id == draft.siteId)
        ? draft.siteId
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selectedId,
              decoration: const InputDecoration(labelText: 'Site'),
              items: availableSites
                  .map((site) => DropdownMenuItem<String>(
                        value: site.id,
                        child: Text(site.name),
                      ))
                  .toList(),
              onChanged: disabled ? null : onSiteChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: draft.targetCount?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Target'),
              keyboardType: TextInputType.number,
              enabled: !disabled,
              onChanged: (value) => onTargetChanged(int.tryParse(value)),
            ),
          ),
          IconButton(
            onPressed: disabled ? null : onRemove,
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
```

### 7. Update DeliverableFormControllers

**File:** `lib/widgets/dialogs/deliverable/deliverable_form_controllers.dart`

**Remove draft lists and related methods:**

```dart
// @tier: pro
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// Manages TextEditingControllers for the deliverable form.
///
/// This encapsulates the controllers required by form text fields, separating
/// them from the main dialog widget for better organization.
///
/// Note: Draft lists for species targets and site allocations have been moved
/// to [DeliverableFormState] and are managed via the cubit.
class DeliverableFormControllers {
  DeliverableFormControllers({
    Deliverable? deliverable,
    String? permitId,
  }) {
    _initControllers(deliverable, permitId);
  }

  late final TextEditingController permitIdController;
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late final TextEditingController requiredSitesController;
  late final TextEditingController progressController;
  late final TextEditingController funderNameController;
  late final TextEditingController funderContactNameController;
  late final TextEditingController funderContactEmailController;
  late final TextEditingController grantNumberController;
  late final TextEditingController totalTargetController;
  late final TextEditingController genetTargetController;

  void _initControllers(Deliverable? d, String? permitId) {
    permitIdController = TextEditingController(
      text: d?.permitId ?? permitId ?? '',
    );
    nameController = TextEditingController(text: d?.name ?? '');
    descriptionController = TextEditingController(text: d?.description ?? '');
    requiredSitesController = TextEditingController(
      text: d?.requiredSiteIds.join(', ') ?? '',
    );
    progressController = TextEditingController(
      text: d?.progressPercent.toString() ?? '0',
    );
    funderNameController = TextEditingController(text: d?.funderName ?? '');
    funderContactNameController = TextEditingController(
      text: d?.funderContactName ?? '',
    );
    funderContactEmailController = TextEditingController(
      text: d?.funderContactEmail ?? '',
    );
    grantNumberController = TextEditingController(text: d?.grantNumber ?? '');
    totalTargetController = TextEditingController(
      text: d?.totalOrganismTarget?.toString() ?? '',
    );
    genetTargetController = TextEditingController(
      text: d?.genetDiversityTarget?.toString() ?? '',
    );
  }

  void dispose() {
    permitIdController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    requiredSitesController.dispose();
    progressController.dispose();
    funderNameController.dispose();
    funderContactNameController.dispose();
    funderContactEmailController.dispose();
    grantNumberController.dispose();
    totalTargetController.dispose();
    genetTargetController.dispose();
  }
}
```

### 8. Update DeliverableFormContent

**File:** `lib/widgets/dialogs/deliverable/deliverable_form_content.dart`

**Remove cubit parameter and onChanged callback:**

```dart
// @tier: pro
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/deliverable_form/deliverable_form_cubit.dart';
import 'package:seafoundry_app/widgets/dialogs/components/dialog_message_box.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_assignees_section.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_basic_fields_section.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_form_controllers.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_funder_section.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_site_allocations_section.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_site_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_species_targets_section.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_target_section.dart';

/// Content area of the deliverable form.
///
/// Composes all the form section widgets into a scrollable column.
/// Accesses the cubit via context.read when needed for callbacks.
class DeliverableFormContent extends StatelessWidget {
  const DeliverableFormContent({
    super.key,
    required this.controllers,
    required this.state,
    required this.organizationId,
    required this.isLoading,
  });

  final DeliverableFormControllers controllers;
  final DeliverableFormState state;
  final String organizationId;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DeliverableFormCubit>();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.errorMessage != null)
            DialogMessageBox.error(state.errorMessage!),
          DeliverableBasicFieldsSection(
            disabled: isLoading,
            permitIdController: controllers.permitIdController,
            nameController: controllers.nameController,
            descriptionController: controllers.descriptionController,
          ),
          const SizedBox(height: 16),
          DeliverableFunderSection(
            disabled: isLoading,
            funderNameController: controllers.funderNameController,
            funderContactNameController: controllers.funderContactNameController,
            funderContactEmailController: controllers.funderContactEmailController,
            grantNumberController: controllers.grantNumberController,
          ),
          const SizedBox(height: 16),
          DeliverableTargetSection(
            disabled: isLoading,
            totalTargetController: controllers.totalTargetController,
            genetTargetController: controllers.genetTargetController,
          ),
          const SizedBox(height: 16),
          const Text('Sites', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DeliverableSiteSelector(
            disabled: isLoading,
            availableSites: state.availableSites,
            selectedSiteIds: state.selectedSiteIds,
            manualSitesController: controllers.requiredSitesController,
            siteLoadError: state.siteLoadError,
            sitesLoading: state.sitesLoading,
            onSiteToggled: cubit.toggleSite,
          ),
          const SizedBox(height: 16),
          DeliverableSpeciesTargetsSection(disabled: isLoading),
          const SizedBox(height: 16),
          DeliverableSiteAllocationsSection(disabled: isLoading),
          const SizedBox(height: 16),
          DeliverableAssigneesSection(disabled: isLoading),
          const SizedBox(height: 16),
          _ProgressField(
            controller: controllers.progressController,
            isLoading: isLoading,
            onChanged: cubit.updateProgress,
          ),
        ],
      ),
    );
  }
}

class _ProgressField extends StatelessWidget {
  const _ProgressField({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Progress (%)'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: !isLoading,
      onChanged: (value) {
        final progress = double.tryParse(value) ?? 0.0;
        onChanged(progress);
      },
    );
  }
}
```

### 9. Update DeliverableCreateEditDialog

**File:** `lib/widgets/dialogs/deliverable/deliverable_create_edit_dialog.dart`

**Remove _syncDraftsToCubit and update form content call:**

```dart
// @tier: pro
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/deliverable_form/deliverable_form_cubit.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';
import 'package:seafoundry_app/repositories/deliverable_repository.dart';
import 'package:seafoundry_app/repositories/funder_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/user_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_form_content.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_form_controllers.dart';
import 'package:seafoundry_app/widgets/dialogs/deliverable/deliverable_management_result.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Dialog for creating or editing a deliverable.
class DeliverableCreateEditDialog extends StatefulWidget {
  const DeliverableCreateEditDialog({
    super.key,
    required this.organizationId,
    required this.userId,
    required this.isEdit,
    this.deliverable,
    this.permitId,
    this.onUpdated,
  });

  final String organizationId;
  final String userId;
  final bool isEdit;
  final Deliverable? deliverable;
  final String? permitId;
  final VoidCallback? onUpdated;

  @override
  State<DeliverableCreateEditDialog> createState() =>
      _DeliverableCreateEditDialogState();
}

class _DeliverableCreateEditDialogState
    extends State<DeliverableCreateEditDialog>
    with SafeDialogMixin<DeliverableCreateEditDialog> {
  late final DeliverableFormControllers _controllers;
  late DeliverableFormCubit _formCubit;
  bool _cubitInitialized = false;

  @override
  void initState() {
    super.initState();
    _controllers = DeliverableFormControllers(
      deliverable: widget.deliverable,
      permitId: widget.permitId,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cubitInitialized) {
      _cubitInitialized = true;
      _formCubit = DeliverableFormCubit(
        deliverableRepository: context.read<DeliverableRepository>(),
        userRepository: context.read<UserRepository>(),
        siteRepository: context.maybeRead<SiteRepository>(),
        funderRepository: context.maybeRead<FunderRepository>(),
        organizationId: widget.organizationId,
        userId: widget.userId,
        deliverable: widget.deliverable,
        permitId: widget.permitId,
      );
      _formCubit.initialize();
    }
  }

  @override
  void dispose() {
    _controllers.dispose();
    _formCubit.close();
    super.dispose();
  }

  Future<void> _save() async {
    final progress =
        double.tryParse(_controllers.progressController.text) ?? 0.0;
    _formCubit.updateProgress(progress);
    _formCubit.updateManualSiteIds(_controllers.requiredSitesController.text);

    final deliverable = await _formCubit.submit();
    if (deliverable != null && mounted) {
      widget.onUpdated?.call();
      popDialog(
        DeliverableManagementResult(
          createdDeliverable: widget.isEdit ? null : deliverable,
          updatedDeliverable: widget.isEdit ? deliverable : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _formCubit,
      child: BlocBuilder<DeliverableFormCubit, DeliverableFormState>(
        builder: (context, state) {
          final isLoading = state.isSubmitting;

          return AlertDialog(
            title: Text(
              widget.isEdit ? 'Edit Deliverable' : 'Create Deliverable',
            ),
            content: DeliverableFormContent(
              controllers: _controllers,
              state: state,
              organizationId: widget.organizationId,
              isLoading: isLoading,
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => popDialog(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : _save,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEdit ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

## MEDIUM PRIORITY FIXES

### 10. Fix DropdownButtonFormField Value Binding

**Files:** `deliverable_funder_section.dart`, `deliverable_species_targets_section.dart`, `deliverable_site_allocations_section.dart`

Change all `initialValue:` to `value:` in DropdownButtonFormField widgets:

```dart
// BEFORE:
DropdownButtonFormField<String>(
  initialValue: selectedId,
  ...
)

// AFTER:
DropdownButtonFormField<String>(
  value: selectedId,
  ...
)
```

### 11. Fix Funder Deselect to Clear Fields

**File:** `lib/cubits/deliverable_form/deliverable_form_field_updates.dart`

**Update `selectFunder` method:**

```dart
void selectFunder(String? funderId) {
  if (funderId == null) {
    // Clear funder fields when deselected
    emit(state.copyWith(
      clearSelectedFunderId: true,
      funderName: '',
      funderContactName: '',
      funderContactEmail: '',
      clearErrorMessage: true,
    ));
  } else {
    emit(state.copyWith(selectedFunderId: funderId, clearErrorMessage: true));
  }
}
```

### 12. Remove Duplicate Export

**File:** `lib/widgets/dialogs/deliverable/deliverable_species_targets_section.dart`

**Remove line 7:**
```dart
// DELETE THIS LINE:
export 'package:seafoundry_app/widgets/dialogs/deliverable/species_target_draft.dart';
```

**Similarly in:** `deliverable_site_allocations_section.dart` remove line 7.

---

## LOW PRIORITY FIXES

### 13. Extract Common Section Components

**New File:** `lib/widgets/dialogs/deliverable/components/section_loading_indicator.dart`

```dart
// @tier: pro
import 'package:flutter/material.dart';

/// Standard loading indicator for deliverable form sections.
class SectionLoadingIndicator extends StatelessWidget {
  const SectionLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: LinearProgressIndicator(),
    );
  }
}
```

**New File:** `lib/widgets/dialogs/deliverable/components/section_empty_state.dart`

```dart
// @tier: pro
import 'package:flutter/material.dart';

/// Standard empty state text for deliverable form sections.
class SectionEmptyState extends StatelessWidget {
  const SectionEmptyState({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
```

**New File:** `lib/widgets/dialogs/deliverable/components/section_error_text.dart`

```dart
// @tier: pro
import 'package:flutter/material.dart';

/// Standard error text for deliverable form sections.
class SectionErrorText extends StatelessWidget {
  const SectionErrorText({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
```

### 14. Delete Deprecated Draft Classes (After Migration)

Once the migration is complete and tested, delete:
- `lib/widgets/dialogs/deliverable/species_target_draft.dart`
- `lib/widgets/dialogs/deliverable/site_allocation_draft.dart`

Update barrel file to remove exports:
```dart
// DELETE these lines from deliverable_dialogs.dart:
export 'site_allocation_draft.dart';
export 'species_target_draft.dart';
```

---

## Implementation Order

### Phase 1: Foundation (Stream 1) - Must Complete First
1. Create `draft_state_models.dart` with immutable draft classes
2. Update `deliverable_form_state.dart` with new fields
3. Update `deliverable_form_cubit.dart` with species loading
4. Add draft CRUD methods to `deliverable_form_field_updates.dart`

### Phase 2: Section Conversions (Stream 2) - After Phase 1
5. Convert `deliverable_species_targets_section.dart` to StatelessWidget
6. Convert `deliverable_site_allocations_section.dart` to StatelessWidget

### Phase 3: Cleanup (Stream 3) - After Phase 2
7. Update `deliverable_form_controllers.dart` (remove drafts)
8. Update `deliverable_form_content.dart` (remove cubit param)
9. Update `deliverable_create_edit_dialog.dart` (remove sync)
10. Remove duplicate exports from section files

### Phase 4: Medium Priority (Stream 4) - Parallel with Phase 2/3
11. Fix DropdownButtonFormField `value:` binding
12. Fix funder deselect to clear fields

### Phase 5: Low Priority (Stream 5) - Final Polish
13. Extract common section components
14. Delete deprecated draft classes
15. Update barrel exports

---

## Testing Strategy

### Unit Tests
- Test `SpeciesTargetDraftState.toTarget()` with various inputs
- Test `SiteAllocationDraftState.toAllocation()` with various inputs
- Test cubit draft CRUD methods

### Widget Tests
- Test species targets section renders drafts from state
- Test add/remove/update operations update state correctly
- Test site allocations section renders drafts from state
- Test dropdown value binding reflects state changes

### Integration Tests
- Test full form submission with species targets and site allocations
- Test edit mode loads existing data into draft state
- Test form validation with drafts

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| TextFormField with initialValue won't update on state changes | Use key based on index or convert to controlled TextEditingController in cubit |
| Breaking existing edit flow | Comprehensive testing of edit mode before/after |
| Species registry not loaded in time | Load synchronously in initialize() before async calls |
| Memory leak from orphaned controllers | No controllers in state - all values are immutable |

---

## Success Criteria

1. No `_syncDraftsToCubit()` calls anywhere
2. No StatefulWidget for species/site sections
3. No draft lists in `DeliverableFormControllers`
4. All form state lives in cubit state
5. All tests pass
6. No regressions in create/edit functionality
