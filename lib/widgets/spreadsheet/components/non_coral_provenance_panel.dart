// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/export/provenance_export_row_source.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';
import 'package:seafoundry_app/services/provenance_formatter.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/organism_placeholder.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';

/// Displays provenance records for non-coral organisms by querying the shared
/// taxonomy collections. Mirrors the holdings panel UX so genetics contexts can
/// surface donor meadow / broodstock metadata without bespoke Firestore calls.
class NonCoralProvenancePanel extends StatefulWidget {
  const NonCoralProvenancePanel({
    super.key,
    required this.organismKind,
    this.speciesId,
    this.headerLabel,
    this.placeholderMessage,
    this.supportsOverride,
    this.loadOverride,
  });

  final OrganismKind organismKind;
  final String? speciesId;
  final String? headerLabel;
  final String? placeholderMessage;
  final bool Function(OrganismKind kind)? supportsOverride;
  final Future<List<ProvenanceRecord>> Function(
    OrganismKind kind,
    String? speciesId,
  )?
  loadOverride;

  @override
  State<NonCoralProvenancePanel> createState() =>
      _NonCoralProvenancePanelState();
}

class _NonCoralProvenancePanelState extends State<NonCoralProvenancePanel> {
  late Future<_PanelState> _futureState;

  @override
  void initState() {
    super.initState();
    _futureState = _load();
  }

  @override
  void didUpdateWidget(covariant NonCoralProvenancePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final organismChanged = oldWidget.organismKind != widget.organismKind;
    final speciesChanged = oldWidget.speciesId != widget.speciesId;
    final loaderChanged =
        oldWidget.loadOverride != widget.loadOverride ||
        oldWidget.supportsOverride != widget.supportsOverride;
    if (organismChanged || speciesChanged || loaderChanged) {
      setState(() {
        _futureState = _load();
      });
    }
  }

  Future<_PanelState> _load() async {
    final taxonomyService = context.maybeRead<TaxonomyService>();
    final speciesRegistry = context.maybeRead<SpeciesRegistry>();
    final supports =
        widget.supportsOverride?.call(widget.organismKind) ??
        taxonomyService != null;
    if (!supports) {
      return const _PanelState.unsupported();
    }

    try {
      await speciesRegistry?.ensureHydrated();
      final rows = widget.loadOverride != null
          ? (await widget.loadOverride!(widget.organismKind, widget.speciesId))
              .map(
                (record) => _ProvenanceRow.fromRecord(
                  record: record,
                  speciesRegistry: speciesRegistry,
                ),
              )
              .toList()
          : await _loadRowsFromCache(
              taxonomyService!,
              speciesRegistry,
            );
      rows.sort((a, b) => a.displayName.compareTo(b.displayName));
      return _PanelState.supported(rows);
    } catch (error) {
      return _PanelState.error(error.toString());
    }
  }

  Future<List<_ProvenanceRow>> _loadRowsFromCache(
    TaxonomyService taxonomyService,
    SpeciesRegistry? speciesRegistry,
  ) async {
    final rowMaps = await ProvenanceExportRowSource.loadRows(
      taxonomyService: taxonomyService,
      organismKind: widget.organismKind,
      speciesId: widget.speciesId,
    );
    return rowMaps
        .map(
          (row) => _ProvenanceRow.fromRowMap(
            row,
            speciesRegistry: speciesRegistry,
          ),
        )
        .toList(growable: false);
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
          return SpreadsheetOrganismPlaceholder(
            organismKind: widget.organismKind,
            message: widget.placeholderMessage,
          );
        }
        if (state.errorMessage != null) {
          return Center(
            child: Text(
              'Failed to load provenances: ${state.errorMessage}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        if (state.rows.isEmpty) {
          return SpreadsheetOrganismPlaceholder(
            organismKind: widget.organismKind,
            message:
                widget.placeholderMessage ??
                'No ${widget.organismKind.metadata.displayName} provenances yet.',
          );
        }
        return _NonCoralProvenanceTable(
          key: ValueKey('non-coral-provenances-${state.reloadToken}'),
          rows: state.rows,
          headerLabel: widget.headerLabel,
          reloadToken: state.reloadToken,
        );
      },
    );
  }
}

class _NonCoralProvenanceTable extends StatelessWidget {
  const _NonCoralProvenanceTable({
    super.key,
    required this.rows,
    required this.headerLabel,
    required this.reloadToken,
  });

  final List<_ProvenanceRow> rows;
  final String? headerLabel;
  final int reloadToken;

  static const PaginationService<_ProvenanceRow> _paginationService =
      PaginationService<_ProvenanceRow>();

