// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Parses an embedded organism record snapshot from event JSON.
///
/// When the snapshot field is present and non-empty, parses via
/// [OrganismRecord.fromJson]. When missing or null, creates a
/// partial record using fields available from the parent event JSON
/// (recordId, organizationId, metadata).
OrganismRecord parseOrganismSnapshot(Map<String, dynamic> eventJson) {
  final snapshotMap = deepNormalizeMap(eventJson['organismRecordSnapshot']);
  if (snapshotMap.isNotEmpty) {
    return OrganismRecord.fromJson(snapshotMap);
  }
  return OrganismRecord.partial(
    id: eventJson['recordId'],
    organizationId: Record.inferOrganizationId(eventJson),
    metadata: safeMapCast(eventJson['metadata']),
  );
}
