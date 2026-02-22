// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Represents a gamete collection entry in the spawn dialog.
///
/// Each entry tracks whether the collection is enabled, the quantity collected,
/// physical form/size details, record naming, and destination group.
/// The gamete role (egg/sperm) determines whether this is a dam or sire collection.
class GameteCollectionEntry extends Equatable {
  const GameteCollectionEntry({
    required this.gameteRole,
    this.enabled = false,
    this.count,
    this.physicalFormId,
    this.sizeSpec,
    this.recordName,
    this.destinationGroup,
  });

  /// The role of this gamete collection (egg for dam, sperm for sire).
  final ProvenanceGameteRole gameteRole;

  /// Whether this gamete collection is enabled.
  final bool enabled;

  /// Number of containers collected.
  final int? count;

  /// Physical form ID for the gamete inventory record.
  final String? physicalFormId;

  /// Size specification for the gamete.
  final SizeSpec? sizeSpec;

  /// User-specified or auto-generated record name.
  final String? recordName;

  /// Destination group for the gamete inventory record.
  final GroupNode? destinationGroup;

  /// Whether this entry has all required fields filled.
  bool get isComplete {
    if (!enabled) return true; // Disabled entries are always "complete"
    return count != null &&
        count! > 0 &&
        physicalFormId != null &&
        physicalFormId!.isNotEmpty &&
        destinationGroup != null;
  }

  /// Creates a copy of this entry with the given fields replaced.
  GameteCollectionEntry copyWith({
    ProvenanceGameteRole? gameteRole,
    bool? enabled,
    int? count,
    bool clearCount = false,
    String? physicalFormId,
    bool clearPhysicalFormId = false,
    SizeSpec? sizeSpec,
    bool clearSizeSpec = false,
    String? recordName,
    bool clearRecordName = false,
    GroupNode? destinationGroup,
    bool clearDestinationGroup = false,
  }) {
    return GameteCollectionEntry(
      gameteRole: gameteRole ?? this.gameteRole,
      enabled: enabled ?? this.enabled,
      count: clearCount ? null : (count ?? this.count),
      physicalFormId: clearPhysicalFormId
          ? null
          : (physicalFormId ?? this.physicalFormId),
      sizeSpec: clearSizeSpec ? null : (sizeSpec ?? this.sizeSpec),
      recordName: clearRecordName ? null : (recordName ?? this.recordName),
      destinationGroup: clearDestinationGroup
          ? null
          : (destinationGroup ?? this.destinationGroup),
    );
  }

  @override
  List<Object?> get props => [
        gameteRole,
        enabled,
        count,
        physicalFormId,
        sizeSpec,
        recordName,
        destinationGroup,
      ];
}

/// Creates default dam (egg) gamete collection entry.
GameteCollectionEntry createDamGameteEntry() {
  return const GameteCollectionEntry(gameteRole: ProvenanceGameteRole.egg);
}

/// Creates default sire (sperm) gamete collection entry.
GameteCollectionEntry createSireGameteEntry() {
  return const GameteCollectionEntry(gameteRole: ProvenanceGameteRole.sperm);
}
