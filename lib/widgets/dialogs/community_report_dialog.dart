// @tier: community
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/repositories/inventory/archived_organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/services/download/file_download_stub.dart'
    if (dart.library.html) 'package:seafoundry_app/services/download/file_download_web.dart'
    if (dart.library.io) 'package:seafoundry_app/services/download/file_download_io.dart';
import 'package:seafoundry_app/services/export/inventory_export_row_formatter.dart';
import 'package:seafoundry_app/services/export/inventory_export_row_source.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/services/reporting/community_report_service.dart';
import 'package:seafoundry_app/services/tiered_field_registry.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import '../notifications/toast_overlay.dart';

/// Dialog that allows Community admins to download the standard six-field report.
class CommunityReportDialog extends StatefulWidget {
  const CommunityReportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => const CommunityReportDialog(),
    );
  }

  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

enum _ReportFormat { csv, pdf }

class _CommunityReportDialogState extends State<CommunityReportDialog>
    with SafeDialogMixin<CommunityReportDialog> {
  bool _isLoading = true;
  bool _isExporting = false;
  String? _loadError;
  List<Map<String, dynamic>> _canonicalRows = const [];
  Map<String, String> _speciesOptions = const {};
  Map<String, String> _siteOptions = const {};
  final Set<String> _selectedSpecies = {};
  final Set<String> _selectedSites = {};
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final organismRecordRepository = context.read<OrganismRecordRepository>();
      final groupRepository = context.read<GroupRepository>();
      final holdingLoader = OrganismHoldingLoader.maybeFromContext(context);
      final genetRepository = context.maybeRead<GenetRepository>();
      final rowSource = InventoryExportRowSource(
        organismRecordRepository: organismRecordRepository,
        archivedOrganismRecordRepository: ArchivedOrganismRecordRepository(
          organization: organismRecordRepository.organization,
          user: organismRecordRepository.user,
          firestore: organismRecordRepository.firestore,
        ),
        groupRepository: groupRepository,
        genetRepository: genetRepository,
        holdingLoader: holdingLoader,
      );
      final rows = await rowSource.loadRowMaps();
      await TieredFieldRegistry.instance.ensureInitialized();
      if (!mounted) return;
      // Default to Community tier (safe mode) since provider may not be available
      final tier = Tier.community;
      final canonicalRows = rows
          .map(
            (row) => InventoryExportRowFormatter.canonicalize(row, tier: tier),
          )
          .toList(growable: false);
      final species = <String, String>{};
      final sites = <String, String>{};
      for (final row in canonicalRows) {
        final speciesId = (row['speciesId'] ?? '').toString();
        if (speciesId.isNotEmpty) {
          final speciesName =
              (row['speciesName'] ?? row['speciesId'] ?? speciesId).toString();
          species.putIfAbsent(speciesId, () => speciesName);
        }
        final siteId = (row['siteId'] ?? '').toString();
        if (siteId.isNotEmpty) {
          final siteLabel =
              (row['siteName'] ?? row['location'] ?? siteId)
                  .toString();
          sites.putIfAbsent(siteId, () => siteLabel);
        }
      }
      if (!mounted) return;
      setState(() {
        _canonicalRows = canonicalRows;
        _speciesOptions = species;
        _siteOptions = sites;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load inventory rows for Community report',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load inventory data. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: UI.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Community Six-Field Report',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => popDialog(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: Spacing.md),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _isLoading = true;
                });
                unawaited(_bootstrap());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_canonicalRows.isEmpty) {
      return const Center(
        child: Text('No inventory records available for reporting.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Spacing.sm),
        _buildDatePickers(),
        const SizedBox(height: Spacing.md),
        _buildFilterChips(
          title: 'Species',
          options: _speciesOptions,
          selected: _selectedSpecies,
        ),
        if (_speciesOptions.isNotEmpty) const SizedBox(height: Spacing.md),
        _buildFilterChips(
          title: 'Sites',
          options: _siteOptions,
          selected: _selectedSites,
        ),
        const SizedBox(height: Spacing.lg),
        _buildExportActions(),
      ],
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: _buildDateButton(
            label: 'Start date',
            value: _startDate,
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked;
                  if (_endDate != null && picked.isAfter(_endDate!)) {
                    _endDate = picked;
                  }
                });
              }
            },
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _buildDateButton(
            label: 'End date',
            value: _endDate,
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setState(() {
                  _endDate = picked;
                  if (_startDate != null && picked.isBefore(_startDate!)) {
                    _startDate = picked;
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
  }) {
    final formatted = value == null ? 'Any' : DateFormat.yMMMMd().format(value);
    return OutlinedButton(
      onPressed: onPressed,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(formatted),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips({
    required String title,
    required Map<String, String> options,
    required Set<String> selected,
  }) {
    if (options.isEmpty) {
      return Text(
        '$title: no filters available.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final entries = options.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map(
                (entry) => FilterChip(
                  label: Text(entry.value),
                  selected: selected.contains(entry.key),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selected.add(entry.key);
                      } else {
                        selected.remove(entry.key);
                      }
                    });
                  },
                ),
              )
              .toList(growable: false),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              selected.clear();
            });
          },
          child: Text('Clear $title filters'),
        ),
      ],
    );
  }

  Widget _buildExportActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExporting)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: Spacing.sm),
                  Text('Preparing report...'),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: Spacing.sm,
          children: [
            ElevatedButton.icon(
              onPressed: _isExporting ? null : () => _export(_ReportFormat.csv),
              icon: const Icon(Icons.table_rows),
              label: const Text('Download CSV'),
            ),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : () => _export(_ReportFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export(_ReportFormat format) async {
    if (_canonicalRows.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final filters = CommunityReportFilters(
        startDate: _startDate,
        endDate: _endDate,
        speciesIds: _selectedSpecies.isEmpty ? null : Set.of(_selectedSpecies),
        siteIds: _selectedSites.isEmpty ? null : Set.of(_selectedSites),
      );
      final service = CommunityReportService();
      final result = service.buildReport(
        rows: _canonicalRows,
        rowsAreCanonical: true,
        filters: filters,
        speciesLabels: _speciesOptions,
      );
      final adapter = createFileDownloadAdapter();
      if (!adapter.isSupported) {
        throw UnsupportedError('Downloads are not supported on this platform.');
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      late Uint8List bytes;
      late String fileName;
      late String mimeType;
      if (format == _ReportFormat.csv) {
        bytes = service.buildCsv(result);
        fileName = 'community_report_$timestamp.csv';
        mimeType = 'text/csv';
      } else {
        bytes = await service.buildPdf(result);
        fileName = 'community_report_$timestamp.pdf';
        mimeType = 'application/pdf';
      }
      await adapter.saveBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      if (!mounted) return;
      ToastOverlay.showSnackBar(
        context,
        SnackBar(content: Text('Saved $fileName')),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to export community report',
        error,
        stackTrace,
      );
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text('Failed to export report: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
