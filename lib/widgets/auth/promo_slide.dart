import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class PromoSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? backgroundColor;

  const PromoSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.backgroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final isCompact = constraints.maxHeight < 300 || textScale > 1.1;
        final padding = isCompact ? Spacing.md : Spacing.lg;
        final iconBoxSize = isCompact ? 80.0 : 120.0;
        final iconSize = isCompact ? 44.0 : 64.0;
        final titleSpacing = isCompact ? Spacing.sm : Spacing.lg;
        final subtitleSpacing = isCompact ? Spacing.xs : Spacing.sm;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgColor, Color.lerp(bgColor, Colors.black, 0.2)!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon placeholder (will be replaced with screenshots later)
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: iconSize, color: AppColors.surface),
                ),
                SizedBox(height: titleSpacing),
                Text(
                  title,
                  style: UIText.h4Style.copyWith(color: AppColors.surface),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: subtitleSpacing),
                Text(
                  subtitle,
                  style: UIText.bodyMediumStyle.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
