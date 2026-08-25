import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_bloc.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_inputs.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_state.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/cubits/site_creation/site_form_inputs.dart';
import 'package:seafoundry_community/errors/domain_errors.dart';
import 'package:seafoundry_community/models/events/outplant_geometry.dart';
import 'package:seafoundry_community/models/site.dart';
import 'package:seafoundry_community/models/site_capabilities.dart';
import 'package:seafoundry_community/models/types/group_type.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/models/types/site_type.dart';
import 'package:seafoundry_community/repositories/inventory/site_repository.dart';
import 'package:seafoundry_community/services/outplant_geometry_builder.dart';
import 'package:seafoundry_community/services/unique_name_validation_service.dart';

class SiteCreationBloc extends RecordFormBloc<Site, SiteFormState> {
  SiteCreationBloc({required this.siteRepository, SiteType? initialSiteType})
    : _initialState = SiteFormState.initial(initialSiteType: initialSiteType),
      super(SiteFormState.initial(initialSiteType: initialSiteType)) {
    on<SiteGeometryParseResult>(_onGeometryParseResult);
    on<SiteGeometryCleared>(_onGeometryCleared);
    if (initialSiteType != null) {
      add(
        SiteSupportedOrganismsChanged(
          _defaultOrganismsForSiteType(initialSiteType),
        ),
      );
    }
  }

  final SiteRepository siteRepository;
  final SiteFormState _initialState;

  @override
  SiteFormState get initialState => _initialState;

  @override
  void onInputEvent(RecordFormInputEvent event, Emitter<SiteFormState> emit) {
    super.onInputEvent(event, emit);
    if (event is SiteTypeSelected) {
      add(
        SiteSupportedOrganismsChanged(
          _defaultOrganismsForSiteType(event.value),
        ),
      );

      // Filter out incompatible group types when site type changes
      final validGroupTypes = event.value.groupTypes;
      final currentGroupTypes = state.groupTypes.value ?? [];
      final filteredGroupTypes =
          currentGroupTypes
              .where((g) => validGroupTypes.any((v) => v.id == g.id))
              .toList();

      if (filteredGroupTypes.length != currentGroupTypes.length) {
        add(GroupTypesSelected(filteredGroupTypes));
      }
    }
  }

  /// Initialize the bloc for editing an existing site
  void initializeForEdit(Site site) {
    final siteType = SiteType.maybeFromId(site.siteTypeId);
    if (siteType != null) {
      add(SiteTypeSelected(siteType));
    }
    add(RecordNameChanged(site.name));
    if (site.description != null) {
      add(SiteDescriptionChanged(site.description!));
    }
    if (site.latitude != null) {
      add(SiteLatitudeChanged(site.latitude!.toString()));
    }
    if (site.longitude != null) {
      add(SiteLongitudeChanged(site.longitude!.toString()));
    }
    if (site.groupIdHierarchy.isNotEmpty) {
      final groupTypes = site.groupIdHierarchy
          .map((id) => GroupType.builtins[id])
          .whereType<GroupType>()
          .toList();
      if (groupTypes.isNotEmpty) {
        add(GroupTypesSelected(groupTypes));
      }
    }
    if (site.geometry != null) {
      add(
        SiteGeometryParseResult(
          geometry: site.geometry,
          statusMessage: 'Geometry loaded from existing site',
          validationMessage: null,
        ),
      );
    }
    add(SiteSupportedOrganismsChanged(site.supportedOrganismKinds));

    add(RecordFormInitializeForEdit(site));
  }

