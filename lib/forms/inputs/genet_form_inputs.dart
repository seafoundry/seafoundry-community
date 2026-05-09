import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

enum GenetNameError {
  empty('Genet name is required'),
  tooShort('Name must be at least 2 characters'),
  tooLong('Name must be less than 50 characters'),
  invalidCharacters('Name contains invalid characters'),
  duplicate('This genet ID already exists in your organization');

  final String message;
  const GenetNameError(this.message);
}

class GenetName extends FormzInput<String, GenetNameError> {
  const GenetName.pure() : super.pure('');
  const GenetName.dirty([super.value = '']) : super.dirty();

  @override
  GenetNameError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return GenetNameError.empty;
    if (trimmed.length < 2) return GenetNameError.tooShort;
    if (trimmed.length > 50) return GenetNameError.tooLong;

    // Check for invalid characters (only alphanumeric, spaces, hyphens, underscores)
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(trimmed)) {
      return GenetNameError.invalidCharacters;
    }

    return null;
  }
}

class GenetAliasEntry extends Equatable {
  const GenetAliasEntry({
    this.sourceSystem = 'local',
    this.value = '',
    this.label,
  });

  final String sourceSystem;
  final String value;
  final String? label;

  GenetAliasEntry copyWith({
    String? sourceSystem,
    String? value,
    String? label,
  }) {
    return GenetAliasEntry(
      sourceSystem: sourceSystem ?? this.sourceSystem,
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }

  OrganismAlias toOrganismAlias() => OrganismAlias(
    sourceSystem: sourceSystem.trim().isEmpty
        ? 'custom'
        : sourceSystem.trim().toLowerCase(),
    value: value.trim(),
    label: (label ?? value).trim().isEmpty ? null : (label ?? value).trim(),
  );

  factory GenetAliasEntry.fromOrganismAlias(OrganismAlias alias) =>
      GenetAliasEntry(
        sourceSystem: alias.sourceSystem,
        value: alias.value,
        label: alias.label,
      );

  @override
  List<Object?> get props => [sourceSystem, value, label];
}

enum GenetSpeciesError {
  notSelected('Please select a species');

  final String message;
  const GenetSpeciesError(this.message);
}

class GenetSpeciesSelection extends FormzInput<Species?, GenetSpeciesError> {
  const GenetSpeciesSelection.pure() : super.pure(null);
  const GenetSpeciesSelection.dirty([super.value]) : super.dirty();

  @override
  GenetSpeciesError? validator(Species? value) {
    if (value == null) return GenetSpeciesError.notSelected;
    return null;
  }
}

enum GenetProvenanceTypeError {
  notSelected('Please select a provenance type');

  final String message;
  const GenetProvenanceTypeError(this.message);
}

class GenetProvenanceTypeSelection
    extends FormzInput<ProvenanceType?, GenetProvenanceTypeError> {
  const GenetProvenanceTypeSelection.pure() : super.pure(null);
  const GenetProvenanceTypeSelection.dirty([super.value]) : super.dirty();

  @override
  GenetProvenanceTypeError? validator(ProvenanceType? value) {
    if (value == null) return GenetProvenanceTypeError.notSelected;
    return null;
  }
}

enum GenetLifeStageError {
  notSelected('Please select a life stage');

  final String message;
  const GenetLifeStageError(this.message);
}

class GenetLifeStageSelection
    extends FormzInput<LifeStage?, GenetLifeStageError> {
  const GenetLifeStageSelection.pure() : super.pure(null);
  const GenetLifeStageSelection.dirty([super.value]) : super.dirty();

  @override
  GenetLifeStageError? validator(LifeStage? value) {
    if (value == null) return GenetLifeStageError.notSelected;
    return null;
  }
}

enum GenetClonalIdError {
  invalidFormat('Clonal ID format is invalid');

  final String message;
  const GenetClonalIdError(this.message);
}

class GenetClonalId extends FormzInput<String?, GenetClonalIdError> {
  const GenetClonalId.pure() : super.pure(null);
  const GenetClonalId.dirty([super.value]) : super.dirty();

