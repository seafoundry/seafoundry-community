// @tier: community
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';
import '../dialogs/components/dialog_scroll_view.dart';

class OceanicDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final double? width;
  final IconData? icon;
  final Color? iconColor;

  const OceanicDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.width = 500,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = (size.width - 32).clamp(0.0, size.width);
    final targetWidth = width == null ? maxWidth : math.min(width!, maxWidth);
    final maxHeight = size.height * 0.9;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: targetWidth,
            constraints: BoxConstraints(
              maxWidth: targetWidth,
              maxHeight: maxHeight,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Flexible(
                  child: DialogScrollView(
                    padding: const EdgeInsets.all(24),
                    child: content,
                  ),
                ),
                if (actions != null) _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop();
            },
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: actions!.map((action) => action).toList(),
        ),
      ),
    );
  }
}