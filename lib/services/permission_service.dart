// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/types/user_role.dart';

/// Service for checking user permissions
class PermissionService {
  /// Check if a user has the admin role
  static bool isAdmin(User user) {
    final role = UserRole.fromId(user.role);
    return role == UserRole.admin;
  }

  /// Check if a user has the canManageUsers capability (admin role)
  static bool canManageUsers(User user) {
    final role = UserRole.fromId(user.role);
    return role?.canManageUsers ?? false;
  }

  /// Check if a user can edit/delete a record
  /// Users can edit/delete if they are:
  /// - Have canManageUsers capability
  /// - The creator of the record
  static bool canEditRecord(User currentUser, GraphNodeRecord record) {
    // Users with canManageUsers can edit anything
    if (canManageUsers(currentUser)) {
      return true;
    }

    // Check if user is the creator of the record
    return record.createdById == currentUser.id;
  }

  /// Check if a user can delete a record
  /// Same as canEditRecord for now, but separated for future flexibility
  static bool canDeleteRecord(User currentUser, GraphNodeRecord record) {
    return canEditRecord(currentUser, record);
  }

  /// Check if a user has a specific role
  static bool hasRole(User user, String roleId) {
    final userRole = UserRole.fromId(user.role);
    final requiredRole = UserRole.fromId(roleId);
    if (userRole == null || requiredRole == null) return false;
    return userRole == requiredRole;
  }

  /// Check if a user is an owner
  static bool isOwner(User user) {
    final role = UserRole.fromId(user.role);
    return role == UserRole.admin;
  }

  /// Check if a user is an advanced user
  static bool isAdvancedUser(User user) {
    final role = UserRole.fromId(user.role);
    return role == UserRole.practitionerPlus || role == UserRole.admin;
  }

  /// Check if a user is at least a specific role level
  /// Role hierarchy: view_only < practitioner < practitioner_plus < admin
  static bool isAtLeast(User user, String minRoleId) {
    final userRole = UserRole.fromId(user.role) ?? UserRole.viewOnly;
    final requiredRole = UserRole.fromId(minRoleId) ?? UserRole.viewOnly;
    return userRole.isAtLeast(requiredRole);
  }
}