  @override
  GenetClonalIdError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null; // Optional field

    // Basic alphanumeric validation for clonal ID
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(trimmed)) {
      return GenetClonalIdError.invalidFormat;
    }

    return null;
  }
}

enum GenetAccessionNumberError {
  invalidFormat('Accession number format is invalid');

  final String message;
  const GenetAccessionNumberError(this.message);
}

class GenetAccessionNumber
    extends FormzInput<String?, GenetAccessionNumberError> {
  const GenetAccessionNumber.pure() : super.pure(null);
  const GenetAccessionNumber.dirty([super.value]) : super.dirty();

  @override
  GenetAccessionNumberError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null; // Optional field

    // Basic alphanumeric validation for accession number
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(trimmed)) {
      return GenetAccessionNumberError.invalidFormat;
    }

    return null;
  }
}

enum GenetProvenanceIdError {
  empty('Provenance ID is required'),
  invalidFormat('Provenance ID must be in format PID-ACER-0001');

  final String message;
  const GenetProvenanceIdError(this.message);
}

class GenetProvenanceId extends FormzInput<String, GenetProvenanceIdError> {
  const GenetProvenanceId.pure() : super.pure('');
  const GenetProvenanceId.dirty([super.value = '']) : super.dirty();

  @override
  GenetProvenanceIdError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return GenetProvenanceIdError.empty;

    // Provenance ID format: PID-{4-letter-code}-{number}
    if (!RegExp(r'^PID-[A-Z0-9]{4}-\d{1,6}$').hasMatch(trimmed)) {
      return GenetProvenanceIdError.invalidFormat;
    }

    return null;
  }
}

// Structured provenance inputs for Genotype entries
enum ProvenanceFieldError {
  tooLong('Value is too long');

  final String message;
  const ProvenanceFieldError(this.message);
}

class ProvenanceText extends FormzInput<String, ProvenanceFieldError> {
  const ProvenanceText.pure() : super.pure('');
  const ProvenanceText.dirty([super.value = '']) : super.dirty();

  @override
  ProvenanceFieldError? validator(String value) {
    if (value.isEmpty) return null;
    if (value.length > 200) return ProvenanceFieldError.tooLong;
    return null;
  }
}

class ProvenanceCollectionDate extends FormzInput<DateTime?, String> {
  const ProvenanceCollectionDate.pure() : super.pure(null);
  const ProvenanceCollectionDate.dirty([super.value]) : super.dirty();

  @override
  String? validator(DateTime? value) {
    return null; // optional
  }
}

enum GpsCoordinateError {
  invalid('Invalid coordinate'),
  precision('Must have at least 5 decimal places'),
  outOfRange('Coordinate out of range');

  final String message;
  const GpsCoordinateError(this.message);
}

class ProvenanceLatitude extends FormzInput<String, GpsCoordinateError> {
  const ProvenanceLatitude.pure() : super.pure('');
  const ProvenanceLatitude.dirty([super.value = '']) : super.dirty();

  @override
  GpsCoordinateError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null; // optional
    final match = RegExp(r'^-?\d{1,2}\.\d{5,}$').firstMatch(trimmed);
    if (match == null) return GpsCoordinateError.precision;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return GpsCoordinateError.invalid;
    if (parsed < -90 || parsed > 90) return GpsCoordinateError.outOfRange;
    return null;
  }
}

class ProvenanceLongitude extends FormzInput<String, GpsCoordinateError> {
  const ProvenanceLongitude.pure() : super.pure('');
  const ProvenanceLongitude.dirty([super.value = '']) : super.dirty();

  @override
  GpsCoordinateError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null; // optional
    final match = RegExp(r'^-?\d{1,3}\.\d{5,}$').firstMatch(trimmed);
    if (match == null) return GpsCoordinateError.precision;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return GpsCoordinateError.invalid;
    if (parsed < -180 || parsed > 180) return GpsCoordinateError.outOfRange;
    return null;
  }
}

enum GenetParentGameteIdsError {
  tooFew('Cohort must include at least 2 parent gametes'),
  tooMany('Cohort cannot have more than 10 parent gametes');

