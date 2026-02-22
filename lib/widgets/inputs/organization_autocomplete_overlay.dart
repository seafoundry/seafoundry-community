// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/widgets/inputs/organization_suggestion_tile.dart';

/// Positioned overlay dropdown for [OrganizationAutocompleteField].
/// Wraps content in [CompositedTransformFollower] + [Material] elevation card.
class OrganizationAutocompleteOverlay extends StatelessWidget {
  const OrganizationAutocompleteOverlay({
    super.key,
    required this.link,
    required this.width,
    required this.targetHeight,
    required this.suggestions,
    required this.isSearching,
    required this.valueLength,
    required this.highlightedIndex,
    required this.onSuggestionSelected,
  });

  final LayerLink link;
  final double width;
  final double targetHeight;
  final List<Organization> suggestions;
  final bool isSearching;
  final int valueLength;
  final int highlightedIndex;
  final ValueChanged<Organization> onSuggestionSelected;

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
            constraints: const BoxConstraints(maxHeight: 200),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isSearching && suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (suggestions.isNotEmpty) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (_, i) => OrganizationSuggestionTile(
          organization: suggestions[i],
          isHighlighted: i == highlightedIndex,
          onTap: onSuggestionSelected,
        ),
      );
    }
    if (valueLength >= 2) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No organizations found',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
