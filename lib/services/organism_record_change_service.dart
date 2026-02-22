// @tier: community
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

/// Detects changes between two [OrganismRecord] instances and enforces the
/// immutability guarantees documented in `docs/taxonomy/README.md`.
class OrganismRecordChangeService {
  const OrganismRecordChangeService();
  static const ListEquality<OrganismAlias> _aliasListEquality =
      ListEquality<OrganismAlias>();

  OrganismRecordChangeSet detectChanges({
    required OrganismRecord previous,
    required OrganismRecord next,
  }) {
    _assertImmutability(previous, next);

    LifeStageChange? lifeStageChange;
    if (!_lifeStageEquals(previous.lifeStage, next.lifeStage)) {
      lifeStageChange = LifeStageChange(
        oldStage: previous.lifeStage.stage,
        newStage: next.lifeStage.stage,
        oldSubtype: previous.lifeStage.subtype,
        newSubtype: next.lifeStage.subtype,
      );
    }

    PhysicalFormChange? physicalFormChange;
    if (previous.lifecycleFormId != next.lifecycleFormId) {
      physicalFormChange = PhysicalFormChange(
        oldFormId: previous.lifecycleFormId,
        newFormId: next.lifecycleFormId,
      );
    }

    SizeBandChange? sizeBandChange;
    final prevSizeBandId = previous.physicalForm?.sizeBandId;
    final nextSizeBandId = next.physicalForm?.sizeBandId;
    if (prevSizeBandId != nextSizeBandId) {
      sizeBandChange = SizeBandChange(
        oldSizeBandId: prevSizeBandId,
        newSizeBandId: nextSizeBandId,
      );
    }

    SizeSpecChange? sizeSpecChange;
    if (!_sizeSpecEquals(previous.sizeSpec, next.sizeSpec)) {
      sizeSpecChange = SizeSpecChange(
        oldSize: previous.sizeSpec,
        newSize: next.sizeSpec,
      );
    }

    QuantityChange? quantityChange;
    if (!_measurementEquals(previous.measurement, next.measurement)) {
      quantityChange = QuantityChange(
        oldMeasurement: previous.measurement,
        newMeasurement: next.measurement,
      );
    }

    final aliasesChanged = !_aliasListEquality.equals(
      previous.aliases,
      next.aliases,
    );
    final ownershipChanged =
        (previous.ownerOrganizationId ?? '') !=
            (next.ownerOrganizationId ?? '') ||
        (previous.managingOrganizationId ?? '') !=
            (next.managingOrganizationId ?? '');

    return OrganismRecordChangeSet(
      lifeStageChange: lifeStageChange,
      physicalFormChange: physicalFormChange,
      sizeBandChange: sizeBandChange,
      sizeSpecChange: sizeSpecChange,
      quantityChange: quantityChange,
      nameChanged: (previous.name) != (next.name),
      aliasesChanged: aliasesChanged,
      ownershipChanged: ownershipChanged,
    );
  }

  void assertImmutableFields({
    required OrganismRecord previous,
    required OrganismRecord next,
  }) {
    _assertImmutability(previous, next);
  }

  void _assertImmutability(OrganismRecord previous, OrganismRecord next) {
    if (previous.organismKind != next.organismKind) {
      throw const OrganismRecordImmutabilityException(
        message: 'organismKind cannot be changed once created.',
      );
    }
    final prevSpecies = previous.speciesId?.trim() ?? '';
    final nextSpecies = next.speciesId?.trim() ?? '';
    final prevHasValue = prevSpecies.isNotEmpty;
    if (prevHasValue && prevSpecies != nextSpecies) {
      throw const OrganismRecordImmutabilityException(
        message: 'speciesId cannot be changed once created.',
      );
    }
  }

  bool _lifeStageEquals(LifeStageSpec a, LifeStageSpec b) =>
      a.stage == b.stage && (a.subtype ?? '') == (b.subtype ?? '');

  bool _sizeSpecEquals(SizeSpec a, SizeSpec b) {
    final sizeClassEqual = (a.sizeClass ?? '') == (b.sizeClass ?? '');
    final measuredUnitEqual =
        (a.dimensionUnit?.name ?? '') == (b.dimensionUnit?.name ?? '');
    final valueEqual =
        a.measuredDimension == b.measuredDimension ||
        (a.measuredDimension == null && b.measuredDimension == null);
    return sizeClassEqual && measuredUnitEqual && valueEqual;
  }

  bool _measurementEquals(PopulationMeasurement a, PopulationMeasurement b) =>
      a.unit == b.unit && a.value == b.value;
}

class OrganismRecordChangeSet extends Equatable {
  const OrganismRecordChangeSet({
    this.lifeStageChange,
    this.physicalFormChange,
    this.sizeBandChange,
    this.sizeSpecChange,
    this.quantityChange,
    this.nameChanged = false,
    this.aliasesChanged = false,
    this.ownershipChanged = false,
  });

  final LifeStageChange? lifeStageChange;
  final PhysicalFormChange? physicalFormChange;
  final SizeBandChange? sizeBandChange;
  final SizeSpecChange? sizeSpecChange;
  final QuantityChange? quantityChange;
  final bool nameChanged;
  final bool aliasesChanged;
  final bool ownershipChanged;

  bool get hasChanges =>
      lifeStageChange != null ||
      physicalFormChange != null ||
      sizeBandChange != null ||
      sizeSpecChange != null ||
      quantityChange != null ||
      nameChanged ||
      aliasesChanged ||
      ownershipChanged;

  @override
  List<Object?> get props => [
    lifeStageChange,
    physicalFormChange,
    sizeBandChange,
    sizeSpecChange,
    quantityChange,
    nameChanged,
    aliasesChanged,
    ownershipChanged,
  ];
}

class LifeStageChange extends Equatable {
  const LifeStageChange({
    required this.oldStage,
    required this.newStage,
    this.oldSubtype,
    this.newSubtype,
  });

  final LifeStage oldStage;
  final LifeStage newStage;
  final String? oldSubtype;
  final String? newSubtype;

  @override
  List<Object?> get props => [oldStage, newStage, oldSubtype, newSubtype];
}

class PhysicalFormChange extends Equatable {
  const PhysicalFormChange({
    required this.oldFormId,
    required this.newFormId,
  });

  /// The previous physical form ID (null if not set).
  final String? oldFormId;

  /// The new physical form ID (null if not set).
  final String? newFormId;

  @override
  List<Object?> get props => [oldFormId, newFormId];
}

class SizeBandChange extends Equatable {
  const SizeBandChange({
    required this.oldSizeBandId,
    required this.newSizeBandId,
  });

  final String? oldSizeBandId;
  final String? newSizeBandId;

  @override
  List<Object?> get props => [oldSizeBandId, newSizeBandId];
}

class SizeSpecChange extends Equatable {
  const SizeSpecChange({required this.oldSize, required this.newSize});

  final SizeSpec oldSize;
  final SizeSpec newSize;

  @override
  List<Object?> get props => [oldSize, newSize];
}

class QuantityChange extends Equatable {
  const QuantityChange({
    required this.oldMeasurement,
    required this.newMeasurement,
  });

  final PopulationMeasurement oldMeasurement;
  final PopulationMeasurement newMeasurement;

  double get delta => newMeasurement.value - oldMeasurement.value;

  @override
  List<Object?> get props => [oldMeasurement, newMeasurement];
}

class OrganismRecordImmutabilityException implements Exception {
  const OrganismRecordImmutabilityException({required this.message});

  final String message;

  @override
  String toString() => message;
}