  @override
  Widget build(BuildContext context) {
    final columns = <SpreadsheetColumn>[
      const SpreadsheetColumn(key: 'name', title: 'Provenance', width: 220),
      const SpreadsheetColumn(key: 'type', title: 'Type', width: 140),
      const SpreadsheetColumn(key: 'species', title: 'Species', width: 200),
      const SpreadsheetColumn(key: 'site', title: 'Site ID', width: 160),
      const SpreadsheetColumn(key: 'parent', title: 'Parent ID', width: 160),
      const SpreadsheetColumn(key: 'aliases', title: 'Aliases', width: 200),
      const SpreadsheetColumn(
        key: 'metadata',
        title: 'Metadata',
        width: 280,
        minWidth: 240,
      ),
    ];

    return SpreadsheetBase<_ProvenanceRow>(
      key: ValueKey('non-coral-provenances-$reloadToken'),
      columns: columns,
      rowBuilder: (row) => SpreadsheetRow(
        key: ValueKey(row.id),
        raw: row.toJson(),
        cells: {
          'name': SpreadsheetCell.text(row.displayName),
          'type': SpreadsheetCell.text(row.typeLabel),
          'species': SpreadsheetCell.text(row.speciesLabel),
          'site': SpreadsheetCell.text(row.siteLabel),
          'parent': SpreadsheetCell.text(row.parentLabel),
          'aliases': SpreadsheetCell.text(row.aliasesLabel),
          'metadata': SpreadsheetCell.text(row.metadataLabel),
        },
      ),
      pageLoader: _paginationService.buildListLoader(() => rows),
      sortField: null,
      header: headerLabel != null ? Text(headerLabel!) : null,
      reloadToken: reloadToken,
    );
  }
}

class _ProvenanceRow {
  _ProvenanceRow({
    required this.id,
    required this.displayName,
    required this.typeLabel,
    required this.speciesLabel,
    required this.siteLabel,
    required this.parentLabel,
    required this.aliasesLabel,
    required this.metadataLabel,
  });

  final String id;
  final String displayName;
  final String typeLabel;
  final String speciesLabel;
  final String siteLabel;
  final String parentLabel;
  final String aliasesLabel;
  final String metadataLabel;

  static _ProvenanceRow fromRecord({
    required ProvenanceRecord record,
    SpeciesRegistry? speciesRegistry,
  }) {
    final speciesName =
        speciesRegistry?.byId(record.speciesId)?.name ?? record.speciesId;
    final kindLabel = ProvenanceFormatter.titleCase(record.provenanceKind.name);
    final metadataLabel = ProvenanceFormatter.summarizeMetadata(
      record.metadata,
    );
    final aliases = record.aliasLabels.isEmpty
        ? ''
        : record.aliasLabels.join(', ');
    return _ProvenanceRow(
      id: record.id,
      displayName: record.displayName,
      typeLabel: kindLabel,
      speciesLabel: speciesName,
      siteLabel: record.siteId ?? '',
      parentLabel: record.parentProvenanceId ?? '',
      aliasesLabel: aliases,
      metadataLabel: metadataLabel,
    );
  }

  static _ProvenanceRow fromRowMap(
    Map<String, dynamic> row, {
    SpeciesRegistry? speciesRegistry,
  }) {
    final speciesId = (row['speciesId'] ?? '').toString();
    final speciesName = speciesId.isEmpty
        ? ''
        : speciesRegistry?.byId(speciesId)?.name ?? speciesId;
    final kindLabel = ProvenanceFormatter.titleCase(
      (row['provenanceKind'] ?? '').toString(),
    );
    final aliasesRaw = (row['aliases'] ?? '').toString();
    final aliasesLabel = aliasesRaw.replaceAll(';', ',').trim();
    return _ProvenanceRow(
      id: (row['provenanceId'] ?? '').toString(),
      displayName: (row['displayName'] ?? '').toString(),
      typeLabel: kindLabel,
      speciesLabel: speciesName,
      siteLabel: (row['siteId'] ?? '').toString(),
      parentLabel: (row['parentProvenanceId'] ?? '').toString(),
      aliasesLabel: aliasesLabel,
      metadataLabel: (row['metadata'] ?? '').toString(),
    );
  }

  Map<String, String> toJson() => {
    'id': id,
    'displayName': displayName,
    'type': typeLabel,
    'species': speciesLabel,
    'site': siteLabel,
    'parent': parentLabel,
    'aliases': aliasesLabel,
    'metadata': metadataLabel,
  };
}

class _PanelState {
  const _PanelState._({
    required this.rows,
    required this.supported,
    required this.reloadToken,
    this.errorMessage,
  });

  final List<_ProvenanceRow> rows;
  final bool supported;
  final String? errorMessage;
  final int reloadToken;

  const _PanelState.unsupported()
    : this._(rows: const [], supported: false, reloadToken: 0);

  factory _PanelState.supported(List<_ProvenanceRow> rows) => _PanelState._(
    rows: rows,
    supported: true,
    reloadToken: DateTime.now().millisecondsSinceEpoch,
  );

  factory _PanelState.error(String message) {
    return _PanelState._(
      rows: const [],
      supported: true,
      errorMessage: message,
      reloadToken: 0,
    );
  }
}
