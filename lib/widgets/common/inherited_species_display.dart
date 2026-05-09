import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Displays an inherited species value as a locked, read-only field.
///
/// Used in spawn event dialogs and organism creation wizards when the species
/// is inherited from parent organisms (e.g., gametes in cross events).
class InheritedSpeciesDisplay extends StatelessWidget {
  const InheritedSpeciesDisplay({
    super.key,
    required this.species,
    this.inheritedFrom,
    this.lockTooltip,
    this.showLockIcon = true,
    this.emptyPlaceholder,
  });

  /// The species to display. If null, shows a placeholder message.
  final Species? species;

  /// Optional label indicating where the species was inherited from.
  /// e.g., "parent organism", "dam gamete". Used to build helper text
  /// like "Inherited from parent organism".
  final String? inheritedFrom;

  /// Optional custom tooltip for the lock icon. If provided, this is used
  /// as the helper text instead of the default "Inherited from X" message.
  /// Useful for split dialogs where the message should be different.
  final String? lockTooltip;

  /// Whether to show the lock icon. Defaults to true.
  final bool showLockIcon;

  /// Custom placeholder text when species is null. Defaults to
  /// "Select a parent organism first".
  final String? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSpecies = species != null;

    // Use lockTooltip if provided, otherwise build from inheritedFrom
    final helperText = lockTooltip ??
        (inheritedFrom != null
            ? 'Inherited from $inheritedFrom'
            : 'Inherited from parent');

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Species',
        helperText: helperText,
        helperStyle: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIcon: showLockIcon
            ? Icon(Icons.lock_outline, color: AppColors.textSecondary)
            : const Icon(Icons.science),
        border: const OutlineInputBorder(),
        enabled: false,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
      ),
      child: hasSpecies
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    species!.code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    species!.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Text(
              emptyPlaceholder ?? 'Select a parent organism first',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}
