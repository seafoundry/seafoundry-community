// @tier: community
import 'package:flutter/material.dart';

class DividerWithLabel extends StatelessWidget {
  const DividerWithLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: theme.textTheme.labelLarge,
          ),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }
}
