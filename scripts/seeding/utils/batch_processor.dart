// Generic batch processing utility for Firestore operations.
//
// Provides a reusable function to process items in parallel batches,
// avoiding overwhelming Firestore with too many concurrent operations.

/// Processes items in parallel batches to avoid overwhelming Firestore.
///
/// Splits [items] into chunks of [batchSize] and processes each chunk
/// concurrently using [Future.wait]. This provides a balance between
/// sequential processing (too slow) and fully parallel processing
/// (may overwhelm Firestore or hit rate limits).
///
/// Example:
/// ```dart
/// await batchProcess(
///   organisms,
///   (o) => organismRepo.deleteRecord(o),
///   batchSize: 50,
/// );
/// ```
Future<void> batchProcess<T>(
  List<T> items,
  Future<void> Function(T item) action, {
  int batchSize = 10,
}) async {
  for (var i = 0; i < items.length; i += batchSize) {
    final end = (i + batchSize < items.length) ? i + batchSize : items.length;
    final batch = items.sublist(i, end);
    await Future.wait(batch.map(action));
  }
}
