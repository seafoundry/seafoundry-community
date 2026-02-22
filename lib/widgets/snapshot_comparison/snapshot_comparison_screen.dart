// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/common/tier_paywall.dart';
import 'package:seafoundry_app/widgets/snapshot_comparison/snapshot_comparison_widget.dart';

/// Screen for displaying snapshot comparisons
class SnapshotComparisonScreen extends StatefulWidget {
  final String recordId;
  final ModelType recordModelType;

  /// Human-readable name shown in the AppBar (e.g. localId for organisms).
  final String? recordDisplayName;

  const SnapshotComparisonScreen({
    super.key,
    required this.recordId,
    required this.recordModelType,
    this.recordDisplayName,
  });

  @override
  State<SnapshotComparisonScreen> createState() =>
      _SnapshotComparisonScreenState();
}

class _SnapshotComparisonScreenState extends State<SnapshotComparisonScreen> {
  DateTime? _pointInTime1;
  DateTime? _pointInTime2;
  String? _recordName;

  @override
  void initState() {
    super.initState();
    // Set default time points (1 week ago and now)
    final now = DateTime.now();
    _pointInTime1 = now.subtract(const Duration(days: 7));
    _pointInTime2 = now;
    _recordName = widget.recordDisplayName;
    if (_recordName == null) _fetchRecordName();
  }

  Future<void> _fetchRecordName() async {
    try {
      final repository = context.read<OrganismRecordRepository>();
      final record = await repository.getRecordForId(widget.recordId);
      if (mounted && record != null) {
        setState(() => _recordName = record.name);
      }
    } catch (e) {
      // Fall back to showing ID
    }
  }

  @override
  Widget build(BuildContext context) {
    final featureAccess = context.watch<FeatureAccessService>();
    final hasAccess = featureAccess.isFeatureEnabled('snapshot_comparison');

    if (!hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Snapshot Comparison'),
        ),
        body: const TierPaywall(
          title: 'Snapshot Comparison - coming soon',
          subtitle:
              'Upgrade to compare historical states and analyze changes over time.',
          featureName: 'Snapshot Comparison',
          requiredTier: Tier.pro,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Snapshot Comparison - ${_recordName ?? widget.recordId.substring(widget.recordId.length > 8 ? widget.recordId.length - 8 : 0)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _showTimePickerDialog,
          ),
        ],
      ),
      body: _pointInTime1 != null && _pointInTime2 != null
          ? SnapshotComparisonWidget(
              recordId: widget.recordId,
              recordModelType: widget.recordModelType,
              pointInTime1: _pointInTime1!,
              pointInTime2: _pointInTime2!,
            )
          : const Center(
              child: Text('Please select time points for comparison'),
            ),
    );
  }

  void _showTimePickerDialog() {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Points'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Point in time 1
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Point in Time 1'),
                subtitle: Text(
                  _pointInTime1 != null
                      ? '${_pointInTime1!.day}/${_pointInTime1!.month}/${_pointInTime1!.year} ${_pointInTime1!.hour}:${_pointInTime1!.minute.toString().padLeft(2, '0')}'
                      : 'Not selected',
                ),
                onTap: () => _selectDateTime(1),
              ),
              const Divider(),
              // Point in time 2
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Point in Time 2'),
                subtitle: Text(
                  _pointInTime2 != null
                      ? '${_pointInTime2!.day}/${_pointInTime2!.month}/${_pointInTime2!.year} ${_pointInTime2!.hour}:${_pointInTime2!.minute.toString().padLeft(2, '0')}'
                      : 'Not selected',
                ),
                onTap: () => _selectDateTime(2),
              ),
              const SizedBox(height: 16),
              // Quick presets
              const Text(
                'Quick Presets:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildPresetButton('1 Day', () => _setPreset(1)),
                  _buildPresetButton('1 Week', () => _setPreset(7)),
                  _buildPresetButton('1 Month', () => _setPreset(30)),
                  _buildPresetButton('3 Months', () => _setPreset(90)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime(int pointNumber) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: pointNumber == 1 ? _pointInTime1 : _pointInTime2,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (pickedTime == null) return;

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (pointNumber == 1) {
        _pointInTime1 = selectedDateTime;
      } else {
        _pointInTime2 = selectedDateTime;
      }
    });
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  void _setPreset(int days) {
    final now = DateTime.now();
    setState(() {
      _pointInTime1 = now.subtract(Duration(days: days));
      _pointInTime2 = now;
    });
  }
}
