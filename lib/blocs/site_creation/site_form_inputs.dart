// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

class SiteTypeSelection
    extends RecordFormInput<SiteType?, RequiredInputError, SiteTypeSelected> {
  const SiteTypeSelection.pure() : super.pure();
  const SiteTypeSelection.dirty([super.value]) : super.dirty();

  @override
  String get label => 'Site Type';

  @override
  String get hintText => 'Select the type of site';

  @override
  SiteTypeSelection copyWith({required SiteType? value}) {
    if (value == this.value) return this;
    if (value == null) return SiteTypeSelection.pure();
    return SiteTypeSelection.dirty(value);
  }
}

class SiteDescription
    extends
        RecordFormInput<String, RecordFormInputError, SiteDescriptionChanged> {
  const SiteDescription.pure() : super.pure();
  const SiteDescription.dirty(super.value) : super.dirty();

  @override
  String get label => 'Description';

  @override
  String get hintText => 'Describe the site (optional)';

  @override
  RecordFormInputError? validator(String? value) {
    if (value != null && value.length > 500) {
      return const RecordFormInputError(
        'Description must be less than 500 characters',
      );
    }
    return null;
  }

  @override
  SiteDescription copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return SiteDescription.pure();
    return SiteDescription.dirty(value);
  }
}

class SiteLatitude
    extends RecordFormInput<String, RecordFormInputError, SiteLatitudeChanged> {
  const SiteLatitude.pure() : super.pure();
  const SiteLatitude.dirty(super.value) : super.dirty();

  @override
  String get label => 'Latitude';

  @override
  String get hintText => 'e.g., 25.761681';

  @override
  RecordFormInputError? validator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return const RecordFormInputError('Invalid latitude');
    }
    if (parsed < -90 || parsed > 90) {
      return const RecordFormInputError('Latitude must be between -90 and 90');
    }
    final decimalIndex = trimmed.indexOf('.');
    if (decimalIndex < 0 || trimmed.substring(decimalIndex + 1).length < 4) {
      return const RecordFormInputError('Use at least four decimal places');
    }
    return null;
  }

  @override
  SiteLatitude copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return SiteLatitude.pure();
    return SiteLatitude.dirty(value);
  }
}

class SiteLongitude
    extends
        RecordFormInput<String, RecordFormInputError, SiteLongitudeChanged> {
  const SiteLongitude.pure() : super.pure();
  const SiteLongitude.dirty(super.value) : super.dirty();

  @override
  String get label => 'Longitude';

  @override
  String get hintText => 'e.g., -80.191788';

  @override
  RecordFormInputError? validator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return const RecordFormInputError('Invalid longitude');
    }
    if (parsed < -180 || parsed > 180) {
      return const RecordFormInputError(
        'Longitude must be between -180 and 180',
      );
    }
    final decimalIndex = trimmed.indexOf('.');
    if (decimalIndex < 0 || trimmed.substring(decimalIndex + 1).length < 4) {
      return const RecordFormInputError('Use at least four decimal places');
    }
    return null;
  }

  @override
  SiteLongitude copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null) return SiteLongitude.pure();
    return SiteLongitude.dirty(value);
  }
}

class GroupTypesSelection
    extends
        RecordFormInput<
          List<GroupType>,
          RecordFormInputError,
          GroupTypesSelected
        > {
  const GroupTypesSelection.pure() : super.pure();
  const GroupTypesSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Group Types';

  @override
  String get hintText => 'Select the types of groups this site can contain';

  @override
  GroupTypesSelection copyWith({required List<GroupType>? value}) {
    if (value == this.value) return this;
    if (value == null) return GroupTypesSelection.pure();
    return GroupTypesSelection.dirty(value);
  }
}

class SiteGeometryManual
    extends
        RecordFormInput<
          String,
          RecordFormInputError,
          SiteGeometryManualChanged
        > {
  const SiteGeometryManual.pure() : super.pure();
  const SiteGeometryManual.dirty(super.value) : super.dirty();

  @override
  String get label => 'Manual Coordinates';

  @override
  String get hintText => 'One coordinate per line (lat,lng)';

  @override
  RecordFormInputError? validator(String? value) {
    return null;
  }

  @override
  SiteGeometryManual copyWith({required String? value}) {
    if (value == null) return const SiteGeometryManual.pure();
    if (value == this.value) return this;
    return SiteGeometryManual.dirty(value);
  }
}

class SiteSupportedOrganismsSelection
    extends
        RecordFormInput<
          List<OrganismKind>,
          RecordFormInputError,
          SiteSupportedOrganismsChanged
        > {
  const SiteSupportedOrganismsSelection.pure() : super.pure();
  const SiteSupportedOrganismsSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Supported Organisms';

  @override
  String get hintText => 'Select at least one organism this site supports';

  @override
  RecordFormInputError? validator(List<OrganismKind>? value) {
    if (value == null || value.isEmpty) {
      return const RecordFormInputError(
        'Select at least one supported organism',
      );
    }
    return null;
  }

  @override
  SiteSupportedOrganismsSelection copyWith({
    required List<OrganismKind>? value,
  }) {
    if (value == null || value.isEmpty) {
      return const SiteSupportedOrganismsSelection.pure();
    }
    if (value == this.value) return this;
    return SiteSupportedOrganismsSelection.dirty(value);
  }
}