  final String message;
  const GenetParentGameteIdsError(this.message);
}

class GenetParentGameteIds
    extends FormzInput<List<String>, GenetParentGameteIdsError> {
  const GenetParentGameteIds.pure() : super.pure(const []);
  const GenetParentGameteIds.dirty([super.value = const []]) : super.dirty();

  @override
  GenetParentGameteIdsError? validator(List<String> value) {
    final filtered = value.map((id) => id.trim()).where((id) => id.isNotEmpty);
    final count = filtered.length;
    if (count > 10) return GenetParentGameteIdsError.tooMany;
    return null;
  }
}

enum GenetParentCohortIdError {
  tooShort('Parent cohort ID must be at least 3 characters');

  final String message;
  const GenetParentCohortIdError(this.message);
}

class GenetParentCohortId extends FormzInput<String, GenetParentCohortIdError> {
  const GenetParentCohortId.pure() : super.pure('');
  const GenetParentCohortId.dirty([super.value = '']) : super.dirty();

  @override
  GenetParentCohortIdError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length < 3) return GenetParentCohortIdError.tooShort;
    return null;
  }
}

enum GenetDonorGenotypeIdError {
  tooShort('Donor genotype ID must be at least 3 characters');

  final String message;
  const GenetDonorGenotypeIdError(this.message);
}

class GenetDonorGenotypeId
    extends FormzInput<String, GenetDonorGenotypeIdError> {
  const GenetDonorGenotypeId.pure() : super.pure('');
  const GenetDonorGenotypeId.dirty([super.value = '']) : super.dirty();

  @override
  GenetDonorGenotypeIdError? validator(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length < 3) return GenetDonorGenotypeIdError.tooShort;
    return null;
  }
}

enum GenetNotesError {
  tooLong('Notes must be less than 1000 characters');

  final String message;
  const GenetNotesError(this.message);
}

class GenetNotes extends FormzInput<String, GenetNotesError> {
  const GenetNotes.pure() : super.pure('');
  const GenetNotes.dirty([super.value = '']) : super.dirty();

  @override
  GenetNotesError? validator(String value) {
    if (value.isEmpty) return null;
    if (value.length > 1000) return GenetNotesError.tooLong;
    return null;
  }
}

class GenetReadyForOutplant extends FormzInput<bool, String> {
  const GenetReadyForOutplant.pure() : super.pure(false);
  const GenetReadyForOutplant.dirty([super.value = false]) : super.dirty();

  @override
  String? validator(bool value) => null;
}

// Transfer fields for partner-received flow
class TransferNotes extends FormzInput<String, String> {
  const TransferNotes.pure() : super.pure('');
  const TransferNotes.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return null; // Required conditionally when sendTransfer is true
  }
}

class TransferDateSelection extends FormzInput<DateTime?, String> {
  const TransferDateSelection.pure() : super.pure(null);
  const TransferDateSelection.dirty([super.value]) : super.dirty();

  @override
  String? validator(DateTime? value) {
    return null; // Required conditionally when sendTransfer is true
  }
}

enum CrossGameteRole { dam, sire, unknown }

class CrossGameteEntry {
  const CrossGameteEntry({required this.id, required this.role});

  final String id;
  final CrossGameteRole role;

  CrossGameteEntry copyWith({String? id, CrossGameteRole? role}) {
    return CrossGameteEntry(id: id ?? this.id, role: role ?? this.role);
  }
}

class GenetCrossGametes extends FormzInput<List<CrossGameteEntry>, String> {
  const GenetCrossGametes.pure() : super.pure(const []);
  const GenetCrossGametes.dirty([super.value = const []]) : super.dirty();

  @override
  String? validator(List<CrossGameteEntry> value) {
    if (value.isEmpty) return null;
    final cleaned = value
        .map((entry) => entry.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (cleaned.isEmpty) return null;
    if (cleaned.length != cleaned.toSet().length) {
      return 'Duplicate gamete IDs not allowed';
    }
    return null;
  }
}

class GenetCrossDate extends FormzInput<DateTime?, String> {
  const GenetCrossDate.pure() : super.pure(null);
  const GenetCrossDate.dirty([super.value]) : super.dirty();

