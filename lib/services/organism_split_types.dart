// @tier: community
import 'package:seafoundry_app/models/events/create_event.dart';
import 'package:seafoundry_app/models/events/split_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Result of a split operation containing the updated source, new record,
/// the split event, and the create event for the new record.
class OrganismSplitResult {
  const OrganismSplitResult({
    required this.updatedSource,
    required this.newRecord,
    required this.splitEvent,
    required this.createEvent,
  });

  final OrganismRecord updatedSource;
  final OrganismRecord newRecord;
  final SplitEvent splitEvent;
  final CreateEvent createEvent;
}

/// Parameters required to execute an organism split transaction.
class OrganismSplitParams {
  const OrganismSplitParams({
    required this.sourceOrganism,
    required this.splitQuantity,
    required this.newRecordName,
    required this.formattedNotes,
    this.preGeneratedRecordSlug,
    this.preGeneratedEventSlug,
    this.preGeneratedCreateEventSlug,
  });

  final OrganismRecord sourceOrganism;
  final double splitQuantity;
  final String newRecordName;
  final String formattedNotes;

  /// Pre-generated slugs for use within an external transaction.
  /// When provided, avoids nested transactions from slug generation.
  final String? preGeneratedRecordSlug;
  final String? preGeneratedEventSlug;
  final String? preGeneratedCreateEventSlug;
}
