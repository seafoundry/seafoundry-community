// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/widgets/event_history/event_history_widget.dart';

/// Screen for displaying comprehensive event history
class EventHistoryScreen extends StatefulWidget {
  final String recordId;
  final ModelType recordModelType;

  /// Human-readable name shown in the AppBar (e.g. localId for organisms).
  final String? recordDisplayName;

  const EventHistoryScreen({
    super.key,
    required this.recordId,
    required this.recordModelType,
    this.recordDisplayName,
  });

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<String>? _selectedEventTypes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Event History - ${widget.recordDisplayName ?? widget.recordId.substring(widget.recordId.length > 8 ? widget.recordId.length - 8 : 0)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: EventHistoryWidget(
        recordId: widget.recordId,
        recordModelType: widget.recordModelType,
        recordDisplayName: widget.recordDisplayName,
        startDate: _startDate,
        endDate: _endDate,
        eventTypes: _selectedEventTypes,
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Filter Events'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date range picker
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Date Range'),
                subtitle: Text(
                  _startDate != null && _endDate != null
                      ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                      : 'All dates',
                ),
                onTap: _selectDateRange,
              ),
              const Divider(),
              // Event type filter
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Event Types'),
                subtitle: Text(
                  _selectedEventTypes?.length == null ||
                          _selectedEventTypes!.isEmpty
                      ? 'All event types'
                      : '${_selectedEventTypes!.length} selected',
                ),
                onTap: _selectEventTypes,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _selectedEventTypes = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _selectEventTypes() {
    final builtinEntries = EventType.builtins.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedTypes = Set<String>.from(_selectedEventTypes ?? []);

          return AlertDialog(
            title: const Text('Select Event Types'),
            content: SizedBox(
              width: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: builtinEntries.length,
                itemBuilder: (context, index) {
                  final entry = builtinEntries[index];
                  final isSelected = selectedTypes.contains(entry.key);

                  return CheckboxListTile(
                    title: Text(entry.value.name),
                    value: isSelected,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedTypes.add(entry.key);
                        } else {
                          selectedTypes.remove(entry.key);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    selectedTypes.clear();
                  });
                },
                child: const Text('Clear All'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedEventTypes = selectedTypes.isEmpty
                        ? null
                        : selectedTypes.toList();
                  });
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }
}