  @override
  String? validator(DateTime? value) {
    return null; // Optional input – enforced per genet type
  }
}

// Gamete sex selection (eggs/sperm)
enum GameteSex { eggs, sperm }

class GameteSexSelection extends FormzInput<GameteSex?, String> {
  const GameteSexSelection.pure() : super.pure(null);
  const GameteSexSelection.dirty([super.value]) : super.dirty();

  @override
  String? validator(GameteSex? value) {
    return null; // optional
  }
}

// Gamete spawn date (optional)
class GameteSpawnDateSelection extends FormzInput<DateTime?, String> {
  const GameteSpawnDateSelection.pure() : super.pure(null);
  const GameteSpawnDateSelection.dirty([super.value]) : super.dirty();

  @override
  String? validator(DateTime? value) {
    return null; // optional
  }
}

/// Complete genet form state with multi-step support
class GenetFormState with FormzMixin {
  const GenetFormState({
    this.name = const GenetName.pure(),
    this.species = const GenetSpeciesSelection.pure(),
    this.provenanceType = const GenetProvenanceTypeSelection.pure(),
    this.lifeStage = const GenetLifeStageSelection.pure(),
    this.slug = '',
    this.clonalId = const GenetClonalId.pure(),
    this.accessionNumber = const GenetAccessionNumber.pure(),
    this.aliases = const <GenetAliasEntry>[],
    this.provOrigin = const ProvenanceText.pure(),
    this.provLocation = const ProvenanceText.pure(),
    this.provCollector = const ProvenanceText.pure(),
    this.provDepth = const ProvenanceText.pure(),
    this.provHabitatType = const ProvenanceText.pure(),
    this.provInstitution = const ProvenanceText.pure(),
    this.provLatitude = const ProvenanceLatitude.pure(),
    this.provLongitude = const ProvenanceLongitude.pure(),
    this.provCollectionDate = const ProvenanceCollectionDate.pure(),
    this.parentGameteIds = const GenetParentGameteIds.pure(),
    this.parentCohortId = const GenetParentCohortId.pure(),
    this.donorGenotypeId = const GenetDonorGenotypeId.pure(),
    this.notes = const GenetNotes.pure(),
    this.crossGametes = const GenetCrossGametes.pure(),
    this.crossDate = const GenetCrossDate.pure(),
    this.sendTransfer = false,
    this.gameteSex = const GameteSexSelection.pure(),
    this.gameteSpawnDate = const GameteSpawnDateSelection.pure(),
    this.transferOrgId = '',
    this.transferEmail = '',
    this.transferNotes = const TransferNotes.pure(),
    this.transferDate = const TransferDateSelection.pure(),
    this.currentStep = 0,
    this.isSubmissionInProgress = false,
    this.submissionError,
    this.allowedProvenanceTypes,
    this.readyForOutplant = const GenetReadyForOutplant.pure(),
    this.heatTested = false,
    this.diseaseTested = false,
    this.heatTestingComment = '',
    this.diseaseTestingComment = '',
    this.ownerOrganizationId = '',
    this.managingOrganizationId = '',
  });

