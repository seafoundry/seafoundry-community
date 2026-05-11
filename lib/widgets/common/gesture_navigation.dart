import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gesture navigation helper for common operations
///
/// Provides swipe gestures for:
/// - Swipe to dismiss dialogs/sheets
/// - Swipe to refresh data
/// - Swipe to navigate (back/forward)
/// - Swipe to delete/archive
///
/// Optimized for wet-finger conditions with generous gesture thresholds.
class GestureNavigation {
  /// Minimum swipe distance (in logical pixels) to trigger action
  static const double minSwipeDistance = 100.0;

  /// Minimum swipe velocity (pixels/second) to trigger action
  static const double minSwipeVelocity = 500.0;
}

/// Wrapper widget that adds swipe-to-dismiss functionality
///
/// Usage:
/// ```dart
/// SwipeToDismissWrapper(
///   onDismiss: () => Navigator.of(context).pop(),
///   child: Dialog(...),
/// )
/// ```
class SwipeToDismissWrapper extends StatefulWidget {
  const SwipeToDismissWrapper({
    super.key,
    required this.child,
    required this.onDismiss,
    this.enabled = true,
    this.direction = DismissDirection.down,
    this.dismissibleKey,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;
  final DismissDirection direction;
  final Key? dismissibleKey;

  @override
  State<SwipeToDismissWrapper> createState() => _SwipeToDismissWrapperState();
}

class _SwipeToDismissWrapperState extends State<SwipeToDismissWrapper> {
  late final Key _internalKey;

  @override
  void initState() {
    super.initState();
    _internalKey = UniqueKey();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Dismissible(
      key: widget.dismissibleKey ?? _internalKey,
      direction: widget.direction,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDismiss();
      },
      background: Container(
        color: Colors.red.withValues(alpha: 0.1),
        alignment: _getAlignment(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          _getIcon(),
          color: Colors.red,
          size: 32,
        ),
      ),
      child: Semantics(
        label: 'Swipe down to dismiss',
        hint: 'Swipe down to close this dialog',
        child: widget.child,
      ),
    );
  }

  Alignment _getAlignment() {
    switch (widget.direction) {
      case DismissDirection.down:
        return Alignment.topCenter;
      case DismissDirection.up:
        return Alignment.bottomCenter;
      case DismissDirection.startToEnd:
        return Alignment.centerLeft;
      case DismissDirection.endToStart:
        return Alignment.centerRight;
      case DismissDirection.horizontal:
      case DismissDirection.vertical:
        return Alignment.center;
      case DismissDirection.none:
        return Alignment.center;
    }
  }

  IconData _getIcon() {
    switch (widget.direction) {
      case DismissDirection.down:
        return Icons.keyboard_arrow_down;
      case DismissDirection.up:
        return Icons.keyboard_arrow_up;
      case DismissDirection.startToEnd:
        return Icons.keyboard_arrow_right;
      case DismissDirection.endToStart:
        return Icons.keyboard_arrow_left;
      case DismissDirection.horizontal:
      case DismissDirection.vertical:
      case DismissDirection.none:
        return Icons.close;
    }
  }
}

/// Wrapper widget that adds swipe-to-refresh functionality
///
/// Usage:
/// ```dart
/// SwipeToRefreshWrapper(
///   onRefresh: () async {
///     await refreshData();
///   },
///   child: ListView(...),
/// )
/// ```
class SwipeToRefreshWrapper extends StatelessWidget {
  const SwipeToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await onRefresh();
      },
      child: child,
    );
  }
}

/// Wrapper widget that adds swipe-to-navigate functionality
///
/// Swipe from the left edge to go back, swipe from right edge to go forward.
/// Only triggers when the gesture starts within [edgeWidth] of the screen edge
/// to avoid conflicting with content scrolling (spreadsheets, lists, etc).
///
/// Usage:
/// ```dart
/// SwipeToNavigateWrapper(
///   onBack: () => Navigator.of(context).pop(),
///   child: Scaffold(...),
/// )
/// ```
class SwipeToNavigateWrapper extends StatefulWidget {
  const SwipeToNavigateWrapper({
    super.key,
    required this.child,
    this.onBack,
    this.onForward,
    this.enabled = true,
    this.edgeWidth = 20.0,
  });

  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final bool enabled;

