// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/constants/in_situ_grid_constants.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class SiteGridSettingsState extends Equatable {
  const SiteGridSettingsState({
    required this.rowInput,
    required this.colInput,
    required this.rowCount,
    required this.colCount,
    this.isSaving = false,
    this.errorMessage,
    this.didSave = false,
  });

  factory SiteGridSettingsState.initial({
    required int? rowCount,
    required int? colCount,
  }) {
    final initialRow = rowCount ?? kInSituMinDimension;
    final initialCol = colCount ?? kInSituMinDimension;
    return SiteGridSettingsState(
      rowInput: '$initialRow',
      colInput: '$initialCol',
      rowCount: initialRow,
      colCount: initialCol,
    );
  }

  final String rowInput;
  final String colInput;
  final int? rowCount;
  final int? colCount;
  final bool isSaving;
  final String? errorMessage;
  final bool didSave;

  bool get canSubmit =>
      !isSaving &&
      rowCount != null &&
      colCount != null &&
      rowCount! >= kInSituMinDimension &&
      colCount! >= kInSituMinDimension;

  String? get rowError =>
      rowCount == null ? 'Enter 1-$kInSituMaxRows rows' : null;
  String? get colError =>
      colCount == null ? 'Enter 1-$kInSituMaxColumns columns' : null;

  SiteGridSettingsState copyWith({
    String? rowInput,
    String? colInput,
    int? rowCount,
    bool rowCountHasValue = false,
    int? colCount,
    bool colCountHasValue = false,
    bool? isSaving,
    String? errorMessage,
    bool? didSave,
  }) => SiteGridSettingsState(
    rowInput: rowInput ?? this.rowInput,
    colInput: colInput ?? this.colInput,
    rowCount: rowCountHasValue ? rowCount : this.rowCount,
    colCount: colCountHasValue ? colCount : this.colCount,
    isSaving: isSaving ?? this.isSaving,
    errorMessage: errorMessage,
    didSave: didSave ?? this.didSave,
  );

  @override
  List<Object?> get props => [
    rowInput,
    colInput,
    rowCount,
    colCount,
    isSaving,
    errorMessage,
    didSave,
  ];
}

class SiteGridSettingsCubit extends SafeCubit<SiteGridSettingsState> {
  SiteGridSettingsCubit({
    required SiteRepository siteRepository,
    required SiteNode siteNode,
    @visibleForTesting
    Future<Site> Function({
      required Site site,
      required int rowCount,
      required int colCount,
    })?
    updateGridDimensionsOverride,
  }) : _siteRepository = siteRepository,
       _siteNode = siteNode,
       _updateGridDimensionsOverride = updateGridDimensionsOverride,
       super(
         SiteGridSettingsState.initial(
           rowCount: siteNode.state.record.rowCount,
           colCount: siteNode.state.record.colCount,
         ),
       );

  final SiteRepository _siteRepository;
  final SiteNode _siteNode;
  final Future<Site> Function({
    required Site site,
    required int rowCount,
    required int colCount,
  })?
  _updateGridDimensionsOverride;

  void rowChanged(String value) {
    emit(
      state.copyWith(
        rowInput: value,
        rowCount: _parseValue(value, max: kInSituMaxRows),
        rowCountHasValue: true,
        didSave: false,
        errorMessage: null,
      ),
    );
  }

  void columnChanged(String value) {
    emit(
      state.copyWith(
        colInput: value,
        colCount: _parseValue(value, max: kInSituMaxColumns),
        colCountHasValue: true,
        didSave: false,
        errorMessage: null,
      ),
    );
  }

  Future<void> save() async {
    if (!state.canSubmit) {
      emit(
        state.copyWith(errorMessage: 'Provide valid row and column counts.'),
      );
      return;
    }

    emit(state.copyWith(isSaving: true, errorMessage: null));

    try {
      final updater =
          _updateGridDimensionsOverride ??
          ({required Site site, required int rowCount, required int colCount}) {
            return _siteRepository.updateGridDimensions(
              site: site,
              rowCount: rowCount,
              colCount: colCount,
            );
          };

      await updater(
        site: _siteNode.state.record,
        rowCount: state.rowCount!,
        colCount: state.colCount!,
      );
      _siteNode.add(const GraphNodeReloadRequested());
      emit(
        state.copyWith(
          isSaving: false,
          didSave: true,
          rowInput: '${state.rowCount}',
          colInput: '${state.colCount}',
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save settings. Please try again.',
        ),
      );
      LoggingService.instance.error(
        'Failed to update grid dimensions for ${_siteNode.name}',
        error,
        stackTrace,
      );
    }
  }

  int? _parseValue(String input, {required int max}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final value = int.tryParse(trimmed);
    if (value == null) {
      return null;
    }
    if (value < kInSituMinDimension || value > max) {
      return null;
    }
    return value;
  }
}
