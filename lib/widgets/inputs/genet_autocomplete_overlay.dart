// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';

/// Positioned overlay dropdown for [GenetAutocompleteField].
/// Wraps content in [CompositedTransformFollower] + [Material] elevation card.
class GenetAutocompleteOverlay extends StatelessWidget {
  const GenetAutocompleteOverlay({
    super.key,
    required this.link,
    required this.width,
    required this.targetHeight,
    required this.suggestions,
    required this.isSearching,
    required this.valueLength,
    required this.highlightedIndex,
    required this.onSuggestionSelected,
    this.onAdvancedSelect,
  });

  final LayerLink link;
  final double width;
  final double targetHeight;
  final List<Genet> suggestions;
  final bool isSearching;
  final int valueLength;
  final int highlightedIndex;
  final ValueChanged<Genet> onSuggestionSelected;

  /// Callback when user wants to open advanced selection dialog.
  final VoidCallback? onAdvancedSelect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      width: width,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        offset: Offset(0, targetHeight),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (isSearching && suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (suggestions.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (_, i) => _GenetSuggestionTile(
                genet: suggestions[i],
                isHighlighted: i == highlightedIndex,
                onTap: onSuggestionSelected,
              ),
            ),
          ),
          if (onAdvancedSelect != null) ...[
            const Divider(height: 1),
            _AdvancedSelectTile(onTap: onAdvancedSelect!),
          ],
        ],
      );
    }

    if (valueLength >= 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No matching genets found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (onAdvancedSelect != null) ...[
            const Divider(height: 1),
            _AdvancedSelectTile(onTap: onAdvancedSelect!),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// Individual genet suggestion tile.
class _GenetSuggestionTile extends StatelessWidget {
  const _GenetSuggestionTile({
    required this.genet,
    required this.isHighlighted,
    required this.onTap,
  });

  final Genet genet;
  final bool isHighlighted;
  final ValueChanged<Genet> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onTap(genet),
      child: Container(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.eco,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    genet.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (genet.provenanceId.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      genet.provenanceId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (genet.speciesId.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  genet.speciesId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tile to open advanced selection dialog.
class _AdvancedSelectTile extends StatelessWidget {
  const _AdvancedSelectTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Create new or advanced search...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
