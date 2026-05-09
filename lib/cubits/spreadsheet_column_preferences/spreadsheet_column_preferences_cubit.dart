import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/column_preferences.dart';
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/spreadsheet_id.dart';

/// Cubit managing per-spreadsheet column order and visibility preferences.
///
/// Preferences are persisted to a local JSON file and restored on app restart.
/// On web, persistence is skipped (defaults only).
class SpreadsheetColumnPreferencesCubit
    extends Cubit<SpreadsheetColumnPreferencesState> {
  SpreadsheetColumnPreferencesCubit()
      : super(const SpreadsheetColumnPreferencesState()) {
    _loadPreferences();
  }

  static const _prefsFileName = 'spreadsheet_column_prefs.json';

  /// Load preferences from local storage.
  Future<void> _loadPreferences() async {
    if (kIsWeb) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');

      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final prefs = <SpreadsheetId, ColumnPreferences>{};

        for (final entry in json.entries) {
          final id = _spreadsheetIdFromString(entry.key);
          if (id != null) {
            prefs[id] = ColumnPreferences.fromJson(
              entry.value as Map<String, dynamic>,
            );
          }
        }

        emit(SpreadsheetColumnPreferencesState(preferences: prefs));
      }
    } catch (e) {
      LoggingService.instance
          .warning('Failed to load column preferences: $e');
    }
  }

  /// Save preferences to local storage.
  Future<void> _savePreferences() async {
    if (kIsWeb) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');
      final json = <String, dynamic>{};

      for (final entry in state.preferences.entries) {
        json[entry.key.id] = entry.value.toJson();
      }

      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      LoggingService.instance
          .warning('Failed to save column preferences: $e');
    }
  }

  /// Update column order for a single spreadsheet.
  void updateColumnOrder(SpreadsheetId id, List<String> order) {
    final current = state.forSpreadsheet(id);
    final updated = current.copyWith(columnOrder: order);
    emit(state.copyWith(
      preferences: {...state.preferences, id: updated},
    ));
    _savePreferences();
  }

  /// Toggle visibility of a single column in a spreadsheet.
  void toggleColumnVisibility(SpreadsheetId id, String columnKey) {
    final current = state.forSpreadsheet(id);
    final hidden = Set<String>.from(current.hiddenColumns);

    if (hidden.contains(columnKey)) {
      hidden.remove(columnKey);
    } else {
      hidden.add(columnKey);
    }

    final updated = current.copyWith(hiddenColumns: hidden);
    emit(state.copyWith(
      preferences: {...state.preferences, id: updated},
    ));
    _savePreferences();
  }

  /// Set both column order and hidden columns for a spreadsheet at once.
  ///
  /// Used by [ColumnConfigDialog] to apply all changes atomically.
  void setPreferences(
    SpreadsheetId id,
    List<String> order,
    Set<String> hidden,
  ) {
    final updated = ColumnPreferences(
      columnOrder: order,
      hiddenColumns: hidden,
    );
    emit(state.copyWith(
      preferences: {...state.preferences, id: updated},
    ));
    _savePreferences();
  }

  /// Reset preferences for a single spreadsheet to factory defaults.
  void resetPreferences(SpreadsheetId id) {
    final updated = Map<SpreadsheetId, ColumnPreferences>.from(
      state.preferences,
    )..remove(id);
    emit(state.copyWith(preferences: updated));
    _savePreferences();
  }

  /// Resolve a [SpreadsheetId] from its string [id] value.
  static SpreadsheetId? _spreadsheetIdFromString(String value) {
    for (final id in SpreadsheetId.values) {
      if (id.id == value) return id;
    }
    return null;
  }
}

/// State for spreadsheet column preferences.
class SpreadsheetColumnPreferencesState extends Equatable {
  const SpreadsheetColumnPreferencesState({
    this.preferences = const {},
  });

  final Map<SpreadsheetId, ColumnPreferences> preferences;

  ColumnPreferences forSpreadsheet(SpreadsheetId id) =>
      preferences[id] ?? const ColumnPreferences();

  SpreadsheetColumnPreferencesState copyWith({
    Map<SpreadsheetId, ColumnPreferences>? preferences,
  }) =>
      SpreadsheetColumnPreferencesState(
        preferences: preferences ?? this.preferences,
      );

  @override
  List<Object?> get props => [preferences];
}
