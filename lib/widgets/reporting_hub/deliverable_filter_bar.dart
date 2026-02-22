// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/reporting_hub/reporting_hub.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// Filter bar for deliverables list
class DeliverableFilterBar extends StatelessWidget {
  const DeliverableFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Text('Filter:', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: BlocSelector<DeliverablesTabCubit, DeliverablesTabState,
                  DeliverableStatus?>(
                selector: (state) => state.statusFilter,
                builder: (context, statusFilter) {
                  final cubit = context.read<DeliverablesTabCubit>();
                  return Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: statusFilter == null,
                        onSelected: () => cubit.setStatusFilter(null),
                      ),
                      const SizedBox(width: 8),
                      ...DeliverableStatus.values.map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: status.displayName,
                            isSelected: statusFilter == status,
                            onSelected: () => cubit.setStatusFilter(status),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
    );
  }
}
