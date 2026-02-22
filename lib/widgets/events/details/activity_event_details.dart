// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'base_event_details.dart';

/// Widget for displaying activity event details
class ActivityEventDetails extends BaseEventDetails {
  ActivityEventDetails({super.key, required ActivityEvent event})
    : super(
        event: event,
        icon: _getIconForActivityType(event.activityType),
        title: _getTitleForActivityType(event.activityType),
      );

  ActivityEvent get activityEvent => event as ActivityEvent;

  static IconData _getIconForActivityType(String activityType) {
    if (activityType.startsWith('health_')) return Icons.favorite_outline;
    if (activityType.contains('disease')) return Icons.sick_outlined;
    if (activityType.contains('pest')) return Icons.pest_control_outlined;
    if (activityType.contains('biofouling')) return Icons.bug_report_outlined;
    if (activityType.contains('discoloration')) return Icons.palette_outlined;
    if (activityType.contains('maintenance')) return Icons.build_outlined;
    if (activityType.contains('outplant')) return Icons.nature_outlined;
    if (activityType.contains('propagation')) return Icons.content_cut_outlined;
    if (activityType == 'observation') return Icons.camera_alt_outlined;
    if (activityType == 'husbandry_task') return Icons.task_outlined;
    if (activityType == 'spawning') return Icons.bubble_chart_outlined;
    if (activityType == 'feeding') return Icons.restaurant_outlined;
    if (activityType == 'water_quality_test') return Icons.water_drop_outlined;
    return Icons.local_activity;
  }

  static String _getTitleForActivityType(String activityType) {
    if (activityType == 'health_observation') return 'Health Observation';
    if (activityType == 'health_issue_disease') return 'Disease Detected';
    if (activityType == 'health_issue_biofouling') return 'Biofouling Detected';
    if (activityType == 'health_issue_pest') return 'Pest Detected';
    if (activityType == 'health_issue_discoloration') {
      return 'Discoloration Detected';
    }
    if (activityType == 'health_issue_maintenance_needed') {
      return 'Maintenance Required';
    }
    if (activityType == 'discoloration_observation') {
      return 'Discoloration Observation';
    }
    if (activityType == 'disease_observation') return 'Disease Observation';
    if (activityType == 'biofouling_observation') {
      return 'Biofouling Observation';
    }
    if (activityType == 'pest_observation') {
      return 'Pest Observation';
    }
    if (activityType == 'maintenance_required_observation') {
      return 'Maintenance Observation';
    }
    if (activityType == 'outplant_ready') {
      return 'Outplant Readiness Updated';
    }
    if (activityType == 'propagation_ready') {
      return 'Propagation Readiness Updated';
    }
    if (activityType == 'observation') return 'Observation Recorded';
    if (activityType == 'husbandry_task') return 'Husbandry Task Created';
    if (activityType == 'spawning') return 'Spawning Event';
    if (activityType == 'feeding') return 'Feeding Activity';
    if (activityType == 'water_quality_test') return 'Water Quality Test';

    // Default: format nicely
    return activityType
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.blue);

  @override
  Widget buildEventContent(BuildContext context) {
    final params = activityEvent.parameters ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Activity Type
        EventDetailRow(
          label: 'Activity Type',
          value: _formatActivityType(activityEvent.activityType),
          icon: Icons.local_activity,
        ),

        // Health Status Changes
        if (params['oldHealthStatus'] != null &&
            params['newHealthStatus'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Health Status Change',
            value:
                '${params['oldHealthStatus']} → ${params['newHealthStatus']}',
            icon: Icons.favorite_outline,
          ),
        ],

        // Outplant readiness changes
        if (params['oldReadyForOutplant'] != null &&
            params['newReadyForOutplant'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Outplant Readiness',
            value:
                _formatReadyValue(params['oldReadyForOutplant']) +
                ' → ' +
                _formatReadyValue(params['newReadyForOutplant']),
            icon: Icons.nature_outlined,
          ),
        ],

        // Propagation readiness changes
        if (params['oldReadyForPropagation'] != null &&
            params['newReadyForPropagation'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Propagation Readiness',
            value:
                _formatReadyValue(params['oldReadyForPropagation']) +
                ' → ' +
                _formatReadyValue(params['newReadyForPropagation']),
            icon: Icons.content_cut_outlined,
          ),
        ],

        // Health Issue Type
        if (params['healthIssueTypeId'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Health Issue',
            value: params['healthIssueTypeId'],
            icon: Icons.warning_outlined,
          ),
        ],

        // Task Information
        if (params['taskTitle'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Task',
            value: params['taskTitle'],
            icon: Icons.task_outlined,
          ),
        ],
        if (params['husbandryActionTypeId'] != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Action Type',
            value: params['husbandryActionTypeId'],
            icon: Icons.construction_outlined,
          ),
        ],
        if (params['priorityId'] != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Priority',
            value: params['priorityId'],
            icon: Icons.priority_high_outlined,
          ),
        ],

        // Spawning Information
        if (params['gameteCount'] != null) ...[
          SizedBox(height: Spacing.sm),
          EventDetailRow(
            label: 'Amount Collected',
            value: '${params['gameteCount']}',
            icon: Icons.bubble_chart_outlined,
          ),
        ],
        if (params['parentCoralIds'] != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Parent Corals',
            value: '${(params['parentCoralIds'] as List).length} parent(s)',
            icon: Icons.family_restroom_outlined,
          ),
        ],

        // Description
        if (activityEvent.description != null &&
            activityEvent.description!.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIText.caption('Description:', color: AppColors.textSecondary),
              SizedBox(height: Spacing.xs),
              UIText.bodyMedium(activityEvent.description!),
            ],
          ),
        ],

        // Debug Information Panel (collapsible)
        if (_hasDebugInfo(params)) ...[
          SizedBox(height: Spacing.md),
          _DebugInfoPanel(params: params, event: activityEvent),
        ],
      ],
    );
  }

  bool _hasDebugInfo(Map<String, dynamic> params) {
    return params['sourceRecordId'] != null ||
        params['sourceEventId'] != null ||
        _hasOtherParameters(params);
  }

  bool _hasOtherParameters(Map<String, dynamic> params) {
    final knownKeys = {
      'sourceRecordType',
      'sourceRecordId',
      'sourceEventId',
      'oldHealthStatus',
      'newHealthStatus',
      'oldReadyForOutplant',
      'newReadyForOutplant',
      'oldReadyForPropagation',
      'newReadyForPropagation',
      'healthIssueTypeId',
      'taskTitle',
      'husbandryActionTypeId',
      'priorityId',
      'isCompleted',
      'gameteCount',
      'parentCoralIds',
    };
    return params.keys.any((key) => !knownKeys.contains(key));
  }

  String _formatActivityType(String activityType) {
    return activityType
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  String _formatReadyValue(dynamic raw) {
    final isReady = raw == true || raw == 'true';
    return isReady ? 'Ready' : 'Not Ready';
  }
}

