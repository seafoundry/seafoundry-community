// @tier: community
import 'package:formz/formz.dart';
import 'package:seafoundry_app/models/site_activity_type.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

enum UserNameError {
  tooShort(message: 'Name must be at least 2 characters'),
  tooLong(message: 'Name must be less than 20 characters');

  final String message;
  const UserNameError({required this.message});
}

class UserName extends FormzInput<String, UserNameError> {
  const UserName.pure() : super.pure('');
  const UserName.dirty({required String value}) : super.dirty(value);

  @override
  UserNameError? validator(String value) {
    final String trimmedValue = value.trim();
    if (trimmedValue.length < 2) return UserNameError.tooShort;
    if (trimmedValue.length > 20) return UserNameError.tooLong;
    return null;
  }
}

enum OrganizationNameError {
  tooShort(message: 'Name must be at least 4 characters'),
  tooLong(message: 'Name must be less than 20 characters'),
  alreadyExists(message: 'Name already exists');

  final String message;
  const OrganizationNameError({required this.message});
}

class OrganizationName extends FormzInput<String, OrganizationNameError> {
  const OrganizationName.pure({required this.isNameAvailable}) : super.pure('');
  const OrganizationName.dirty({required this.isNameAvailable, required String value}) : super.dirty(value);
  final bool Function(String) isNameAvailable;

  @override
  OrganizationNameError? validator(String value) {
    final String trimmedValue = value.trim();
    if (trimmedValue.length < 4) return OrganizationNameError.tooShort;
    if (trimmedValue.length > 20) return OrganizationNameError.tooLong;
    if (!isNameAvailable(value)) return OrganizationNameError.alreadyExists;
    return null;
  }
}

enum OrganismSelectionsError {
  noOrganisms(message: 'Please select at least one organism type'),
  multipleOrganismsRequiresPro(message: 'Multiple organism types require a Pro subscription. Please select only one.');

  final String message;
  const OrganismSelectionsError({required this.message});
}

class OrganismSelections extends FormzInput<List<OrganismKind>, OrganismSelectionsError> {
  const OrganismSelections.pure() : super.pure(const []);
  const OrganismSelections.dirty({required List<OrganismKind> value}) : super.dirty(value);

  @override
  OrganismSelectionsError? validator(List<OrganismKind> value) {
    if (value.isEmpty) return OrganismSelectionsError.noOrganisms;
    // Community tier restriction: only one organism kind allowed
    if (value.length > 1) return OrganismSelectionsError.multipleOrganismsRequiresPro;
    return null;
  }
}

enum OrganizationActivitiesError {
  noActivities(message: 'Please select at least one activity');

  final String message;
  const OrganizationActivitiesError({required this.message});
}

class OrganizationActivitySelections extends FormzInput<List<SiteActivityType>, OrganizationActivitiesError> {
  const OrganizationActivitySelections.pure() : super.pure(const []);
  const OrganizationActivitySelections.dirty({required List<SiteActivityType> value}) : super.dirty(value);

  List<String> get activityIds => value.map((e) => e.id).toList();

  @override
  OrganizationActivitiesError? validator(List<SiteActivityType> value) {
    if (value.isEmpty) return OrganizationActivitiesError.noActivities;
    return null;
  }
}

enum OrganizationSpeciesError {
  noSpecies(message: 'Please select at least one species');

  final String message;
  const OrganizationSpeciesError({required this.message});
}

class OrganizationSpeciesSelections extends FormzInput<List<Species>, OrganizationSpeciesError> {
  const OrganizationSpeciesSelections.pure() : super.pure(const []);
  const OrganizationSpeciesSelections.dirty({required List<Species> value}) : super.dirty(value);

  List<String> get speciesIds => value.map((e) => e.id).toList();

  @override
  OrganizationSpeciesError? validator(List<Species> value) {
    if (value.isEmpty) return OrganizationSpeciesError.noSpecies;
    return null;
  }
}

enum OrganizationDomainError {
  tooShort(message: 'Domain must be 2-4 characters'),
  tooLong(message: 'Domain can\'t be more than 4 characters'),
  alreadyExists(message: 'Domain already exists');

  final String message;
  const OrganizationDomainError({required this.message});
}

class OrganizationDomain extends FormzInput<String, OrganizationDomainError> with FormzInputErrorCacheMixin {
  OrganizationDomain.pure({required this.isDomainAvailable}) : super.pure('');
  OrganizationDomain.dirty({required this.isDomainAvailable, required String value}) : super.dirty(value);
  final bool Function(String) isDomainAvailable;

  @override
  OrganizationDomainError? validator(String value) {
    if (value.length < 2) return OrganizationDomainError.tooShort;
    if (value.length > 4) return OrganizationDomainError.tooLong;
    if (!isDomainAvailable(value)) return OrganizationDomainError.alreadyExists;
    return null;
  }
}
