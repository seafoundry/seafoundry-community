// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/reporting_hub/reporting_hub.dart';
import 'package:seafoundry_app/models/operations/funder.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';
import 'package:seafoundry_app/widgets/dialogs/funder_edit_dialog.dart';
import 'package:seafoundry_app/widgets/reporting_hub/funder_deliverable_list_item.dart';

/// Card widget for displaying a funder with expandable deliverables list
class FunderCard extends StatelessWidget {
  final Funder funder;

  const FunderCard({super.key, required this.funder});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FundersTabCubit>();

    return BlocSelector<FundersTabCubit, FundersTabState, bool>(
      selector: (state) => state.isExpanded(funder.id),
      builder: (context, isExpanded) {
        return Card(
          child: ExpansionTile(
            key: PageStorageKey(funder.id),
            initiallyExpanded: isExpanded,
            onExpansionChanged: (_) => cubit.toggleExpanded(funder.id),
            leading: Icon(
              Icons.monetization_on,
              size: 32,
              color: funder.isActive ? Colors.green : Colors.grey,
            ),
            title: Text(funder.name),
            subtitle: Row(
              children: [
                if (!funder.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label:
                          const Text('Inactive', style: TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Expanded(
                  child: Text(
                    funder.contactName ?? 'No contact info',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => FunderEditDialog.show(context, funder: funder),
            ),
            children: [
              _FunderDeliverablesList(funderId: funder.id),
            ],
          ),
        );
      },
    );
  }
}

class _FunderDeliverablesList extends StatelessWidget {
  final String funderId;

  const _FunderDeliverablesList({required this.funderId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FundersTabCubit, FundersTabState, _DeliverableListData>(
      selector: (state) => _DeliverableListData(
        deliverables: state.getDeliverables(funderId),
        isLoading: state.isLoadingDeliverables(funderId),
      ),
      builder: (context, data) {
        if (data.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final deliverables = data.deliverables;
        if (deliverables.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No deliverables associated with this funder'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Associated Deliverables (${deliverables.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...deliverables.map((d) => FunderDeliverableListItem(deliverable: d)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// Helper class to group deliverable list data for BlocSelector
class _DeliverableListData {
  final List<Deliverable> deliverables;
  final bool isLoading;

  const _DeliverableListData({
    required this.deliverables,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DeliverableListData &&
          runtimeType == other.runtimeType &&
          deliverables == other.deliverables &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(deliverables, isLoading);
}
