import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// User roles within an organization, determining permissions and capabilities
class UserRole extends Equatable {
  final String id;
  final String label;
  final String description;
  final int level;
  final Color color;

  const UserRole._({
    required this.id,
    required this.label,
    required this.description,
    required this.level,
    required this.color,
  });

  /// Create a UserRole from an ID
  static UserRole? fromId(String? id) {
    if (id == null) return null;
    final normalized = id.trim().toLowerCase();
    final mappedId = _legacyRoleMap[normalized] ?? normalized;
    return values.firstWhere(
      (role) => role.id == mappedId,
      orElse: () => UserRole.practitioner,
    );
  }

  static const Map<String, String> _legacyRoleMap = {
    'novice': 'view_only',
    'viewer': 'view_only',
    'view-only': 'view_only',
    'view_only': 'view_only',
    'member': 'practitioner',
    'user': 'practitioner',
    'practitioner': 'practitioner',
    'advanced_user': 'practitioner_plus',
    'manager': 'practitioner_plus',
    'practitioner_plus': 'practitioner_plus',
    'owner': 'admin',
    'admin': 'admin',
    'editor': 'practitioner_plus',
  };

  /// View Only - Read-only role with public metrics access
  static const UserRole viewOnly = UserRole._(
    id: 'view_only',
    label: 'View Only',
    description: 'Read-only access to shared metrics and public content',
    level: 1,
    color: Colors.grey,
  );

  /// Practitioner - Core workflow access with limited inventory actions
  static const UserRole practitioner = UserRole._(
    id: 'practitioner',
    label: 'Practitioner',
    description: 'Core workflow access with limited inventory actions',
    level: 2,
    color: Colors.teal,
  );

  /// Practitioner+ - Full data interaction + advanced workflows
  static const UserRole practitionerPlus = UserRole._(
    id: 'practitioner_plus',
    label: 'Practitioner+',
    description: 'Full data access and advanced workflows',
    level: 3,
    color: Colors.blue,
  );

  /// Admin - Practitioner+ with member and site management
  static const UserRole admin = UserRole._(
    id: 'admin',
    label: 'Admin',
    description: 'Practitioner+ access with member and site management',
    level: 4,
    color: Colors.red,
  );

  /// List of all user roles
  static const List<UserRole> values = [
    viewOnly,
    practitioner,
    practitionerPlus,
    admin,
  ];

  /// Check if this role is at least the specified level
  bool isAtLeast(UserRole role) {
    return level >= role.level;
  }

  @override
  List<Object?> get props => [id];
}
