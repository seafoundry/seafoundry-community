// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Mixin for dialogs that perform batch operations
///
/// This mixin provides:
/// - Progress tracking for batch operations
/// - Error collection and reporting
/// - Cancellation support
/// - Success/failure summaries
/// - Retry failed items
///
/// Usage:
/// ```dart
/// class BulkUpdateDialog extends StatefulWidget {
///   const BulkUpdateDialog({super.key});
///
///   @override
///   State<BulkUpdateDialog> createState() => _BulkUpdateDialogState();
/// }
///
/// class _BulkUpdateDialogState extends State<BulkUpdateDialog>
///     with BatchOperationMixin<BulkUpdateDialog, Coral> {
///
///   @override
///   Future<void> processItem(Coral item) async {
///     // Process individual item
///     await repository.update(item);
///   }
///
///   Future<void> _startBulkUpdate() async {
///     final items = getSelectedItems();
///     await executeBatchOperation(
///       items: items,
///       operationName: 'Updating corals',
///       onComplete: (results) {
///         showBatchSummaryDialog(context, results);
///       },
///     );
///   }
/// }
/// ```
mixin BatchOperationMixin<T extends StatefulWidget, I> on State<T> {
  BatchOperationController<I>? _batchController;

  /// Process a single item in the batch
  ///
  /// This should be implemented to define what happens to each item.
  /// Throw an exception if the operation fails for this item.
  Future<void> processItem(I item);

  /// Optional: Transform the item before displaying in progress/results
  String getItemDisplayName(I item) => item.toString();

  /// Optional: Custom error message for a failed item
  String getItemErrorMessage(I item, dynamic error) => error.toString();

  /// Optional: Whether to continue on errors
  bool get continueOnError => true;

  /// Optional: Maximum concurrent operations
  int get maxConcurrent => 3;

  /// Execute a batch operation
  Future<BatchOperationResult<I>> executeBatchOperation({
    required List<I> items,
    required String operationName,
    VoidCallback? onComplete,
    bool showProgress = true,
  }) async {
    _batchController = BatchOperationController<I>(
      items: items,
      processItem: processItem,
      getItemDisplayName: getItemDisplayName,
      continueOnError: continueOnError,
      maxConcurrent: maxConcurrent,
    );

    if (showProgress) {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: false,
        builder: (context) => BatchProgressDialog<I>(
          controller: _batchController!,
          operationName: operationName,
        ),
      );
    }

    final result = await _batchController!.execute();

    if (showProgress && mounted) {
      popSafeDialogContext(context);
    }

    onComplete?.call();

    return result;
  }

  /// Show a summary dialog for batch results
  void showBatchSummaryDialog(
    BuildContext context,
    BatchOperationResult<I> result,
  ) {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => BatchSummaryDialog<I>(
        result: result,
        getItemDisplayName: getItemDisplayName,
        onRetry: result.hasFailures
            ? () async {
                popSafeDialogContext(context);
                await executeBatchOperation(
                  items: result.failures.map((f) => f.item).toList(),
                  operationName: 'Retrying failed items',
                );
              }
            : null,
      ),
    );
  }

  /// Cancel the current batch operation
  void cancelBatchOperation() {
    _batchController?.cancel();
  }

  @override
  void dispose() {
    _batchController?.dispose();
    super.dispose();
  }
}

/// Controller for batch operations
class BatchOperationController<I> {
  final List<I> items;
  final Future<void> Function(I item) processItem;
  final String Function(I item) getItemDisplayName;
  final bool continueOnError;
  final int maxConcurrent;

  final _progressNotifier = ValueNotifier<BatchProgress<I>>(
    BatchProgress<I>(total: 0, completed: 0, failures: []),
  );

  bool _isCancelled = false;

  BatchOperationController({
    required this.items,
    required this.processItem,
    required this.getItemDisplayName,
    this.continueOnError = true,
    this.maxConcurrent = 3,
  }) {
    _progressNotifier.value = BatchProgress<I>(
      total: items.length,
      completed: 0,
      failures: [],
    );
  }

  ValueNotifier<BatchProgress<I>> get progress => _progressNotifier;

