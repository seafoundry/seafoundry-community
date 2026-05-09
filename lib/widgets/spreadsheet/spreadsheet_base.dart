import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:seafoundry_app/services/logging_service.dart';

import 'spreadsheet_models.dart';

typedef PageCursor = Object?;

class PageResult<T> {
  final List<T> items;
  final PageCursor? nextCursor;
  final int? totalCount;

  const PageResult({required this.items, this.nextCursor, this.totalCount});
}

typedef PageLoader<T> =
    Future<PageResult<T>> Function({
      required int pageSize,
      PageCursor? startAfter,
      String? sortField,
      bool descending,
    });

class SpreadsheetBaseController {
  _SpreadsheetBaseState? _state;

  bool get isAttached => _state != null;
  List<dynamic>? get debugItems => _state?.debugItems;

  Future<void> reload({bool maintainPageIndex = false}) async {
    await _state?._reloadFromController(maintainPageIndex: maintainPageIndex);
  }

  Future<void> nextPage() async {
    await _state?._nextPageFromController();
  }

  Future<void> previousPage() async {
    await _state?._previousPageFromController();
  }

  void markAsChanged() {
    _state?.markAsChanged();
  }

  void markAsSaved() {
    _state?.markAsSaved();
  }

  void _attach(_SpreadsheetBaseState state) {
    _state = state;
  }

  void _detach(_SpreadsheetBaseState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

/// Base class for paginated spreadsheet widgets using PlutoGrid
///
/// **Migration Status**: Remains StatefulWidget (legitimate use case)
///
/// **Why StatefulWidget**:
/// - Manages complex controller attachment/detachment lifecycle (`SpreadsheetBaseController`)
/// - Handles PlutoGrid state initialization and disposal
/// - Maintains pagination state (_pageIndex, _cursors, _nextCursor) that requires
///   lifecycle-aware initialization
/// - Navigation protection (unsaved changes warning) requires widget lifecycle
/// - Controller pattern requires state attachment/detachment in initState/dispose
///
/// **Design Decision**: Controller pattern allows external code to trigger reloads
/// and pagination. This requires state attachment which needs StatefulWidget lifecycle.
/// Could theoretically migrate to BLoC, but controller pattern is simpler for this
/// spreadsheet use case and doesn't require testable business logic.
class SpreadsheetBase<T> extends StatefulWidget {
  const SpreadsheetBase({
    super.key,
    required this.columns,
    required this.rowBuilder,
    required this.pageLoader,
    this.initialPageSize = 100,
    this.pageSizeOptions = const [50, 100, 200],
    this.sortField,
    this.descending = true,
    this.header,
    this.actions,
    this.reloadToken = 0,
    this.enableNavigationProtection = false,
    this.navigationProtectionTitle = 'Leave spreadsheet?',
    this.navigationProtectionMessage =
        'You have unsaved changes. Are you sure you want to leave?',
    this.controller,
  });

  final List<SpreadsheetColumn> columns;
  final SpreadsheetRow Function(T item) rowBuilder;
  final PageLoader<T> pageLoader;
  final int initialPageSize;
  final List<int> pageSizeOptions;
  final String? sortField;
  final bool descending;
  final Widget? header;
  final List<Widget>? actions;

  /// When this value changes, the spreadsheet reloads its first page.
  final int reloadToken;
  final bool enableNavigationProtection;
  final String navigationProtectionTitle;
  final String navigationProtectionMessage;
  final SpreadsheetBaseController? controller;

  @override
  State<SpreadsheetBase<T>> createState() => _SpreadsheetBaseState<T>();
}

class _SpreadsheetBaseState<T> extends State<SpreadsheetBase<T>> {
  final List<T> _items = [];
  final List<PageCursor?> _cursors = [null];
  bool _loading = false;
  int _pageIndex = 0;
  int _pageSize = 100;
  PageCursor? _nextCursor;
  int? _totalCount;
  bool _hasUnsavedChanges = false;
  int _lastReloadToken = 0;
  @visibleForTesting
  List<T> get debugItems => List.unmodifiable(_items);

  List<PlutoColumn> _plutoColumns = const [];
  List<PlutoRow> _plutoRows = const [];
  int _columnsVersion = 0;
  int _dataVersion = 0;

  SpreadsheetBaseController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.initialPageSize;
    _lastReloadToken = widget.reloadToken;
    _plutoColumns = _createPlutoColumns(widget.columns);
    _attachController();
    _loadFirstPage();
  }

  void _attachController() {
    _controller?._attach(this);
  }

  void _detachController(SpreadsheetBaseController? controller) {
    controller?._detach(this);
  }

  @override
  void didUpdateWidget(covariant SpreadsheetBase<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController();
    }

    if (!_columnsEqual(oldWidget.columns, widget.columns)) {
      setState(() {
        _plutoColumns = _createPlutoColumns(widget.columns);
        _columnsVersion++;
      });
    }

    final shouldReload =
        widget.reloadToken != _lastReloadToken ||
        widget.sortField != oldWidget.sortField ||
        widget.descending != oldWidget.descending ||
        widget.initialPageSize != oldWidget.initialPageSize;

    if (shouldReload) {
      _lastReloadToken = widget.reloadToken;
      _pageSize = widget.initialPageSize;
      _loadFirstPage();
    }
  }

