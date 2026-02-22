// @tier: community
import 'package:seafoundry_app/models/user.dart';

/// Service to manage first-time login tour state and determine if tour should be shown
///
/// IMPORTANT: tourVersion must be kept in sync with scripts/constants.js:TOUR_VERSION
/// Files that reference this constant:
/// - scripts/constants.js (TOUR_VERSION) - JavaScript source of truth for seed scripts
/// - scripts/seed-demo.js (imports from constants.js)
/// - scripts/fix-demo-user-docs.js (imports from constants.js)
/// - scripts/fix-demo-users-uid.js (imports from constants.js)
class TourService {
  /// Tour version identifier - update this when tour content changes
  /// @sync scripts/constants.js:TOUR_VERSION
  static const String tourVersion = '1.0.1';

  /// Determines if the tour should be shown for a user
  ///
  /// Tour should be shown if:
  /// - User has not completed the tour OR tour version has changed
  /// - Organization exists (not during initial setup)
  static bool shouldShowTour(User user, {required bool organizationExists}) {
    // Only show tour if organization is set up
    if (!organizationExists) {
      return false;
    }

    // Admin users do not receive the tour flow.
    if (user.isAdmin) {
      return false;
    }

    // Check if user has completed tour (stored in user metadata)
    final hasCompletedTour = user.metadata?['hasCompletedTour'] == true;
    if (!hasCompletedTour) {
      return true;
    }

    // Check if tour version has changed since last completion
    final completedVersion = user.metadata?['tourVersion'] as String?;
    if (completedVersion == null || completedVersion != tourVersion) {
      // Tour version changed or missing - show tour again
      return true;
    }

    return false;
  }

  /// Gets the tour path based on user role
  /// Different roles see different tour steps
  static TourPath getTourPath(User user) {
    // For now, all users get the standard tour
    // Future: role-specific tours (field tech, researcher, manager)
    return TourPath.standard;
  }

  /// Creates tour completion metadata to store in user document
  static Map<String, dynamic> createTourCompletionMetadata() {
    return {
      'hasCompletedTour': true,
      'tourCompletedAt': DateTime.now().toIso8601String(),
      'tourVersion': tourVersion,
    };
  }
}

/// Tour path types for different user roles
enum TourPath {
  standard,      // Default tour for all users
  fieldTech,     // Field operations focused
  researcher,    // Data analysis focused
  manager,       // Oversight and reporting focused
}
