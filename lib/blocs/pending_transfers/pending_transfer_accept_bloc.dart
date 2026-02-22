// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/cubits/pending_transfers/pending_transfers_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/outplant_geometry_parser.dart';

class PendingTransferAcceptBloc
    extends RecordFormBloc<ProvenanceRecord, PendingTransferAcceptState> {
  PendingTransferAcceptBloc({
    required this.entry,
    required PendingTransfersCubit pendingTransfersCubit,
    this.destinationRequired = false,
  }) : _pendingTransfersCubit = pendingTransfersCubit,
       _geometryParser = const OutplantGeometryParser(),
       super(
         PendingTransferAcceptState.initial(
           entry: entry,
           destinationRequired: destinationRequired,
         ),
       ) {
    on<PendingTransferGeometryChanged>(_onGeometryChanged);
  }

  final PendingTransferEntry entry;
  final PendingTransfersCubit _pendingTransfersCubit;
  final OutplantGeometryParser _geometryParser;
  final bool destinationRequired;

  @override
  PendingTransferAcceptState get initialState =>
      PendingTransferAcceptState.initial(
        entry: entry,
        destinationRequired: destinationRequired,
      );

  @override
  Future<ProvenanceRecord?> createRecord() async {
    final state = this.state;
    final name = state.name.value?.trim();
    final localId = state.localId.value?.trim();
    final provenanceSelection = state.provenanceSelection;
    final destination = state.destinationSelection;

    if (name == null || name.isEmpty) {
      throw const RequiredInputError('Please enter a name');
    }
    if (localId == null || localId.isEmpty) {
      throw const RequiredInputError('Please enter a local ID');
    }

    final record = await _pendingTransfersCubit.acceptTransfer(
      entry: entry,
      localId: localId,
      name: name,
      provenanceSelection: provenanceSelection,
      geometryInput: state.geometryInput,
      targetUrlPath: destination?.targetUrlPath,
      destinationSiteId: destination?.destinationSiteId,
      destinationGroupId: destination?.groupId,
    );

    return record;
  }

  void _onGeometryChanged(
    PendingTransferGeometryChanged event,
    Emitter<PendingTransferAcceptState> emit,
  ) {
    final raw = event.text.trim();
    if (raw.isEmpty) {
      emit(
        state.copyWith(
          geometryText: '',
          geometryInput: null,
          geometryValidationMessage: null,
        ),
      );
      return;
    }

    try {
      final parsed = _geometryParser.parseManual(event.text);
      emit(
        state.copyWith(
          geometryText: event.text,
          geometryInput: parsed.input,
          geometryValidationMessage: null,
        ),
      );
    } on FormatException catch (error) {
      emit(
        state.copyWith(
          geometryText: event.text,
          geometryInput: null,
          geometryValidationMessage: error.message,
        ),
      );
    }
  }
}

class PendingTransferAcceptState extends RecordFormState<ProvenanceRecord> {
  PendingTransferAcceptState({
    required this.entry,
    List<RecordFormStep>? steps,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    this.geometryText = '',
    this.geometryInput,
    this.geometryValidationMessage,
  }) : super(
         steps:
             steps ??
             [
               PendingTransferAcceptStep(
                 entry: entry,
                 name: _defaultName(entry),
                 provenanceSelection: _defaultSelection(entry),
                 destinationRequired: false,
               ),
             ],
       );

  factory PendingTransferAcceptState.initial({
    required PendingTransferEntry entry,
    bool destinationRequired = false,
  }) {
    return PendingTransferAcceptState(
      entry: entry,
      steps: [
        PendingTransferAcceptStep(
          entry: entry,
          name: _defaultName(entry),
          provenanceSelection: _defaultSelection(entry),
          destinationRequired: destinationRequired,
        ),
      ],
      geometryText: _defaultGeometryText(entry),
      geometryInput: _defaultGeometryInput(entry),
    );
  }

  final PendingTransferEntry entry;
  final String geometryText;
  final OutplantGeometryInput? geometryInput;
  final String? geometryValidationMessage;

  PendingTransferAcceptStep get acceptStep =>
      steps[currentStepIndex] as PendingTransferAcceptStep;

  PendingTransferNameInput get name => acceptStep.name;
  PendingTransferLocalIdInput get localId => acceptStep.localId;
  PendingTransferProvenanceInput get provenance => acceptStep.provenance;
  PendingTransferDestinationInput get destination => acceptStep.destination;
  ProvenanceLifeStageSelection get provenanceSelection =>
      provenance.value ?? ProvenanceLifeStageSelection.fallback();
  PendingTransferDestinationSelection? get destinationSelection =>
      destination.value;

