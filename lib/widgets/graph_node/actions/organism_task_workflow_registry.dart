// @tier: community
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Tracks which organisms support fully-fledged task workflows.
///
/// Most organisms still rely on the coral dialog stack. While their bespoke
/// flows are under construction, the action dock can consult this registry to
/// decide whether to display the TaskManagement UI or the shared placeholder.
class OrganismTaskWorkflowRegistry {
  static final Set<OrganismKind> _defaultSupported =
      Set<OrganismKind>.from(OrganismKind.values);

  static Set<OrganismKind>? _overrideSupported;

  /// Returns true when the active organism has task workflows implemented.
  static bool supports(OrganismKind kind) {
    final overrides = _overrideSupported;
    if (overrides != null) {
      return overrides.contains(kind);
    }
    return _defaultSupported.contains(kind);
  }

  @visibleForTesting
  static void debugOverrideSupported(Set<OrganismKind> kinds) {
    _overrideSupported = Set<OrganismKind>.from(kinds);
  }

  @visibleForTesting
  static void resetDebugOverrides() {
    _overrideSupported = null;
  }
}
