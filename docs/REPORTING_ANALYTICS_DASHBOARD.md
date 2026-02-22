# Reports & Analytics Dashboard

**Last Updated**: 2026-01-09
**Status**: Implemented (Phase 5 complete, all issues resolved)

## Overview

The Reports & Analytics Dashboard enables users to create customizable data visualizations and export data for funder/manager reports. The system follows the NOAA Coral Reef Restoration Monitoring Guide metrics framework.

## Architecture

### Screen Structure

```
ReportingDashboardScreen
├── Sidebar (collapsible)
│   ├── Template Gallery (Monthly, Quarterly, Annual)
│   └── Saved Reports List
└── Main Content (TabBarView)
    ├── Tab 0: Dashboard View (KPIs + quick charts)
    ├── Tab 1: Report Builder (5-step wizard)
    └── Tab 2: Saved Reports (management)
```

### State Management

Orchestrated sub-cubit pattern for clean separation of concerns:

```
ReportingDashboardCubit (orchestrator)
├── ReportFilterCubit (filter state, time range)
├── ReportDataCubit (data loading/caching)
├── ReportVisualizationCubit (chart configs)
└── ReportExportCubit (export operations)
```

### Data Flow

```
Repositories (Event, Site, Organism)
    ↓
SnapshotService / StateReconstructionService
    ↓
ReportingAnalyticsService (aggregates analytics)
    ↓
ReportDataAggregationService (time-series, comparisons)
    ↓
ReportDataCubit (caches filtered/aggregated data)
    ↓
UI (charts, tables, KPIs)
    ↓
ReportExportService (CSV + JSON export)
```

## File Structure

### Models (`lib/models/reporting/`)

| File | Purpose |
|------|---------|
| `report_configuration.dart` | Main config with filters, visualizations, time range |
| `report_template.dart` | Template definitions (monthly, quarterly, annual) |
| `time_range_config.dart` | Time range with presets + comparison support |
| `filter_config.dart` | Multi-level filter configuration |
| `visualization_config.dart` | Chart/table configuration |
| `report_kpi.dart` | KPI card data model |

### Services (`lib/services/reporting/`)

| File | Purpose |
|------|---------|
| `reporting_analytics_service.dart` | Computes KPIs, distributions, trends |
| `report_data_aggregation_service.dart` | Time-series aggregation |
| `report_template_registry.dart` | Built-in template definitions |

### Cubits (`lib/cubits/reporting/`)

| File | Purpose |
|------|---------|
| `reporting_dashboard_cubit.dart` | Orchestrator |
| `report_filter_cubit.dart` | Filter/time range management |
| `report_data_cubit.dart` | Data loading/caching |
| `report_visualization_cubit.dart` | Chart configurations |
| `report_export_cubit.dart` | Export operations |

### Screens & Widgets

| File | Purpose |
|------|---------|
| `lib/screens/reporting/reporting_dashboard_screen.dart` | Main container |
| `lib/widgets/reporting/reporting_sidebar.dart` | Template gallery |
| `lib/widgets/reporting/reporting_dashboard_tab.dart` | Quick view |
| `lib/widgets/reporting/reporting_builder_tab.dart` | 5-step wizard |
| `lib/widgets/reporting/reporting_saved_tab.dart` | Saved reports |
| `lib/widgets/reporting/report_kpi_card.dart` | KPI display |
| `lib/widgets/reporting/time_range_selector.dart` | Time presets |
| `lib/widgets/reporting/report_filter_panel.dart` | Multi-level filters |
| `lib/widgets/reporting/visualization_palette.dart` | Chart selection |
| `lib/widgets/reporting/chart_config_panel.dart` | Chart customization |
| `lib/widgets/reporting/report_preview.dart` | Full preview |

## Tier Strategy

| Feature | Community | Pro | Scale |
|---------|-----------|-----|-------|
| **Templates** (Monthly, Quarterly, Annual) | Yes | Yes | Yes |
| **Custom date range** | Yes | Yes | Yes |
| **Site/Structure/Species filters** | Yes | Yes | Yes |
| **Comparative periods** (A vs B) | - | Yes | Yes |
| **Life stage/Health/Genet/Zone filters** | - | Yes | Yes |
| **Cross-site aggregation** | - | Yes | Yes |
| **KPI Cards** | 3 max | Unlimited | Unlimited |
| **Pie/Line Charts** | 1 each | Unlimited | Unlimited |
| **Bar Charts / Data Tables** | - | Yes | Yes |
| **CSV export** | Yes | Yes | Yes |
| **Chart config JSON export** | - | Yes | Yes |
| **Saved reports** | 3 max | Unlimited | Unlimited |
| **Scheduled reports** | - | - | Yes |

### Tier Gating Implementation

Tier gating uses the `TierGate` and `ProGate` widgets from `lib/widgets/common/tier_gate.dart`:

