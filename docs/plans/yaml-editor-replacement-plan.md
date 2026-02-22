# Observation Overrides UI Replacement Plan

## Objective
Replace the raw YAML editor in Observation Overrides tab with an intuitive, form-based UI. YAML should NEVER be exposed to any users - it remains purely internal for serialization.

**Note**: The 4 simpler config tabs (Husbandry Schedules, Environmental Thresholds, Mortality Causes, Validation Rules) have already been converted to form-based UI using the `BaseYamlConfigCubit` pattern. Only Observation Overrides remains.

## Current State

### Observation Overrides Tab (~1407 lines)
**File**: `lib/screens/admin/taxonomy/tabs/observation_overrides_tab.dart`

**Current Features to Preserve:**
1. Load from Firestore
2. Load bundled defaults (MUST KEEP)
3. Validate entries
4. View diff (saved vs editor) - convert to structural diff
5. Copy current config (JSON export, not YAML)
6. Reload registry (MUST KEEP)
7. Save changes with annotation note
8. **History Panel:**
   - Snapshot selection (multi-select)
   - Load snapshot to editor
   - Diff snapshot vs editor
   - Apply snapshot (restore)
   - Copy snapshot
   - Multi-snapshot apply with ordering
   - Copy selected (JSON format)
   - Download compliance bundle
   - Annotation filter
   - Override filter
   - Pagination (10 per page)
9. **Audit Panel:**
   - Action filter dropdown
   - Annotation filter
   - Quick filter presets
   - Pagination (10 per page)
   - Drill-down details
10. Metadata banner (source, updatedAt, updatedBy)
11. Legacy JSON format detection and normalization
12. Read-only mode for non-admin roles
13. Change annotation field

### Data Model
```dart
class ObservationFieldOverrideDocument {
  List<ObservationFieldOverrideEntry> entries;
}

class ObservationFieldOverrideEntry {
  OrganismKind organismKind;
  ObservationDialogType dialogType;
  String title;
  String? recordTypeId;
  LifeStage? lifeStage;
  List<ObservationFieldConfig> fields;
}

class ObservationFieldConfig {
  String fieldId;
  String label;
  FieldType type;  // text, number, dropdown, toggle, etc.
  bool required;
  List<String>? options;  // For dropdown type
  String? defaultValue;
  String? hint;
  int? displayOrder;
}
```

## Architecture

### Existing Patterns to Reuse (NOT recreate)

| Component | Location | Purpose |
|-----------|----------|---------|
| `BaseYamlConfigCubit<T, S>` | `lib/cubits/base/` | Pattern for cubit structure |
| `OrganismKindSection<T>` | `lib/widgets/admin/taxonomy/shared/` | Generic expandable section |
| `ConfigTabHeader` | `lib/widgets/admin/taxonomy/shared/` | Header widget |
| `OrganismKindEntry` | `lib/models/interfaces/` | Entry interface |
| `*EditDialog` pattern | `lib/widgets/dialogs/` | Dialog structure |

### New Components

```
lib/cubits/observation_override_config/
├── observation_override_config_cubit.dart
└── observation_override_config_state.dart

lib/widgets/admin/taxonomy/observation_overrides/
├── observation_override_card.dart          # Entry card display
├── observation_override_edit_dialog.dart   # Add/Edit dialog
├── field_config_list_editor.dart           # Nested field editor
├── field_options_editor.dart               # Dropdown options editor
└── structural_diff_viewer.dart             # Entry-level diff (not YAML)
```

### UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│ [History Panel - collapsed by default]                      │
│   Annotation filter | Override filter | Multi-select actions│
│   [Snapshot cards with Load/Diff/Apply/Copy actions]        │
│   [Load More button for pagination]                         │
├─────────────────────────────────────────────────────────────┤
│ [Audit Panel - collapsed by default]                        │
│   Quick filters | Action filter | Annotation filter         │
│   [Audit entry list with drill-down]                        │
│   [Load More button for pagination]                         │
├─────────────────────────────────────────────────────────────┤
│ [Action Bar]                                                │
│   [Reload Firestore] [Load Bundled Defaults] [Validate]     │
│   [View Diff] [Copy JSON] [Reload Registry]                 │
├─────────────────────────────────────────────────────────────┤
│ [Metadata Banner: Source | Updated At | Updated By]         │
├─────────────────────────────────────────────────────────────┤
│ [Change Annotation Field]                                   │
├─────────────────────────────────────────────────────────────┤
│ [Override Entry List - grouped by OrganismKind + DialogType]│
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ▼ Coral - Monitoring                                    │ │
│ │   ┌───────────────────────────────────────────────────┐ │ │
│ │   │ Water Quality Check           [Edit] [Delete] [⋮] │ │ │
│ │   │ Fields: 12 | Required: 3                          │ │ │
│ │   └───────────────────────────────────────────────────┘ │ │
│ │   ┌───────────────────────────────────────────────────┐ │ │
│ │   │ Health Assessment             [Edit] [Delete] [⋮] │ │ │
│ │   │ Fields: 8 | Required: 2                           │ │ │
│ │   └───────────────────────────────────────────────────┘ │ │
│ │   [+ Add Override Entry]                                │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ▼ Oyster - Health Status                                │ │
│ │   ...                                                   │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ [Save Changes]                                    [Read-only]│
└─────────────────────────────────────────────────────────────┘
```

### Edit Dialog Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Add/Edit Override Entry                              [X]    │
├─────────────────────────────────────────────────────────────┤
│ Organism Kind:  [Coral ▼]                                   │
│ Dialog Type:    [Monitoring ▼]                              │
│ Title:          [Water Quality Check_______________]        │
│ Record Type ID: [optional_____________________]             │
│ Life Stage:     [All Stages ▼]                              │
├─────────────────────────────────────────────────────────────┤
│ Fields (12)                                      [+ Add]    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☰ temperature  | Number | Required ✓    [Edit] [Delete] │ │
│ │ ☰ salinity     | Number | Required ✓    [Edit] [Delete] │ │
│ │ ☰ ph_level     | Number | Optional      [Edit] [Delete] │ │
│ │ ☰ notes        | Text   | Optional      [Edit] [Delete] │ │
│ │ ... (drag to reorder)                                   │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                              [Cancel]         [Save Entry]  │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Cubit and State (1 day)
**Files:**
- `lib/cubits/observation_override_config/observation_override_config_cubit.dart`
- `lib/cubits/observation_override_config/observation_override_config_state.dart`

**Features:**
- Parse entries from YAML on load (internal)
- Serialize to YAML on save (internal)
- Expose `overridesByOrganismAndDialog` for UI grouping
- CRUD operations for entries
- Dirty state tracking
- Integration with `ObservationFieldOverrideService`

### Phase 2: Entry Card and List (1 day)
**Files:**
- `lib/widgets/admin/taxonomy/observation_overrides/observation_override_card.dart`
- Update `observation_overrides_tab.dart` to use card list instead of YAML editor

**Features:**
- Card shows: organismKind, dialogType, title, field count, required count
- Edit/Delete/More actions menu
- Grouped by organismKind + dialogType sections
- Uses existing `OrganismKindSection<T>` pattern

### Phase 3: Edit Dialog with Field Editor (2 days)
**Files:**
- `lib/widgets/admin/taxonomy/observation_overrides/observation_override_edit_dialog.dart`
- `lib/widgets/admin/taxonomy/observation_overrides/field_config_list_editor.dart`
- `lib/widgets/admin/taxonomy/observation_overrides/field_options_editor.dart`

**Features:**
- Form for entry metadata (organismKind, dialogType, title, etc.)
- Nested field configuration list with drag-to-reorder
- Field editor dialog (type, label, required, options, hint, default)
- Options editor for dropdown fields
- Validation (required fields, unique field IDs)

### Phase 4: Structural Diff Viewer (1 day)
**Files:**
- `lib/widgets/admin/taxonomy/observation_overrides/structural_diff_viewer.dart`
- Update diff dialog to use structural comparison

**Features:**
- Compare entries structurally (not YAML text)
- Show added/removed/modified entries
- Show field-level changes within entries
- Highlight specific field property changes
- Keep existing `DiffPreviewDialog` shell, replace content

### Phase 5: History/Audit Integration (1.5 days)
**Files:**
- Update `lib/screens/admin/taxonomy/tabs/observation_overrides/overrides_history_panel.dart`
- Update `lib/screens/admin/taxonomy/tabs/observation_overrides/overrides_audit_panel.dart`

**Features:**
- Load snapshot populates cubit state (not YAML text)
- Apply snapshot saves via cubit
- Multi-snapshot apply preserves ordering
- Structural diff for snapshot comparisons
- Preserve all filter/pagination functionality

### Phase 6: Final Integration and Cleanup (0.5 days)
**Files:**
- `lib/screens/admin/taxonomy/tabs/observation_overrides_tab.dart` (major refactor)

**Features:**
- Remove YAML editor completely
- Wire up cubit to all UI components
- Preserve: Load bundled defaults, Reload registry buttons
- Preserve: Change annotation field
- Preserve: Metadata banner
- Preserve: Read-only mode
- Legacy JSON format handled by cubit (transparent to UI)

### Phase 7: Tests (2 days)
**Files:**
- `test/widget/admin/taxonomy/observation_overrides_ui_test.dart`
- `test/cubits/observation_override_config_cubit_test.dart`
- `test/integration/yaml_round_trip_test.dart`

**Test Coverage:**
- Cubit CRUD operations
- Entry card rendering
- Edit dialog form validation
- Field editor interactions
- Structural diff accuracy
- History load/apply/multi-apply
- YAML round-trip integrity
- Legacy JSON format loading
- Performance with 100+ entries
- Tier gating (Pro only)

## Data Flow

```
                    ┌──────────────────────┐
                    │     Firestore        │
                    │   (YAML string)      │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │ ObservationField     │
                    │ OverrideService      │
                    │ (parse/serialize)    │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │ ObservationOverride  │
                    │ ConfigCubit          │
                    │ (state management)   │
                    └──────────┬───────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
