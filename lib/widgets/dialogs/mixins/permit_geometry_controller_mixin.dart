// @tier: community
import 'package:flutter/material.dart';

/// Mixin that provides common TextEditingController lifecycle management for
/// dialogs that handle permit metadata and geometry fields.
///
/// This mixin extracts the repeated pattern of:
/// - Declaring permit-related and geometry controllers
/// - Initializing controllers
/// - Adding listeners for form validation or state sync
/// - Properly disposing controllers
///
/// **Usage**: Mix into a State class that extends State of a StatefulWidget.
///
/// **Example**:
/// ```dart
/// class _MyDialogState extends State<MyDialog>
///     with PermitGeometryControllerMixin {
///   @override
///   void initState() {
///     super.initState();
///     initControllers();
///     addControllerListeners(() {
///       // Validate form or sync with cubit
///     });
///   }
///
///   @override
///   void dispose() {
///     disposeControllers();
///     super.dispose();
///   }
/// }
/// ```
mixin PermitGeometryControllerMixin<T extends StatefulWidget> on State<T> {
  /// Controller for permit ID field
  late final TextEditingController permitIdController;

  /// Controller for permit type field
  late final TextEditingController permitTypeController;

  /// Controller for issuing authority field
  late final TextEditingController issuingAuthorityController;

  /// Controller for permit attachment URLs field
  late final TextEditingController permitAttachmentsController;

  /// Controller for geometry field (coordinates, KML, etc.)
  late final TextEditingController geometryController;

  /// Flag to track whether controllers are being programmatically updated
  /// to prevent listener loops
  bool isUpdatingControllers = false;

  /// Initialize all controllers with optional initial values.
  ///
  /// Call this in initState() before adding listeners.
  void initControllers({
    String permitId = '',
    String permitType = '',
    String issuingAuthority = '',
    String permitAttachments = '',
    String geometry = '',
  }) {
    permitIdController = TextEditingController(text: permitId);
    permitTypeController = TextEditingController(text: permitType);
    issuingAuthorityController = TextEditingController(text: issuingAuthority);
    permitAttachmentsController = TextEditingController(text: permitAttachments);
    geometryController = TextEditingController(text: geometry);
  }

  /// Add listeners to all controllers that call [onChanged] when any controller
  /// value changes.
  ///
  /// Typically [onChanged] would validate the form or sync state with a cubit.
  /// Call this in initState() after calling initControllers().
  void addControllerListeners(VoidCallback onChanged) {
    permitIdController.addListener(onChanged);
    permitTypeController.addListener(onChanged);
    issuingAuthorityController.addListener(onChanged);
    permitAttachmentsController.addListener(onChanged);
    geometryController.addListener(onChanged);
  }

  /// Remove all listeners and dispose all controllers.
  ///
  /// Call this in dispose() before calling super.dispose().
  void disposeControllers() {
    permitIdController.dispose();
    permitTypeController.dispose();
    issuingAuthorityController.dispose();
    permitAttachmentsController.dispose();
    geometryController.dispose();
  }

  /// Programmatically sync a controller's value without triggering listeners.
  ///
  /// Sets [isUpdatingControllers] to true during the update to prevent
  /// listener callbacks from firing.
  void syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;

    isUpdatingControllers = true;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    isUpdatingControllers = false;
  }

  /// Sync all permit and geometry controllers with provided values.
  ///
  /// Useful when reacting to cubit/bloc state changes in a BlocBuilder/BlocListener.
  void syncAllControllers({
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachments,
    String? geometry,
  }) {
    if (permitId != null) syncController(permitIdController, permitId);
    if (permitType != null) syncController(permitTypeController, permitType);
    if (issuingAuthority != null) {
      syncController(issuingAuthorityController, issuingAuthority);
    }
    if (permitAttachments != null) {
      syncController(permitAttachmentsController, permitAttachments);
    }
    if (geometry != null) syncController(geometryController, geometry);
  }
}
