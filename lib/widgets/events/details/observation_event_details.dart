// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/components/core/loading_indicator.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/types/observation_severity.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'base_event_details.dart';

/// Widget for displaying observation event details
class ObservationEventDetails extends BaseEventDetails {
  ObservationEventDetails({super.key, required ObservationEvent event})
    : super(event: event, icon: _getIconForObservationType(event), title: _getTitleForObservationType(event));

  ObservationEvent get observationEvent => event as ObservationEvent;

  static IconData _getIconForObservationType(ObservationEvent event) {
    if (event.oldHealthStatus != null) {
      return Icons.favorite_outline;
    }
    final eventTypeId = event.eventTypeId;
    if (eventTypeId.contains('disease')) {
      return Icons.sick_outlined;
    }
    if (eventTypeId.contains('pest')) {
      return Icons.pest_control_outlined;
    }
    if (eventTypeId.contains('biofouling')) {
      return Icons.pest_control_outlined;
    }
    if (eventTypeId.contains('discoloration')) {
      return Icons.palette_outlined;
    }
    if (eventTypeId.contains('maintenance')) {
      return Icons.build_outlined;
    }
    return Icons.visibility;
  }

  static String _getTitleForObservationType(ObservationEvent event) {
    if (event.oldHealthStatus != null) {
      return 'Health Status Change';
    }
    final eventTypeId = event.eventTypeId;
    if (eventTypeId.contains('disease')) {
      return 'Disease Observation';
    }
    if (eventTypeId.contains('pest')) {
      return 'Pest Observation';
    }
    if (eventTypeId.contains('biofouling')) {
      return 'Biofouling Observation';
    }
    if (eventTypeId.contains('discoloration')) {
      return 'Discoloration Observation';
    }
    if (eventTypeId.contains('maintenance')) {
      return 'Maintenance Required';
    }
    return 'Observation';
  }

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.amber);

  @override
  Widget buildEventContent(BuildContext context) {
    final hasImageUrl = observationEvent.imageUrl != null &&
        observationEvent.imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health Status Changes
        if (observationEvent.oldHealthStatus != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UIText.caption('Health Status Change:', color: AppColors.textSecondary),
                    SizedBox(height: Spacing.xs),
                    UIText.bodyMedium('${observationEvent.oldHealthStatus} → ${observationEvent.newHealthStatus}'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Spacing.sm),
        ],

        // Observation Type
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.category_outlined, size: 16, color: AppColors.textSecondary),
            SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UIText.caption('Observation Type:', color: AppColors.textSecondary),
                  SizedBox(height: Spacing.xs),
                  UIText.bodyMedium(_formatObservationType(observationEvent.eventTypeId)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: Spacing.sm),

        ..._buildObservationSpecificDetails(observationEvent),

        // Comment
        if (observationEvent.comment != null && observationEvent.comment!.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIText.caption('Notes:', color: AppColors.textSecondary),
              SizedBox(height: Spacing.xs),
              UIText.bodyMedium(observationEvent.comment!),
            ],
          ),
        ],

        // Images - support both legacy imageUrl and new imageAttachments
        if (hasImageUrl ||
            (observationEvent is MonitoringEventRecord &&
                (observationEvent as MonitoringEventRecord)
                    .imageAttachments
                    .isNotEmpty)) ...[
          SizedBox(height: Spacing.md),
          _buildImageSection(context),
        ],

        // Debug Information Panel (collapsible)
        if (_hasDebugInfo()) ...[SizedBox(height: Spacing.md), _DebugInfoPanel(event: observationEvent)],
      ],
    );
  }

  List<Widget> _buildObservationSpecificDetails(ObservationEvent event) {
    final rows = <Widget>[];

    if (event is DiseaseObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.local_hospital_outlined,
          label: 'Disease',
          value: event.diseaseType.name,
        ),
        _buildDetailRow(
          icon: Icons.warning_amber_outlined,
          label: 'Severity',
          value: event.severityLevel.displayName,
        ),
        if (event.affectedPercentage != null)
          _buildDetailRow(
            icon: Icons.percent,
            label: 'Affected',
            value: '${event.affectedPercentage!.toStringAsFixed(0)}%',
          ),
        _buildDetailRow(
          icon: Icons.healing_outlined,
          label: 'Treatment initiated',
          value: event.treatmentInitiated ? 'Yes' : 'No',
        ),
      ]);
    } else if (event is PestObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.pest_control_outlined,
          label: 'Pest',
          value: event.pestType.label,
        ),
        _buildDetailRow(
          icon: Icons.warning_amber_outlined,
          label: 'Severity',
          value: event.severityLevel.displayName,
        ),
        if (event.location != null && event.location!.isNotEmpty)
          _buildDetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: event.location!,
          ),
        _buildDetailRow(
          icon: Icons.cleaning_services_outlined,
          label: 'Mitigation performed',
          value: event.mitigationPerformed ? 'Yes' : 'No',
        ),
      ]);
    } else if (event is BiofoulingObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.science_outlined,
          label: 'Biofouling',
          value: event.biofoulingType.label,
        ),
        _buildDetailRow(
          icon: Icons.warning_amber_outlined,
          label: 'Severity',
          value: event.severityLevel.displayName,
        ),
        if (event.location != null && event.location!.isNotEmpty)
          _buildDetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: event.location!,
          ),
        _buildDetailRow(
          icon: Icons.cleaning_services_outlined,
          label: 'Cleaning performed',
          value: event.cleaningPerformed ? 'Yes' : 'No',
        ),
      ]);
    } else if (event is DiscolorationObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.palette_outlined,
          label: 'Type',
          value: event.discolorationType.label,
        ),
        _buildDetailRow(
          icon: Icons.layers_outlined,
          label: 'Extent',
          value: event.extentLevel.label,
        ),
        if (event.affectedPercentage != null)
          _buildDetailRow(
            icon: Icons.percent,
            label: 'Affected',
            value: '${event.affectedPercentage!.toStringAsFixed(0)}%',
          ),
        if (event.trend != null && event.trend!.isNotEmpty)
          _buildDetailRow(
            icon: Icons.trending_up_outlined,
            label: 'Trend',
            value: _formatObservationType(event.trend!),
          ),
      ]);
    } else if (event is MaintenanceRequiredObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.build_outlined,
          label: 'Maintenance',
          value: event.maintenanceType.label,
        ),
        _buildDetailRow(
          icon: Icons.flag_outlined,
          label: 'Priority',
          value: _formatObservationType(event.priority),
        ),
        _buildDetailRow(
          icon: Icons.check_circle_outline,
          label: 'Completed',
          value: event.completed ? 'Yes' : 'No',
        ),
      ]);
    } else if (event is ThermalStressObservationEvent) {
      rows.addAll([
        _buildDetailRow(
          icon: Icons.warning_amber_outlined,
          label: 'Severity',
          value: (ObservationSeverity.tryParse(event.severity) ??
                  ObservationSeverity.moderate)
              .displayName,
        ),
        if (event.affectedPercentage != null)
          _buildDetailRow(
            icon: Icons.percent,
            label: 'Affected',
            value: '${event.affectedPercentage!.toStringAsFixed(0)}%',
          ),
      ]);
    }

    if (rows.isEmpty) {
      return const [];
    }

    return [
      ...rows,
      SizedBox(height: Spacing.sm),
    ];
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UIText.caption('$label:', color: AppColors.textSecondary),
                SizedBox(height: Spacing.xs),
                UIText.bodyMedium(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasDebugInfo() {
    return observationEvent.oldHealthStatus != null ||
        (observationEvent.imageUrl != null &&
            observationEvent.imageUrl!.isNotEmpty);
  }

  String _formatObservationType(String typeId) {
    return typeId.split('_').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Widget _buildImageSection(BuildContext context) {
    // Check if this is a MonitoringEventRecord with imageAttachments
    if (observationEvent is MonitoringEventRecord) {
      final monitoringEvent = observationEvent as MonitoringEventRecord;
      if (monitoringEvent.imageAttachments.isNotEmpty) {
        return _buildImageAttachmentsSection(context, monitoringEvent);
      }
    }

    // Fall back to legacy imageUrl
    if (observationEvent.imageUrl != null &&
        observationEvent.imageUrl!.isNotEmpty) {
      return _buildSingleImage(context, observationEvent.imageUrl!);
    }

    return const SizedBox.shrink();
  }

  /// Builds a section displaying multiple image attachments
  Widget _buildImageAttachmentsSection(
    BuildContext context,
    MonitoringEventRecord event,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIText.caption(
          'Images (${event.imageAttachments.length})',
          color: AppColors.textSecondary,
        ),
        SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: event.imageAttachments.map((attachment) {
            return SizedBox(
              width: 150,
              height: 150,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSingleImage(context, attachment.imageUrl),
                    ),
                    Padding(
                      padding: EdgeInsets.all(Spacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (attachment.isOrthomosaic)
                            Row(
                              children: [
                                Icon(Icons.map, size: 12, color: Colors.orange),
                                SizedBox(width: 4),
                                Expanded(
                                  child: UIText.bodySmall(
                                    'Orthomosaic',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          if (attachment.hasSpecificTargets)
                            UIText.bodySmall(
                              '${attachment.coralIds.length + attachment.groupIds.length} targets',
                              color: AppColors.textSecondary,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Builds a single image widget with loading and error states
  Widget _buildSingleImage(BuildContext context, String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            color: AppColors.disabled.withValues(alpha: 0.1),
            child: Center(
              child: LoadingIndicator(
                message: 'Loading image...',
                size: 24.0,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            color: AppColors.disabled.withValues(alpha: 0.1),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Collapsible debug information panel for observation events
class _DebugInfoPanel extends StatefulWidget {
  final ObservationEvent event;

  const _DebugInfoPanel({required this.event});

  @override
  State<_DebugInfoPanel> createState() => _DebugInfoPanelState();
}

class _DebugInfoPanelState extends State<_DebugInfoPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.disabled),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.all(Spacing.sm),
              child: Row(
                children: [
                  Icon(Icons.code_outlined, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: Spacing.sm),
                  Expanded(child: UIText.caption('Debug Information', color: AppColors.textSecondary)),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Type ID
                  _buildDebugRow('Event Type ID', widget.event.eventTypeId),
                  SizedBox(height: Spacing.xs),

                  // Old Health Status
                  if (widget.event.oldHealthStatus != null) ...[
                    _buildDebugRow('Old Health Status', widget.event.oldHealthStatus ?? ''),
                    SizedBox(height: Spacing.xs),
                  ],

                  // New Health Status
                  if (widget.event.newHealthStatus != null) ...[
                    _buildDebugRow('New Health Status', widget.event.newHealthStatus ?? ''),
                    SizedBox(height: Spacing.xs),
                  ],

                  // Observation Event ID
                  _buildDebugRow('Event ID', widget.event.id),

                  // Record ID
                  SizedBox(height: Spacing.xs),
                  _buildDebugRow('Record ID', widget.event.recordId),

                  // Image URL
                  if (widget.event.imageUrl != null) ...[
                    SizedBox(height: Spacing.xs),
                    _buildDebugRow('Image URL', widget.event.imageUrl ?? ''),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: UIText.bodySmall('$label:', color: AppColors.textSecondary)),
        Expanded(child: UIText.bodySmall(value, color: AppColors.textPrimary)),
      ],
    );
  }
}