  /// Width of the edge zone where swipe gestures trigger navigation.
  /// Gestures starting outside this zone are ignored to allow content scrolling.
  final double edgeWidth;

  @override
  State<SwipeToNavigateWrapper> createState() => _SwipeToNavigateWrapperState();
}

class _SwipeToNavigateWrapperState extends State<SwipeToNavigateWrapper> {
  double _dragDistance = 0;
  double? _startX;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _EdgeSwipeGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EdgeSwipeGestureRecognizer>(
          () => _EdgeSwipeGestureRecognizer(
            isEdgePosition: _isEdgePosition,
            debugOwner: this,
          ),
          (_EdgeSwipeGestureRecognizer instance) {
            instance
              ..dragStartBehavior = DragStartBehavior.down
              ..onStart = _handleDragStart
              ..onUpdate = _handleDragUpdate
              ..onEnd = _handleDragEnd;
          },
        ),
      },
      child: widget.child,
    );
  }

  bool _isEdgePosition(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final canGoBack = widget.onBack != null;
    final canGoForward = widget.onForward != null;
    final isLeftEdge = canGoBack && position.dx <= widget.edgeWidth;
    final isRightEdge =
        canGoForward && position.dx >= screenWidth - widget.edgeWidth;
    return isLeftEdge || isRightEdge;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragDistance = 0;
    _startX = details.globalPosition.dx;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_startX == null) {
      _reset();
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final fastEnough = velocity.abs() >= GestureNavigation.minSwipeVelocity;
    final farEnough =
        _dragDistance.abs() >= GestureNavigation.minSwipeDistance;

    if (!fastEnough || !farEnough) {
      _reset();
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    // Swipe right from left edge = go back
    if (velocity > 0 &&
        _startX! <= widget.edgeWidth &&
        widget.onBack != null) {
      HapticFeedback.selectionClick();
      widget.onBack!();
    }
    // Swipe left from right edge = go forward
    else if (velocity < 0 &&
        _startX! >= screenWidth - widget.edgeWidth &&
        widget.onForward != null) {
      HapticFeedback.selectionClick();
      widget.onForward!();
    }

    _reset();
  }

  void _reset() {
    _dragDistance = 0;
    _startX = null;
  }
}

class _EdgeSwipeGestureRecognizer extends HorizontalDragGestureRecognizer {
  _EdgeSwipeGestureRecognizer({
    required this.isEdgePosition,
    super.debugOwner,
  });

  final bool Function(Offset position) isEdgePosition;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (!isEdgePosition(event.position)) {
      return false;
    }
    return super.isPointerAllowed(event);
  }
}

/// Wrapper widget that adds swipe-to-delete functionality
///
/// Usage:
/// ```dart
/// SwipeToDeleteWrapper(
///   onDelete: () => deleteItem(),
///   child: ListTile(...),
/// )
/// ```
class SwipeToDeleteWrapper extends StatelessWidget {
  const SwipeToDeleteWrapper({
    super.key,
    required this.child,
    required this.onDelete,
    this.enabled = true,
    this.confirmBeforeDelete = true,
    this.dismissibleKey,
  });

  final Widget child;
  final VoidCallback onDelete;
  final bool enabled;
  final bool confirmBeforeDelete;
  final Key? dismissibleKey;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Dismissible(
      key: dismissibleKey ?? ValueKey('swipe-to-delete-$hashCode'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        if (!confirmBeforeDelete) {
          onDelete();
          return true;
        }
        return await _showDeleteConfirmation(context);
      },
      onDismissed: (_) {},
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      child: child,
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onDelete();
      return true;
    }
    return false;
  }
}

