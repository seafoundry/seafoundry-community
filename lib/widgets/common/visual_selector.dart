// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/models/models.dart';

/// Visual selector component with large touch targets
///
/// Provides a grid-based selection UI with icons/images optimized for:
/// - Large touch targets (80x80dp minimum per item)
/// - Wet-finger operation (clear visual feedback)
/// - Single or multi-select modes
/// - Organism type selection, life stage selection, etc.
///
/// Usage:
/// ```dart
/// VisualSelector<OrganismKind>(
///   options: [
///     VisualOption(
///       value: OrganismKind.coral,
///       icon: Icons.coral,
///       label: 'Coral',
///       color: Colors.red,
///     ),
///     // ... more options
///   ],
///   selected: OrganismKind.coral,
///   onChanged: (value) => print('Selected: $value'),
/// )
/// ```
class VisualSelector<T> extends StatelessWidget {
  /// Available options to select from
  final List<VisualOption<T>> options;

  /// Currently selected value (single-select mode)
  final T? selected;

  /// Currently selected values (multi-select mode)
  final Set<T>? selectedMultiple;

  /// Callback when selection changes
  final ValueChanged<T>? onChanged;

  /// Callback for multi-select changes
  final ValueChanged<Set<T>>? onChangedMultiple;

  /// Number of columns in the grid
  final int columns;

  /// Whether to allow multiple selections
  final bool multiSelect;

  /// Spacing between grid items
  final double spacing;

  /// Minimum height for each grid item
  final double itemHeight;

  const VisualSelector({
    super.key,
    required this.options,
    this.selected,
    this.selectedMultiple,
    this.onChanged,
    this.onChangedMultiple,
    this.columns = 2,
    this.multiSelect = false,
    this.spacing = 12.0,
    this.itemHeight = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    if (multiSelect && (selectedMultiple == null || onChangedMultiple == null)) {
      return const SizedBox.shrink();
    }
    if (!multiSelect && selected == null && onChanged == null) {
      return const SizedBox.shrink();
    }
    // Build rows of items manually to avoid ShrinkWrappingViewport
    // intrinsic dimension issues with AlertDialog. Using Column wrapped in
    // SingleChildScrollView to handle overflow while supporting intrinsic dimensions.
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += columns) {
      final rowItems = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final index = i + j;
        if (index < options.length) {
          final option = options[index];
          final isSelected = multiSelect
              ? selectedMultiple?.contains(option.value) ?? false
              : selected == option.value;
          rowItems.add(
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: _VisualSelectorItem<T>(
                  option: option,
                  isSelected: isSelected,
                  onTap: () => _handleSelection(option.value),
                  minHeight: itemHeight,
                ),
              ),
            ),
          );
        } else {
          // Empty placeholder to maintain grid alignment
          rowItems.add(const Expanded(child: SizedBox.shrink()));
        }
        if (j < columns - 1) {
          rowItems.add(SizedBox(width: spacing));
        }
      }
      rows.add(Row(children: rowItems));
      if (i + columns < options.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    // SingleChildScrollView handles overflow while supporting intrinsic dimensions
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  void _handleSelection(T value) {
    // Provide haptic feedback for better tactile response
    HapticFeedback.selectionClick();

    if (multiSelect) {
      final newSelection = Set<T>.from(selectedMultiple ?? {});
      if (newSelection.contains(value)) {
        newSelection.remove(value);
      } else {
        newSelection.add(value);
      }
      onChangedMultiple?.call(newSelection);
    } else {
      onChanged?.call(value);
    }
  }
}

/// Individual option in the visual selector
class _VisualSelectorItem<T> extends StatelessWidget {
  final VisualOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;
  final double minHeight;

