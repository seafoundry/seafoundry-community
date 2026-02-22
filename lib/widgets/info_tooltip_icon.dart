// @tier: community
import 'package:flutter/material.dart';

/// Compact info icon with tooltip used to annotate form fields.
class InfoTooltipIcon extends StatelessWidget {
  const InfoTooltipIcon({
    super.key,
    required this.message,
    this.icon,
    this.padding = const EdgeInsets.all(8),
  });

  final String message;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: padding,
        child: Icon(
          icon ?? Icons.info_outline,
          size: 18,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}
