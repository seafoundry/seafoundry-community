// @tier: community
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Common interface for YAML config entry types.
///
/// Provides a unified contract for entries that belong to an organism kind,
/// enabling shared widgets to work with any config entry type.
abstract interface class OrganismKindEntry {
  /// Unique identifier for this entry.
  String get id;

  /// The organism kind this entry belongs to.
  OrganismKind get organismKind;

  /// Human-readable display name for this entry.
  ///
  /// Used in delete confirmation dialogs and other UI that needs
  /// to identify the entry to the user.
  String get displayName;
}
