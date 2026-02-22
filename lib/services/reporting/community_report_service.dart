// @tier: community
import 'dart:convert';
import 'dart:typed_data';

import 'package:seafoundry_app/services/export/export_formatters.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:seafoundry_app/services/export/inventory_export_row_formatter.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';

/// Filters used when building the Community six-field report.
class CommunityReportFilters {
  const CommunityReportFilters({
    this.startDate,
    this.endDate,
    this.speciesIds,
    this.siteIds,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String>? speciesIds;
  final Set<String>? siteIds;

  bool matches(CommunityReportRow row) {
    final hasDateFilter = startDate != null || endDate != null;
    if (hasDateFilter && row.eventDate == null) {
      return false;
    }
    if (startDate != null &&
        row.eventDate != null &&
        row.eventDate!.isBefore(DateRangePresets.startOfDay(startDate!))) {
      return false;
    }
    if (endDate != null &&
        row.eventDate != null &&
        row.eventDate!.isAfter(DateRangePresets.endOfDay(endDate!))) {
      return false;
    }
    final normalizedSpeciesIds =
        (speciesIds != null && speciesIds!.isNotEmpty)
            ? SpeciesRegistry.normalizeIds(speciesIds!)
            : const <String>{};
    if (normalizedSpeciesIds.isNotEmpty) {
      final speciesId = SpeciesRegistry.normalizeId(row.speciesId);
      if (speciesId == null || !normalizedSpeciesIds.contains(speciesId)) {
        return false;
      }
    }
    if (siteIds != null && siteIds!.isNotEmpty) {
      final siteId = row.siteId;
      if (siteId.isEmpty || !siteIds!.contains(siteId)) {
        return false;
      }
    }
    return true;
  }
}

/// Canonical six-field row for Community reporting.
class CommunityReportRow {
  CommunityReportRow({
    required this.eventDate,
    required this.species,
    required this.speciesId,
    required this.provenance,
    required this.provenanceId,
    required this.location,
    required this.siteId,
    required this.lifeStage,
    required this.quantityValue,
    required this.quantityUnit,
    required this.readyForOutplant,
  });

  final DateTime? eventDate;
  final String species;
  final String speciesId;
  final String provenance;
  final String provenanceId;
  final String location;
  final String siteId;
  final String lifeStage;
  final double quantityValue;
  final String quantityUnit;
  final bool readyForOutplant;

  String get dateLabel {
    if (eventDate == null) return '';
    return DateFormat('yyyy-MM-dd').format(eventDate!.toLocal());
  }

  String get quantityLabel {
    final value = quantityValue.toStringAsFixed(
      quantityValue.truncateToDouble() == quantityValue ? 0 : 2,
    );
    return quantityUnit.isEmpty ? value : '$value $quantityUnit';
  }

  List<String> asValueList() {
    return [dateLabel, species, provenance, location, lifeStage, quantityLabel];
  }

  static CommunityReportRow fromCanonicalRow(
    Map<String, dynamic> row, {
    Map<String, String>? speciesLabels,
  }) {
    final eventDate = _parseDate(row['eventDate'] ?? row['lastEventAt']);
    final speciesId = _string(row['speciesId']) ?? '';
    final speciesLabel = speciesLabels?[speciesId];
    final provenanceId = _string(row['provenanceId']) ?? '';
    final siteId = _string(row['siteId']) ?? '';
    final location = _resolveLocation(row, siteId);
    final lifeStage =
        _string(row['lifeStageLabel']) ?? _string(row['lifeStage']) ?? '';
    final quantityValue = _parseDouble(row['quantityValue']);
    final quantityUnit = _string(row['measurementUnit']) ?? 'count';
    return CommunityReportRow(
      eventDate: eventDate,
      species: (speciesLabel != null && speciesLabel.isNotEmpty)
          ? speciesLabel
          : _string(row['speciesName']) ?? speciesId,
      speciesId: speciesId,
      provenance: _resolveProvenance(row, provenanceId),
      provenanceId: provenanceId,
      location: location,
      siteId: siteId,
      lifeStage: lifeStage,
      quantityValue: quantityValue,
      quantityUnit: quantityUnit,
      readyForOutplant: _parseBool(row['readyForOutplant']),
    );
  }

  static String _resolveLocation(Map<String, dynamic> row, String siteId) {
    final siteName = _string(row['siteName']);
    if (siteName != null && siteName.isNotEmpty) {
      return siteName;
    }
    final lat = _string(row['siteCenterLat']) ?? _string(row['latitude']);
    final lng = _string(row['siteCenterLng']) ?? _string(row['longitude']);
    if (lat != null && lat.isNotEmpty && lng != null && lng.isNotEmpty) {
      return '$lat,$lng';
    }
    return siteId;
  }

  static String _resolveProvenance(Map<String, dynamic> row, String fallback) {
    final provenanceLabel =
        _string(row['provenanceLabel']) ?? _string(row['provenanceType']);
    if (provenanceLabel != null && provenanceLabel.isNotEmpty) {
      return provenanceLabel;
    }
    return fallback;
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static DateTime? _parseDate(dynamic raw) {
    final value = _string(raw);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static double _parseDouble(dynamic raw) {
    final value = _string(raw);
    if (value == null || value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    final value = _string(raw)?.toLowerCase();
    if (value == null) return false;
    return value == 'true' || value == '1' || value == 'yes';
  }
}

/// Summary KPIs shown above the six-field rows.
class CommunityReportKpis {
  const CommunityReportKpis({
    required this.totalRows,
    required this.totalQuantity,
    required this.readyForOutplantCount,
    required this.speciesCount,
    required this.siteCount,
    required this.uniqueGenets,
  });

  final int totalRows;
  final double totalQuantity;
  final int readyForOutplantCount;
  final int speciesCount;
  final int siteCount;
  final int uniqueGenets;

  static CommunityReportKpis fromRows(List<CommunityReportRow> rows) {
    final species = <String>{};
    final sites = <String>{};
    final genets = <String>{};
    var ready = 0;
    var quantity = 0.0;
    for (final row in rows) {
      quantity += row.quantityValue;
      if (row.readyForOutplant) ready += 1;
      if (row.speciesId.isNotEmpty) species.add(row.speciesId);
      if (row.siteId.isNotEmpty) sites.add(row.siteId);
      if (row.provenanceId.isNotEmpty) genets.add(row.provenanceId);
    }
    return CommunityReportKpis(
      totalRows: rows.length,
      totalQuantity: quantity,
      readyForOutplantCount: ready,
      speciesCount: species.length,
      siteCount: sites.length,
      uniqueGenets: genets.length,
    );
  }

  List<List<String>> toSummaryRows() {
    return [
      ['Total rows', '$totalRows'],
      [
        'Total quantity',
        totalQuantity.toStringAsFixed(
          totalQuantity.truncateToDouble() == totalQuantity ? 0 : 2,
        ),
      ],
      ['Species represented', '$speciesCount'],
      ['Sites represented', '$siteCount'],
      ['Ready for outplant', '$readyForOutplantCount'],
      ['Unique genets/provenance IDs', '$uniqueGenets'],
    ];
  }
}

/// Report result used for rendering CSV/PDF.
class CommunityReportResult {
  const CommunityReportResult({
    required this.rows,
    required this.kpis,
    required this.generatedAt,
    required this.upgradeCta,
    this.filters = const CommunityReportFilters(),
  });

  final List<CommunityReportRow> rows;
  final CommunityReportKpis kpis;
  final DateTime generatedAt;
  final String upgradeCta;
  final CommunityReportFilters filters;
}

/// Builder that converts canonical inventory rows into Community six-field reports.
class CommunityReportService {
  const CommunityReportService();
  static pw.Font? _cachedReportFont;

  static const _defaultUpgradeMessage =
      'Upgrade to SeaFoundry Pro to unlock custom filters, advanced CSV/PDF exports, and automation-ready KPIs.';

  CommunityReportResult buildReport({
    required Iterable<Map<String, dynamic>> rows,
    Tier tier = Tier.community,
    CommunityReportFilters filters = const CommunityReportFilters(),
    bool rowsAreCanonical = false,
    String? upgradeCta,
    Map<String, String>? speciesLabels,
  }) {
    final canonicalRows = rowsAreCanonical
        ? rows.map((row) => Map<String, dynamic>.from(row))
        : rows.map(
            (row) => InventoryExportRowFormatter.canonicalize(row, tier: tier),
          );
    final reportRows = <CommunityReportRow>[];
    for (final row in canonicalRows) {
      final reportRow = CommunityReportRow.fromCanonicalRow(
        row,
        speciesLabels: speciesLabels,
      );
      if (!filters.matches(reportRow)) continue;
      reportRows.add(reportRow);
    }
    reportRows.sort((a, b) {
      final aDate = a.eventDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.eventDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final kpis = CommunityReportKpis.fromRows(reportRows);
    return CommunityReportResult(
      rows: reportRows,
      kpis: kpis,
      generatedAt: DateTime.now().toUtc(),
      upgradeCta: upgradeCta ?? _defaultUpgradeMessage,
      filters: filters,
    );
  }

  Uint8List buildCsv(CommunityReportResult result) {
    final headers = [
      'Date',
      'Species',
      'Provenance',
      'Location',
      'Life Stage',
      'Quantity',
    ];

    final dataRows = result.rows
        .map((row) => row.asValueList().map((v) => v as dynamic).toList())
        .toList();

    final prefaceLines = [
      'Community Six-Field Report',
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(result.generatedAt.toLocal())}',
      '',
      ...result.kpis.toSummaryRows().map((row) => '${row[0]}: ${row[1]}'),
    ];

    final csv = ExportFormatters.generateCsv(
      headers: headers,
      rows: dataRows,
      prefaceLines: prefaceLines,
    );

    return Uint8List.fromList(utf8.encode(csv));
  }

  Future<Uint8List> buildPdf(CommunityReportResult result) async {
    final doc = pw.Document();
    final loadedFont = await _loadReportFont();
    final baseFont = loadedFont ?? pw.Font.helvetica();
    final boldFont = loadedFont ?? pw.Font.helveticaBold();
    final summaryData = [
      ['Metric', 'Value'],
      ...result.kpis.toSummaryRows(),
    ];
    final headerStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      font: boldFont,
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Community Six-Field Report', style: headerStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${DateFormat.yMMMMd().add_Hm().format(result.generatedAt.toLocal())}',
            style: pw.TextStyle(font: baseFont),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: boldFont,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xffe0e0e0),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(font: baseFont),
            data: summaryData,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Six-Field Rows',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              font: boldFont,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: boldFont,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xfff5f5f5),
            ),
            cellStyle: pw.TextStyle(font: baseFont),
            data: [
              [
                'Date',
                'Species',
                'Provenance',
                'Location',
                'Life Stage',
                'Quantity',
              ],
              ...result.rows.map((row) => row.asValueList()),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xffe8f5e9),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              result.upgradeCta,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                font: baseFont,
              ),
            ),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  static Future<pw.Font?> _loadReportFont() async {
    if (_cachedReportFont != null) {
      return _cachedReportFont;
    }
    try {
      final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _cachedReportFont = pw.Font.ttf(data);
      return _cachedReportFont;
    } catch (_) {
      return null;
    }
  }
}
