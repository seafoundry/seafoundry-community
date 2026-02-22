// @tier: community
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/cubits/monitoring_dialog/monitoring_dialog_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/monitoring/image_attachment.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/monitoring_event_repository.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/image_workflow_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/common/upgrade_cta.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/wizards/organism_selection_wizard.dart';
import '../components/dialog_scroll_view.dart';

/// Dialog for uploading orthomosaics/time-series images from site graph nodes,
/// optionally tagging specific organisms/groups.
///
/// ### Architecture
/// - Mirrors the monitoring dialog attachment model but keeps the UI light for
///   FAB shortcuts (pick files → optional targeting → upload → event creation).
/// - Provider dependencies are read before async boundaries so tests can inject
///   stubs (e.g., `MonitoringEventRepository`) without touching inner contexts.
/// - Upload/event logic is split into helpers (`_uploadPendingImages`,
///   `_createMonitoringEvent`) to keep `_submit` readable and well documented.
/// - Navigator interactions are guarded by `mounted` checks and use captured
///   references to avoid setState-after-dispose warnings.
///
/// Providers required in scope:
/// - `EventRepository`
/// - `FirebaseService`
/// - `ImageService` (optional; falls back to a new instance if absent)
/// - `MonitoringEventRepository` (optional override for testing/offline flows)
class ImageObservationDialog extends StatefulWidget {
  const ImageObservationDialog({super.key, required this.node});

  final GraphNode node;

  /// Shows the dialog and returns the created [MonitoringEventRecord] on success.
  static Future<MonitoringEventRecord?> show(
    BuildContext context, {
    required GraphNode node,
  }) {
    final eventRepository = context.read<EventRepository>();
    return showDialog<MonitoringEventRecord>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => RepositoryProvider<EventRepository>.value(
        value: eventRepository,
        child: ImageObservationDialog(node: node),
      ),
    );
  }

  @override
  State<ImageObservationDialog> createState() => _ImageObservationDialogState();
}