/// Collapsible debug information panel
class _DebugInfoPanel extends StatefulWidget {
  final Map<String, dynamic> params;
  final ActivityEvent event;

  const _DebugInfoPanel({required this.params, required this.event});

  @override
  State<_DebugInfoPanel> createState() => _DebugInfoPanelState();
}

class _DebugInfoPanelState extends State<_DebugInfoPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(Spacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.code_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: Spacing.sm),
                  Expanded(
                    child: UIText.caption(
                      'Debug Information',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
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
                  // Source Record ID
                  if (widget.params['sourceRecordType'] != null &&
                      widget.params['sourceRecordId'] != null) ...[
                    _buildDebugRow(
                      'Source Record',
                      '${widget.params['sourceRecordType']} (${widget.params['sourceRecordId']})',
                    ),
                    SizedBox(height: Spacing.xs),
                  ],

                  // Source Event ID
                  if (widget.params['sourceEventId'] != null) ...[
                    _buildDebugRow(
                      'Source Event ID',
                      widget.params['sourceEventId'],
                    ),
                    SizedBox(height: Spacing.xs),
                  ],

                  // Activity Event ID
                  _buildDebugRow('Activity Event ID', widget.event.id),

                  // Record ID (where this activity is stored)
                  SizedBox(height: Spacing.xs),
                  _buildDebugRow('Record ID', widget.event.recordId),

                  // Other parameters
                  if (_hasOtherParameters()) ...[
                    SizedBox(height: Spacing.sm),
                    Divider(height: 1),
                    SizedBox(height: Spacing.sm),
                    UIText.caption(
                      'Other Parameters:',
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: Spacing.xs),
                    ..._buildOtherParameters(),
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
        SizedBox(
          width: 140,
          child: UIText.bodySmall('$label:', color: AppColors.textSecondary),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasOtherParameters() {
    final knownKeys = {
      'sourceRecordType',
      'sourceRecordId',
      'sourceEventId',
      'oldHealthStatus',
      'newHealthStatus',
      'healthIssueTypeId',
      'taskTitle',
      'husbandryActionTypeId',
      'priorityId',
      'isCompleted',
      'gameteCount',
      'parentCoralIds',
    };
    return widget.params.keys.any((key) => !knownKeys.contains(key));
  }

  List<Widget> _buildOtherParameters() {
    final knownKeys = {
      'sourceRecordType',
      'sourceRecordId',
      'sourceEventId',
      'oldHealthStatus',
      'newHealthStatus',
      'healthIssueTypeId',
      'taskTitle',
      'husbandryActionTypeId',
      'priorityId',
      'isCompleted',
      'gameteCount',
      'parentCoralIds',
    };

    final otherParams = Map.fromEntries(
      widget.params.entries.where((e) => !knownKeys.contains(e.key)),
    );

    return otherParams.entries.map((entry) {
      return Padding(
        padding: EdgeInsets.only(bottom: Spacing.xs),
        child: _buildDebugRow(_formatKey(entry.key), entry.value.toString()),
      );
    }).toList();
  }

  String _formatKey(String key) {
    return key
        .split(RegExp(r'(?=[A-Z])|_'))
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
