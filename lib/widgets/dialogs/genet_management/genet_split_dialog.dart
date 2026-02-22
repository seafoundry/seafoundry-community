// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_split_preview.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';

/// Dialog for splitting a cohort/genet into multiple records.
class GenetSplitDialog extends StatefulWidget {
  const GenetSplitDialog({super.key, required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  State<GenetSplitDialog> createState() => _GenetSplitDialogState();
}

class _GenetSplitDialogState extends State<GenetSplitDialog>
    with SafeDialogMixin<GenetSplitDialog> {
  static const int _maxChildren = 5;
  late List<TextEditingController> _nameControllers;
  bool _archiveSource = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameControllers = _buildInitialControllers();
  }

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> _buildInitialControllers() {
    final base = widget.record.displayName.trim();
    final suggestions = ['$base-A', '$base-B'];
    return suggestions
        .map((name) => TextEditingController(text: name))
        .toList(growable: true);
  }

  @override
  Widget build(BuildContext context) {
    return OceanicDialog(
      title: 'Split cohort / genet',
      icon: Icons.call_split,
      iconColor: Colors.orange,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Create new genet records that inherit the same species, provenance, and gamete lineage. Aliases are not copied automatically to avoid conflicts.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'New record names',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._nameControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OceanicTextFormField(
                        controller: controller,
                        enabled: !_isSubmitting,
                        label: 'Child ${index + 1}',
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove child',
                      onPressed: _isSubmitting || _nameControllers.length <= 1
                          ? null
                          : () => _removeRow(index),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: OceanicSecondaryButton(
                onPressed:
                    _isSubmitting || _nameControllers.length >= _maxChildren
                        ? null
                        : _addRow,
                icon: Icons.add,
                label: 'Add another',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _archiveSource,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() {
                        _archiveSource = value ?? false;
                      }),
              title: const Text('Archive source after split'),
              subtitle: const Text(
                'Keep history clean by archiving the original record after new genets are created.',
              ),
            ),
            if (_nameControllers.isNotEmpty) ...[
              const SizedBox(height: 12),
              GenetSplitPreview(
                record: widget.record,
                childCount: _nameControllers.length,
                archiveSource: _archiveSource,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        OceanicSecondaryButton(
          onPressed: _isSubmitting ? null : () => popDialog(null),
          label: 'Cancel',
        ),
        OceanicPrimaryButton(
          onPressed: _isSubmitting ? null : _submit,
          label: 'Create records',
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  void _addRow() {
    setState(() {
      _nameControllers.add(TextEditingController());
    });
  }

  void _removeRow(int index) {
    if (index < 0 || index >= _nameControllers.length) return;
    setState(() {
      _nameControllers.removeAt(index).dispose();
    });
  }

  /// Validates names for basic requirements (non-empty, locally unique).
  /// Returns the list of trimmed names or throws StateError.
  List<String> _validateNamesBasic() {
    final names = _nameControllers
        .map((controller) => controller.text.trim())
        .toList();
    if (names.any((name) => name.isEmpty)) {
      throw StateError('All child records need a name.');
    }
    final seen = <String>{};
    for (final name in names) {
      if (!seen.add(name.toLowerCase())) {
        throw StateError('Names must be unique within this split.');
      }
    }
    return names;
  }

  /// Validates that all names are unique within the organization.
  /// Returns the list of validated names or throws StateError with conflict info.
  Future<List<String>> _validateNamesOrgWide(
    List<String> names,
    FirebaseFirestore firestore,
    String organizationId,
    String organizationDomain,
  ) async {
    final validationService = UniqueNameValidationService(firestore: firestore);
    final conflicts = <String>[];

    for (final name in names) {
      final isUnique = await validationService.isGenetNameUnique(
        name: name,
        organizationDomain: organizationDomain,
        organizationId: organizationId,
      );
      if (!isUnique) {
        conflicts.add(name);
      }
    }

    if (conflicts.isNotEmpty) {
      final conflictList = conflicts.map((n) => '"$n"').join(', ');
      throw StateError(
        'The following name(s) already exist in your organization: '
        '$conflictList. Please choose different names.',
      );
    }

    return names;
  }

  Future<void> _submit() async {
    // Capture all context dependencies before any async operations
    final currentUser = context.read<CurrentUser>();
    final currentUserState = currentUser.state;
    if (currentUserState is! CurrentUserLoaded) {
      setState(() {
        _error = 'User not authenticated';
        _isSubmitting = false;
      });
      return;
    }
    final organization = currentUserState.organization;
    final firebaseService = context.read<FirebaseService>();
    final provenanceRepository = context.read<ProvenanceRepository>();

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Basic validation first (sync)
      final names = _validateNamesBasic();

      // Validate org-wide uniqueness
      await _validateNamesOrgWide(
        names,
        firebaseService.firestore,
        organization.id,
        organization.domain,
      );

      final sourceRecord = widget.record;
      final created = <ProvenanceRecord>[];
      for (final name in names) {
        final metadata = <String, dynamic>{
          ...sourceRecord.metadata,
          'splitFromGenetId': sourceRecord.id,
          'splitFromProvenanceId': sourceRecord.provenanceId,
        };
        final newRecord = ProvenanceRecord(
          id: '', // Will be set by repository
          displayName: name,
          speciesId: sourceRecord.speciesId,
          organismKind: sourceRecord.organismKind,
          provenanceKind: sourceRecord.provenanceKind,
          parentProvenanceId: sourceRecord.id,
          aliasLabels: const [],
          metadata: metadata,
        );
        final persisted = await provenanceRepository.createProvenanceRecord(
          newRecord,
        );
        created.add(persisted);
      }

      if (_archiveSource) {
        await provenanceRepository.archiveGenet(sourceRecord.id);
      }

      widget.onUpdated?.call();
      if (!mounted) return;
      popDialog(
        GenetManagementResult(
          createdRecords: created,
          archivedGenetIds: _archiveSource ? [sourceRecord.id] : const [],
          primaryRecord: sourceRecord,
        ),
      );
      showDialogSnackBar(
        _archiveSource
            ? 'Created ${created.length} records and archived ${sourceRecord.displayName}.'
            : 'Created ${created.length} new records.',
        isSuccess: true,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to split genet', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSubmitting = false;
      });
    }
  }
}