```dart
// Example: JSON export button gating
TierGate(
  requiredTier: Tier.pro,
  featureName: 'JSON Export',
  mode: TierGateMode.badge,
  child: OutlinedButton.icon(
    onPressed: null,
    icon: const Icon(Icons.code),
    label: const Text('Export JSON'),
  ),
)
```

## Export Formats

### CSV (Analytics Data)

```csv
sf_csv_template,reporting_analytics
sf_csv_version,1.0
generated_at,2026-01-15T10:30:00Z
report_name,Monthly Inventory Summary
time_range_start,2026-01-01
time_range_end,2026-01-31

# KEY PERFORMANCE INDICATORS
kpi_id,label,value,unit,change_percent
total_organisms,Total Organisms,1500,count,5.2
survival_rate,Survival Rate,89.5,%,-1.3

# HEALTH DISTRIBUTION
status,count
healthy,1280
stressed,150
diseased,70

# SPECIES DISTRIBUTION
species,count
Acropora cervicornis,850
Acropora palmata,450
Montastraea cavernosa,200

# INVENTORY TREND
date,value
2026-01-01,1450
2026-01-08,1475
2026-01-15,1500

# SITE COMPARISON
site,value
Main Nursery,800
Outplant Site A,450
Outplant Site B,250
```

### JSON (Chart Configuration) - Pro Feature

```json
{
  "version": "1.0",
  "exportedAt": "2026-01-15T10:30:00Z",
  "reportConfiguration": {
    "id": "report_001",
    "name": "Monthly Inventory Summary",
    "timeRange": {
      "preset": "last30Days",
      "startDate": "2026-01-01",
      "endDate": "2026-01-31"
    },
    "filters": {
      "siteIds": ["site_001"],
      "speciesIds": []
    },
    "visualizations": [
      {
        "id": "viz_001",
        "type": "kpiCard",
        "title": "Total Organisms",
        "dataSource": {
          "metric": "totalCount"
        }
      }
    ]
  },
  "computedData": {
    "kpis": [
      {
        "id": "total_organisms",
        "label": "Total Organisms",
        "value": 1500,
        "unit": "count",
        "changePercent": 5.2
      }
    ]
  }
}
```

## Report Builder Wizard

The 5-step wizard guides users through report creation:

1. **Basics** - Report name and description
2. **Time Range** - Preset or custom dates, comparison period toggle (Pro)
3. **Filters** - Site, structure, species (Community); Life stage, health, genet, zone (Pro)
4. **Visualizations** - Select and configure charts (limited in Community)
5. **Preview & Save** - Review configuration, export CSV/JSON, save report

## Navigation

Access the Reports & Analytics Dashboard from:
- App Drawer → "Reports & Analytics" (under Nursery Management section)
- Route: `/reports`

## Testing

### Verification Checklist

- [ ] Dashboard loads with KPIs and charts
- [ ] Template selection applies filters and visualizations
- [ ] Time range presets calculate correct date ranges
- [ ] Comparison toggle only visible for Pro users
- [ ] Filters section shows/hides Pro filters based on tier
- [ ] Visualization palette gates Bar Chart and Data Table
- [ ] CSV export generates valid analytics data
- [ ] JSON export gated for Pro users
- [ ] Saved reports respect tier limits (3 for Community)
- [ ] Duplicate report respects tier limits

### Commands

```bash
# Analyze reporting files
flutter analyze lib/widgets/reporting/ lib/screens/reporting/ lib/cubits/reporting/

# Run widget tests
flutter test test/widget/reporting/
```

## Known Limitations

1. **Export Download**: Export is web-only. Mobile displays a toast message directing users to web.
2. ~~**Mock Filter Data**: Filter options use mock data; needs connection to real repositories.~~ **RESOLVED**: Connected to SiteRepository, GroupRepository, and SpeciesRegistry.
3. ~~**Persistence**: Saved reports are stored in cubit state only; Firestore persistence not yet implemented.~~ **RESOLVED**: Firestore persistence with 30-day TTL.

## TTL Cleanup Strategy

Saved reports have a 30-day TTL implemented as follows:

1. **Client-side filtering**: Queries exclude expired reports (`ttlExpiry > now`)
2. **TTL refresh**: Accessing or updating a report extends TTL by 30 days
3. **Firestore index**: Compound index on `ttlExpiry` + `updatedAt` for efficient queries

**Note**: Actual document deletion of expired reports requires one of:
- **Firestore TTL policy** (recommended): Configure `ttlExpiry` as a TTL field in Firebase Console
- **Cloud Function**: Scheduled cleanup function to delete expired documents
- **Lazy deletion**: Documents remain but are filtered out of queries until accessed

The current implementation uses client-side filtering (#1 + #2), which is sufficient for small-to-medium usage. For production at scale, enable Firestore's native TTL feature on the `ttlExpiry` field.

## Related Documentation

- [Tier Strategy - Dialogs](tier_strategy_dialogs.md) - Tier gating patterns
- [UI/UX README](architecture/ui_ux/README.md) - Design system
- [Community vs Pro RFC](architecture/community_vs_pro_rfc.md) - Tier strategy overview