┌───────▼───────┐    ┌─────────▼─────────┐   ┌───────▼───────┐
│ Entry List    │    │ Edit Dialog       │   │ History Panel │
│ (cards)       │    │ (forms)           │   │ (snapshots)   │
└───────────────┘    └───────────────────┘   └───────────────┘
```

## Acceptance Criteria

### Must Have
- [ ] No raw YAML visible to any user
- [ ] All entries displayed as cards grouped by organism + dialog type
- [ ] Add/Edit dialog with full field configuration
- [ ] Field list editor with drag-to-reorder
- [ ] Dropdown options editor for select fields
- [ ] Structural diff viewer (entry-level, field-level)
- [ ] Load bundled defaults button functional
- [ ] Reload registry button functional
- [ ] History panel with all current features preserved
- [ ] Audit panel with all current features preserved
- [ ] Multi-snapshot apply with ordering
- [ ] Compliance bundle download functional
- [ ] Change annotation preserved on save
- [ ] Legacy JSON format loads correctly
- [ ] YAML round-trip without semantic data loss
- [ ] Pro tier gating enforced
- [ ] Read-only mode for non-admin roles
- [ ] All widget tests passing

### Performance
- [ ] 100+ entries load and render within 3 seconds
- [ ] Save operation completes within 2 seconds

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| YAML round-trip data corruption | Add round-trip tests FIRST before any refactoring |
| Feature regression | Checklist all 14 current features before starting |
| History panel complexity | Keep existing panel widgets, only change data source |
| Nested field editor UX | Follow existing dialog patterns (e.g., HusbandryScheduleEditDialog) |

## Estimated Effort

| Phase | Scope | Estimate |
|-------|-------|----------|
| Phase 1 | Cubit and State | 1 day |
| Phase 2 | Entry Card and List | 1 day |
| Phase 3 | Edit Dialog with Field Editor | 2 days |
| Phase 4 | Structural Diff Viewer | 1 day |
| Phase 5 | History/Audit Integration | 1.5 days |
| Phase 6 | Final Integration | 0.5 days |
| Phase 7 | Tests | 2 days |
| **Total** | | **9 days** |

## Labels
`enhancement`, `ui/ux`, `admin`, `taxonomy`, `pro-tier`, `observation-overrides`
