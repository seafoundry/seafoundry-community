// @tier: community
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for enforcing regulatory compliance by validating activities
/// against permit conditions such as authorized sites, activity types, 
/// and validity periods.
class PermitEnforcerService {
  /// Check if a specific activity is authorized by the given permit at a specific site.
  static bool isAuthorized({
    required Permit permit,
    required String activityId,
    required String siteId,
    DateTime? date,
  }) {
    final checkDate = date ?? DateTime.now();

    // 1. Time-window validation
    if (checkDate.isBefore(permit.validFrom) || 
        checkDate.isAfter(permit.validTo)) {
      LoggingService.instance.debug(
        'PermitEnforcerService: Permit ${permit.id} is not valid for date $checkDate. '
        'Valid from ${permit.validFrom} to ${permit.validTo}.'
      );
      return false;
    }

    // 2. Site-lock validation
    // If permit defines specific sites, the action must be performed at one of them.
    if (permit.siteIds.isNotEmpty && !permit.siteIds.contains(siteId)) {
      LoggingService.instance.debug(
        'PermitEnforcerService: Site $siteId is not authorized by permit ${permit.id}. '
        'Authorized sites: ${permit.siteIds}.'
      );
      return false;
    }

    // 3. Activity-lock validation
    // If permit defines specific authorized activities, the action must match one.
    if (permit.authorizedActivities.isNotEmpty && 
        !permit.authorizedActivities.contains(activityId)) {
      LoggingService.instance.debug(
        'PermitEnforcerService: Activity $activityId is not authorized by permit ${permit.id}. '
        'Authorized activities: ${permit.authorizedActivities}.'
      );
      return false;
    }

    return true;
  }

  /// Validates a list of sites against a permit.
  /// Returns a list of site IDs that are NOT authorized by the permit.
  static List<String> getUnauthorizedSites({
    required Permit permit,
    required List<String> siteIds,
  }) {
    if (permit.siteIds.isEmpty) return [];
    return siteIds.where((id) => !permit.siteIds.contains(id)).toList();
  }

  /// Validates an activity against a permit.
  /// Returns true if the activity is authorized.
  static bool isActivityAuthorized({
    required Permit permit,
    required String activityId,
  }) {
    if (permit.authorizedActivities.isEmpty) return true;
    return permit.authorizedActivities.contains(activityId);
  }
}

/// Standardized activity identifiers for permit enforcement.
class PermitActivities {
  static const String outplanting = 'outplanting';
  static const String monitoring = 'monitoring';
  static const String collection = 'collection';
  static const String research = 'research';
  static const String husbandry = 'husbandry';
  
  static const List<String> all = [
    outplanting,
    monitoring,
    collection,
    research,
    husbandry,
  ];
}
