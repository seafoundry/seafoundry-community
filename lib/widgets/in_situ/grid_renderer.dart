import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/in_situ/in_situ_grid_cell.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

export 'package:seafoundry_app/models/in_situ/in_situ_grid_cell.dart';

class InSituGridRenderer extends StatelessWidget {
  const InSituGridRenderer({
    super.key,
    required this.rowCount,
    required this.columnCount,
    required this.cells,
    this.selectedCoordinate,
    this.onCellSelected,
    this.scale = 1.0,
    this.cellSpacing = 8,
  });

  final int rowCount;
  final int columnCount;
  final Map<InSituGridCoordinate, InSituGridCellSummary> cells;
  final InSituGridCoordinate? selectedCoordinate;
  final InSituGridCellSelected? onCellSelected;
  final double scale;
  final double cellSpacing;

  static const double _baseCellSize = 120;

  @override
  Widget build(BuildContext context) {
    final summaries = cells;
    final safeRowCount = rowCount <= 0 ? 1 : rowCount;
    final safeColumnCount = columnCount <= 0 ? 1 : columnCount;
    final safeCellSpacing = cellSpacing < 0 ? 0 : cellSpacing;
    final effectiveCellSize = (_baseCellSize * scale).clamp(80, 220).toDouble();
    final gridWidth =
        safeColumnCount * effectiveCellSize +
            (safeColumnCount + 1) * safeCellSpacing;
    final gridHeight =
        safeRowCount * effectiveCellSize +
            (safeRowCount + 1) * safeCellSpacing;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: GridView.builder(
          padding: EdgeInsets.all(cellSpacing),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: safeColumnCount,
            childAspectRatio: 1,
            crossAxisSpacing: cellSpacing,
            mainAxisSpacing: cellSpacing,
          ),
          itemCount: safeRowCount * safeColumnCount,
          itemBuilder: (context, index) {
            final rowIndex = index ~/ safeColumnCount;
            final columnIndex = index % safeColumnCount;
            final coordinate = InSituGridCoordinate(
              rowIndex: rowIndex,
              columnIndex: columnIndex,
            );
            final summary =
                summaries[coordinate] ??
                InSituGridCellSummary.empty(coordinate);
            final isSelected = coordinate == selectedCoordinate;
            return _InSituGridCell(
              key: Key('grid_cell_${coordinate.displayLabel}'),
              summary: summary,
              isSelected: isSelected,
              onTap: onCellSelected,
            );
          },
        ),
      ),
    );
  }
}

class _InSituGridCell extends StatelessWidget {
  const _InSituGridCell({
    super.key,
    required this.summary,
    required this.isSelected,
    required this.onTap,
  });

  final InSituGridCellSummary summary;
  final bool isSelected;
  final InSituGridCellSelected? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _statusPalette(theme.colorScheme, summary.status);

    return FocusableActionDetector(
      mouseCursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onTap?.call(summary);
            return null;
          },
        ),
      },
      child: Semantics(
        selected: isSelected,
        button: true,
        label: _buildSemanticLabel(),
        child: Tooltip(
          message: _tooltip(),
          waitDuration: const Duration(milliseconds: 400),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap == null ? null : () => onTap!(summary),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  color: palette.fill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? palette.accent : palette.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [],
                ),
                child: _CellContents(summary: summary, palette: palette),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final buffer = StringBuffer('${summary.coordinate.displayLabel}: ');
    buffer.write(summary.statusLabel);
    buffer.write(', ');
    buffer.write(summary.occupancyLabel);
    return buffer.toString();
  }

  String _tooltip() {
    final details = <String>[summary.structureName, summary.occupancyLabel];

    if (summary.healthBreakdown.isNotEmpty) {
      final breakdown = summary.healthBreakdown.entries
          .map(
            (entry) => '${entry.value} ${entry.key.displayName.toLowerCase()}',
          )
          .join(', ');
      if (breakdown.isNotEmpty) {
        details.add(breakdown);
      }
    }

    return details.join(' · ');
  }

  _StatusPalette _statusPalette(
    ColorScheme scheme,
    InSituGridCellStatus status,
  ) {
    switch (status) {
      case InSituGridCellStatus.empty:
        return _StatusPalette(
          fill: scheme.surface,
          accent: scheme.outline,
          border: scheme.outlineVariant,
          chipBackground: scheme.surfaceContainerHighest,
          chipForeground: scheme.onSurfaceVariant,
        );
      case InSituGridCellStatus.healthy:
        return const _StatusPalette(
          fill: Color(0xFFE2F4E8),
          accent: Color(0xFF0D6E2E),
          border: Color(0xFF65A075),
          chipBackground: Color(0xFF0D6E2E),
          chipForeground: Colors.white,
        );
      case InSituGridCellStatus.warning:
        return const _StatusPalette(
          fill: Color(0xFFFFF4DC),
          accent: Color(0xFFB78903),
          border: Color(0xFFF1C550),
          chipBackground: Color(0xFFB78903),
          chipForeground: Colors.white,
        );
      case InSituGridCellStatus.critical:
        return const _StatusPalette(
          fill: Color(0xFFFCE5E8),
          accent: Color(0xFFC62828),
          border: Color(0xFFF58A8E),
          chipBackground: Color(0xFFC62828),
          chipForeground: Colors.white,
        );
    }
  }
}

class _CellContents extends StatelessWidget {
  const _CellContents({required this.summary, required this.palette});

  final InSituGridCellSummary summary;
  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    summary.coordinate.displayLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    summary.statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.chipForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.structureName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.structureTypeLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                summary.structureTypeLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              summary.occupancyLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (summary.hasCorals) ...[
              const SizedBox(height: 12),
              _HealthBreakdownBar(summary: summary),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPalette {
  const _StatusPalette({
    required this.fill,
    required this.accent,
    required this.border,
    required this.chipBackground,
    required this.chipForeground,
  });

  final Color fill;
  final Color accent;
  final Color border;
  final Color chipBackground;
  final Color chipForeground;
}

class _HealthBreakdownBar extends StatelessWidget {
  const _HealthBreakdownBar({required this.summary});

  final InSituGridCellSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.coralCount.toDouble();
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final segments = summary.healthBreakdown.entries.toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: segments
            .map(
              (entry) => Expanded(
                flex: (entry.value / total * 1000).round().clamp(1, 1000),
                child: Container(
                  height: 6,
                  color: _segmentColor(
                    Theme.of(context).colorScheme,
                    entry.key,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color _segmentColor(ColorScheme colorScheme, HealthStatus status) {
    if (status == HealthStatus.diseased ||
        status == HealthStatus.deceased ||
        status == HealthStatus.lost) {
      return const Color(0xFFD32F2F);
    }
    if (status == HealthStatus.stressed ||
        status == HealthStatus.bleached ||
        status == HealthStatus.damaged ||
        status == HealthStatus.unknown ||
        status == HealthStatus.fragmented) {
      return const Color(0xFFF57C00);
    }
    if (status == HealthStatus.recovering || status.isHealthy) {
      return const Color(0xFF2E7D32);
    }
    if (status.isInactiveInventory) {
      return colorScheme.outlineVariant;
    }
    return colorScheme.secondary;
  }
}
