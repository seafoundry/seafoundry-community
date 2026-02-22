// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/theme/colors.dart';

class StructureCapacityBanner extends StatelessWidget {
  const StructureCapacityBanner({
    super.key,
    this.result,
    this.isLoading = false,
    this.margin,
  });

  final StructureCapacityResult? result;
  final bool isLoading;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: margin ?? const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Checking capacity...',
                style: TextStyle(color: AppColors.info),
              ),
            ),
          ],
        ),
      );
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    final isError = result!.isOverCapacity;
    final isWarning = result!.isWarning;
    if (!isError && !isWarning) {
      return const SizedBox.shrink();
    }

    final color = isError ? AppColors.error : AppColors.warning;
    final icon = isError ? Icons.error_outline : Icons.warning_amber_outlined;
    final message = isError
        ? result!.blockingMessage
        : (result!.warnings.isNotEmpty
              ? result!.warnings.first
              : 'Approaching capacity for this structure.');

    return Container(
      margin: margin ?? const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
