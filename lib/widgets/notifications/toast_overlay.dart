// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';

enum ToastPosition { top, bottom }

class ToastController {
  ToastController._(this._dismiss);

  final VoidCallback _dismiss;

  void close() => _dismiss();

  static ToastController noop() => ToastController._(() {});
}

class ToastOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static ToastController show({
    required BuildContext context,
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? textColor,
    ToastPosition position = ToastPosition.bottom,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(8)),
    double elevation = 6,
    bool autoDismiss = true,
  }) {
    if (!context.mounted) {
      return ToastController.noop();
    }

    _dismissCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);
    // Analyzer reports this check as unnecessary, but it's needed for edge cases
    // where widgets are rendered outside MaterialApp/Navigator (tests, etc.)
    // ignore: unnecessary_null_comparison
    if (overlay == null) {
      return ToastController.noop();
    }

    final entry = OverlayEntry(
      builder: (context) => _ToastOverlayEntry(
        content: content,
        backgroundColor: backgroundColor,
        textColor: textColor,
        position: position,
        margin: margin,
        padding: padding,
        borderRadius: borderRadius,
        elevation: elevation,
      ),
    );

    overlay.insert(entry);
    _currentEntry = entry;

    if (autoDismiss) {
      _dismissTimer = Timer(duration, _dismissCurrent);
    }

    return ToastController._(_dismissCurrent);
  }

  static ToastController showText(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
    ToastPosition position = ToastPosition.bottom,
    bool autoDismiss = true,
  }) {
    final theme = Theme.of(context);
    final resolvedBackground = backgroundColor ??
        (isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : theme.snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface);

    final resolvedTextColor = textColor ?? _resolveTextColor(resolvedBackground, theme);

    final content = _buildContent(
      Text(message, style: TextStyle(color: resolvedTextColor)),
      action,
      resolvedTextColor,
    );

    return show(
      context: context,
      content: content,
      backgroundColor: resolvedBackground,
      textColor: resolvedTextColor,
      duration: duration,
      position: position,
      autoDismiss: autoDismiss,
    );
  }

  static ToastController showSnackBar(
    BuildContext context,
    SnackBar snackBar, {
    ToastPosition position = ToastPosition.bottom,
  }) {
    final theme = Theme.of(context);
    final resolvedBackground =
        snackBar.backgroundColor ?? theme.snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface;
    final resolvedTextColor = _resolveTextColor(resolvedBackground, theme);

    final content = _buildContent(
      DefaultTextStyle(style: TextStyle(color: resolvedTextColor), child: snackBar.content),
      snackBar.action,
      resolvedTextColor,
    );

    return show(
      context: context,
      content: content,
      backgroundColor: resolvedBackground,
      textColor: resolvedTextColor,
      duration: snackBar.duration,
      position: position,
      autoDismiss: snackBar.duration > Duration.zero,
      borderRadius: snackBar.shape is RoundedRectangleBorder
          ? (snackBar.shape as RoundedRectangleBorder).borderRadius
          : const BorderRadius.all(Radius.circular(8)),
    );
  }

  static void dismissCurrent() => _dismissCurrent();

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static Widget _buildContent(Widget content, SnackBarAction? action, Color textColor) {
    if (action == null) {
      return content;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: content),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () {
            action.onPressed();
            _dismissCurrent();
          },
          style: TextButton.styleFrom(
            foregroundColor: action.textColor ?? textColor,
          ),
          child: Text(action.label),
        ),
      ],
    );
  }

  static Color _resolveTextColor(Color backgroundColor, ThemeData theme) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : theme.colorScheme.onSurface;
  }
}

class _ToastOverlayEntry extends StatefulWidget {
  const _ToastOverlayEntry({
    required this.content,
    required this.backgroundColor,
    required this.textColor,
    required this.position,
    required this.margin,
    required this.padding,
    required this.borderRadius,
    required this.elevation,
  });

  final Widget content;
  final Color? backgroundColor;
  final Color? textColor;
  final ToastPosition position;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry borderRadius;
  final double elevation;

  @override
  State<_ToastOverlayEntry> createState() => _ToastOverlayEntryState();
}

class _ToastOverlayEntryState extends State<_ToastOverlayEntry> {
  @override
  void dispose() {
    // Cancel the static dismiss timer when the widget tree tears down.
    // This prevents "Timer still pending" assertions in tests.
    // The OverlayEntry is already being removed by the framework.
    ToastOverlay._dismissTimer?.cancel();
    ToastOverlay._dismissTimer = null;
    ToastOverlay._currentEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground =
        widget.backgroundColor ?? theme.snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface;
    final resolvedTextColor = widget.textColor ?? ToastOverlay._resolveTextColor(resolvedBackground, theme);

    final resolvedMargin = widget.margin ??
        (widget.position == ToastPosition.top
            ? const EdgeInsets.only(left: 16, right: 16, top: 16)
            : const EdgeInsets.only(left: 16, right: 16, bottom: 16));
    final resolvedPadding = widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: widget.position == ToastPosition.top ? Alignment.topCenter : Alignment.bottomCenter,
          child: Padding(
            padding: resolvedMargin,
            child: Material(
              color: resolvedBackground,
              elevation: widget.elevation,
              borderRadius: widget.borderRadius,
              child: DefaultTextStyle(
                style: TextStyle(color: resolvedTextColor),
                child: Padding(
                  padding: resolvedPadding,
                  child: widget.content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
