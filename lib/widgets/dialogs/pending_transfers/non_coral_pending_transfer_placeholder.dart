// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/non_coral_holdings_panel.dart';
import '../components/dialog_scroll_view.dart';

/// Shared placeholder for pending transfer dialogs when non-coral organisms are
/// active. Renders the shared non-coral holdings panel plus the standard
/// "coming soon" banner so users still get context even though the workflow is
/// not yet available.
class NonCoralPendingTransferPlaceholder extends StatelessWidget {
  const NonCoralPendingTransferPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.organismKind,
    required this.message,
    this.loaderOverride,
    this.supportsOverride,
    this.loadRowsOverride,
  });

  final IconData icon;
  final String title;
  final OrganismKind organismKind;
  final String message;
  final OrganismHoldingLoader? loaderOverride;
  final bool Function(OrganismKind kind)? supportsOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  loadRowsOverride;

  static const double _dialogWidth = 560;
  static const double _panelHeight = 240;

  @override
  Widget build(BuildContext context) {
    final displayName = organismKind.metadata.displayName;
    final placeholderMessage =
        '$displayName holdings have not been seeded yet for this organization.';
    final headerLabel = '$displayName Holdings • {count}';

    return AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: _dialogWidth,
        child: DialogScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: _panelHeight,
                    child: _buildHoldingsPanel(
                      context: context,
                      headerLabel: headerLabel,
                      placeholderMessage: placeholderMessage,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(message, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildHoldingsPanel({
    required BuildContext context,
    required String headerLabel,
    required String placeholderMessage,
  }) {
    if (loaderOverride == null &&
        supportsOverride == null &&
        loadRowsOverride == null) {
      return NonCoralHoldingsPanel.withContext(
        context: context,
        organismKind: organismKind,
        headerLabel: headerLabel,
        placeholderMessage: placeholderMessage,
      );
    }
    return NonCoralHoldingsPanel(
      organismKind: organismKind,
      headerLabel: headerLabel,
      placeholderMessage: placeholderMessage,
      loaderOverride: loaderOverride,
      supportsOverride: supportsOverride,
      loadRowsOverride: loadRowsOverride,
    );
  }
}