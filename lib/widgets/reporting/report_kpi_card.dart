// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/reporting/report_kpi.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// A card displaying a Key Performance Indicator (KPI) for reports.
///
/// Shows:
/// - Primary value with optional unit
/// - Label and optional subtitle
/// - Optional trend indicator with percentage change
/// - Optional icon
class ReportKpiCard extends StatelessWidget {
  const ReportKpiCard({
    super.key,
    required this.kpi,
    this.onTap,
    this.compact = false,
  });

  final ReportKpi kpi;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Spacing.sm),
        child: Padding(
          padding: EdgeInsets.all(compact ? Spacing.md : Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              SizedBox(height: compact ? Spacing.sm : Spacing.md),
              _buildValue(context),
              if (kpi.changePercent != null || kpi.subtitle != null) ...[
                SizedBox(height: compact ? Spacing.xs : Spacing.sm),
                _buildFooter(context),
              ],
            ],
          ),
        ),
      ),
    );

    return card;
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (kpi.icon != null) ...[
          Icon(
            kpi.icon,
            size: compact ? 18 : 22,
            color: kpi.color ?? AppColors.primary,
          ),
          const SizedBox(width: Spacing.sm),
        ],
        Expanded(
          child: Text(
            kpi.label,
            style: (compact
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildValue(BuildContext context) {
    return Text(
      kpi.displayValue,
      style: (compact
              ? Theme.of(context).textTheme.headlineSmall
              : Theme.of(context).textTheme.headlineMedium)
          ?.copyWith(
        fontWeight: FontWeight.bold,
        color: kpi.color ?? AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final trend = kpi.effectiveTrend;
    final change = kpi.displayChange;

    return Row(
      children: [
        if (change != null) ...[
          Icon(
            trend.icon,
            size: compact ? 14 : 16,
            color: trend.color,
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            change,
            style: (compact
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(
              color: trend.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (change != null && kpi.subtitle != null)
          const SizedBox(width: Spacing.sm),
        if (kpi.subtitle != null)
          Expanded(
            child: Text(
              kpi.subtitle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// A grid of KPI cards with responsive layout.
class ReportKpiGrid extends StatelessWidget {
  const ReportKpiGrid({
    super.key,
    required this.kpis,
    this.crossAxisCount = 4,
    this.compact = false,
    this.onKpiTap,
  });

  final List<ReportKpi> kpis;
  final int crossAxisCount;
  final bool compact;
  final void Function(ReportKpi kpi)? onKpiTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive column count based on width
        final columns = _getColumnCount(constraints.maxWidth);

        return Wrap(
          spacing: Spacing.md,
          runSpacing: Spacing.md,
          children: kpis.map((kpi) {
            final cardWidth =
                (constraints.maxWidth - (Spacing.md * (columns - 1))) / columns;
            return SizedBox(
              width: cardWidth,
              child: ReportKpiCard(
                kpi: kpi,
                compact: compact,
                onTap: onKpiTap != null ? () => onKpiTap!(kpi) : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  int _getColumnCount(double width) {
    if (width < 400) return 1;
    if (width < 600) return 2;
    if (width < 900) return 3;
    return crossAxisCount;
  }
}
