// @tier: community
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';

/// Cubit managing user preferences for how organism records are displayed.
///
/// Controls two independent settings:
/// 1. showUuid: When true, displays recordUUID instead of tagId
/// 2. showIdentifier: When false, hides both tagId and recordUUID entirely
///
/// Preferences are persisted to local storage and restored on app restart.
class RecordDisplayPreferencesCubit extends Cubit<RecordDisplayPreferencesState> {
  RecordDisplayPreferencesCubit()
      : super(
          const RecordDisplayPreferencesState(
            showUuid: false,
            showIdentifier: true,
          ),
        ) {
    _loadPreferences();
  }

  static const _prefsFileName = 'record_display_prefs.json';

  /// Load preferences from local storage
  Future<void> _loadPreferences() async {
    if (kIsWeb) return; // Skip on web

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');

      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        emit(
          RecordDisplayPreferencesState(
            showUuid: json['showUuid'] as bool? ?? false,
            showIdentifier: json['showIdentifier'] as bool? ?? true,
          ),
        );
      }
    } catch (e) {
      // Ignore errors loading preferences - use defaults
    }
  }

  /// Save preferences to local storage
  Future<void> _savePreferences() async {
    if (kIsWeb) return; // Skip on web

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefsFileName');
      await file.writeAsString(
        jsonEncode({
          'showUuid': state.showUuid,
          'showIdentifier': state.showIdentifier,
        }),
      );
    } catch (e) {
      // Ignore errors saving preferences
    }
  }

  /// Toggle between showing tagId and recordUUID.
  void toggleShowUuid() {
    emit(state.copyWith(showUuid: !state.showUuid));
    _savePreferences();
  }

  /// Toggle whether to show any identifier (name or UUID) at all.
  void toggleShowIdentifier() {
    emit(state.copyWith(showIdentifier: !state.showIdentifier));
    _savePreferences();
  }

  /// Set specific preference values.
  void setPreferences({bool? showUuid, bool? showIdentifier}) {
    emit(
      state.copyWith(
        showUuid: showUuid ?? state.showUuid,
        showIdentifier: showIdentifier ?? state.showIdentifier,
      ),
    );
    _savePreferences();
  }
}

/// State for record display preferences.
class RecordDisplayPreferencesState extends Equatable {
  const RecordDisplayPreferencesState({
    required this.showUuid,
    required this.showIdentifier,
  });

  /// When true, show recordUUID instead of tagId.
  final bool showUuid;

  /// When false, hide both tagId and recordUUID entirely.
  final bool showIdentifier;

  RecordDisplayPreferencesState copyWith({
    bool? showUuid,
    bool? showIdentifier,
  }) {
    return RecordDisplayPreferencesState(
      showUuid: showUuid ?? this.showUuid,
      showIdentifier: showIdentifier ?? this.showIdentifier,
    );
  }

  @override
  List<Object?> get props => [showUuid, showIdentifier];
}
