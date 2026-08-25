import 'package:flutter/foundation.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/health_status.dart';

enum InSituGridCellStatus { empty, healthy, warning, critical }

typedef InSituGridCellSelected = void Function(InSituGridCellSummary summary);

@immutable
class InSituGridCoordinate {
  const InSituGridCoordinate({
    required this.rowIndex,
    required this.columnIndex,
  });

  final int rowIndex;
  final int columnIndex;

  String get displayLabel {
    final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + rowIndex);
    final colLabel = (columnIndex + 1).toString();
    return '$rowLabel$colLabel';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InSituGridCoordinate &&
        other.rowIndex == rowIndex &&
        other.columnIndex == columnIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

@immutable
class InSituGridCellSummary {
  const InSituGridCellSummary({
    required this.coordinate,
    required this.coralCount,
    required this.status,
    required this.structure,
    required this.healthBreakdown,
    required this.corals,
  });

  factory InSituGridCellSummary.empty(InSituGridCoordinate coordinate) {
    return InSituGridCellSummary(
      coordinate: coordinate,
      coralCount: 0,
      status: InSituGridCellStatus.empty,
      structure: null,
      healthBreakdown: const <HealthStatus, int>{},
      corals: const <OrganismRecord>[],
    );
  }

  factory InSituGridCellSummary.fromSnapshot({
    required InSituGridCoordinate coordinate,
    required Group? structure,
    required Iterable<OrganismRecord> corals,
  }) {
    final breakdown = <HealthStatus, int>{};
    var coralTotal = 0;
    var hasCritical = false;
    var hasWarning = false;

    for (final organism in corals) {
      final healthStatus = HealthStatus.fromId(organism.metadata?['healthStatus'] as String? ?? 'healthy');
      final quantity = organism.measurement.value.round();
      breakdown.update(
        healthStatus,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
      coralTotal += quantity;
      if (_isCriticalStatus(healthStatus)) {
        hasCritical = true;
      } else if (_isWarningStatus(healthStatus)) {
        hasWarning = true;
      }
    }

    final status = coralTotal == 0
        ? InSituGridCellStatus.empty
        : hasCritical
        ? InSituGridCellStatus.critical
        : hasWarning
        ? InSituGridCellStatus.warning
        : InSituGridCellStatus.healthy;

    return InSituGridCellSummary(
      coordinate: coordinate,
      coralCount: coralTotal,
      status: status,
      structure: structure,
      healthBreakdown: Map.unmodifiable(breakdown),
      corals: List.unmodifiable(corals),
    );
  }

  factory InSituGridCellSummary.fromCorals({
    required InSituGridCoordinate coordinate,
    required Iterable<OrganismRecord> corals,
  }) {
    return InSituGridCellSummary.fromSnapshot(
      coordinate: coordinate,
      structure: null,
      corals: corals,
    );
  }

  final InSituGridCoordinate coordinate;
  final int coralCount;
  final InSituGridCellStatus status;
  final Group? structure;
  final Map<HealthStatus, int> healthBreakdown;
  final List<OrganismRecord> corals;

  bool get hasStructure => structure != null;

  bool get hasCorals => coralCount > 0;

  String get structureName {
    final name = structure?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return hasStructure ? 'Structure' : 'Open position';
  }

  String? get structureTypeLabel {
    if (structure == null) return null;
    final typeName = structure!.groupType.name.trim();
    return typeName.isEmpty ? null : typeName;
  }

  String get statusLabel {
    switch (status) {
      case InSituGridCellStatus.empty:
        return 'Empty';
      case InSituGridCellStatus.healthy:
        return 'Healthy';
      case InSituGridCellStatus.warning:
        return 'Watch';
      case InSituGridCellStatus.critical:
        return 'Critical';
    }
  }

  String get occupancyLabel {
    if (!hasCorals) {
      return hasStructure ? 'No corals assigned' : 'Tap to assign a structure';
    }
    final suffix = coralCount == 1 ? 'coral' : 'corals';
    return '$coralCount $suffix';
  }

  static bool _isCriticalStatus(HealthStatus status) {
    return status == HealthStatus.diseased ||
        status == HealthStatus.deceased ||
        status == HealthStatus.lost;
  }

  static bool _isWarningStatus(HealthStatus status) {
    return status == HealthStatus.stressed ||
        status == HealthStatus.bleached ||
        status == HealthStatus.damaged ||
        status == HealthStatus.unknown ||
        status == HealthStatus.fragmented;
  }
}