  const _VisualSelectorItem({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = option.disabled;

    // Determine colors based on disabled/selected state
    final backgroundColor = isDisabled
        ? UI.surfaceColor.withValues(alpha: 0.5)
        : isSelected
            ? (option.color?.withValues(alpha: 0.1) ?? UI.primaryColor.withValues(alpha: 0.1))
            : UI.surfaceColor;
    final borderColor = isDisabled
        ? UI.dividerColor.withValues(alpha: 0.5)
        : isSelected
            ? (option.color ?? UI.primaryColor)
            : UI.dividerColor;
    final iconColor = isDisabled
        ? UI.textDisabledColor
        : isSelected
            ? (option.color ?? UI.primaryColor)
            : UI.textSecondaryColor;
    final textColor = isDisabled
        ? UI.textDisabledColor
        : isSelected
            ? (option.color ?? UI.primaryColor)
            : UI.textPrimaryColor;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            constraints: BoxConstraints(minHeight: minHeight),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor,
                width: isSelected && !isDisabled ? 2.0 : 1.0,
              ),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (option.icon != null)
                  Icon(
                    option.icon,
                    size: 32.0,
                    color: iconColor,
                  ),
                if (option.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: ColorFiltered(
                      colorFilter: isDisabled
                          ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                          : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                      child: Image.network(
                        option.imageUrl!,
                        width: 40.0,
                        height: 40.0,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported,
                          size: 32.0,
                          color: UI.textDisabledColor,
                        ),
                      ),
                    ),
                  ),
                UI.dividerSm,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: isSelected && !isDisabled ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (option.description != null && !isDisabled) ...[
                  UI.dividerXs,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      option.description!,
                      style: TextStyle(
                        fontSize: 11.0,
                        color: UI.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // "Coming Soon" badge for disabled items
          if (isDisabled && option.disabledLabel != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  option.disabledLabel!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Represents a selectable option in the visual selector
class VisualOption<T> {
  /// The value this option represents
  final T value;

  /// Display label for the option
  final String label;

  /// Optional icon to display
  final IconData? icon;

  /// Optional image URL to display (instead of icon)
  final String? imageUrl;

  /// Optional description text
  final String? description;

  /// Optional color for the option (used for selection highlighting)
  final Color? color;

  /// Whether this option is disabled (greyed out, not selectable)
  final bool disabled;

  /// Optional label to show when disabled (e.g., "Coming Soon")
  final String? disabledLabel;

  const VisualOption({
    required this.value,
    required this.label,
    this.icon,
    this.imageUrl,
    this.description,
    this.color,
    this.disabled = false,
    this.disabledLabel,
  });
}

/// Selector for OrganismKind with icons and colors
class OrganismKindSelector extends StatelessWidget {
  const OrganismKindSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.availableKinds,
  });

  final OrganismKind? selected;
  final ValueChanged<OrganismKind?> onChanged;
  final List<OrganismKind>? availableKinds;

  @override
  Widget build(BuildContext context) {
    final kinds = availableKinds ?? OrganismKind.values;
    
    return VisualSelector<OrganismKind>(
      options: kinds.map((kind) => VisualOption(
        value: kind,
        label: kind.metadata.displayName,
        icon: _getIconForKind(kind),
        color: _getColorForKind(kind),
        description: null,
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 3,
    );
  }

  IconData _getIconForKind(OrganismKind kind) {
    switch (kind) {
      case OrganismKind.coral: return Icons.water; // or Icons.coral if available
      case OrganismKind.kelp: return Icons.grass;
      case OrganismKind.oyster: return Icons.circle;
      case OrganismKind.seagrass: return Icons.eco;
      case OrganismKind.mangrove: return Icons.forest;
      case OrganismKind.echinoid: return Icons.stars; // Spiky/star-like
      case OrganismKind.crab: return Icons.bug_report; // Closest to crab logic
      case OrganismKind.finfish: return Icons.set_meal;
      case OrganismKind.seaCucumber: return Icons.horizontal_rule; // Elongated shape
    }
  }

  Color _getColorForKind(OrganismKind kind) {
    switch (kind) {
      case OrganismKind.coral: return const Color(0xFFFF6F61);
      case OrganismKind.kelp: return const Color(0xFF689F38);
      case OrganismKind.oyster: return const Color(0xFF78909C);
      case OrganismKind.seagrass: return const Color(0xFF66BB6A);
      case OrganismKind.mangrove: return const Color(0xFF2E7D32);
      case OrganismKind.echinoid: return const Color(0xFF9C27B0);
      case OrganismKind.crab: return const Color(0xFFE53935);
      case OrganismKind.finfish: return const Color(0xFF42A5F5);
      case OrganismKind.seaCucumber: return const Color(0xFF5D4037);
    }
  }
}

/// Selector for ProvenanceType with descriptive metadata
class ProvenanceTypeSelector extends StatelessWidget {
  const ProvenanceTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.availableTypes,
  });

  final ProvenanceType? selected;
  final ValueChanged<ProvenanceType?> onChanged;
  final List<ProvenanceType>? availableTypes;

  @override
  Widget build(BuildContext context) {
    final types = availableTypes ?? ProvenanceType.values;
    return VisualSelector<ProvenanceType>(
      options: types.map((type) => VisualOption(
        value: type,
        label: type.displayName,
        description: type.metadata.description,
        icon: _getIconForType(type),
        color: _getColorForType(context, type),
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 2,
    );
  }

  IconData _getIconForType(ProvenanceType type) {
    switch (type) {
      case ProvenanceType.wild: return Icons.nature;
      case ProvenanceType.sexualCohort: return Icons.group_work;
      case ProvenanceType.graduatedIndividual: return Icons.school;
      case ProvenanceType.transfer: return Icons.local_shipping;
      case ProvenanceType.unknown: return Icons.help_outline;
    }
  }

  Color _getColorForType(BuildContext context, ProvenanceType type) {
    // Using theme-aware colors or fixed semantic colors
    switch (type) {
      case ProvenanceType.wild: return Colors.green;
      case ProvenanceType.sexualCohort: return Colors.pinkAccent;
      case ProvenanceType.graduatedIndividual: return Colors.orange;
      case ProvenanceType.transfer: return Colors.blue;
      case ProvenanceType.unknown: return Colors.grey;
    }
  }
}

/// Selector for LifeStage
class LifeStageSelector extends StatelessWidget {
  const LifeStageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.availableStages,
  });

  final LifeStage? selected;
  final ValueChanged<LifeStage?> onChanged;
  final List<LifeStage>? availableStages;

  @override
  Widget build(BuildContext context) {
    final stages =
        availableStages == null || availableStages!.isEmpty
            ? LifeStage.values
            : availableStages!;
    return SizedBox(
      width: double.infinity,
      child: VisualSelector<LifeStage>(
        options: stages.map((stage) => VisualOption(
          value: stage,
          label: stage.displayName,
          icon: _getIconForStage(stage),
        )).toList(),
        selected: selected,
        onChanged: onChanged,
        columns: 3,
      ),
    );
  }

  IconData _getIconForStage(LifeStage stage) {
    switch (stage) {
      case LifeStage.unknown: return Icons.help_outline;
      case LifeStage.gamete: return Icons.grain;
      case LifeStage.embryo: return Icons.blur_circular;
      case LifeStage.larva: return Icons.bug_report; // Best approximation
      case LifeStage.juvenile: return Icons.child_care;
      case LifeStage.adult: return Icons.accessibility_new;
      case LifeStage.broodstock: return Icons.pregnant_woman;
    }
  }
}

/// Visual selector for size classes using card-style selection buttons
class SizeClassVisualSelector extends StatelessWidget {
  const SizeClassVisualSelector({
    super.key,
    required this.options,
    required this.selectedClass,
    required this.onChanged,
    this.columns = 3,
  });

  final List<String> options;
  final String? selectedClass;
  final ValueChanged<String?>? onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isEnabled = onChanged != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final sizeClass = options[i];
                final isSelected = selectedClass == sizeClass;
                return Material(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: isEnabled ? () => onChanged!(sizeClass) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 52,
                        minHeight: 44,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.4),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          sizeClass,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? primaryColor
                                : (isEnabled
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Visual selector for rich size band configs using card-style selection
class SizeBandVisualSelector extends StatelessWidget {
  const SizeBandVisualSelector({
    super.key,
    required this.sizeBands,
    required this.selectedBandId,
    required this.onChanged,
    this.metricsByBandId,
  });

  final List<SizeBandConfig> sizeBands;
  final String? selectedBandId;
  final ValueChanged<String?>? onChanged;
  final Map<String, SizeMetrics>? metricsByBandId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onChanged != null;
    final primaryColor = theme.colorScheme.primary;
    final showNote =
        sizeBands.any((band) => band.enableVolume || band.enableTissueArea);

    if (sizeBands.isEmpty) {
      return Text(
        'No size bands configured',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < sizeBands.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final band = sizeBands[i];
                    final isSelected = selectedBandId == band.id;
                    final metrics = _resolveMetrics(band);
                    final showVolume = band.enableVolume;
                    final showTissue = band.enableTissueArea;
                    return Material(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: isEnabled ? () => onChanged!(band.id) : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 64,
                            minHeight: 48,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : theme.colorScheme.outline
                                      .withValues(alpha: 0.4),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                band.id.toUpperCase(),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : (isEnabled
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5)),
                                ),
                              ),
                              if (band.label.isNotEmpty &&
                                  band.label != band.id) ...[
                                const SizedBox(height: 2),
                                Text(
                                  band.label,
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.8)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (showVolume || showTissue) ...[
                                const SizedBox(height: 4),
                                if (showVolume)
                                  Text(
                                    'Physical Volume ${_formatMetric(metrics.volumeCm3)} cm³',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                if (showTissue)
                                  Text(
                                    'Tissue Area ${_formatMetric(metrics.tissueAreaCm2)} cm²',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (showNote) ...[
          const SizedBox(height: 6),
          Text(
            '* Size band metrics use a standardized hemisphere model. '
            'Customize in Organization > Biology.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  SizeMetrics _resolveMetrics(SizeBandConfig band) {
    final provided = metricsByBandId?[band.id];
    final volume = provided?.volumeCm3 ??
        band.defaultVolumeCm3 ??
        (band.volumeMm3 / 1000.0);
    final tissue = provided?.tissueAreaCm2 ?? band.defaultTissueAreaCm2;
    return SizeMetrics(volumeCm3: volume, tissueAreaCm2: tissue);
  }

  String _formatMetric(double? value) {
    if (value == null) return '--';
    return value.round().toString();
  }
}

/// Selector for DeliverableType
class DeliverableTypeSelector extends StatelessWidget {
  const DeliverableTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DeliverableType selected;
  final ValueChanged<DeliverableType> onChanged;

  @override
  Widget build(BuildContext context) {
    return VisualSelector<DeliverableType>(
      options: DeliverableType.values.map((type) => VisualOption(
        value: type,
        label: type.displayName,
        icon: _getIconForType(type),
        color: _getColorForType(context, type),
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 2,
    );
  }

  IconData _getIconForType(DeliverableType type) {
    switch (type) {
      case DeliverableType.report: return Icons.description;
      case DeliverableType.survey: return Icons.poll;
      case DeliverableType.documentation: return Icons.article;
      case DeliverableType.permitRenewal: return Icons.autorenew;
      case DeliverableType.compliance: return Icons.verified_user;
    }
  }

  Color _getColorForType(BuildContext context, DeliverableType type) {
    switch (type) {
      case DeliverableType.report: return Colors.blue;
      case DeliverableType.survey: return Colors.teal;
      case DeliverableType.documentation: return Colors.orange;
      case DeliverableType.permitRenewal: return Colors.purple;
      case DeliverableType.compliance: return Colors.green;
    }
  }
}

/// Selector for DeliverableStatus
class DeliverableStatusSelector extends StatelessWidget {
  const DeliverableStatusSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DeliverableStatus selected;
  final ValueChanged<DeliverableStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return VisualSelector<DeliverableStatus>(
      options: DeliverableStatus.values.map((status) => VisualOption(
        value: status,
        label: status.displayName,
        icon: _getIconForStatus(status),
        color: _getColorForStatus(context, status),
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 3,
    );
  }

  IconData _getIconForStatus(DeliverableStatus status) {
    switch (status) {
      case DeliverableStatus.notStarted: return Icons.radio_button_unchecked;
      case DeliverableStatus.inProgress: return Icons.trending_up;
      case DeliverableStatus.atRisk: return Icons.warning;
      case DeliverableStatus.pendingReview: return Icons.hourglass_full;
      case DeliverableStatus.completed: return Icons.check_circle;
      case DeliverableStatus.overdue: return Icons.error;
    }
  }

  Color _getColorForStatus(BuildContext context, DeliverableStatus status) {
    switch (status) {
      case DeliverableStatus.notStarted: return Colors.grey;
      case DeliverableStatus.inProgress: return Colors.blue;
      case DeliverableStatus.atRisk: return Colors.orange;
      case DeliverableStatus.pendingReview: return Colors.purple;
      case DeliverableStatus.completed: return Colors.green;
      case DeliverableStatus.overdue: return Colors.red;
    }
  }
}

/// Selector for DeliverableFrequency
class DeliverableFrequencySelector extends StatelessWidget {
  const DeliverableFrequencySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DeliverableFrequency selected;
  final ValueChanged<DeliverableFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return VisualSelector<DeliverableFrequency>(
      options: DeliverableFrequency.values.map((freq) => VisualOption(
        value: freq,
        label: freq.displayName,
        icon: _getIconForFrequency(freq),
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 3,
    );
  }

  IconData _getIconForFrequency(DeliverableFrequency freq) {
    switch (freq) {
      case DeliverableFrequency.oneTime: return Icons.filter_1;
      case DeliverableFrequency.monthly: return Icons.calendar_month;
      case DeliverableFrequency.quarterly: return Icons.pie_chart;
      case DeliverableFrequency.semiAnnual: return Icons.donut_large;
      case DeliverableFrequency.annual: return Icons.calendar_today;
    }
  }
}

/// Selector for HealthStatus
class HealthStatusSelector extends StatelessWidget {
  const HealthStatusSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.availableStatuses,
  });

  final HealthStatus? selected;
  final ValueChanged<HealthStatus?> onChanged;
  final List<HealthStatus>? availableStatuses;

  @override
  Widget build(BuildContext context) {
    final statuses = availableStatuses ?? HealthStatus.values;
    return VisualSelector<HealthStatus>(
      options: statuses.map((status) => VisualOption(
        value: status,
        label: status.displayName,
        icon: _getIconForStatus(status),
        color: _getColorForStatus(context, status),
      )).toList(),
      selected: selected,
      onChanged: onChanged,
      columns: 3,
    );
  }

  IconData _getIconForStatus(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy: return Icons.check_circle;
      case HealthStatus.stressed: return Icons.warning_amber;
      case HealthStatus.diseased: return Icons.coronavirus;
      case HealthStatus.recovering: return Icons.healing;
      case HealthStatus.deceased: return Icons.cancel;
      case HealthStatus.lost: return Icons.search_off;
      case HealthStatus.bleached: return Icons.wb_sunny_outlined;
      case HealthStatus.damaged: return Icons.broken_image;
      case HealthStatus.fragmented: return Icons.grid_view;
      case HealthStatus.transferred: return Icons.exit_to_app;
      case HealthStatus.outplanted: return Icons.forest;
      case HealthStatus.unknown: return Icons.help_outline;
    }
  }

  Color _getColorForStatus(BuildContext context, HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy: return Colors.green;
      case HealthStatus.recovering: return Colors.lightGreen;
      case HealthStatus.outplanted: return Colors.green.shade800;
      case HealthStatus.stressed: return Colors.orange;
      case HealthStatus.diseased: return Colors.red;
      case HealthStatus.bleached: return Colors.amber;
      case HealthStatus.damaged: return Colors.brown;
      case HealthStatus.deceased: return Colors.grey;
      case HealthStatus.lost: return Colors.blueGrey;
      case HealthStatus.fragmented: return Colors.teal;
      case HealthStatus.transferred: return Colors.blue;
      case HealthStatus.unknown: return Colors.grey.shade400;
    }
  }
}
