# Community vs Pro Tier Strategy - Dialogs & Data Capture

**Last Updated**: 2026-01-08
**Status**: Active Implementation

## Philosophy

Community tier enables **complete data capture with full upgrade path** to Pro tier:
- ✅ **Raw data capture**: ALL core 5-axis data (taxonomy, provenance, location, life stage, measurement)
- ✅ **Data display**: Spreadsheet views show captured data
- ✅ **Upgrade path**: Historical data becomes fully analyzable when upgrading to Pro
- ❌ **Analytics disabled**: Summary statistics, trends, visualizations hidden until Pro

## Tier Decision Matrix

### Data Capture (Dialogs)

| Feature | Community | Pro | Rationale |
|---------|-----------|-----|-----------|
| **Quantity Tracking** | ✅ Full | ✅ Full | Core 5-axis data (measurement axis) |
| **Size Changes** | ✅ Capture | ✅ + Analytics | 5-axis core - capture raw data, hide trends |
| **Population Loss/Gain** | ✅ Basic reasons | ✅ + Disease analytics | Track quantity with reasons, detailed disease analysis Pro only |
| **Provenance Relationships** | ✅ Preserve data | ✅ + Tree visualization | Capture spawn/batch relationships, visualization Pro only |
| **Health Status** | ❌ Disabled | ✅ Full | Backwards compatibility - historical health data visible after upgrade |
| **Transfer Events** | ✅ Basic transfers | ✅ + Detailed metadata | Track movement, detailed provenance tracking Pro only |
| **Fragmentation/Reproduction** | ❌ Disabled | ✅ Full | Advanced husbandry operation |
| **Outplanting** | ✅ Basic events | ✅ + Compliance tracking | Record outplanting, detailed permit metadata Pro only |

### Data Display (Spreadsheets)

| Feature | Community | Pro | Implementation |
|---------|-----------|-----|----------------|
| **Basic Columns** | ✅ Show | ✅ Show | Nursery, structure, species, genotype, quantity |
| **Size Data** | ✅ Show raw | ✅ + Statistics | Display size values, hide growth rate calculations |
| **Loss Reasons** | ❌ Hide | ✅ Show | Reason column hidden in Community exports |
| **Health Status** | ❌ Hide | ✅ Show | Status column hidden (backwards compatibility) |
| **Provenance Links** | ❌ Hide | ✅ Show | Spawn/parent relationships captured but not displayed |
| **Permit Metadata** | ❌ Hide | ✅ Show | Permit fields hidden in Community |
| **Summary Stats** | ❌ Hide | ✅ Show | Growth rates, survival rates, trends |

## Implementation Patterns

### Pattern 1: Community Tier Dialog (No Conditional Rendering)

**Use when**: Dialog captures core 5-axis data without analytics

**Example**: `SizeChangeDialog` (size_change_dialog.dart)

```dart
// @tier: community
class SizeChangeDialog extends StatefulWidget {
  // Full size data capture (5-axis measurement)
  // - Size class input
  // - Measured value + unit
  // - Comment field
  // - Growth/tissue loss differentiation
  // Analytics are hidden in spreadsheet views, not the dialog
}
```

**Characteristics**:
- Tier annotation: `@tier: community`
- No conditional rendering needed
- Full data capture for upgrade path
- Analytics hidden in **reporting/spreadsheet views**, not dialog

### Pattern 2: Community Dialog with Pro Fields (Conditional Rendering)

**Use when**: Dialog has basic data capture (Community) + advanced analytics (Pro)

**Example**: `PopulationLossDialog` (population_loss_dialog.dart)

```dart
// @tier: community
class _PopulationLossDialogState extends State<PopulationLossDialog> {
  Widget _buildDialog(BuildContext context, InventoryEventFormState state) {
    final featureAccess = context.watch<FeatureAccessService>();
    final showProFields = featureAccess.tier != OrganizationTier.community;

    return AlertDialog(
      content: Column(
        children: [
          // Community: Basic quantity + loss reason
          _buildQuantityAdjuster(),
          _buildBasicLossReasonDropdown(),

          // Pro only: Detailed mortality analytics
          if (showProFields) ...[
            _buildDetailedMortalityReason(),
            _buildDiseaseTypeDropdown(),
          ],

          // Community: Simple comment
          _buildCommentField(),
        ],
      ),
    );
  }
}
```

**Characteristics**:
- Tier annotation: `@tier: community`
- Conditional rendering with `if (showProFields)`
- FeatureAccessService tier check
- Community fields always shown
- Pro analytics fields conditionally shown

### Pattern 3: Pro-Only Dialog (Complete Feature Gating)

**Use when**: Feature is entirely Pro tier with no Community equivalent

**Example**: `HealthStatusDialog` (health_status_dialog.dart)

```dart
// @tier: pro
class HealthStatusDialog extends StatefulWidget {
  // Entire dialog is Pro tier
  // Community users never see health observations
  // Backwards compatibility: historical health data visible after upgrade
}
```

**Characteristics**:
- Tier annotation: `@tier: pro`
- No conditional rendering
- Dialog completely hidden from Community users
- File-level tier segregation

## Dialog Tier Assignments

### ✅ Community Tier (with conditional rendering where needed)

| Dialog | File | Conditional Fields | Notes |
|--------|------|-------------------|-------|
| Population Loss/Gain | `population_loss_dialog.dart` | ✅ Disease analytics | Basic reasons Community, detailed analytics Pro |
| Size Change | `size_change_dialog.dart` | ❌ None | Pure data capture, analytics in spreadsheets |
| Transfer (Basic) | TBD | ✅ Provenance tracking | Basic movement Community, detailed provenance Pro |

