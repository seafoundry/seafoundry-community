// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/identity_edit_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Dialog to confirm identity changes when external associations exist.
///
/// Shows a warning about external associations (aliases, clonal IDs, accession
/// numbers, transfer linkages) that will be decoupled if the identity changes.
/// Includes PID preview showing current vs new PID when available.
class IdentityChangeConfirmationDialog extends StatefulWidget {
  const IdentityChangeConfirmationDialog({
    super.key,
    required this.associationInfo,
    this.currentPid,
    this.newPid,
    this.currentLocalId,
    this.newLocalId,
  });

  final ExternalAssociationInfo associationInfo;
  final String? currentPid;
  final String? newPid;
  final String? currentLocalId;
  final String? newLocalId;

  /// Shows the confirmation dialog and returns true if user confirms.
  static Future<bool> show(
    BuildContext context, {
    required ExternalAssociationInfo associationInfo,
    String? currentPid,
    String? newPid,
    String? currentLocalId,
    String? newLocalId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => IdentityChangeConfirmationDialog(
        associationInfo: associationInfo,
        currentPid: currentPid,
        newPid: newPid,
        currentLocalId: currentLocalId,
        newLocalId: newLocalId,
      ),
    );
    return result ?? false;
  }

  @override
  State<IdentityChangeConfirmationDialog> createState() =>
      _IdentityChangeConfirmationDialogState();
}

class _IdentityChangeConfirmationDialogState
    extends State<IdentityChangeConfirmationDialog>
    with SafeDialogMixin<IdentityChangeConfirmationDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.associationInfo;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Confirm Identity Change'),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This record has external associations that will be affected:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // List of associations
              _buildAssociationsList(theme, info),

              const SizedBox(height: 16),

              // LocalID change preview
              if (widget.currentLocalId != null && widget.newLocalId != null)
                _buildChangePreview(
                  theme,
                  label: 'Local ID',
                  current: widget.currentLocalId!,
                  next: widget.newLocalId!,
                  icon: Icons.badge_outlined,
                ),

              // PID preview
              if (widget.currentPid != null &&
                  widget.newPid != null &&
                  widget.currentPid != widget.newPid) ...[
                const SizedBox(height: 12),
                _buildChangePreview(
                  theme,
                  label: 'Provenance ID',
                  current: widget.currentPid!,
                  next: widget.newPid!,
                  icon: Icons.fingerprint,
                ),
              ],

              const SizedBox(height: 16),

              // Warning text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Changing the identity will decouple existing external '
                        'associations. This action cannot be easily undone.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popDialog(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => popDialog(true),
          child: const Text('Yes, Continue'),
        ),
      ],
    );
  }

  Widget _buildAssociationsList(ThemeData theme, ExternalAssociationInfo info) {
    final items = <Widget>[];

    if (info.aliasCount > 0) {
      items.add(_buildAssociationItem(
        theme,
        icon: Icons.label_outline,
        label: '${info.aliasCount} alias${info.aliasCount == 1 ? '' : 'es'}',
      ));
    }

    if (info.clonalId != null && info.clonalId!.trim().isNotEmpty) {
      items.add(_buildAssociationItem(
        theme,
        icon: Icons.content_copy,
        label: 'Clonal ID: ${info.clonalId}',
      ));
    }

    if (info.accessionNumber != null && info.accessionNumber!.trim().isNotEmpty) {
      items.add(_buildAssociationItem(
        theme,
        icon: Icons.bookmarks_outlined,
        label: 'Accession #: ${info.accessionNumber}',
      ));
    }

    if (info.sourceOrganizationId != null &&
        info.sourceOrganizationId!.trim().isNotEmpty) {
      items.add(_buildAssociationItem(
        theme,
        icon: Icons.swap_horiz,
        label: 'Transfer from: ${info.sourceOrganizationId}',
        isWarning: true,
      ));
    }

    if (info.senderLocalId != null && info.senderLocalId!.trim().isNotEmpty) {
      items.add(_buildAssociationItem(
        theme,
        icon: Icons.link,
        label: 'Sender Local ID: ${info.senderLocalId}',
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildAssociationItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isWarning
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isWarning
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePreview(
    ThemeData theme, {
    required String label,
    required String current,
    required String next,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        current,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        next,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