  final GenetName name;
  final GenetSpeciesSelection species;
  final GenetProvenanceTypeSelection provenanceType;
  final GenetLifeStageSelection lifeStage;
  final String slug;
  final GenetClonalId clonalId;
  final GenetAccessionNumber accessionNumber;
  final List<GenetAliasEntry> aliases;
  final ProvenanceText provOrigin;
  final ProvenanceText provLocation;
  final ProvenanceText provCollector;
  final ProvenanceText provDepth;
  final ProvenanceText provHabitatType;
  final ProvenanceText provInstitution;
  final ProvenanceLatitude provLatitude;
  final ProvenanceLongitude provLongitude;
  final ProvenanceCollectionDate provCollectionDate;
  final GenetParentGameteIds parentGameteIds;
  final GenetParentCohortId parentCohortId;
  final GenetDonorGenotypeId donorGenotypeId;
  final GenetNotes notes;
  final GenetCrossGametes crossGametes;
  final GenetCrossDate crossDate;
  final GameteSexSelection gameteSex;
  final GameteSpawnDateSelection gameteSpawnDate;
  final bool sendTransfer;
  final String transferOrgId;
  final String transferEmail;
  final TransferNotes transferNotes;
  final TransferDateSelection transferDate;
  final int currentStep;
  final bool isSubmissionInProgress;
  final String? submissionError;
  final List<ProvenanceType>? allowedProvenanceTypes;
  final GenetReadyForOutplant readyForOutplant;
  final bool heatTested;
  final bool diseaseTested;
  final String heatTestingComment;
  final String diseaseTestingComment;
  final String ownerOrganizationId;
  final String managingOrganizationId;

