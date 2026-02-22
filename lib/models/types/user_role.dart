// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// User roles within an organization, determining permissions and capabilities
class UserRole extends Equatable {
  final String id;
  final String label;
  final String description;
  final int level;
  final Color color;
  final int monthlyPriceUsd;
  final String stripePaymentLink;

  // Whether this role can perform basic observations
  final bool canObserve;

  // Whether this role can perform basic husbandry tasks
  final bool canPerformBasicTasks;

  // Whether this role can perform advanced husbandry tasks
  final bool canPerformAdvancedTasks;

  // Whether this role can manage users (add, promote)
  final bool canManageUsers;

  // Whether this role can create and edit training modules
  final bool canManageTraining;

  // Whether this role can approve task completion
  final bool canApproveCompletion;

  // Whether this role can assign tasks to others
  final bool canAssignTasks;

  const UserRole._({
    required this.id,
    required this.label,
    required this.description,
    required this.level,
    required this.color,
    required this.monthlyPriceUsd,
    required this.stripePaymentLink,
    required this.canObserve,
    required this.canPerformBasicTasks,
    required this.canPerformAdvancedTasks,
    required this.canManageUsers,
    required this.canManageTraining,
    required this.canApproveCompletion,
    required this.canAssignTasks,
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

  static const String _stripeViewOnly =
      'https://buy.stripe.com/REPLACE_ME_VIEW_ONLY';
  static const String _stripePractitioner =
      'https://buy.stripe.com/REPLACE_ME_PRACTITIONER';
  static const String _stripePractitionerPlus =
      'https://buy.stripe.com/REPLACE_ME_PRACTITIONER_PLUS';
  static const String _stripeAdmin =
      'https://buy.stripe.com/REPLACE_ME_ADMIN';

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

  String get priceLabel => '\$$monthlyPriceUsd/mo';

  /// View Only - Read-only role with public metrics access
  static const UserRole viewOnly = UserRole._(
    id: 'view_only',
    label: 'View Only',
    description: 'Read-only access to shared metrics and public content',
    level: 1,
    color: Colors.grey,
    monthlyPriceUsd: 9,
    stripePaymentLink: _stripeViewOnly,
    canObserve: false,
    canPerformBasicTasks: false,
    canPerformAdvancedTasks: false,
    canManageUsers: false,
    canManageTraining: false,
    canApproveCompletion: false,
    canAssignTasks: false,
  );

  /// Practitioner - Core workflow access with limited inventory actions
  static const UserRole practitioner = UserRole._(
    id: 'practitioner',
    label: 'Practitioner',
    description: 'Core workflow access with limited inventory actions',
    level: 2,
    color: Colors.teal,
    monthlyPriceUsd: 11,
    stripePaymentLink: _stripePractitioner,
    canObserve: true,
    canPerformBasicTasks: true,
    canPerformAdvancedTasks: false,
    canManageUsers: false,
    canManageTraining: false,
    canApproveCompletion: false,
    canAssignTasks: false,
  );

  /// Practitioner+ - Full data interaction + training/task management
  static const UserRole practitionerPlus = UserRole._(
    id: 'practitioner_plus',
    label: 'Practitioner+',
    description: 'Full data access plus training and task management',
    level: 3,
    color: Colors.blue,
    monthlyPriceUsd: 15,
    stripePaymentLink: _stripePractitionerPlus,
    canObserve: true,
    canPerformBasicTasks: true,
    canPerformAdvancedTasks: true,
    canManageUsers: false,
    canManageTraining: true,
    canApproveCompletion: true,
    canAssignTasks: true,
  );

  /// Admin - Practitioner+ with member and site management
  static const UserRole admin = UserRole._(
    id: 'admin',
    label: 'Admin',
    description: 'Practitioner+ access with member and site management',
    level: 4,
    color: Colors.red,
    monthlyPriceUsd: 15,
    stripePaymentLink: _stripeAdmin,
    canObserve: true,
    canPerformBasicTasks: true,
    canPerformAdvancedTasks: true,
    canManageUsers: true,
    canManageTraining: true,
    canApproveCompletion: true,
    canAssignTasks: true,
  );

  // Aliases for compatibility
  static const UserRole novice = viewOnly;
  static const UserRole user = practitioner;
  static const UserRole advancedUser = practitionerPlus;
  static const UserRole owner = admin;
  static const UserRole viewer = viewOnly;
  static const UserRole manager = practitionerPlus;

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

  /// Check if this role can be promoted to the target role
  bool canPromoteTo(UserRole targetRole) {
    return targetRole.level > level;
  }

  /// Get the next role in the progression
  UserRole? getNextRole() {
    final nextLevel = level + 1;
    try {
      return values.firstWhere((role) => role.level == nextLevel);
    } catch (_) {
      return null; // No next role (already at highest)
    }
  }

  /// Get promotion requirements for the next role
  Map<String, dynamic> getPromotionRequirements() {
    switch (id) {
      case 'view_only':
        return {
          'trainingRequired': true,
          'trainingModules': ['all_basic_husbandry'],
          'eventsLogged': 20,
          'description': 'Complete all basic husbandry training and log 20 events',
        };
      case 'practitioner':
        return {
          'trainingRequired': true,
          'trainingModules': ['all_advanced_husbandry'],
          'outplantingEvents': 10,
          'monitoringEvents': 10,
          'eventsLogged': 800,
          'description':
              'Complete all advanced training, participate in 10 outplanting and 10 monitoring events, and log 800 total events',
        };
      case 'practitioner_plus':
        return {'description': 'Already at Practitioner+ level'};
      case 'admin':
        return {'description': 'Already at Admin level'};
      default:
        return {'description': 'Unknown role'};
    }
  }

  @override
  List<Object?> get props => [id];
}
