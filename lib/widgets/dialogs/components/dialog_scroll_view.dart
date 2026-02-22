// @tier: community
import 'package:flutter/material.dart';

/// Dialog-friendly scroll view that preserves the user's scroll position
/// across rebuilds triggered by form state updates.
class DialogScrollView extends StatefulWidget {
  const DialogScrollView({
    super.key,
    required this.child,
    this.padding,
    this.physics,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.primary,
    this.clipBehavior = Clip.hardEdge,
    this.keyboardDismissBehavior,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool reverse;
  final bool? primary;
  final Clip clipBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  @override
  State<DialogScrollView> createState() => _DialogScrollViewState();
}

class _DialogScrollViewState extends State<DialogScrollView> {
  ScrollController? _ownedController;
  double _pendingRestoreOffset = 0.0;
  bool _restoreScheduled = false;

  ScrollController get _controller =>
      widget.controller ?? (_ownedController ??= ScrollController());

  @override
  void didUpdateWidget(DialogScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ownedController?.dispose();
      _ownedController = widget.controller == null ? ScrollController() : null;
    }
    _captureOffset();
    _scheduleRestore();
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  void _captureOffset() {
    if (_controller.hasClients) {
      _pendingRestoreOffset = _controller.offset;
    }
  }

  void _scheduleRestore() {
    if (_restoreScheduled) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      _restoreOffset();
    });
  }

  void _restoreOffset() {
    if (!mounted || !_controller.hasClients) return;
    final maxOffset = _controller.position.maxScrollExtent;
    final target = _pendingRestoreOffset.clamp(0.0, maxOffset);
    final current = _controller.offset;
    final needsRestore = target > 0 && current <= 4.0;
    if (needsRestore && (current - target).abs() > 0.5) {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      padding: widget.padding,
      physics: widget.physics,
      clipBehavior: widget.clipBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior ??
          ScrollViewKeyboardDismissBehavior.manual,
      primary: widget.controller == null ? widget.primary : false,
      child: widget.child,
    );
  }
}