  Future<BatchOperationResult<I>> execute() async {
    final failures = <BatchFailure<I>>[];
    final successful = <I>[];
    int completed = 0;

    // Process items with concurrency limit
    for (int i = 0; i < items.length; i += maxConcurrent) {
      if (_isCancelled) break;

      final batch = items.skip(i).take(maxConcurrent).toList();

      await Future.wait(
        batch.map((item) async {
          if (_isCancelled) return;

          try {
            await processItem(item);
            successful.add(item);
          } catch (e, stackTrace) {
            LoggingService.instance.error(
              'Batch operation failed for item: ${getItemDisplayName(item)}',
              e,
              stackTrace,
            );
            failures.add(
              BatchFailure(item: item, error: e, stackTrace: stackTrace),
            );

            if (!continueOnError) {
              _isCancelled = true;
              return;
            }
          } finally {
            completed++;
            _progressNotifier.value = BatchProgress<I>(
              total: items.length,
              completed: completed,
              failures: List.from(failures),
              currentItem: completed < items.length
                  ? getItemDisplayName(items[completed])
                  : null,
            );
          }
        }),
      );
    }

    return BatchOperationResult<I>(
      total: items.length,
      successful: successful,
      failures: failures,
      cancelled: _isCancelled,
    );
  }

  void cancel() {
    _isCancelled = true;
  }

  void dispose() {
    _progressNotifier.dispose();
  }
}

/// Progress information for batch operations
class BatchProgress<I> {
  final int total;
  final int completed;
  final List<BatchFailure<I>> failures;
  final String? currentItem;

  BatchProgress({
    required this.total,
    required this.completed,
    required this.failures,
    this.currentItem,
  });

  double get percentage => total > 0 ? completed / total : 0;
  int get remaining => total - completed;
  bool get isComplete => completed >= total;
  int get successCount => completed - failures.length;
}

/// Result of a batch operation
class BatchOperationResult<I> {
  final int total;
  final List<I> successful;
  final List<BatchFailure<I>> failures;
  final bool cancelled;

  BatchOperationResult({
    required this.total,
    required this.successful,
    required this.failures,
    required this.cancelled,
  });

  bool get hasFailures => failures.isNotEmpty;
  bool get isFullySuccessful => failures.isEmpty && !cancelled;
  double get successRate => total > 0 ? successful.length / total : 0;

  String get summary {
    if (cancelled) {
      return 'Operation cancelled. $successCount of $total completed successfully.';
    }
    if (isFullySuccessful) {
      return 'All $total items processed successfully!';
    }
    return '$successCount of $total items succeeded, ${failures.length} failed.';
  }

  int get successCount => successful.length;
}

/// Information about a failed item
class BatchFailure<I> {
  final I item;
  final dynamic error;
  final StackTrace? stackTrace;

  BatchFailure({required this.item, required this.error, this.stackTrace});
}

/// Dialog showing batch operation progress
class BatchProgressDialog<I> extends StatelessWidget {
  final BatchOperationController<I> controller;
  final String operationName;

  const BatchProgressDialog({
    super.key,
    required this.controller,
    required this.operationName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(operationName),
      content: SizedBox(
        width: 400,
        child: ValueListenableBuilder<BatchProgress<I>>(
          valueListenable: controller.progress,
          builder: (context, progress, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.percentage,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${progress.completed} of ${progress.total}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${(progress.percentage * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (progress.currentItem != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Processing: ${progress.currentItem}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (progress.failures.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${progress.failures.length} failed',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: Theme.of(context).textTheme.bodySmall!.fontSize,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => controller.cancel(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Dialog showing batch operation summary
class BatchSummaryDialog<I> extends StatelessWidget {
  final BatchOperationResult<I> result;
  final String Function(I item) getItemDisplayName;
  final VoidCallback? onRetry;

  const BatchSummaryDialog({
    super.key,
    required this.result,
    required this.getItemDisplayName,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final success = result.isFullySuccessful;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.warning,
            color: success ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Text('Operation Complete'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.summary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (result.hasFailures) ...[
              const SizedBox(height: 16),
              const Text(
                'Failed items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.failures.length,
                  itemBuilder: (context, index) {
                    final failure = result.failures[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 20,
                      ),
                      title: Text(getItemDisplayName(failure.item)),
                      subtitle: Text(
                        failure.error.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (onRetry != null && result.hasFailures)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Failed'),
          ),
        ElevatedButton(
          onPressed: () => popSafeDialogContext(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
