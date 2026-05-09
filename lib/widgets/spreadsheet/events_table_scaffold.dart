import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/responsive_filter_section.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';

/// Generic scaffold for event-history table widgets shared by inventory and
/// genetics events tables.
///
/// Owns the load / error / empty / loaded display states plus the surrounding
/// filter chrome. Subclasses provide the row type, columns, toolbar, data
/// loader, and filter logic.
///
/// Field naming intentionally drops the `_` prefix so subclass-side mixins
/// (which live in the same library via `part`) can write to the lifecycle
/// state during loading without piping it through setters.
abstract class EventsTableScaffoldState<W extends StatefulWidget, TRow>
    extends State<W> with SafeProviderReadMixin<W> {
  // --- Lifecycle state owned by the scaffold ---
  @protected
  bool isLoading = true;
  @protected
  double? loadingProgress;
  @protected
  String? loadingStatus;
  @protected
  String? error;
  @protected
  final List<TRow> rows = [];
  @protected
  List<TRow> filteredRows = const [];

  // --- Subclass contract ---

  /// Display title used in headers, log messages, and the empty state.
  @protected
  String get title;

  /// Icon shown in the empty state when no events have been loaded.
  @protected
  IconData get emptyIcon;

  /// Optional copy shown beneath the empty-state title.
  @protected
  String? get emptyMessage => null;

  /// Columns rendered by the inner [SpreadsheetBase].
  @protected
  List<SpreadsheetColumn> get columns;

  /// Builds a single spreadsheet row from a hydrated event row.
  @protected
  SpreadsheetRow Function(TRow row) get rowBuilder;

  /// Pagination service backing the inner [SpreadsheetBase].
  @protected
  PaginationService<TRow> get paginationService;

  /// Builds the filter toolbar shown inside the [ResponsiveFilterSection].
  @protected
  Widget buildToolbar(BuildContext context);

  /// Loads events into [rows]. Subclasses populate [rows] and call
  /// [setState] / mutate the inherited lifecycle fields directly.
  @protected
  Future<void> loadEvents();

  /// Recomputes [filteredRows] from [rows] using the subclass's filter state.
  @protected
  void applyFilters({required bool updateState});

  /// Stable key for the inner [SpreadsheetBase], typically derived from the
  /// active filter selections so the grid resets when filters change.
  @protected
  String currentFilterKey();

  /// Optional widgets rendered above the filter chrome (e.g. summary cards
  /// from the genetics view).
  @protected
  List<Widget> get leadingHeader => const <Widget>[];

  /// Widget shown when [rows] is non-empty but no row matches the current
  /// filters. Defaults to a plain message; override for a custom no-match UX
  /// (such as a "reset filters" affordance).
  @protected
  Widget buildEmptyFilteredState(BuildContext context) {
    return const Center(
      child: Text(
        'No events match the current filters.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  // --- Lifecycle ---

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadEvents());
  }

  // --- Standard scaffold build ---

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return EventsTableLoading(
        status: loadingStatus,
        progress: loadingProgress,
      );
    }

    if (error != null) {
      return EventsTableError(error: error!, onRetry: loadEvents);
    }

    if (rows.isEmpty) {
      return EventsTableEmpty(
        title: title,
        icon: emptyIcon,
        message: emptyMessage,
      );
    }

    final headerWidgets = <Widget>[
      ...leadingHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveFilterSection(
              label: 'Filters',
              initiallyExpanded: false,
              child: buildToolbar(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: filteredRows.isEmpty
          ? buildEmptyFilteredState(context)
          : SpreadsheetBase<TRow>(
              key: ValueKey(currentFilterKey()),
              columns: columns,
              rowBuilder: rowBuilder,
              pageLoader: paginationService.buildListLoader(() => filteredRows),
              sortField: 'timestamp',
              descending: true,
              header: Text('$title - ${filteredRows.length} records'),
            ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }
}

/// Loading placeholder shared by event-history tables.
class EventsTableLoading extends StatelessWidget {
  const EventsTableLoading({super.key, required this.status, required this.progress});

  final String? status;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status!, textAlign: TextAlign.center),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(value: progress),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error placeholder shared by event-history tables.
class EventsTableError extends StatelessWidget {
  const EventsTableError({super.key, required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state placeholder shown when no events have been loaded yet.
class EventsTableEmpty extends StatelessWidget {
  const EventsTableEmpty({
    super.key,
    required this.title,
    required this.icon,
    this.message,
  });

  final String title;
  final IconData icon;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No $title found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