class _ImageObservationDialogState extends State<ImageObservationDialog>
    with SafeDialogMixin<ImageObservationDialog> {
  final List<File> _pendingImageFiles = [];
  final Map<int, ImageAttachmentSelection> _pendingSelections = {};
  final _commentController = TextEditingController();
  bool _isUploading = false;
  String? _error;

  FeatureAccessService? _maybeFeatureAccess() {
    try {
      return context.read<FeatureAccessService>();
    } catch (_) {
      return null;
    }
  }

  bool _imageryEnabled() {
    final access = _maybeFeatureAccess();
    if (access == null) return true;
    return access.isFeatureEnabled('imagery_attachments');
  }

  OrganismKind _resolveOrganismKind(BuildContext context) {
    try {
      return context.read<OrganismContext>().kind;
    } catch (_) {
      return OrganismKind.coral;
    }
  }

  String _capitalizeLabel(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _organismCountLabel(int count) {
    final kind = _resolveOrganismKind(context);
    final label =
        count == 1
            ? kind.metadata.displayName.toLowerCase()
            : kind.metadata.pluralDisplayName;
    return '$count $label';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Launches the image picker and adds selected files to the pending list.
  ///
  /// Errors are surfaced through the lifecycle mixin's snackbar helper so
  /// messaging still works even if the dialog is hosted inside nested
  /// navigators without an ancestor `Scaffold`.
  Future<void> _pickImageFiles() async {
    if (!_imageryEnabled()) {
      if (!mounted) return;
      showDialogSnackBar(
        'Image uploads coming soon.',
        isError: true,
      );
      return;
    }

    try {
      final files = await ImageWorkflowService.pickImageFiles(context);
      if (files.isNotEmpty && mounted) {
        setState(() {
          _pendingImageFiles.addAll(files);
        });
      }
    } catch (e) {
      if (!mounted) return;
      showDialogSnackBar('Failed to pick images: $e', isError: true);
    }
  }

  /// Opens the organism selection wizard so users can target specific organisms,
  /// groups, or tags for a pending image attachment.
  ///
  /// **Workflow:**
  /// 1. Shows `OrganismSelectionWizard` in a dialog
  /// 2. User selects organisms/groups
  /// 3. Selection is stored in `_pendingSelections` map keyed by image index
  Future<void> _selectImageTargets(int index) async {
    List<OrganismRecord>? selectedOrganisms;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => _buildTargetSelectionDialog(
        dialogContext,
        (organisms) => selectedOrganisms = organisms,
      ),
    );

    final selections = selectedOrganisms;
    if (selections != null && selections.isNotEmpty && mounted) {
      setState(() {
        _pendingSelections[index] = ImageAttachmentSelection(
          coralIds: selections.map((o) => o.id).toList(),
        );
      });
    }
  }

  /// Builds the organism selection wizard dialog for targeting images.
  /// Renders the modal that reuses `OrganismSelectionWizard` for per-image tags.
  Widget _buildTargetSelectionDialog(
    BuildContext dialogContext,
    void Function(List<OrganismRecord>?) onSelectionChanged,
  ) {
    final organismKind = _resolveOrganismKind(dialogContext);
    final pluralLabel = _capitalizeLabel(
      organismKind.metadata.pluralDisplayName,
    );
    return Dialog(
      child: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select $pluralLabel/Groups for Image',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: OrganismSelectionWizard(
                config: const OrganismSelectionConfig(
                  mode: OrganismSelectionMode.multiple,
                  showFilters: true,
                ),
                onSelectionChanged: onSelectionChanged,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _pendingImageFiles.removeAt(index);
      _pendingSelections.remove(index);
      // Shift indices
      final shifted = <int, ImageAttachmentSelection>{};
      for (final entry in _pendingSelections.entries) {
        if (entry.key > index) {
          shifted[entry.key - 1] = entry.value;
        } else {
          shifted[entry.key] = entry.value;
        }
      }
      _pendingSelections.clear();
      _pendingSelections.addAll(shifted);
    });
  }

  /// Submits image uploads as a monitoring event.
  ///
  /// **Flow:**
  /// 1. Validates at least one image is selected
  /// 2. Ensures graph node is loaded before accessing record
  /// 3. Uploads all images to Firebase Storage (with progress tracking)
  /// 4. Creates `ImageAttachment` objects with organism/group/tag associations
  /// 5. Creates a `MonitoringEventRecord` with image attachments
  /// 6. Returns the created event to the caller via `Navigator.pop()`
  ///
  /// **Error Handling:**
  /// - Upload errors are caught and displayed in error banner
  /// - Uses `mounted` checks before state updates and navigation
  /// - Errors are logged via `LoggingService` for debugging
  /// - Includes timeout guard to prevent hanging tests
  Future<void> _submit() async {
    if (!_imageryEnabled()) {
      setState(() {
        _error = 'Image uploads coming soon.';
      });
      return;
    }

    if (_pendingImageFiles.isEmpty) {
      setState(() {
        _error = 'Please select at least one image';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    // Capture context-dependent services before async operations
    // This ensures services are available even if context becomes invalid during async work
    final eventRepository = context.read<EventRepository>();
    final navigator = dialogNavigator ?? Navigator.maybeOf(context);
    final storageKey =
        ImageService.resolveOrganizationStorageKeyFromOrganization(
          eventRepository.organization,
        );

    try {
      final attachments = await _uploadPendingImages(
        organizationId: storageKey,
        eventRepository: eventRepository,
      );

      if (attachments.isEmpty) {
        throw Exception('Failed to upload any images');
      }

      await widget.node.awaitLoaded();
      if (!mounted) {
        if (kDebugMode) {
          LoggingService.instance.debug(
            '[ImageObservationDialog._submit] Widget unmounted after awaitLoaded',
          );
        }
        return;
      }
      if (widget.node.state is! GraphLoadedState) {
        throw Exception('Node is not loaded');
      }

      final record = widget.node.state.record;
      final event = await _createMonitoringEvent(
        eventRepository: eventRepository,
        record: record,
        attachments: attachments,
      );

      // Ensure Navigator.pop is called - use captured navigator to avoid context access after pop
      // This prevents widget inspector errors during teardown
      if (!mounted) {
        if (kDebugMode) {
          LoggingService.instance.debug(
            '[ImageObservationDialog._submit] Widget unmounted, cannot pop',
          );
        }
        return;
      }

      // Capture everything we need before calling Navigator.pop
      // This ensures we don't access context/widget state after pop (which triggers disposal)
      final eventToReturn = event;
      final navigatorToUse =
          navigator ?? dialogNavigator ?? Navigator.maybeOf(context);

      if (navigatorToUse != null) {
        if (kDebugMode) {
          LoggingService.instance.debug(
            '[ImageObservationDialog._submit] Calling Navigator.pop with event',
          );
        }
        // Call Navigator.pop directly - this will trigger widget disposal
        // But we've captured everything we need, so no further context access is required
        navigatorToUse.pop(eventToReturn);
        if (kDebugMode) {
          LoggingService.instance.debug(
            '[ImageObservationDialog._submit] Navigator.pop completed',
          );
        }
        // Immediately return - don't access context or widget state after pop
        return;
      }

      if (kDebugMode) {
        LoggingService.instance.debug(
          '[ImageObservationDialog._submit] ERROR: No navigator available to pop dialog',
        );
      }
      // If we can't pop, the dialog will remain open - this is an error condition
      // But we don't want to throw here as it might cause widget inspector issues
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create image observation',
        e,
        stackTrace,
      );
      // Only update state if widget is still mounted and not disposing
      // Access context/widget state before any potential disposal
      if (mounted) {
        try {
          setState(() {
            _error = 'Failed to upload images: $e';
            _isUploading = false;
          });
        } catch (stateError) {
          // Widget might be disposing - just log, don't access context
          if (kDebugMode) {
            LoggingService.instance.debug(
              '[ImageObservationDialog._submit] Could not update state after error: $stateError',
            );
          }
        }
      }
    }
  }

  MonitoringEventRepository _resolveMonitoringRepository(
    EventRepository eventRepository,
  ) {
    final provided = context.maybeRead<MonitoringEventRepository>();
    final featureAccess = context.maybeRead<FeatureAccessService>();

    return provided ??
        MonitoringEventRepository(
          organization: eventRepository.organization,
          user: eventRepository.user,
          firestore: eventRepository.db,
          organismContext: eventRepository.organismContext,
          featureEnabled: featureAccess?.supportsMonitoringDialog ?? true,
        );
  }

  Future<List<ImageAttachment>> _uploadPendingImages({
    required String organizationId,
    required EventRepository eventRepository,
  }) async {
    final attachments = <ImageAttachment>[];
    final tempEventId = generateId(firestore: eventRepository.firestore);
    final imageService = ImageWorkflowService.resolveImageService(context);

    for (int i = 0; i < _pendingImageFiles.length; i++) {
      final file = _pendingImageFiles[i];
      final selection =
          _pendingSelections[i] ?? const ImageAttachmentSelection();
      final fileName = file.path.split('/').last;
      final isTiff =
          fileName.toLowerCase().endsWith('.tiff') ||
          fileName.toLowerCase().endsWith('.tif');

      final imageUrl = await ImageWorkflowService.uploadImageWithService(
        imageService: imageService,
        imageFile: file,
        organizationId: organizationId,
        recordType: 'event',
        recordId: tempEventId,
        timeout: const Duration(seconds: 10),
      );

      if (imageUrl == null) continue;
      attachments.add(
        await _buildAttachment(
          file: file,
          imageUrl: imageUrl,
          selection: selection,
          isTiff: isTiff,
        ),
      );
    }

    return attachments;
  }

  Future<ImageAttachment> _buildAttachment({
    required File file,
    required String imageUrl,
    required ImageAttachmentSelection selection,
    required bool isTiff,
  }) async {
    final fileName = file.path.split('/').last;
    final contentType = isTiff
        ? 'image/tiff'
        : fileName.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    final fileSizeBytes = await Future.microtask(
      () => file.length(),
    ).timeout(const Duration(seconds: 2), onTimeout: () => 0);

    return ImageAttachment(
      imageUrl: imageUrl,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      contentType: contentType,
      uploadedAtIso: DateTime.now().toIso8601String(),
      organismIds: selection.coralIds,
      groupIds: selection.groupIds,
      tagIds: selection.tagIds,
      isOrthomosaic: isTiff || selection.isOrthomosaic,
      description: selection.description,
    );
  }

  Future<MonitoringEventRecord> _createMonitoringEvent({
    required EventRepository eventRepository,
    required InventoryRecord record,
    required List<ImageAttachment> attachments,
  }) {
    final monitoringRepository = _resolveMonitoringRepository(eventRepository);
    return monitoringRepository
        .createMonitoringEvent(
          forRecord: record,
          oldHealthStatus: null,
          newHealthStatus: null,
          comment: _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
          siteId: (record is Site) ? record.id : null,
          monitoringDate: DateTime.now(),
          organismIds:
              attachments.expand((a) => a.organismIds).toSet().toList(),
          entries: const [],
          totalCount: 0,
          imageAttachments: attachments,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'createMonitoringEvent timed out after 30 seconds',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final imageryEnabled = _imageryEnabled();
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.image, color: Colors.blue),
          SizedBox(width: 8),
          Text('Upload Images'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: _isUploading
            ? const Center(child: CircularProgressIndicator())
            : DialogScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildErrorBanner(),
                    _buildImageSelectionSection(imageryEnabled: imageryEnabled),
                    if (imageryEnabled) ...[
                      const SizedBox(height: 16),
                      _buildCommentField(),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : popDialog,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading || !imageryEnabled ? null : _submit,
          child: const Text('Upload'),
        ),
      ],
    );
  }

  /// Builds the error banner if an error exists.
  Widget _buildErrorBanner() {
    final error = _error;
    if (error == null) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds the image selection section with file picker and image cards.
  Widget _buildImageSelectionSection({required bool imageryEnabled}) {
    if (!imageryEnabled) {
      final access = _maybeFeatureAccess();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: UpgradeCta(
          title: 'Image uploads - coming soon',
          subtitle:
              'Upgrade to attach orthomosaics and time-series imagery to observation records.',
          url: access?.upgradeUrl,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Image Attachments',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _pickImageFiles,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Add Images'),
                ),
                if (_pendingImageFiles.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _pendingImageFiles.clear();
                        _pendingSelections.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_pendingImageFiles.isEmpty)
          _buildEmptyStateCard()
        else
          ..._pendingImageFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return _buildImageCard(index, file);
          }),
      ],
    );
  }

  /// Builds the empty state card when no images are selected.
  Widget _buildEmptyStateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upload orthomosaics (TIFF) or time series images. '
                'Associate images with specific organisms/groups using the selection wizard.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the comment input field.
  Widget _buildCommentField() {
    return TextField(
      controller: _commentController,
      decoration: const InputDecoration(
        labelText: 'Comment (Optional)',
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
    );
  }

  Widget _buildImageCard(int index, File file) {
    final fileName = file.path.split('/').last;
    final isTiff =
        fileName.toLowerCase().endsWith('.tiff') ||
        fileName.toLowerCase().endsWith('.tif');
    final selection =
        _pendingSelections[index] ?? const ImageAttachmentSelection();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTiff ? Icons.map : Icons.image,
                  color: isTiff ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _removeImage(index),
                  tooltip: 'Remove image',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Orthomosaic (TIFF)'),
                    value: isTiff || selection.isOrthomosaic,
                    onChanged: isTiff
                        ? null
                        : (value) {
                            setState(() {
                              _pendingSelections[index] = selection.copyWith(
                                isOrthomosaic: value ?? false,
                              );
                            });
                          },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectImageTargets(index),
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(
                    selection.hasSpecificTargets
                        ? 'Edit Targets'
                        : 'Select Targets',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            if (selection.hasSpecificTargets) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (selection.coralIds.isNotEmpty)
                    Chip(
                      label: Text(
                        _organismCountLabel(selection.coralIds.length),
                      ),
                      avatar: const Icon(Icons.circle, size: 16),
                    ),
                  if (selection.groupIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${selection.groupIds.length} group${selection.groupIds.length > 1 ? 's' : ''}',
                      ),
                      avatar: const Icon(Icons.folder, size: 16),
                    ),
                  if (selection.tagIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${selection.tagIds.length} tag${selection.tagIds.length > 1 ? 's' : ''}',
                      ),
                      avatar: const Icon(Icons.tag, size: 16),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}