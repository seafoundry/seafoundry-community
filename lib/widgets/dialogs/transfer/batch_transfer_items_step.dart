// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/utils/human_sort.dart';
import 'package:seafoundry_app/widgets/dialogs/base_search_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_cart.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/transfer_shared.dart';
import 'package:seafoundry_app/widgets/notifications/toast_overlay.dart';

/// Step 2 of the batch transfer wizard: add items to the cart.
///
/// Mode A (multiGenetToOneOrg): select genets from a dropdown with quantities.
/// Mode B (oneGenetToMultiOrg): add target organizations via search.
class BatchTransferItemsStep extends StatefulWidget {
  const BatchTransferItemsStep({super.key});
  @override
  State<BatchTransferItemsStep> createState() => _BatchTransferItemsStepState();
}

class _BatchTransferItemsStepState extends State<BatchTransferItemsStep> {
  final _qtyController = TextEditingController(text: '1');
  Genet? _selectedGenet;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchTransferCubit, BatchTransferState>(
      builder: (context, state) {
        final isModeA = state.mode == BatchTransferMode.multiGenetToOneOrg;
        final cubit = context.read<BatchTransferCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isModeA) _buildGenetControls(context) else _buildOrgControls(context),
            const SizedBox(height: 16),
            if (state.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No items added yet. Add your first ${isModeA ? 'genet' : 'organization'} above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              BatchTransferCart(
                items: state.items,
                mode: state.mode,
                editable: true,
                onRemove: cubit.removeItem,
                availableInventory: state.availableInventory,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => cubit.goToStep(BatchTransferStep.selectFixed),
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: state.canGoNext
                      ? () => cubit.goToStep(BatchTransferStep.review)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGenetControls(BuildContext context) {
    return StreamBuilder<List<Genet>>(
      stream: context.read<GenetRepository>().streamAll,
      builder: (context, snapshot) {
        final sorted = List<Genet>.from(snapshot.data ?? [])
          ..sort((a, b) =>
              compareHumanReadable(_genetLabel(a), _genetLabel(b)));
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<Genet>(
                key: ValueKey('genet-${_selectedGenet?.id ?? 'none'}'),
                initialValue: _selectedGenet,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Local ID',
                  hintText: 'Select genet',
                  isDense: true,
                ),
                items: sorted
                    .map((g) => DropdownMenuItem(
                        value: g, child: Text(_genetLabel(g))))
                    .toList(),
                onChanged: (g) => setState(() => _selectedGenet = g),
              ),
            ),
            const SizedBox(width: 8),
            _buildQtyField(),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton(
                onPressed:
                    _selectedGenet == null ? null : () => _addGenetItem(context),
                child: const Text('Add'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrgControls(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildQtyField(label: 'Quantity')),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _addOrgItem(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Organization'),
        ),
      ],
    );
  }

  Widget _buildQtyField({String label = 'Qty'}) {
    return SizedBox(
      width: 80,
      child: TextFormField(
        controller: _qtyController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          border: const OutlineInputBorder(), labelText: label, isDense: true),
      ),
    );
  }

  // -- Add-to-cart actions ----------------------------------------------------

  Future<void> _addGenetItem(BuildContext context) async {
    final genet = _selectedGenet;
    if (genet == null) return;
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) return _snack('Quantity must be greater than 0');
    final result = await context.read<BatchTransferCubit>().addItem(
          genetRecordId: genet.id,
          genetLocalId: _genetLabel(genet),
          quantity: qty);
    if (mounted) _handleResult(result);
  }

  Future<void> _addOrgItem(BuildContext context) async {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) return _snack('Quantity must be greater than 0');
    final cubit = context.read<BatchTransferCubit>();
    final currentOrgId = context.read<Organization>().id;
    final orgRepo = context.read<OrganizationRepository>();
    final selected = await BaseSearchDialog.showSingle<Organization>(
      context,
      dialog: OrganizationSearchDialog(
        repository: orgRepo,
        excludeOrganizationId: currentOrgId,
      ),
    );
    if (selected == null || !mounted) return;
    final result = await cubit.addItem(
          organizationId: selected.id,
          organizationName: selected.name,
          quantity: qty);
    if (mounted) _handleResult(result);
  }

  void _handleResult(AddItemResult result) {
    switch (result) {
      case AddItemResult.success:
        _qtyController.text = '1';
        setState(() => _selectedGenet = null);
      case AddItemResult.duplicateGenet:
        _snack('Already in cart');
      case AddItemResult.duplicateOrganization:
        _snack('Organization already in cart');
      case AddItemResult.exceedsInventory:
        _snack('Exceeds available inventory');
      case AddItemResult.selfTransfer:
        _snack('Cannot transfer to your own organization');
      case AddItemResult.missingFixedTarget:
      case AddItemResult.closed:
        break;
    }
  }

  String _genetLabel(Genet genet) => genetDisplayLabel(genet);

  void _snack(String msg) =>
      ToastOverlay.showSnackBar(context, SnackBar(content: Text(msg)));
}
