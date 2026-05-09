// @tier: community
import 'package:formz/formz.dart';

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