  GenetFormState copyWith({
    GenetName? name,
    GenetSpeciesSelection? species,
    GenetProvenanceTypeSelection? provenanceType,
    GenetLifeStageSelection? lifeStage,
    String? slug,
    GenetClonalId? clonalId,
    GenetAccessionNumber? accessionNumber,
    ProvenanceText? provOrigin,
    ProvenanceText? provLocation,
    ProvenanceText? provCollector,
    ProvenanceText? provDepth,
    ProvenanceText? provHabitatType,
    ProvenanceText? provInstitution,
    ProvenanceLatitude? provLatitude,
    ProvenanceLongitude? provLongitude,
    ProvenanceCollectionDate? provCollectionDate,
    GenetParentGameteIds? parentGameteIds,
    GenetParentCohortId? parentCohortId,
    GenetDonorGenotypeId? donorGenotypeId,
    GenetNotes? notes,
    GenetCrossGametes? crossGametes,
    List<GenetAliasEntry>? aliases,
    GenetCrossDate? crossDate,
    GameteSexSelection? gameteSex,
    GameteSpawnDateSelection? gameteSpawnDate,
    bool? sendTransfer,
    String? transferOrgId,
    String? transferEmail,
    TransferNotes? transferNotes,
    TransferDateSelection? transferDate,
    int? currentStep,
    bool? isSubmissionInProgress,
    String? submissionError,
    bool overrideSubmissionError = false,
    List<ProvenanceType>? allowedProvenanceTypes,
    GenetReadyForOutplant? readyForOutplant,
    bool? heatTested,
    bool? diseaseTested,
    String? heatTestingComment,
    String? diseaseTestingComment,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) {
    return GenetFormState(
      name: name ?? this.name,
      species: species ?? this.species,
      provenanceType: provenanceType ?? this.provenanceType,
      lifeStage: lifeStage ?? this.lifeStage,
      slug: slug ?? this.slug,
      clonalId: clonalId ?? this.clonalId,
      accessionNumber: accessionNumber ?? this.accessionNumber,
      provOrigin: provOrigin ?? this.provOrigin,
      provLocation: provLocation ?? this.provLocation,
      provCollector: provCollector ?? this.provCollector,
      provDepth: provDepth ?? this.provDepth,
      provHabitatType: provHabitatType ?? this.provHabitatType,
      provInstitution: provInstitution ?? this.provInstitution,
      provLatitude: provLatitude ?? this.provLatitude,
      provLongitude: provLongitude ?? this.provLongitude,
      provCollectionDate: provCollectionDate ?? this.provCollectionDate,
      parentGameteIds: parentGameteIds ?? this.parentGameteIds,
      parentCohortId: parentCohortId ?? this.parentCohortId,
      donorGenotypeId: donorGenotypeId ?? this.donorGenotypeId,
      notes: notes ?? this.notes,
      crossGametes: crossGametes ?? this.crossGametes,
      aliases: aliases ?? this.aliases,
      crossDate: crossDate ?? this.crossDate,
      gameteSex: gameteSex ?? this.gameteSex,
      gameteSpawnDate: gameteSpawnDate ?? this.gameteSpawnDate,
      sendTransfer: sendTransfer ?? this.sendTransfer,
      transferOrgId: transferOrgId ?? this.transferOrgId,
      transferEmail: transferEmail ?? this.transferEmail,
      transferNotes: transferNotes ?? this.transferNotes,
      transferDate: transferDate ?? this.transferDate,
      currentStep: currentStep ?? this.currentStep,
      isSubmissionInProgress:
          isSubmissionInProgress ?? this.isSubmissionInProgress,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      allowedProvenanceTypes:
          allowedProvenanceTypes ?? this.allowedProvenanceTypes,
      readyForOutplant: readyForOutplant ?? this.readyForOutplant,
      heatTested: heatTested ?? this.heatTested,
      diseaseTested: diseaseTested ?? this.diseaseTested,
      heatTestingComment: heatTestingComment ?? this.heatTestingComment,
      diseaseTestingComment:
          diseaseTestingComment ?? this.diseaseTestingComment,
      ownerOrganizationId: ownerOrganizationId ?? this.ownerOrganizationId,
      managingOrganizationId:
          managingOrganizationId ?? this.managingOrganizationId,
    );
  }

  @override
  List<FormzInput> get inputs => [
    name,
    species,
    provenanceType,
    lifeStage,
    clonalId,
    accessionNumber,
    provOrigin,
    provLocation,
    provCollector,
    provDepth,
    provHabitatType,
    provInstitution,
    provLatitude,
    provLongitude,
    parentGameteIds,
    parentCohortId,
    donorGenotypeId,
    notes,
    readyForOutplant,
    crossGametes,
    crossDate,
  ];

  bool get isTypeSpecificValid {
    final provType = provenanceType.value;
    if (provType == null) return false;

    final trimmedTransferOrgId = transferOrgId.trim();
    final hasTransferOrg =
        trimmedTransferOrgId.isNotEmpty ||
        provInstitution.value.trim().isNotEmpty;
    final hasTransferDate = transferDate.value != null;

    // Check for gamete life stage
    if (lifeStage.value == LifeStage.gamete) {
      // Gametes require donor genotype or transfer fields
      if (sendTransfer) {
        return hasTransferOrg && hasTransferDate;
      }
      return donorGenotypeId.value.trim().isNotEmpty &&
          donorGenotypeId.isValid;
    }

    // Validate based on provenance type
    switch (provType) {
      case ProvenanceType.wild:
      case ProvenanceType.cohort:
      case ProvenanceType.graduatedIndividual:
      case ProvenanceType.transfer:
      case ProvenanceType.unknown:
        // All types use founder-like validation
        if (sendTransfer) {
          return hasTransferOrg && hasTransferDate;
        }
        return true;
    }
  }

  bool get isFormValid {
    // Always validate core fields
    final coreValid =
        name.isValid &&
        species.isValid &&
        provenanceType.isValid &&
        lifeStage.isValid;

    // Optional fields that should be validated if provided
    final optionalValid =
        clonalId.isValid && accessionNumber.isValid && notes.isValid;

    return coreValid && optionalValid && isTypeSpecificValid;
  }

  /// Returns a human-readable error message describing validation failures,
  /// or null if the form is valid.
  String? get validationErrorMessage {
    if (isFormValid) return null;

    final errors = <String>[];

    // Check core fields
    if (!name.isValid) {
      final error = name.validator(name.value);
      if (error != null) errors.add(error.message);
    }
    if (!species.isValid) {
      final error = species.validator(species.value);
      if (error != null) errors.add(error.message);
    }
    if (!provenanceType.isValid) {
      final error = provenanceType.validator(provenanceType.value);
      if (error != null) errors.add(error.message);
    }
    if (!lifeStage.isValid) {
      final error = lifeStage.validator(lifeStage.value);
      if (error != null) errors.add(error.message);
    }

    // Check optional fields that have validation errors
    if (!clonalId.isValid) {
      final error = clonalId.validator(clonalId.value);
      if (error != null) errors.add(error.message);
    }
    if (!accessionNumber.isValid) {
      final error = accessionNumber.validator(accessionNumber.value);
      if (error != null) errors.add(error.message);
    }
    if (!notes.isValid) {
      final error = notes.validator(notes.value);
      if (error != null) errors.add(error.message);
    }

    // Check type-specific fields
    if (!isTypeSpecificValid) {
      final provType = provenanceType.value;
      if (provType == null) {
        errors.add('Please select a provenance type');
      } else if (lifeStage.value == LifeStage.gamete) {
        if (sendTransfer) {
          if (provInstitution.value.trim().isEmpty &&
              transferOrgId.trim().isEmpty) {
            errors.add('Collecting institution is required for transfers');
          }
          if (transferDate.value == null) {
            errors.add('Transfer date is required');
          }
        } else if (donorGenotypeId.value.trim().isEmpty ||
            !donorGenotypeId.isValid) {
          errors.add('Donor genotype is required for gametes');
        }
      } else if (sendTransfer) {
        if (provInstitution.value.trim().isEmpty &&
            transferOrgId.trim().isEmpty) {
          errors.add('Collecting institution is required for transfers');
        }
        if (transferDate.value == null) {
          errors.add('Transfer date is required');
        }
      }
    }

    if (errors.isEmpty) {
      return 'Please complete all required fields';
    }

    return errors.join('. ');
  }

  List<String> get normalizedParentGameteIds {
    final fromCross = crossGametes.value
        .map((entry) => entry.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (fromCross.isNotEmpty) return fromCross;
    return parentGameteIds.value
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  List<String> get normalizedDamIds => crossGametes.value
      .where((entry) => entry.role == CrossGameteRole.dam)
      .map((entry) => entry.id.trim())
      .where((id) => id.isNotEmpty)
      .toList();

  List<String> get normalizedSireIds => crossGametes.value
      .where((entry) => entry.role == CrossGameteRole.sire)
      .map((entry) => entry.id.trim())
      .where((id) => id.isNotEmpty)
      .toList();

  List<OrganismAlias> get normalizedAliases {
    final seen = <String>{};
    final cleaned = <OrganismAlias>[];
    for (final entry in aliases) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final source = entry.sourceSystem.trim().isEmpty
          ? 'custom'
          : entry.sourceSystem.trim().toLowerCase();
      final key = '$source::${value.toLowerCase()}';
      if (seen.add(key)) {
        cleaned.add(
          entry.copyWith(sourceSystem: source, value: value).toOrganismAlias(),
        );
      }
    }
    return cleaned;
  }

  /// Create Genet populated from form state
  Genet toIncompleteGenet({String? slugOverride}) {
    if (!isFormValid) throw Exception('Form is not valid');

    final provenanceTypeValue = provenanceType.value;
    final lifeStageValue = lifeStage.value;
    if (provenanceTypeValue == null || lifeStageValue == null) {
      throw Exception('Provenance type and life stage are required');
    }

    final provenanceKind = ProvenanceKind.genet;

    Map<String, dynamic>? provenanceData;

    // Build provenance data based on provenance type and life stage
    if (lifeStageValue == LifeStage.gamete) {
      // Gamete provenance
      final fields = <String, dynamic>{};
      if (gameteSex.value != null) {
        fields['gamete_sex'] = gameteSex.value == GameteSex.eggs
            ? 'eggs'
            : 'sperm';
      }
      final spawn = gameteSpawnDate.value;
      if (spawn != null) {
        final m = spawn.month.toString().padLeft(2, '0');
        final d = spawn.day.toString().padLeft(2, '0');
        fields['spawn_date'] = '${spawn.year}-$m-$d';
      }
      if (fields.isNotEmpty) provenanceData = fields;
    } else {
      // Founder-like provenance (wild, transfer, unknown)
      final fields = <String, dynamic>{};
      final origin = provOrigin.value.trim();
      final location = provLocation.value.trim();
      final collector = provCollector.value.trim();
      final depth = provDepth.value.trim();
      final habitat = provHabitatType.value.trim();
      final institution = provInstitution.value.trim();
      final lat = provLatitude.value.trim();
      final lng = provLongitude.value.trim();
      final date = provCollectionDate.value;

      fields['reef_of_origin'] = origin.isEmpty ? 'unknown' : origin;
      fields['location'] = location.isEmpty ? 'unknown' : location;
      fields['collector'] = collector.isEmpty ? 'unknown' : collector;
      if (depth.isNotEmpty) fields['depth'] = depth;
      if (habitat.isNotEmpty) fields['habitat_type'] = habitat;
      if (institution.isNotEmpty) {
        fields['collecting_institution'] = institution;
      }
      if (lat.isNotEmpty) fields['latitude'] = lat;
      if (lng.isNotEmpty) fields['longitude'] = lng;
      if (date != null) {
        final m = date.month.toString().padLeft(2, '0');
        final d = date.day.toString().padLeft(2, '0');
        fields['collection_date'] = '${date.year}-$m-$d';
      }
      // Include transfer provenance when applicable
      if (sendTransfer) {
        final dt = transferDate.value;
        final dateStr = dt == null
            ? null
            : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        fields['sending_organization'] = transferOrgId.isEmpty
            ? 'unknown'
            : transferOrgId;
        if (dateStr != null) fields['transfer_date'] = dateStr;
        final notesVal = transferNotes.value.trim();
        if (notesVal.isNotEmpty) fields['transfer_notes'] = notesVal;
      }
      provenanceData = fields;
    }

    final notesValue = notes.value.trim();
    final ownerId = ownerOrganizationId.trim();
    final managingId = managingOrganizationId.trim();
    final metadata = <String, dynamic>{
      'provenanceTypeId': provenanceTypeValue.id,
      'lifeStageId': lifeStageValue.id,
    };
    if (ownerId.isNotEmpty) {
      metadata['ownerOrganizationId'] = ownerId;
    }
    if (managingId.isNotEmpty) {
      metadata['managingOrganizationId'] = managingId;
    }
    return Genet.partial(
      name: name.value,
      speciesId: species.value!.id,
      provenanceTypeId: provenanceTypeValue.id,
      overrideProvenanceKind: provenanceKind,
      slug: slugOverride ?? slug,
      clonalId: clonalId.value?.trim().isNotEmpty == true
          ? clonalId.value!.trim()
          : null,
      accessionNumber: accessionNumber.value?.trim().isNotEmpty == true
          ? accessionNumber.value!.trim()
          : null,
      notes: notesValue.isEmpty ? null : notesValue,
      provenance: provenanceData,
      readyForOutplant:
          false, // Ready for outplant applies to coral clusters, not genets
      aliases: normalizedAliases.isEmpty
          ? null
          : normalizedAliases
                .map((alias) => alias.toJson())
                .toList(growable: false),
      heatTested: isFormValid ? heatTested : false,
      diseaseTested: isFormValid ? diseaseTested : false,
      heatTestingComment: isFormValid && heatTestingComment.trim().isNotEmpty
          ? heatTestingComment.trim()
          : null,
      diseaseTestingComment:
          isFormValid && diseaseTestingComment.trim().isNotEmpty
          ? diseaseTestingComment.trim()
          : null,
      metadata: metadata.isEmpty ? null : metadata,
    );
  }

  Genet applyEdits(Genet original) {
    final payload = toIncompleteGenet(slugOverride: original.slug);
    return original.copyWith(
      name: payload.name,
      speciesId: payload.speciesId,
      provenanceTypeId: payload.provenanceTypeId,
      clonalId: payload.clonalId,
      accessionNumber: payload.accessionNumber,
      notes: payload.notes,
      provenance: payload.provenance,
      aliases: payload.aliases,
      heatTested: payload.heatTested,
      diseaseTested: payload.diseaseTested,
      heatTestingComment: payload.heatTestingComment,
      diseaseTestingComment: payload.diseaseTestingComment,
      metadata: payload.metadata,
    );
  }
}

List<ProvenanceType> deriveAllowedProvenanceTypes() {
  return const [
    ProvenanceType.wild,
    ProvenanceType.transfer,
    ProvenanceType.unknown,
  ];
}
