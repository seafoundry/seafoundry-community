import 'package:flutter/material.dart';
import 'package:seafoundry_community/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_community/cubits/transfer/batch_transfer_item.dart';

/// Displays the batch transfer cart items as a list with a total footer.
///
/// Used in both the add-items step (editable) and the review step (read-only).
class BatchTransferCart extends StatelessWidget {
  const BatchTransferCart({
    super.key,
    required this.items,
    required this.mode,
    this.editable = true,
    this.onRemove,
    this.availableInventory,
  });

  final List<BatchTransferItem> items;
  final BatchTransferMode mode;
  final bool editable;
  final void Function(int index)? onRemove;

  /// For Mode B: total available inventory for "X of Y available" footer.
  final int? availableInventory;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }
    final totalQuantity = items.fold(0, (sum, i) => sum + i.quantity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) _buildItemRow(context, i),
        const Divider(),
        _buildFooter(context, totalQuantity),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No items added yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, int index) {
    final item = items[index];
    final label = mode == BatchTransferMode.multiGenetToOneOrg
        ? item.genetLocalId
        : item.toOrganizationName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text('x${item.quantity}',
              style: Theme.of(context).textTheme.bodyMedium),
          if (editable && onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onRemove!(index),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, int totalQuantity) {
    final theme = Theme.of(context).textTheme;
    final remaining = availableInventory != null
        ? availableInventory! - totalQuantity
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Total: $totalQuantity organism${totalQuantity == 1 ? '' : 's'}',
            style: theme.titleSmall),
        if (mode == BatchTransferMode.oneGenetToMultiOrg &&
            remaining != null) ...[
          const SizedBox(width: 8),
          Text(
            '($remaining remaining)',
            style: theme.bodySmall?.copyWith(
              color: remaining < 0 ? Colors.red : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
