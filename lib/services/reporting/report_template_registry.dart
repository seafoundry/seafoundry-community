// @tier: community
import 'package:seafoundry_app/models/reporting/report_template.dart';
import 'package:seafoundry_app/services/tier.dart';

/// Registry of built-in report templates.
///
/// Provides predefined templates for common reporting scenarios:
/// - Monthly: Last 30 days with basic metrics
/// - Quarterly: Last 90 days with comprehensive analysis
/// - Annual: Last 365 days with year-over-year comparison
class ReportTemplateRegistry {
  const ReportTemplateRegistry();

  /// Get all available templates.
  List<ReportTemplate> get allTemplates => BuiltInTemplates.all;

  /// Get template by ID.
  ReportTemplate? getById(String id) {
    return BuiltInTemplates.byId(id);
  }

  /// Get templates by category.
  List<ReportTemplate> getByCategory(ReportTemplateCategory category) {
    return allTemplates.where((t) => t.category == category).toList();
  }

  /// Get templates accessible by a user tier.
  List<ReportTemplate> getAccessibleTemplates(Tier userTier) {
    return allTemplates.where((t) => t.isAccessibleTo(userTier)).toList();
  }
}