  @override
  PendingTransferAcceptState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    ProvenanceRecord? createdRecord,
    ProvenanceRecord? originalRecord,
    bool overrideSubmissionError = false,
    String? geometryText,
    Object? geometryInput = _geometryUnset,
    Object? geometryValidationMessage = _geometryUnset,
  }) {
    return PendingTransferAcceptState(
      entry: entry,
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      geometryText: geometryText ?? this.geometryText,
      geometryInput: geometryInput == _geometryUnset
          ? this.geometryInput
          : geometryInput as OutplantGeometryInput?,
      geometryValidationMessage: geometryValidationMessage == _geometryUnset
          ? this.geometryValidationMessage
          : geometryValidationMessage as String?,
    );
  }

  static String _defaultName(PendingTransferEntry entry) {
    final genetName = entry.genet?.displayName ?? 'Transferred Genet';
    final organizationName = entry.fromOrganization?.name;
    if (organizationName == null || organizationName.isEmpty) {
      return genetName;
    }
    return '$genetName (from $organizationName)';
  }

  static ProvenanceLifeStageSelection _defaultSelection(
    PendingTransferEntry entry,
  ) =>
      entry.provenanceSelection;

  static String _defaultGeometryText(PendingTransferEntry entry) {
    final geometry = entry.transfer.geometry;
    if (geometry == null || geometry.coordinates.isEmpty) {
      return '';
    }
    return geometry.coordinates
        .map(
          (coord) => '${coord.latitude},${coord.longitude}',
        )
        .join('\n');
  }

  static OutplantGeometryInput? _defaultGeometryInput(
    PendingTransferEntry entry,
  ) {
    final geometry = entry.transfer.geometry;
    if (geometry == null || geometry.coordinates.isEmpty) {
      return null;
    }
    return OutplantGeometryInput(
      type: geometry.type,
      coordinates: List<GeoCoordinate>.from(geometry.coordinates),
      source: geometry.source,
      kmlAttachment: geometry.kmlAttachment,
    );
  }

  static const _geometryUnset = Object();

  @override
  List<Object?> get props => [
    ...super.props,
    geometryText,
    geometryInput,
    geometryValidationMessage,
  ];
}

class PendingTransferAcceptStep extends RecordFormStep {
  PendingTransferAcceptStep({
    required this.entry,
    required String name,
    required ProvenanceLifeStageSelection provenanceSelection,
    required this.destinationRequired,
    List<RecordFormInput>? inputs,
  }) : super(
         title: 'Accept Transfer',
         inputs:
             inputs ??
             [
               PendingTransferNameInput.dirty(name),
               const PendingTransferLocalIdInput.pure(),
               PendingTransferProvenanceInput.dirty(provenanceSelection),
               PendingTransferDestinationInput.pure(
                 isRequired: destinationRequired,
               ),
             ],
       );

  final PendingTransferEntry entry;
  final bool destinationRequired;

  PendingTransferNameInput get name =>
      inputs.whereType<PendingTransferNameInput>().first;

  PendingTransferLocalIdInput get localId =>
      inputs.whereType<PendingTransferLocalIdInput>().first;
  PendingTransferProvenanceInput get provenance =>
      inputs.whereType<PendingTransferProvenanceInput>().first;
  PendingTransferDestinationInput get destination =>
      inputs.whereType<PendingTransferDestinationInput>().first;

  @override
  PendingTransferAcceptStep copyWith({required RecordFormInput copiedInput}) {
    return PendingTransferAcceptStep(
      entry: entry,
      name: name.value ?? '',
      provenanceSelection:
          provenance.value ?? ProvenanceLifeStageSelection.fallback(),
      destinationRequired: destinationRequired,
      inputs: updateInputs(copiedInput),
    );
  }
}

class PendingTransferNameChanged extends RecordFormInputEvent<String?> {
  const PendingTransferNameChanged(super.value);
}

class PendingTransferLocalIdChanged extends RecordFormInputEvent<String?> {
  const PendingTransferLocalIdChanged(super.value);
}

