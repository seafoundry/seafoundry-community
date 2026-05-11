
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Parsed and validated row for inventory import operations.
class InventoryImportRow {
  const InventoryImportRow({
    required this.rowNumber,
    required this.organism,
    required this.targetGroup,
    required this.localGenetId,
    required this.tagId,
    required this.speciesId,
    required this.physicalFormId,
    required this.quantity,
    required this.populationMeasurement,
    required this.updateHealthStatus,
    required this.healthStatus,
    required this.updateSizeSpec,
    required this.sizeSpec,
    required this.shouldUpdateNotes,
    required this.notes,
    required this.updateGenet,
    required this.genet,
    required this.lastEventAt,
    required this.aliases,
  });

  final int rowNumber;
  final OrganismRecord organism;
  final Group targetGroup;
  final String localGenetId;
  final String tagId;
  final String speciesId;
  final String physicalFormId;
  final int quantity;
  final PopulationMeasurement? populationMeasurement;
  final bool updateHealthStatus;
  final HealthStatus? healthStatus;
  final bool updateSizeSpec;
  final SizeSpec sizeSpec;
  final bool shouldUpdateNotes;
  final String? notes;
  final bool updateGenet;
  final Genet? genet;
  final String? lastEventAt;
  final List<OrganismAlias> aliases;
}
