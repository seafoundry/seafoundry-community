// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/utils/spreadsheet_filter_utils.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/non_coral_holding_table.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/organism_placeholder.dart';

/// Displays a non-coral holdings table when repositories exist, otherwise
/// falls back to the standard organism placeholder / error display.
class NonCoralHoldingsPanel extends StatefulWidget {
  const NonCoralHoldingsPanel({
    super.key,
    required this.organismKind,
    this.headerLabel,
    this.placeholderMessage,
    this.loaderOverride,
    this.supportsOverride,
    this.loadRowsOverride,
    this.siteId,
    this.structurePath,
    this.speciesId,
    this.appendCountToHeader = true,
  });

  factory NonCoralHoldingsPanel.withContext({
    required BuildContext context,
    required OrganismKind organismKind,
    String? headerLabel,
    String? placeholderMessage,
    String? siteId,
    String? structurePath,
    String? speciesId,
    bool appendCountToHeader = true,
  }) {
    final loader = OrganismHoldingLoader.maybeFromContext(context);
    return NonCoralHoldingsPanel(
      organismKind: organismKind,
      headerLabel: headerLabel,
      placeholderMessage: placeholderMessage,
      siteId: siteId,
      structurePath: structurePath,
      speciesId: speciesId,
      appendCountToHeader: appendCountToHeader,
      loaderOverride: loader,
      supportsOverride: loader == null ? null : (kind) => loader.supports(kind),
      loadRowsOverride: loader == null ? null : (kind) => loader.loadRows(kind),
    );
  }

  final OrganismKind organismKind;
  final String? headerLabel;
  final String? placeholderMessage;
  final OrganismHoldingLoader? loaderOverride;
  final bool Function(OrganismKind kind)? supportsOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  loadRowsOverride;
  final String? siteId;
  final String? structurePath;
  final String? speciesId;
  final bool appendCountToHeader;

  @visibleForTesting
  static bool matchesFiltersForTest({
    required Map<String, dynamic> row,
    String? siteId,
    String? structurePath,
    String? speciesId,
  }) {
    return _NonCoralHoldingsPanelState._matchesFiltersStatic(
      row: row,
      siteId: siteId,
      structurePath: structurePath,
      speciesId: speciesId,
    );
  }

  @override
  State<NonCoralHoldingsPanel> createState() => _NonCoralHoldingsPanelState();
}

class _NonCoralHoldingsPanelState extends State<NonCoralHoldingsPanel> {
  late Future<_PanelState> _futureState;

  @override
  void initState() {
    super.initState();
    _futureState = _load();
  }

  @override
  void didUpdateWidget(covariant NonCoralHoldingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final organismChanged = oldWidget.organismKind != widget.organismKind;
    final loaderChanged =
        oldWidget.loaderOverride != widget.loaderOverride ||
        oldWidget.supportsOverride != widget.supportsOverride ||
        oldWidget.loadRowsOverride != widget.loadRowsOverride;
    final filterChanged =
        oldWidget.siteId != widget.siteId ||
        oldWidget.structurePath != widget.structurePath ||
        oldWidget.speciesId != widget.speciesId;
    if (organismChanged || loaderChanged || filterChanged) {
      setState(() {
        _futureState = _load();
      });
    }
  }

  Future<_PanelState> _load() async {
    final loader =
        widget.loaderOverride ??
        OrganismHoldingLoader.maybeFromContext(context);
    final supports = widget.supportsOverride != null
        ? widget.supportsOverride!(widget.organismKind)
        : loader?.supports(widget.organismKind) ?? false;
    if (!supports) {
      return const _PanelState.unsupported();
    }
    try {
      final rows = widget.loadRowsOverride != null
          ? await widget.loadRowsOverride!(widget.organismKind)
          : await loader!.loadRows(widget.organismKind);
      final filteredRows = _filterRows(rows);
      return _PanelState.supported(filteredRows);
    } catch (error) {
      return _PanelState.error(error.toString());
    }
  }

  List<Map<String, dynamic>> _filterRows(List<Map<String, dynamic>> rows) {
    return rows.where((row) {
      return _matchesFiltersStatic(
        row: row,
        siteId: widget.siteId,
        speciesId: widget.speciesId,
        structurePath: widget.structurePath,
      );
    }).toList();
  }

  static bool _matchesFiltersStatic({
    required Map<String, dynamic> row,
    String? siteId,
    String? structurePath,
    String? speciesId,
  }) {
    if (!SpreadsheetFilterUtils.matchesField(
      row,
      siteId,
      const ['siteId'],
    )) {
      return false;
    }
    if (!SpreadsheetFilterUtils.matchesField(
      row,
      speciesId,
      const ['speciesId'],
    )) {
      return false;
    }
    if (!SpreadsheetFilterUtils.matchesField(
      row,
      structurePath,
      const ['groupId'],
      partial: true,
    )) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PanelState>(
      future: _futureState,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final state = snapshot.data!;
        if (!state.supported) {
          return Center(
            child: SpreadsheetOrganismPlaceholder(
              organismKind: widget.organismKind,
              message: widget.placeholderMessage,
            ),
          );
        }
        if (state.errorMessage != null) {
          return Center(
            child: Text(
              'Failed to load holdings: ${state.errorMessage}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        final headerLabel = widget.appendCountToHeader
            ? _headerLabelWithCount(widget.headerLabel, state.rows.length)
            : widget.headerLabel;
        return LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight =
                constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
            final table = NonCoralHoldingTable(
              rows: state.rows,
              organismKind: widget.organismKind,
              reloadToken: state.reloadToken,
              headerLabel: headerLabel,
            );
            final tableWidget = hasBoundedHeight
                ? Expanded(child: table)
                : ConstrainedBox(
                    constraints: const BoxConstraints(),
                    child: table,
                  );
            return Column(
              mainAxisSize: hasBoundedHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Refresh holdings',
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _futureState = _load();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 4),
                tableWidget,
              ],
            );
          },
        );
      },
    );
  }

  String? _headerLabelWithCount(String? base, int count) {
    if (base == null || base.isEmpty) return base;
    final formatted = NumberFormat.compact().format(count);
    if (base.contains('{count}')) {
      return base.replaceAll('{count}', formatted);
    }
    return '$base • $formatted rows';
  }
}

class _PanelState {
  const _PanelState._({
    required this.supported,
    this.rows = const [],
    this.errorMessage,
    this.reloadToken = 0,
  });

  _PanelState.supported(List<Map<String, dynamic>> rows)
    : this._(
        supported: true,
        rows: rows,
        reloadToken: DateTime.now().microsecondsSinceEpoch,
      );

  const _PanelState.unsupported() : this._(supported: false, rows: const []);

  const _PanelState.error(String message)
    : this._(supported: true, rows: const [], errorMessage: message);

  final bool supported;
  final List<Map<String, dynamic>> rows;
  final String? errorMessage;
  final int reloadToken;
}
