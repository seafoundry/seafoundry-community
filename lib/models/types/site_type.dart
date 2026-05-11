// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

class SiteType extends BuiltinRecordType {
  const SiteType({
    required super.id,
    required super.name,
    required this.description,
    required this.groupTypes,
  });

  final String description;
  final List<GroupType> groupTypes;

  static final Map<String, SiteType> builtins = {
    nursery.id: nursery,
    outplanting.id: outplanting,
  };

  static const SiteType nursery = SiteType(
    id: 'site_type_nursery',
    name: 'Nursery',
    description: 'Facility for rearing corals — land-based (tanks, raceways) or ocean-based (trees, tables).',
    groupTypes: [
      GroupType.tank,
      GroupType.raceway,
      GroupType.tree,
      GroupType.dome,
      GroupType.reebarTable,
      GroupType.cradle,
      GroupType.aframe,
      GroupType.group,
      GroupType.patch,
    ],
  );

  static const SiteType outplanting = SiteType(
    id: 'site_type_outplanting',
    name: 'Outplanting',
    description: 'Reef restoration site where corals are permanently placed.',
    groupTypes: [
      GroupType.group,
      GroupType.patch,
    ],
  );

  /// Backward-compatibility aliases for consolidated site types.
  ///
  /// Old Firestore data may contain `site_type_nursery_ex_situ` or
  /// `site_type_nursery_in_situ` which were consolidated into the single
  /// `site_type_nursery` type.
  static const Map<String, SiteType> _legacyAliases = {
    'site_type_nursery_ex_situ': nursery,
    'site_type_nursery_in_situ': nursery,
    // Also handle bare IDs without the site_type_ prefix
    'nursery_ex_situ': nursery,
    'nursery_in_situ': nursery,
  };

  /// Get SiteType by ID, returns null if not found.
  static SiteType? maybeFromId(String? id) {
    if (id == null) return null;
    return builtins[id] ?? _legacyAliases[id];
  }

  /// Get SiteType by ID, returns [nursery] as default if not found.
  static SiteType fromId(String? id) {
    return maybeFromId(id) ?? nursery;
  }

  /// Whether this is an outplanting site type.
  bool get isOutplanting => this == outplanting;
}