  /// Parses manually entered coordinate text (one lat,lng pair per line).
  static List<GeoCoordinate> _parseManualCoordinates(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('No coordinate pairs found.');
    }
    final coordinates = <GeoCoordinate>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,\s]+'));
      if (parts.length < 2) {
        throw FormatException('Invalid coordinate pair: "$line"');
      }
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) {
        throw FormatException('Non-numeric coordinate: "$line"');
      }
      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return coordinates;
  }

  List<OrganismKind> _defaultOrganismsForSiteType(SiteType siteType) {
    return SiteCapabilities.defaultOrganismsForSite(
      siteType,
      const [OrganismKind.coral],
    );
  }

  void _onGeometryParseResult(
    SiteGeometryParseResult event,
    Emitter<SiteFormState> emit,
  ) {
    emit(
      state.copyWith(
        geometry: () => event.geometry,
        geometryStatusMessage: () => event.statusMessage,
        geometryValidationMessage: () => event.validationMessage,
      ),
    );
  }

  void _onGeometryCleared(
    SiteGeometryCleared event,
    Emitter<SiteFormState> emit,
  ) {
    emit(
      state.copyWith(
        geometry: () => null,
        geometryStatusMessage: () => null,
        geometryValidationMessage: () => null,
      ),
    );
  }

  @override
  Future<Site?> createRecord() async {
    // Validate required fields before creating the site
    if (state.name.value == null || state.name.value!.trim().isEmpty) {
      throw Exception('Site name is required');
    }
    if (state.siteType.value == null) {
      throw Exception('Site type is required');
    }

    final trimmedName = state.name.value!.trim();

    // Validate uniqueness within organization
    final validationService = UniqueNameValidationService(
      firestore: siteRepository.db,
    );
    final isUnique = await validationService.isSiteNameUnique(
      name: trimmedName,
      organizationDomain: siteRepository.organization.domain,
      organizationId: siteRepository.organization.id,
      excludeRecordId: state.originalRecord?.id,
    );

    if (!isUnique) {
      throw Exception(
        'A site with the name "$trimmedName" already exists in ${siteRepository.organization.name}. Please choose a different name.',
      );
    }

    final siteType = state.siteType.value!;
    final supportsGeometry = SiteCapabilities.resolve(siteType).supportsGeometry;
    OutplantGeometry? geometry = state.geometry;
    double? latitude = (state.locationLatitude.value?.trim().isEmpty ?? true)
        ? null
        : double.tryParse(state.locationLatitude.value!.trim());
    double? longitude = (state.locationLongitude.value?.trim().isEmpty ?? true)
        ? null
        : double.tryParse(state.locationLongitude.value!.trim());

    // Auto-parse geometry for in-situ sites if not already parsed
    if (supportsGeometry && geometry == null) {
      final manualText = state.geometryManual?.value?.trim() ?? '';
      if (manualText.isNotEmpty) {
        // Auto-parse the manually entered coordinates (lat,lng per line).
        const builder = OutplantGeometryBuilder();
        try {
          final coordinates = _parseManualCoordinates(manualText);
          final input = OutplantGeometryInput(
            type: coordinates.length == 1
                ? OutplantGeometryType.point
                : OutplantGeometryType.polygon,
            coordinates: coordinates,
            source: OutplantGeometrySource.manual,
          );
          geometry = builder.build(input: input);
        } on FormatException catch (e) {
          throw RepositoryError(
            message: 'Invalid geometry format: ${e.message}',
            recoverySuggestion: 'Check the coordinate format and try again.',
          );
        }
      } else if (latitude != null && longitude != null) {
        // Fall back to a single coordinate from the site lat/long.
        const builder = OutplantGeometryBuilder();
        final coordinate = GeoCoordinate(
          latitude: latitude,
          longitude: longitude,
        );
        geometry = builder.build(
          input: OutplantGeometryInput(
            type: OutplantGeometryType.point,
            coordinates: [coordinate],
            source: OutplantGeometrySource.siteCentroid,
          ),
          siteCentroid: coordinate,
        );
      }
    }

    if (geometry != null) {
      final centroid =
          geometry.centroid ??
          (geometry.coordinates.isNotEmpty ? geometry.coordinates.first : null);
      latitude = centroid?.latitude ?? latitude;
      longitude = centroid?.longitude ?? longitude;
    }

    final newSite = Site.partial(
      name: trimmedName,
      siteTypeId: siteType.id,
      description: state.description.value?.trim().isEmpty ?? true
          ? null
          : state.description.value!.trim(),
      groupIdHierarchy:
          state.groupTypes.value?.map((gt) => gt.id).toList() ?? [],
      latitude: latitude,
      longitude: longitude,
      geometry: geometry,
    );

    // If editing, update existing record with correction event; otherwise create new
    if (state.isEditing && state.originalRecord != null) {
      final now = DateTime.now().toIso8601String();
      final updatedSite = newSite.copyWith(
        id: state.originalRecord!.id,
        createdAt: state.originalRecord!.createdAt,
        createdById: state.originalRecord!.createdById,
        updatedAt: now,
        updatedById: siteRepository.user.id,
        organizationId: state.originalRecord!.organizationId,
        urlPath: state.originalRecord!.urlPath,
        internalPath: state.originalRecord!.internalPath,
        slug: state.originalRecord!.slug,
      );
      // Use updateWithCorrection to create correction event
      return await siteRepository.updateSiteWithCorrection(
        originalSite: state.originalRecord!,
        updatedSite: updatedSite,
      );
    }

    final created = await siteRepository.createRecord(
      newSite,
      siteRepository.organization,
    );
    return created;
  }
}

class SiteFormState extends RecordFormState<Site> {
  SiteFormState({
    SiteType? initialSiteType,
    List<RecordFormStep>? steps,
    super.currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    this.geometry,
    this.geometryStatusMessage,
    this.geometryValidationMessage,
  }) : super(
         steps:
             steps ??
             [
               SiteSelectTypeStep(initialSiteType: initialSiteType),
               SiteDetailsStep(),
               SiteGroupTypesStep(),
               RecordFormReviewStep(),
             ],
         submissionStatus: submissionStatus ?? FormzSubmissionStatus.initial,
       );

  factory SiteFormState.initial({SiteType? initialSiteType}) =>
      SiteFormState(initialSiteType: initialSiteType);

  final OutplantGeometry? geometry;
  final String? geometryStatusMessage;
  final String? geometryValidationMessage;

