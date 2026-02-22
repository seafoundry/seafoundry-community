// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/user.dart';

/// Bottom sheet for selecting crew members for a mission.
class MissionCrewSelectorSheet extends StatefulWidget {
  const MissionCrewSelectorSheet({
    super.key,
    required this.availableCrew,
    required this.selectedCrewIds,
    required this.onSelectionChanged,
  });

  final List<User> availableCrew;
  final List<String> selectedCrewIds;
  final ValueChanged<List<String>> onSelectionChanged;

  /// Shows the crew selector bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<User> availableCrew,
    required List<String> selectedCrewIds,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MissionCrewSelectorSheet(
        availableCrew: availableCrew,
        selectedCrewIds: selectedCrewIds,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }

  @override
  State<MissionCrewSelectorSheet> createState() =>
      _MissionCrewSelectorSheetState();
}

class _MissionCrewSelectorSheetState extends State<MissionCrewSelectorSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.selectedCrewIds);
  }

  void _toggleSelection(String userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(userId);
      } else {
        _selectedIds.remove(userId);
      }
    });
    widget.onSelectionChanged(_selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.availableCrew.length,
                  itemBuilder: (_, index) {
                    final user = widget.availableCrew[index];
                    final isSelected = _selectedIds.contains(user.id);
                    return CheckboxListTile(
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      value: isSelected,
                      onChanged: (val) => _toggleSelection(user.id, val == true),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Crew',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
