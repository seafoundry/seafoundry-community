// @tier: community
import 'package:seafoundry_app/models/types/record_type.dart';

/// Builtin attachment methods that define how organisms are attached during outplanting.
///
/// These methods serve as the base set of attachment options.
class AttachmentMethod extends BuiltinRecordType {
  final String? description;

  const AttachmentMethod({
    required super.id,
    required super.name,
    this.description,
  });

  // ==========================================================================
  // BUILTIN ATTACHMENT METHODS
  // ==========================================================================

  static const AttachmentMethod nail = AttachmentMethod(
    id: 'attachment_method_nail',
    name: 'Nail',
    description: 'Metal nail or spike attachment',
  );

  static const AttachmentMethod cement = AttachmentMethod(
    id: 'attachment_method_cement',
    name: 'Cement',
    description: 'Marine cement or epoxy putty',
  );

  static const AttachmentMethod epoxy = AttachmentMethod(
    id: 'attachment_method_epoxy',
    name: 'Epoxy',
    description: 'Two-part epoxy adhesive',
  );

  static const AttachmentMethod substrate = AttachmentMethod(
    id: 'attachment_method_substrate',
    name: 'Substrate',
    description: 'Natural substrate placement',
  );

  /// Ordered list of builtin attachment methods
  static const List<AttachmentMethod> values = [
    nail,
    cement,
    epoxy,
    substrate,
  ];

  /// Map of ID to AttachmentMethod for quick lookup
  static final Map<String, AttachmentMethod> builtins = {
    for (final method in values) method.id: method,
  };

  /// Get AttachmentMethod by ID, returns null if not found.
  ///
  /// Use this when the attachment method is optional or when you need to handle
  /// missing/invalid IDs gracefully.
  static AttachmentMethod? maybeFromId(String? id) {
    if (id == null) return null;
    return builtins[id];
  }

  /// Get AttachmentMethod by ID, returns [cement] as default if not found.
  ///
  /// Use this when a fallback is acceptable. For nullable semantics,
  /// use [maybeFromId] instead.
  static AttachmentMethod fromId(String? id) {
    return maybeFromId(id) ?? cement;
  }
}