class PendingTransferGeometryChanged extends RecordFormEvent {
  const PendingTransferGeometryChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

class PendingTransferNameInput
    extends
        RecordFormInput<
          String,
          RequiredInputError,
          PendingTransferNameChanged
        > {
  const PendingTransferNameInput.pure() : super.pure();
  PendingTransferNameInput.dirty(String? value) : super.dirty(value?.trim());

  @override
  String get label => 'Name in Your System';

  @override
  String? get hintText => 'Rename the genet for your organization';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Please enter a name');
    }
    if (trimmed.length < 2) {
      return const RequiredInputError('Name must be at least 2 characters');
    }
    return null;
  }

  @override
  PendingTransferNameInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    if (trimmed == this.value) return this;
    if (trimmed == null || trimmed.isEmpty) {
      return const PendingTransferNameInput.pure();
    }
    return PendingTransferNameInput.dirty(trimmed);
  }
}

class PendingTransferLocalIdInput
    extends
        RecordFormInput<
          String,
          RequiredInputError,
          PendingTransferLocalIdChanged
        > {
  const PendingTransferLocalIdInput.pure() : super.pure();
  PendingTransferLocalIdInput.dirty(String? value) : super.dirty(value?.trim());

  @override
  String get label => 'Local ID';

  @override
  String? get hintText => 'Organization identifier for this genet';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Please enter a local ID');
    }
    return null;
  }

  @override
  PendingTransferLocalIdInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    if (trimmed == this.value) return this;
    if (trimmed == null || trimmed.isEmpty) {
      return const PendingTransferLocalIdInput.pure();
    }
    return PendingTransferLocalIdInput.dirty(trimmed);
  }
}

class PendingTransferProvenanceChanged
    extends RecordFormInputEvent<ProvenanceLifeStageSelection> {
  const PendingTransferProvenanceChanged(super.value);
}

class PendingTransferDestinationChanged
    extends RecordFormInputEvent<PendingTransferDestinationSelection> {
  const PendingTransferDestinationChanged(super.value);
}

class PendingTransferProvenanceInput extends RecordFormInput<
    ProvenanceLifeStageSelection,
    RecordFormInputError,
    PendingTransferProvenanceChanged> {
  const PendingTransferProvenanceInput.pure() : super.pure();
  const PendingTransferProvenanceInput.dirty(
    ProvenanceLifeStageSelection super.value,
  ) : super.dirty();

  @override
  String get label => 'Provenance Metadata';

  @override
  String? get hintText => 'Select provenance type and life stage';

  @override
  RecordFormInputError? validator(ProvenanceLifeStageSelection? value) {
    if (value == null) {
      return const RecordFormInputError('Select provenance metadata');
    }
    return null;
  }

  @override
  PendingTransferProvenanceInput copyWith({
    required ProvenanceLifeStageSelection? value,
  }) {
    if (value == null) {
      return const PendingTransferProvenanceInput.pure();
    }
    return PendingTransferProvenanceInput.dirty(value);
  }
}

class PendingTransferDestinationSelection extends Equatable {
  const PendingTransferDestinationSelection({
    this.siteId,
    this.groupId,
    this.targetUrlPath,
    this.destinationSiteId,
    this.requiresGroup = false,
  });

  final String? siteId;
  final String? groupId;
  final String? targetUrlPath;
  final String? destinationSiteId;
  final bool requiresGroup;

  bool get hasSite => siteId != null && siteId!.isNotEmpty;
  bool get hasGroup => groupId != null && groupId!.isNotEmpty;

  @override
  List<Object?> get props => [
    siteId,
    groupId,
    targetUrlPath,
    destinationSiteId,
    requiresGroup,
  ];
}

class PendingTransferDestinationInput extends RecordFormInput<
    PendingTransferDestinationSelection,
    RecordFormInputError,
    PendingTransferDestinationChanged> {
  const PendingTransferDestinationInput.pure({required this.isRequired})
    : super.pure();
  const PendingTransferDestinationInput.dirty({
    required this.isRequired,
    PendingTransferDestinationSelection? value,
  }) : super.dirty(value);

  final bool isRequired;

  @override
  String get label => 'Destination';

  @override
  String? get hintText => 'Select a destination';

  @override
  RecordFormInputError? validator(
    PendingTransferDestinationSelection? value,
  ) {
    if (!isRequired) {
      return null;
    }
    if (value == null || !value.hasSite) {
      return const RecordFormInputError('Please select a site');
    }
    if (value.requiresGroup && !value.hasGroup) {
      return const RecordFormInputError('Please select a group');
    }
    return null;
  }

  @override
  PendingTransferDestinationInput copyWith({
    required PendingTransferDestinationSelection? value,
  }) {
    if (value == null) {
      return PendingTransferDestinationInput.pure(isRequired: isRequired);
    }
    return PendingTransferDestinationInput.dirty(
      value: value,
      isRequired: isRequired,
    );
  }
}
