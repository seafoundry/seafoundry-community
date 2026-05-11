#!/usr/bin/env node

/**
 * Script to update media_app_usage.json with local screenshot file paths
 * Run this after capturing screenshots to the assets/training_screenshots directory
 */

const fs = require('fs');
const path = require('path');

const SCREENSHOTS_PATH = path.join(__dirname, '../assets/training_screenshots');
const MEDIA_FILE = path.join(__dirname, '../config/seed_data/training/media_app_usage.json');

// Mapping of media IDs to local file paths
const SCREENSHOT_PATHS = {
  // Authentication
  'media-app-001': 'auth/login_screen.png',

  // Profile
  'media-app-002': 'profile/profile_settings.png',

  // Navigation
  'media-app-003': 'nav/organization_selector.png',
  'media-app-022': 'nav/hierarchy_diagram.png',

  // Dashboard
  'media-app-004': 'dashboard/org_map_dashboard.png',
  'media-app-021': 'dashboard/activity_feed.png',
  'media-app-039': 'dashboard/site_weather_sheet.png',

  // Observations
  'media-app-005': 'observation/action_dock_observations.png',
  'media-app-006': 'observation/unified_observation_dialog.png',
  'media-app-007': 'observation/target_selector.png',
  'media-app-008': 'observation/health_observation_form.png',
  'media-app-024': 'observation/disease_form.png',
  'media-app-025': 'observation/biofouling_form.png',
  'media-app-026': 'observation/camera_controls.png',

  // Inventory
  'media-app-009': 'inventory/inventory_screen_tabs.png',
  'media-app-010': 'inventory/holdings_spreadsheet.png',
  'media-app-011': 'inventory/fragging_dialog.png',
  'media-app-012': 'inventory/transfer_initiate_dialog.png',
  'media-app-027': 'inventory/inventory_events_spreadsheet.png',
  'media-app-028': 'inventory/provenance_detail.png',

  // Reporting
  'media-app-013': 'reporting/reporting_dashboard_screen.png',
  'media-app-014': 'reporting/dashboard_tab_overview.png',
  'media-app-015': 'reporting/kpi_cards.png',
  'media-app-016': 'reporting/report_builder_tab.png',
  'media-app-029': 'reporting/trend_line_chart.png',
  'media-app-030': 'reporting/health_distribution_pie.png',
  'media-app-031': 'reporting/site_comparison_bars.png',
  'media-app-032': 'reporting/filter_panel.png',
  'media-app-033': 'reporting/export_options.png',
  'media-app-034': 'reporting/saved_reports_tab.png',
  'media-app-035': 'reporting/template_gallery.png',
  'media-app-040': 'reporting/inventory_analytics.png',

  // Data Quality
  'media-app-017': 'quality/completeness_indicator.png',
  'media-app-018': 'quality/photo_quality_examples.png',
  'media-app-019': 'quality/health_status_guide.png',
  'media-app-020': 'quality/csv_import_preview.png',
  'media-app-036': 'quality/standardized_dropdowns.png',
  'media-app-037': 'quality/size_measurement.png',
  'media-app-038': 'quality/validation_error.png',

  // Common
  'media-app-023': 'common/organism_selector.png',
};

const WORKFLOW_PATHS = {
  'workflow-001': 'workflows/observation_workflow.png',
  'workflow-002': 'workflows/fragmentation_workflow.png',
  'workflow-003': 'workflows/transfer_workflow.png',
  'workflow-004': 'workflows/report_generation_workflow.png',
  'workflow-005': 'workflows/data_correction_workflow.png',
};

const EXAMPLE_PATHS = {
  'example-report-001': 'examples/monthly_inventory_report.pdf',
  'example-report-002': 'examples/health_assessment_report.pdf',
  'example-report-003': 'examples/community_report_example.pdf',
};

function checkFileExists(relativePath) {
  const fullPath = path.join(SCREENSHOTS_PATH, relativePath);
  return fs.existsSync(fullPath);
}

function updateMediaFile() {
  console.log('📸 Updating app screenshot URLs...\n');

  const content = fs.readFileSync(MEDIA_FILE, 'utf8');
  const data = JSON.parse(content);

  let updatedCount = 0;
  let missingCount = 0;
  const missing = [];

  // Update media references
  if (data.mediaReferences) {
    for (const item of data.mediaReferences) {
      const relativePath = SCREENSHOT_PATHS[item.id];
      if (relativePath) {
        if (checkFileExists(relativePath)) {
          item.contentUrl = `assets/training_screenshots/${relativePath}`;
          item.thumbnailUrl = `assets/training_screenshots/${relativePath}`;
          updatedCount++;
          console.log(`  ✅ ${item.id}: ${relativePath}`);
        } else {
          missing.push({ id: item.id, path: relativePath, title: item.title });
          missingCount++;
        }
      }
    }
  }

  // Update workflow diagrams
  if (data.workflowDiagrams) {
    for (const item of data.workflowDiagrams) {
      const relativePath = WORKFLOW_PATHS[item.id];
      if (relativePath) {
        if (checkFileExists(relativePath)) {
          item.contentUrl = `assets/training_screenshots/${relativePath}`;
          updatedCount++;
          console.log(`  ✅ ${item.id}: ${relativePath}`);
        } else {
          missing.push({ id: item.id, path: relativePath, title: item.title });
          missingCount++;
        }
      }
    }
  }

  // Update example reports
  if (data.exampleReports) {
    for (const item of data.exampleReports) {
      const relativePath = EXAMPLE_PATHS[item.id];
      if (relativePath) {
        if (checkFileExists(relativePath)) {
          item.contentUrl = `assets/training_screenshots/${relativePath}`;
          updatedCount++;
          console.log(`  ✅ ${item.id}: ${relativePath}`);
        } else {
          missing.push({ id: item.id, path: relativePath, title: item.title });
          missingCount++;
        }
      }
    }
  }

  // Write back
  fs.writeFileSync(MEDIA_FILE, JSON.stringify(data, null, 2) + '\n');

  console.log(`\n📊 Summary:`);
  console.log(`  Updated: ${updatedCount}`);
  console.log(`  Missing: ${missingCount}`);

  if (missing.length > 0) {
    console.log(`\n⚠️  Missing screenshots:`);
    for (const m of missing) {
      console.log(`  - ${m.id}: ${m.path}`);
      console.log(`    "${m.title}"`);
    }
    console.log(`\n💡 Capture these with:`);
    console.log(`   xcrun simctl io booted screenshot assets/training_screenshots/<path>`);
  }

  console.log('\n✨ Done!');
}

updateMediaFile();
