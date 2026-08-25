import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_community/theme/animation_constants.dart';

/// Bottom action bar optimized for mobile-first, wet-finger operation
///
/// Replaces FAB with persistent bottom bar showing 3-5 primary actions
/// with large touch targets (64x64dp minimum) suitable for field use.
///
/// Usage:
/// ```dart
/// BottomActionBar(
///   actions: [
///     BottomAction(
///       label: 'Add',
///       icon: Icons.add,
///       onPressed: () => showAddDialog(),
///     ),
///     BottomAction(
///       label: 'Monitor',
///       icon: Icons.visibility,
///       onPressed: () => showMonitorDialog(),
///     ),
///   ],
/// )
/// ```
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.actions,
    this.backgroundColor,
    this.elevation = 4.0,
  });

  /// List of actions to display
  final List<BottomAction> actions;

  /// Background color (defaults to surface color)
  final Color? backgroundColor;

  /// Elevation for the bar
  final double elevation;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to 5 actions max for usability
    final displayActions = actions.length > 5 ? actions.sublist(0, 5) : actions;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: elevation,
            offset: Offset(0, -elevation / 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: displayActions.map((action) => _ActionButton(action: action)).toList(),
          ),
        ),
      ),
    );
  }
}

/// Individual action button in the bottom action bar
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final BottomAction action;

  @override
  Widget build(BuildContext context) {
    final isEnabled = action.onPressed != null && !action.disabled;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled
              ? () {
                  HapticFeedback.selectionClick();
                  action.onPressed?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(12.0),
          child: Semantics(
            button: true,
            enabled: isEnabled,
            label: action.tooltip ?? action.label,
            hint: action.tooltip != null ? null : 'Tap to ${action.label.toLowerCase()}',
            child: Container(
              constraints: BoxConstraints(
                minHeight: TouchTargetSizes.primary, // Minimum touch target per UI/UX spec
                minWidth: TouchTargetSizes.primary,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action.icon,
                    size: 28.0,
                    color: isEnabled
                        ? (action.color ?? Theme.of(context).colorScheme.primary)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    semanticLabel: action.label,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: isEnabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (action.badge != null) ...[
                    const SizedBox(height: 2.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: action.badgeColor ?? Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        action.badge!,
                        style: const TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with tooltip if provided
    if (action.tooltip != null && action.tooltip!.isNotEmpty) {
      content = Tooltip(
        message: action.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        preferBelow: false,
        child: content,
      );
    }

    return Expanded(child: content);
  }
}

/// Represents a single action in the bottom action bar
class BottomAction {
  /// Display label for the action
  final String label;

  /// Icon to display
  final IconData icon;

  /// Callback when action is pressed
  final VoidCallback? onPressed;

  /// Whether the action is disabled
  final bool disabled;

  /// Optional color for the icon
  final Color? color;

  /// Optional badge text (e.g., "3" for count)
  final String? badge;

  /// Optional badge color
  final Color? badgeColor;

  /// Optional tooltip message
  final String? tooltip;

  const BottomAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.disabled = false,
    this.color,
    this.badge,
    this.badgeColor,
    this.tooltip,
  });
}
