// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Steps in the data import workflow.
///
/// Each step represents a distinct phase of the import process,
/// typically backed by a separate Google Sheet tab.
enum DataImportStep {
  genetics,
  inventory,
  outplanting,
  monitoring;

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case DataImportStep.genetics:
        return 'Genetics';
      case DataImportStep.inventory:
        return 'Inventory';
      case DataImportStep.outplanting:
        return 'Outplanting';
      case DataImportStep.monitoring:
        return 'Monitoring';
    }
  }

  /// Short description of what this step imports.
  String get description {
    switch (this) {
      case DataImportStep.genetics:
        return 'Genotype and provenance records';
      case DataImportStep.inventory:
        return 'Inventory batches and quantities';
      case DataImportStep.outplanting:
        return 'Outplant events and allocations';
      case DataImportStep.monitoring:
        return 'Monitoring observations';
    }
  }
}

/// Tracks the availability status of all import steps.
///
/// Each step can be either available (can import) or complete (has data).
/// Steps are unlocked based on whether prior steps have data.
class StepAvailability extends Equatable {
  const StepAvailability({
    this.geneticsAvailable = true,
    this.geneticsComplete = false,
    this.inventoryAvailable = false,
    this.inventoryComplete = false,
    this.outplantingAvailable = false,
    this.outplantingComplete = false,
    this.monitoringAvailable = false,
    this.monitoringComplete = false,
  });

  /// Genetics step is always available (first step).
  final bool geneticsAvailable;

  /// Whether genetics data has been imported.
  final bool geneticsComplete;

  /// Inventory available once genetics is complete.
  final bool inventoryAvailable;

  /// Whether inventory data has been imported.
  final bool inventoryComplete;

  /// Outplanting available once inventory is complete.
  final bool outplantingAvailable;

  /// Whether outplanting data has been imported.
  final bool outplantingComplete;

  /// Monitoring available once outplanting is complete.
  final bool monitoringAvailable;

  /// Whether monitoring data has been imported.
  final bool monitoringComplete;

  @override
  List<Object?> get props => [
        geneticsAvailable,
        geneticsComplete,
        inventoryAvailable,
        inventoryComplete,
        outplantingAvailable,
        outplantingComplete,
        monitoringAvailable,
        monitoringComplete,
      ];
}

/// Configuration for data import sources.
///
/// Holds URLs to Google Sheets or other import sources,
/// plus workflow configuration.
class DataImportConfig {
  const DataImportConfig({
    this.geneticsSheetUrl,
    this.inventorySheetUrl,
    this.outplantingSheetUrl,
    this.monitoringSheetUrl,
  });

  /// Static placeholder for Google Sheet URLs by organism and step.
  /// These will be provided by the user later.
  static const Map<OrganismKind, Map<DataImportStep, String>> googleSheetUrls = {
    // Example structure - URLs to be provided:
    // OrganismKind.coral: {
    //   DataImportStep.genetics: 'https://docs.google.com/spreadsheets/d/...',
    //   DataImportStep.inventory: 'https://docs.google.com/spreadsheets/d/...',
    //   DataImportStep.outplanting: 'https://docs.google.com/spreadsheets/d/...',
    //   DataImportStep.monitoring: 'https://docs.google.com/spreadsheets/d/...',
    // },
  };

  /// URL to the Google Sheet containing genetics data.
  final String? geneticsSheetUrl;

  /// URL to the Google Sheet containing inventory data.
  final String? inventorySheetUrl;

  /// URL to the Google Sheet containing outplanting data.
  final String? outplantingSheetUrl;

  /// URL to the Google Sheet containing monitoring data.
  final String? monitoringSheetUrl;

  /// Returns the sheet URL for a given step.
  String? urlForStep(DataImportStep step) {
    switch (step) {
      case DataImportStep.genetics:
        return geneticsSheetUrl;
      case DataImportStep.inventory:
        return inventorySheetUrl;
      case DataImportStep.outplanting:
        return outplantingSheetUrl;
      case DataImportStep.monitoring:
        return monitoringSheetUrl;
    }
  }

  /// Returns true if any sheet URL is configured.
  bool get hasAnyUrl =>
      geneticsSheetUrl != null ||
      inventorySheetUrl != null ||
      outplantingSheetUrl != null ||
      monitoringSheetUrl != null;

  /// Creates a copy with updated fields.
  DataImportConfig copyWith({
    String? geneticsSheetUrl,
    String? inventorySheetUrl,
    String? outplantingSheetUrl,
    String? monitoringSheetUrl,
  }) {
    return DataImportConfig(
      geneticsSheetUrl: geneticsSheetUrl ?? this.geneticsSheetUrl,
      inventorySheetUrl: inventorySheetUrl ?? this.inventorySheetUrl,
      outplantingSheetUrl: outplantingSheetUrl ?? this.outplantingSheetUrl,
      monitoringSheetUrl: monitoringSheetUrl ?? this.monitoringSheetUrl,
    );
  }
}
