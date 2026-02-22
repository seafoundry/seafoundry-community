// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Base widget for holdings map detail sheets with common boilerplate.
///
/// Provides:
/// - DraggableScrollableSheet configuration
/// - Material wrapper with rounded corners
/// - Sheet drag handle
/// - Header with icon, title, optional subtitle, and close button
/// - Divider between header and content
///
/// Usage:
/// ```dart
/// HoldingsMapDetailsSheet(
///   title: 'Site Name',
///   subtitle: 'Region',
///   contentBuilder: (scrollController) => MyContentWidget(
///     scrollController: scrollController,
///   ),
/// )
/// ```
class HoldingsMapDetailsSheet extends StatelessWidget {
  const HoldingsMapDetailsSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.contentBuilder,
    this.initialChildSize = 0.55,
  });

  /// The main title displayed in the header.
  final String title;

  /// Optional subtitle displayed below the title.
  final String? subtitle;

  /// Builder that provides the sheet content with access to the scroll controller.
  final Widget Function(ScrollController scrollController) contentBuilder;

  /// Initial size of the sheet as a fraction of screen height.
  /// Defaults to 0.55 (55%).
  final double initialChildSize;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SheetHandle(),
              SheetHeader(title: title, subtitle: subtitle),
              const Divider(height: 1),
              Expanded(child: contentBuilder(scrollController)),
            ],
          ),
        );
      },
    );
  }
}

/// Drag handle indicator for bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Header row for holdings map detail sheets.
///
/// Shows a location icon, title, optional subtitle, and close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.location_on, color: crcAccentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
