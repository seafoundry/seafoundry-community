import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_community/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_community/models/genet.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/organization_repository.dart';
import 'package:seafoundry_community/utils/human_sort.dart';
import 'package:seafoundry_community/widgets/dialogs/base_search_dialog.dart';
import 'package:seafoundry_community/widgets/dialogs/transfer/transfer_shared.dart';

/// Step 1 of the batch transfer wizard: select the "fixed" side.
///
/// - Mode A (multiGenetToOneOrg): select a target organization.
/// - Mode B (oneGenetToMultiOrg): select a genet from the dropdown.
class BatchTransferTargetStep extends StatelessWidget {
  const BatchTransferTargetStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchTransferCubit, BatchTransferState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.mode == BatchTransferMode.multiGenetToOneOrg)
              _ModeATargetSelector(state: state)
            else
              _ModeBGenetSelector(state: state),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: state.canGoNext
                    ? () => context
                        .read<BatchTransferCubit>()
                        .goToStep(BatchTransferStep.addItems)
                    : null,
                child: const Text('Next'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Mode A: Select a target organization via [OrganizationSearchDialog].
class _ModeATargetSelector extends StatelessWidget {
  const _ModeATargetSelector({required this.state});

  final BatchTransferState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.fixedOrganization;
    if (selected != null) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.business)),
          title: Text(selected.name),
          trailing: TextButton(
            onPressed: () => _selectOrganization(context),
            child: const Text('Change'),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _selectOrganization(context),
      icon: const Icon(Icons.business),
      label: const Text('Select Target Organization'),
    );
  }

  Future<void> _selectOrganization(BuildContext context) async {
    final cubit = context.read<BatchTransferCubit>();
    final orgRepo = context.read<OrganizationRepository>();
    final currentOrgId = context.read<Organization>().id;

    final selected = await BaseSearchDialog.showSingle<Organization>(
      context,
      dialog: OrganizationSearchDialog(
        repository: orgRepo,
        excludeOrganizationId: currentOrgId,
      ),
    );
    if (selected != null) {
      cubit.setFixedOrganization(selected);
    }
  }
}

/// Mode B: Select a genet from a dropdown populated by [GenetRepository].
class _ModeBGenetSelector extends StatelessWidget {
  const _ModeBGenetSelector({required this.state});

  final BatchTransferState state;

  @override
  Widget build(BuildContext context) {
    final genetRepo = context.read<GenetRepository>();
    return StreamBuilder<List<Genet>>(
      stream: genetRepo.streamAll,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _buildUnavailable('Failed to load genets');
        }
        final genets = snapshot.data ?? [];
        if (genets.isEmpty) {
          return _buildUnavailable('No genets available');
        }
        return _buildDropdown(context, genets);
      },
    );
  }

  Widget _buildUnavailable(String message) {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Local ID',
        isDense: true,
      ),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildDropdown(BuildContext context, List<Genet> genets) {
    final sorted = List<Genet>.from(genets)
      ..sort((a, b) => compareHumanReadable(_genetLabel(a), _genetLabel(b)));

    Genet? selected;
    if (state.fixedGenetId != null) {
      for (final g in sorted) {
        if (g.id == state.fixedGenetId) {
          selected = g;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Genet>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Local ID',
            hintText: 'Select genet',
            isDense: true,
          ),
          items: sorted
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(_genetLabel(g)),
                  ))
              .toList(),
          onChanged: (genet) {
            if (genet == null) return;
            _onGenetSelected(context, genet);
          },
        ),
        if (state.fixedGenetId != null && state.availableInventory != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              '${state.availableInventory} organism${state.availableInventory == 1 ? '' : 's'} available',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Future<void> _onGenetSelected(BuildContext context, Genet genet) async {
    final cubit = context.read<BatchTransferCubit>();
    final genetRepo = context.read<GenetRepository>();
    final count = await genetRepo.countOrganismRecordsForGenet(genet.id);
    cubit.setFixedGenet(genet.id, _genetLabel(genet), count);
  }

  String _genetLabel(Genet genet) => genetDisplayLabel(genet);
}