### ❌ Pro Tier (complete feature gating)

| Dialog | File | Reason |
|--------|------|--------|
| Health Status | `health_status_dialog.dart` | Backwards compatibility for upgrade path |
| Fragmentation | `fragging_dialog.dart` | Advanced husbandry operation |
| Asexual Propagation | `asexual_propagation_dialog.dart` | Advanced husbandry operation |
| Group Fragmentation | `group_fragmentation_dialog.dart` | Advanced husbandry operation |
| Organism Collection | `organism_collection_dialog.dart` | Advanced workflow with permits |
| Outplant Batch | `outplant_batch_dialog.dart` | **Deep architectural coupling** to Pro features (offline queue, geometry components, KML uploads). Includes optional deliverable assignment and attachment method selection. Custom attachment methods (prefix `custom_attach_`) are Pro-only; builtins available to all tiers. |
| Monitoring | `monitoring_dialog.dart` | Advanced with KML/imagery |

## Spreadsheet Conditional Columns

### Community Spreadsheet (6-field export)

```dart
// Community columns (always shown)
final communityColumns = [
  'nursery',        // Site name
  'structure',      // Group/container
  'species',        // Species name
  'genotype',       // Genet identifier
  'quantity',       // Measurement value
  'size',           // Size data (if captured)
];

// Pro columns (hidden in Community)
final proColumns = [
  'lossReason',           // Why quantity decreased
  'diseaseType',          // Specific disease classification
  'healthStatus',         // Current health condition
  'provenanceParent',     // Spawn/parent relationships
  'permitId',             // Compliance metadata
  'substructure',         // Detailed location hierarchy
  'notes',                // Extended metadata
];
```

### Implementation Example

```dart
// In spreadsheet builder
Widget buildColumn(String columnId) {
  final featureAccess = context.watch<FeatureAccessService>();
  final showProFields = featureAccess.tier != OrganizationTier.community;

  // Pro-only columns
  if (['lossReason', 'diseaseType', 'healthStatus', 'permitId'].contains(columnId)) {
    if (!showProFields) {
      return SizedBox.shrink(); // Hide column in Community
    }
  }

  return _buildColumnContent(columnId);
}
```

## Testing Strategy

### Community Build Test

```bash
# Build Community tier
flutter build web --dart-define=SF_TIER=community

# Verify tier checker passes
dart run tool/bin/tier_check.dart

# Expected: 0 violations
```

### Tier Verification Checklist

- [ ] Community dialogs capture all 5-axis core data
- [ ] Pro-only analytics fields hidden in Community
- [ ] Tier checker passes (0 violations)
- [ ] Spreadsheet columns conditionally shown/hidden
- [ ] Historical data preserved for upgrade path
- [ ] No compilation errors in Community build

## Upgrade Path Verification

When a Community user upgrades to Pro, they should see:

1. **Historical size data** → Growth trends, statistical analysis
2. **Historical loss events** → Disease analytics, mortality patterns
3. **Provenance relationships** → Lineage tree visualization
4. **Hidden health data** → Full health observation history (if Pro features were used pre-upgrade)

**Critical**: Data is always captured in Community (where allowed), just not displayed with analytics. Upgrade unlocks visualization and analysis, not historical data.

## Migration Guide

### Converting Pro Dialog to Community with Conditional Rendering

1. **Change tier annotation**:
   ```dart
   // @tier: pro  →  // @tier: community
   ```

2. **Add FeatureAccessService**:
   ```dart
   import 'package:seafoundry_app/services/feature_access_service.dart';
   import 'package:seafoundry_app/models/types/organization_tier.dart';
   ```

3. **Add tier check in build method**:
   ```dart
   final featureAccess = context.watch<FeatureAccessService>();
   final showProFields = featureAccess.tier != OrganizationTier.community;
   ```

4. **Wrap Pro-only sections**:
   ```dart
   if (showProFields) ...[
     _buildProAnalytics(),
   ],
   ```

5. **Verify tier checker**: `dart run tool/bin/tier_check.dart`

6. **Test Community build**: `flutter build web --dart-define=SF_TIER=community`

## Related Documentation

- `docs/architecture/community_vs_pro_rfc.md` - Overall tier strategy
- `docs/ui_ux/TIER_VISUAL_INDICATORS_GUIDE.md` - Visual tier indicators (TierGate, UpgradeDialog)
- `docs/tier_indicator_integration_summary.md` - Tier indicator implementation
- `docs/OUTPLANT_DIALOG_ENHANCEMENT_IMPLEMENTATION.md` - Outplant deliverable & attachment methods
- `docs/CUSTOM_ENUM_TYPES_IMPLEMENTATION.md` - Custom enum types (task, observation, group)
- `docs/REPORTING_ANALYTICS_DASHBOARD.md` - Reports & Analytics Dashboard with tier-gated exports
- `CLAUDE.md` - Tier system overview

## Future Enhancements

### Short-term
- [ ] Add tier badges to navigation showing Pro features
- [ ] Implement TierGate visual indicators for locked fields
- [ ] Create "Upgrade to unlock analytics" tooltips on hidden spreadsheet columns

### Long-term
- [x] Analytics dashboard showing value of Pro tier (preview with locked data) - **Implemented**: See [REPORTING_ANALYTICS_DASHBOARD.md](REPORTING_ANALYTICS_DASHBOARD.md)
- [ ] "Compare Plans" screen showing Community vs Pro feature matrix
- [ ] Automated testing for tier-specific builds
