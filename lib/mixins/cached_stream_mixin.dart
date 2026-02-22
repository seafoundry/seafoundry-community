// @tier: community
import 'package:flutter/widgets.dart';

/// Mixin for widgets that need to cache a stream to prevent infinite rebuilds.
///
/// ## Problem
/// Creating new stream instances in build() methods causes infinite rebuild
/// loops on web because each rebuild creates a new Firestore subscription,
/// which emits initial data, triggering another rebuild.
///
/// ## Solution
/// This mixin caches the stream in initState() and provides a stable stream
/// reference that persists across rebuilds.
///
/// ## Usage
/// ```dart
/// class _MyWidgetState extends State<MyWidget>
///     with CachedStreamMixin<MyWidget, List<Item>> {
///   @override
///   Stream<List<Item>> createStream() {
///     return context.read<Repository>().watchItems(widget.itemId);
///   }
///
///   @override
///   bool shouldRecreateStream(MyWidget oldWidget) {
///     // Recreate stream if the itemId changes
///     return oldWidget.itemId != widget.itemId;
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return StreamBuilder<List<Item>>(
///       stream: cachedStream,
///       builder: (context, snapshot) { ... },
///     );
///   }
/// }
/// ```
///
/// ## Important Notes
/// - Override [createStream] to create your stream
/// - Override [shouldRecreateStream] if your stream depends on widget properties
///   that can change during the widget's lifecycle
/// - The stream is created once in initState() and cached
/// - If shouldRecreateStream returns true, the stream is recreated in didUpdateWidget
/// - [cachedStream] is only valid after initState() completes
/// - StreamBuilder automatically handles subscription cleanup in dispose()
/// - If [createStream] throws, an error stream is created to prevent crashes
mixin CachedStreamMixin<W extends StatefulWidget, S> on State<W> {
  late Stream<S> _cachedStream;

  /// The cached stream that persists across rebuilds.
  ///
  /// Use this in your StreamBuilder instead of creating a new stream.
  Stream<S> get cachedStream => _cachedStream;

  /// Create the stream. Called once in initState() and optionally in
  /// didUpdateWidget() if [shouldRecreateStream] returns true.
  ///
  /// Access widget properties via [widget].
  Stream<S> createStream();

  /// Determine if the stream should be recreated when widget properties change.
  ///
  /// Override this if your stream depends on widget properties that can change.
  /// Return true if any property affecting the stream has changed.
  ///
  /// Default: false (stream is created once and never recreated)
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool shouldRecreateStream(MyWidget oldWidget) {
  ///   return oldWidget.userId != widget.userId;
  /// }
  /// ```
  bool shouldRecreateStream(covariant W oldWidget) => false;

  @override
  void initState() {
    super.initState();
    try {
      _cachedStream = createStream();
    } catch (e, stackTrace) {
      // If createStream() throws, emit an error stream to prevent
      // uninitialized field access and provide error feedback to StreamBuilder
      _cachedStream = Stream.error(e, stackTrace);
    }
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shouldRecreateStream(oldWidget)) {
      try {
        _cachedStream = createStream();
      } catch (e, stackTrace) {
        _cachedStream = Stream.error(e, stackTrace);
      }
    }
  }
}
