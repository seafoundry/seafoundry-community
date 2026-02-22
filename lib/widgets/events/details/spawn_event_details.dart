// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/common/organism_reference_links.dart';
import 'base_event_details.dart';

/// Widget for displaying spawn event details
class SpawnEventDetails extends BaseEventDetails {
  const SpawnEventDetails({
    super.key,
    required SpawnEvent event,
    this.relatedOrganismRecords = const {},
  }) : super(event: event, icon: Icons.bubble_chart, title: 'Spawning Event');

  SpawnEvent get spawnEvent => event as SpawnEvent;
  final Map<String, OrganismRecord?> relatedOrganismRecords;

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.cyan);

  @override
  Widget buildEventContent(BuildContext context) {
    final gameteRole = spawnEvent.gameteRole;
    final parentOrganismLabels = _resolveOrganismLabels(
      spawnEvent.parentOrganismIds,
      relatedOrganismRecords,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(
          label: 'Amount Collected',
          value: spawnEvent.gameteCount.toString(),
          icon: Icons.bubble_chart,
        ),
        if (gameteRole != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Gamete Type',
            value: gameteRole == ProvenanceGameteRole.egg ? 'Eggs' : 'Sperm',
            icon: Icons.science_outlined,
          ),
        ],
        if (parentOrganismLabels.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          EventDetailList(
            label: 'Parent Organisms',
            items: parentOrganismLabels,
          ),
        ],
      ],
    );
  }
}

/// Widget for displaying cross event details
class CrossEventDetails extends BaseEventDetails {
  const CrossEventDetails({
    super.key,
    required CrossEvent event,
    this.relatedOrganismRecords = const {},
  }) : super(event: event, icon: Icons.merge_type, title: 'Cross Event');

  CrossEvent get crossEvent => event as CrossEvent;
  final Map<String, OrganismRecord?> relatedOrganismRecords;

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.pink);

  @override
  Widget buildEventContent(BuildContext context) {
    final damLabels = _resolveOrganismLabels(
      crossEvent.damIds,
      relatedOrganismRecords,
    );
    final sireLabels = _resolveOrganismLabels(
      crossEvent.sireIds,
      relatedOrganismRecords,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (damLabels.isNotEmpty) ...[
          EventDetailList(label: 'Dam IDs', items: damLabels),
        ],
        if (sireLabels.isNotEmpty) ...[
          if (damLabels.isNotEmpty) SizedBox(height: Spacing.sm),
          EventDetailList(label: 'Sire IDs', items: sireLabels),
        ],
      ],
    );
  }
}

/// Widget for displaying settle event details
class SettleEventDetails extends BaseEventDetails {
  const SettleEventDetails({super.key, required SettleEvent event})
    : super(event: event, icon: Icons.foundation, title: 'Settlement');

  SettleEvent get settleEvent => event as SettleEvent;

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.teal);

  @override
  Widget buildEventContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(label: 'Cross Event ID', value: settleEvent.crossEventId),
        if (settleEvent.settledCount != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(label: 'Settled Count', value: settleEvent.settledCount.toString()),
        ],
      ],
    );
  }
}

List<String> _resolveOrganismLabels(
  List<String> organismIds,
  Map<String, OrganismRecord?> relatedOrganismRecords,
) {
  if (organismIds.isEmpty) return const [];
  return organismIds
      .map(
        (id) {
          final record = relatedOrganismRecords[id];
          if (record == null) return id;
          final recordName = _sanitizeLabel(record.recordName);
          final localId = _sanitizeLabel(record.localId);
          return formatOrganismReferenceLabel(
            localId: localId,
            recordName: recordName,
            fallback: record.id,
          );
        },
      )
      .toList();
}

String? _sanitizeLabel(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == Missing.string) {
    return null;
  }
  return trimmed;
}