  @override
  SiteFormState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    Site? createdRecord,
    Site? originalRecord,
    OutplantGeometry? Function()? geometry,
    String? Function()? geometryStatusMessage,
    String? Function()? geometryValidationMessage,
    bool overrideSubmissionError = false,
  }) {
    return SiteFormState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
      geometry: geometry != null ? geometry() : this.geometry,
      geometryStatusMessage: geometryStatusMessage != null
          ? geometryStatusMessage()
          : this.geometryStatusMessage,
      geometryValidationMessage: geometryValidationMessage != null
          ? geometryValidationMessage()
          : this.geometryValidationMessage,
    );
  }

  SiteTypeSelection get siteType =>
      inputs.whereType<SiteTypeSelection>().firstOrNull ??
      const SiteTypeSelection.pure();

  RecordNameInput get name =>
      inputs.whereType<RecordNameInput>().firstOrNull ??
      const RecordNameInput.pure();

  SiteDescription get description =>
      inputs.whereType<SiteDescription>().firstOrNull ??
      const SiteDescription.pure();

  SiteSupportedOrganismsSelection get supportedOrganisms =>
      inputs.whereType<SiteSupportedOrganismsSelection>().firstOrNull ??
      const SiteSupportedOrganismsSelection.pure();

  SiteLatitude get locationLatitude =>
      inputs.whereType<SiteLatitude>().firstOrNull ?? const SiteLatitude.pure();

  SiteLongitude get locationLongitude =>
      inputs.whereType<SiteLongitude>().firstOrNull ??
      const SiteLongitude.pure();

  GroupTypesSelection get groupTypes =>
      inputs.whereType<GroupTypesSelection>().firstOrNull ??
      const GroupTypesSelection.pure();

  SiteGeometryManual? get geometryManual =>
      inputs.whereType<SiteGeometryManual>().firstOrNull;

  @override
  List<Object?> get props => [
    ...super.props,
    geometry,
    geometryStatusMessage,
    geometryValidationMessage,
    geometryManual?.value,
    supportedOrganisms.value,
  ];
}

class SiteSelectTypeStep extends RecordFormStep {
  SiteSelectTypeStep({SiteType? initialSiteType, List<RecordFormInput>? inputs})
    : super(
        inputs:
            inputs ??
            [
              initialSiteType != null
                  ? SiteTypeSelection.dirty(initialSiteType)
                  : SiteTypeSelection.pure(),
            ],
        title: 'Site Type',
      );

  @override
  SiteSelectTypeStep copyWith({required RecordFormInput copiedInput}) {
    return SiteSelectTypeStep(inputs: updateInputs(copiedInput));
  }
}

class SiteDetailsStep extends RecordFormStep {
  SiteDetailsStep({List<RecordFormInput>? inputs})
    : super(
        inputs:
            inputs ??
            [
              RecordNameInput.pure(),
              SiteDescription.pure(),
              SiteSupportedOrganismsSelection.pure(),
              SiteLatitude.pure(),
              SiteLongitude.pure(),
              SiteGeometryManual.pure(),
            ],
        title: 'Site Details',
      );

  @override
  SiteDetailsStep copyWith({required RecordFormInput copiedInput}) {
    return SiteDetailsStep(inputs: updateInputs(copiedInput));
  }
}

class SiteGroupTypesStep extends RecordFormStep {
  SiteGroupTypesStep({List<RecordFormInput>? inputs})
    : super(
        inputs: inputs ?? [GroupTypesSelection.pure()],
        title: 'Group Types',
      );

  @override
  SiteGroupTypesStep copyWith({required RecordFormInput copiedInput}) {
    return SiteGroupTypesStep(inputs: updateInputs(copiedInput));
  }
}

class SiteTypeSelected extends RecordFormInputEvent<SiteType> {
  const SiteTypeSelected(super.value);
}

class SiteDescriptionChanged extends RecordFormInputEvent<String> {
  const SiteDescriptionChanged(super.value);
}

class SiteLatitudeChanged extends RecordFormInputEvent<String> {
  const SiteLatitudeChanged(super.value);
}

class SiteLongitudeChanged extends RecordFormInputEvent<String> {
  const SiteLongitudeChanged(super.value);
}

class SiteGeometryManualChanged extends RecordFormInputEvent<String> {
  const SiteGeometryManualChanged(super.value);
}

class SiteGeometryParseResult extends RecordFormEvent {
  const SiteGeometryParseResult({
    this.geometry,
    this.statusMessage,
    this.validationMessage,
  });

  final OutplantGeometry? geometry;
  final String? statusMessage;
  final String? validationMessage;

  @override
  List<Object?> get props => [geometry, statusMessage, validationMessage];
}

class SiteGeometryCleared extends RecordFormEvent {
  const SiteGeometryCleared();

  @override
  List<Object?> get props => const [];
}

class GroupTypesSelected extends RecordFormInputEvent<List<GroupType>> {
  const GroupTypesSelected(super.value);
}

class SiteSupportedOrganismsChanged
    extends RecordFormInputEvent<List<OrganismKind>> {
  const SiteSupportedOrganismsChanged(super.value);
}