  bool _columnsEqual(List<SpreadsheetColumn> a, List<SpreadsheetColumn> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key ||
          a[i].title != b[i].title ||
          a[i].width != b[i].width ||
          a[i].minWidth != b[i].minWidth ||
          a[i].alignment != b[i].alignment ||
          a[i].type != b[i].type ||
          a[i].enableSorting != b[i].enableSorting ||
          a[i].enableEditing != b[i].enableEditing) {
        return false;
      }
    }
    return true;
  }

  /// Mark that there are unsaved changes
  void markAsChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Clear the unsaved changes flag
  void markAsSaved() {
    if (_hasUnsavedChanges && mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _items.clear();
      _plutoRows = const [];
      _cursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
      _nextCursor = null;
      _totalCount = null;
    });

    final result = await widget.pageLoader(
      pageSize: _pageSize,
      startAfter: null,
      sortField: widget.sortField,
      descending: widget.descending,
    );

    if (!mounted) return;

    setState(() {
      _applyPageResult(result);
      _loading = false;
    });
  }

  void _applyPageResult(PageResult<T> result) {
    _items
      ..clear()
      ..addAll(result.items);
    _plutoRows = _buildPlutoRows(_items);
    _nextCursor = result.nextCursor;
    _totalCount = result.totalCount;
    _dataVersion++;
  }

  Future<void> _reloadFromController({bool maintainPageIndex = false}) async {
    if (!mounted) return;
    if (maintainPageIndex && _pageIndex > 0) {
      final startCursor = _cursors[_pageIndex];
      setState(() => _loading = true);
      final result = await widget.pageLoader(
        pageSize: _pageSize,
        startAfter: startCursor,
        sortField: widget.sortField,
        descending: widget.descending,
      );
      if (!mounted) return;
      setState(() {
        _applyPageResult(result);
        _loading = false;
      });
      return;
    }
    await _loadFirstPage();
  }

  Future<void> _loadNextPage() async {
    if (_nextCursor == null || _loading) return;
    setState(() => _loading = true);
    final result = await widget.pageLoader(
      pageSize: _pageSize,
      startAfter: _nextCursor,
      sortField: widget.sortField,
      descending: widget.descending,
    );
    if (!mounted) return;
    setState(() {
      _cursors.add(_nextCursor);
      _applyPageResult(result);
      _pageIndex += 1;
      _loading = false;
    });
  }

  Future<void> _loadPrevPage() async {
    if (_pageIndex == 0 || _loading) return;
    setState(() => _loading = true);
    final prevCursor = _cursors[_pageIndex];
    final result = await widget.pageLoader(
      pageSize: _pageSize,
      startAfter: prevCursor,
      sortField: widget.sortField,
      descending: widget.descending,
    );
    if (!mounted) return;
    setState(() {
      _applyPageResult(result);
      _pageIndex -= 1;
      _loading = false;
    });
  }

  Future<void> _nextPageFromController() async {
    await _loadNextPage();
  }

  Future<void> _previousPageFromController() async {
    await _loadPrevPage();
  }

  @override
  void dispose() {
    _detachController(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final actions = widget.actions;

    Widget buildContent(BoxConstraints constraints) {
      final hasBoundedHeight =
          constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
      final hasHeader = header != null || (actions?.isNotEmpty ?? false);

      // On narrow screens, constrain header height to prevent overflow
      final isNarrow = constraints.maxWidth < 600;
      final maxHeaderHeight = hasBoundedHeight && isNarrow
          ? constraints.maxHeight * 0.4
          : double.infinity;

      Widget? headerWidget;
      if (hasHeader) {
        final headerContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) header,
              if (actions != null && actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(spacing: 8, runSpacing: 8, children: actions),
                ),
            ],
          ),
        );

        // Make header scrollable on narrow screens to prevent overflow
        headerWidget = isNarrow && hasBoundedHeight
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeaderHeight),
                child: SingleChildScrollView(child: headerContent),
              )
            : headerContent;
      }

      final gridSection = hasBoundedHeight
          ? Expanded(
              // Let PlutoGrid fill the remaining bounded height.
              child: _buildGrid(context),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 240),
              child: _buildGrid(context),
            );

      final footer = _buildFooter(context);

      final columnChildren = <Widget>[
        if (headerWidget != null) headerWidget,
        gridSection,
        footer,
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
        children: columnChildren,
      );
    }

    final content = LayoutBuilder(
      builder: (context, constraints) {
        return buildContent(constraints);
      },
    );

    if (widget.enableNavigationProtection) {
      return PopScope(
        canPop: !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || !_hasUnsavedChanges) return;

          final navigator = Navigator.of(context);
          final shouldLeave = await showDialog<bool>(
            context: context,
            useRootNavigator: false,
            builder: (ctx) => AlertDialog(
              title: Text(widget.navigationProtectionTitle),
              content: Text(widget.navigationProtectionMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );

          if (!mounted) return;
          if (shouldLeave ?? false) {
            navigator.pop(result);
          }
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final style = PlutoGridStyleConfig(
      gridBorderColor: theme.dividerColor,
      rowHeight: 36, // Denser rows (was 44)
      columnHeight: 40, // Denser headers (was 48)
      columnFilterHeight: 40,
      columnTextStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: theme.textTheme.bodyMedium?.color,
          ) ??
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      cellTextStyle: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.1,
            fontFamily: 'RobotoMono', // Monospace for data feel
          ) ??
          const TextStyle(fontSize: 12, height: 1.1),
      gridBackgroundColor: theme.colorScheme.surface,
      borderColor: theme.dividerColor,
      menuBackgroundColor: theme.cardColor,
      activatedBorderColor: theme.primaryColor,
      inactivatedBorderColor: theme.dividerColor,
      checkedColor: theme.primaryColor.withValues(alpha: 0.1),
      enableCellBorderVertical: true,
      enableColumnBorderVertical: true,
    );

    final grid = PlutoGrid(
      key: ValueKey(
        '${_columnsVersion}_${widget.reloadToken}_${_pageIndex}_$_dataVersion',
      ),
      columns: _plutoColumns,
      rows: _plutoRows,
      mode: PlutoGridMode.readOnly,
      configuration: PlutoGridConfiguration(
        style: style,
        columnFilter: const PlutoGridColumnFilterConfig(),
        enterKeyAction: PlutoGridEnterKeyAction.none,
      ),
    );

    // Wrap grid in GestureDetector to capture horizontal drags and prevent
    // browser back/forward navigation on web when scrolling the spreadsheet.
    // Uses HitTestBehavior.opaque to fully consume horizontal gestures and
    // prevent SwipeToNavigateWrapper from misinterpreting spreadsheet scrolling
    // as a back navigation gesture.
    final wrappedGrid = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: grid,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Removed heavy card decorations for a sharper "data" look
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.dividerColor),
          ),
          child: wrappedGrid,
        ),
        if (_loading)
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_items.isEmpty)
          Positioned.fill(
            child: Center(
              child: Text(
                'No data',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final options = <int>{...widget.pageSizeOptions, _pageSize}.toList()
      ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final rowControls = Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Rows:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _pageSize,
                isDense: true,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                items: options
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _pageSize) return;
                  setState(() => _pageSize = value);
                  _loadFirstPage();
                },
              ),
            ),
            if (_totalCount != null)
              Text(
                '${_totalCount!} records',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );

        final paginationControls = Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              icon: const Icon(Icons.chevron_left, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _loading || _pageIndex == 0 ? null : _loadPrevPage,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Page ${_pageIndex + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              icon: const Icon(Icons.chevron_right, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _loading || _nextCursor == null ? null : _loadNextPage,
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.surfaceContainerLow, // Subtle footer background
            border: Border(
              top: BorderSide(color: theme.dividerColor),
              left: BorderSide(color: theme.dividerColor),
              right: BorderSide(color: theme.dividerColor),
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    rowControls,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: paginationControls,
                    ),
                  ],
                )
              : Row(
                  children: [
                    rowControls,
                    const Spacer(),
                    paginationControls,
                  ],
                ),
        );
      },
    );
  }

  List<PlutoColumn> _createPlutoColumns(List<SpreadsheetColumn> columns) {
    return List<PlutoColumn>.generate(columns.length, (index) {
      final column = columns[index];
      final field = _fieldForIndex(index);

      final PlutoColumnTextAlign columnTextAlign;
      final Alignment contentAlignment;
      final TextAlign textAlign;

      if (column.alignment == Alignment.centerRight) {
        columnTextAlign = PlutoColumnTextAlign.right;
        contentAlignment = Alignment.centerRight;
        textAlign = TextAlign.right;
      } else if (column.alignment == Alignment.center) {
        columnTextAlign = PlutoColumnTextAlign.center;
        contentAlignment = Alignment.center;
        textAlign = TextAlign.center;
      } else {
        columnTextAlign = PlutoColumnTextAlign.left;
        contentAlignment = Alignment.centerLeft;
        textAlign = TextAlign.left;
      }

      PlutoColumnType columnType;
      switch (column.type) {
        case SpreadsheetColumnType.number:
          columnType = PlutoColumnType.number();
          break;
        case SpreadsheetColumnType.date:
          columnType = PlutoColumnType.date();
          break;
        case SpreadsheetColumnType.dropdown:
          final items = column.dropdownOptions ?? const [];
          columnType = PlutoColumnType.select(items);
          break;
        case SpreadsheetColumnType.boolean:
          columnType = PlutoColumnType.select(
            (column.booleanLabels ?? const {true: 'Yes', false: 'No'}).values
                .toList(),
          );
          break;
        case SpreadsheetColumnType.text:
          columnType = PlutoColumnType.text();
          break;
      }

      final minWidth = column.minWidth ?? (column.width * 0.6);

      return PlutoColumn(
        title: column.title,
        field: field,
        textAlign: columnTextAlign,
        titleTextAlign: columnTextAlign,
        type: columnType,
        enableSorting: column.enableSorting,
        enableColumnDrag: false,
        enableEditingMode: column.enableEditing,
        readOnly: !column.enableEditing,
        width: column.width,
        minWidth: minWidth,
        renderer: (rendererContext) {
          final value = rendererContext.cell.value;
          if (value is SpreadsheetCell) {
            return _buildSpreadsheetCellWidget(value, contentAlignment);
          }
          if (value is Widget) {
            return value;
          }
          if (value is String) {
            return Align(
              alignment: contentAlignment,
              child: Text(value, textAlign: textAlign),
            );
          }
          if (value is num) {
            final displayValue = value is int || value == value.roundToDouble()
                ? value.toInt().toString()
                : value.toString();
            return Align(
              alignment: contentAlignment,
              child: Text(displayValue, textAlign: textAlign),
            );
          }
          if (value is bool) {
            final labels =
                column.booleanLabels ?? const {true: 'Yes', false: 'No'};
            final label = labels[value] ?? value.toString();
            return Align(
              alignment: contentAlignment,
              child: Text(label, textAlign: textAlign),
            );
          }
          return const SizedBox.shrink();
        },
      );
    });
  }

  List<PlutoRow> _buildPlutoRows(List<T> items) {
    if (items.isEmpty) return const [];
    final columnCount = widget.columns.length;

    return List<PlutoRow>.generate(items.length, (rowIndex) {
      final item = items[rowIndex];
      final dataRow = widget.rowBuilder(item);
      final cells = <String, PlutoCell>{};

      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++) {
        final column = widget.columns[columnIndex];
        final field = _fieldForIndex(columnIndex);
        final cell = dataRow.cells[column.key];
        // Always use the cell's widget if provided, otherwise fallback to raw value
        dynamic value;
        if (cell != null) {
          value = cell;
        } else {
          // Fallback to raw value if no cell provided
          value = dataRow.raw?[column.key] ?? '';
          LoggingService.instance.warning(
            'SpreadsheetBase: Missing cell for column ${column.key} at row index $rowIndex',
          );
        }

        cells[field] = PlutoCell(value: value);
      }

      return PlutoRow(
        key: dataRow.key,
        type: PlutoRowType.normal(),
        cells: cells,
      );
    });
  }

  String _fieldForIndex(int index) => 'col_$index';

  Widget _buildSpreadsheetCellWidget(
    SpreadsheetCell cell,
    Alignment contentAlignment,
  ) {
    Widget content = Align(alignment: contentAlignment, child: cell.child);
    if (cell.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cell.onTap,
          child: content,
        ),
      );
    }
    return Semantics(button: cell.onTap != null, child: content);
  }
}
