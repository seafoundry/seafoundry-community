// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Helper class for resolved record information during row hydration.
class ResolvedRecordInfo {
  const ResolvedRecordInfo({
    required this.displayName,
    this.siteId,
    this.parentGroupId,
    this.structureId,
    this.structureName,
    this.physicalForm,
    this.organism,
    this.genetLocalId,
  });

  final String displayName;
  final String? siteId;
  final String? parentGroupId;
  final String? structureId;
  final String? structureName;
  final String? physicalForm;
  final OrganismRecord? organism;
  final String? genetLocalId;
}

/// A hydrated row representing an inventory event for display in a spreadsheet.
///
/// Contains all the resolved metadata (site, structure, user names, etc.)
/// needed to render a single row in the inventory events spreadsheet.
///
/// This is a pure data class. Use [InventoryEventHydrationService] to create
/// instances from [Event] objects.
class InventoryEventRow {
  InventoryEventRow({
    required this.eventId,
    required this.eventTypeId,
    required this.eventLabel,
    required this.recordId,
    required this.recordModelType,
    required this.recordDisplay,
    this.recordName,
    this.recordUrlPath,
    this.genetLocalId,
    this.genetId,
    required this.createdAt,
    required this.userName,
    required this.details,
    required this.quantityDelta,
    required this.siteId,
    required this.siteName,
    required this.locationPath,
    this.structureId,
    this.structureName,
    this.organismKind,
    this.physicalForm,
    required this.permitSummary,
    required this.permitAuthority,
    required this.permitWindow,
    required this.hasPermitMetadata,
  });

  final String eventId;
  final String eventTypeId;
  final String eventLabel;
  final String? recordId;
  final ModelType? recordModelType;
  final String recordDisplay;
  final String? recordName;
  final String? recordUrlPath;
  final String? genetLocalId;
  final String? genetId;
  final DateTime? createdAt;
  final String? userName;
  final String details;
  final String? quantityDelta;
  final String? siteId;
  final String? siteName;
  final String? locationPath;
  final String? structureId;
  final String? structureName;
  final OrganismKind? organismKind;
  final String? physicalForm;
  final String permitSummary;
  final String permitAuthority;
  final String permitWindow;
  final bool hasPermitMetadata;

  /// Formats a label suffix with a bullet separator.
  static String labelSuffix(String? label) {
    if (label == null || label.isEmpty) {
      return '';
    }
    return ' - $label';
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'eventTypeId': eventTypeId,
    'eventLabel': eventLabel,
    'recordId': recordId,
    'recordType': recordModelType?.name,
    'recordDisplay': recordDisplay,
    'genetLocalId': genetLocalId,
    'createdAt': createdAt?.toIso8601String(),
    'userName': userName,
    'details': details,
    'quantityDelta': quantityDelta,
    'siteId': siteId,
    'siteName': siteName,
    'locationPath': locationPath,
    'structureId': structureId,
    'structureName': structureName,
    'organismKind': organismKind?.name,
    'physicalForm': physicalForm,
    'permitSummary': permitSummary,
    'permitAuthority': permitAuthority,
    'permitWindow': permitWindow,
    'hasPermitMetadata': hasPermitMetadata,
  };
}
