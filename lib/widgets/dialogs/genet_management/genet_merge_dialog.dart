// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/genet_merge_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_merge_preview.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management_dialog.dart';
import 'package:seafoundry_app/widgets/genet_selector.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';

/// Dialog for merging two genets into a single record.
///
/// Uses [GenetMergeService] to execute the merge operation which:
/// - Combines aliases from both genets
/// - Reassigns corals from the source to target
/// - Archives the source genet
class GenetMergeDialog extends StatefulWidget {
  const GenetMergeDialog({super.key, required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  State<GenetMergeDialog> createState() => _GenetMergeDialogState();
}

class _GenetMergeDialogState extends State<GenetMergeDialog>
    with SafeDialogMixin<GenetMergeDialog> {
  Genet? _selectedGenet;
  bool _useSelectedAsPrimary = false;
  bool _isSubmitting = false;
  String? _error;
  int? _coralCount;
  bool _isLoadingCoralCount = false;
  late final GenetMergeService _mergeService;

  @override
  void initState() {
    super.initState();
    _mergeService = GenetMergeService(
      provenanceRepository: context.read<ProvenanceRepository>(),
      organismRecordRepository: context.read<OrganismRecordRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.record;
    final targetGenetName =
        _useSelectedAsPrimary ? _selectedGenet?.name : base.name;
    final sourceGenetName =
        _useSelectedAsPrimary ? base.name : _selectedGenet?.name;

    return OceanicDialog(
      title: 'Merge genets',
      icon: Icons.merge_type,
      iconColor: Colors.green,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoBox(),
            const SizedBox(height: 12),
            Text('Base genet', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildBaseGenetCard(base),
            const SizedBox(height: 12),
            GenetSelector(
              genet: _selectedGenet,
              label: 'Genet to merge',
              onSelected: _onGenetSelected,
              allowedSpeciesId: base.speciesId,
              tooltip: 'Only matching species can be merged.',
            ),
            const SizedBox(height: 8),
            _buildPrimaryCheckbox(),
            if (_selectedGenet != null) ...[
              const SizedBox(height: 12),
              GenetMergePreview(
                primaryGenetName: targetGenetName ?? '',
                secondaryGenetName: sourceGenetName ?? '',
                mergedAliasCount: _calculateMergedAliasCount(),
                coralCount: _coralCount,
                isLoadingCoralCount: _isLoadingCoralCount,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              _buildErrorRow(),
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
          label: 'Merge',
          isLoading: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: const Text(
        'Combine two genets that represent the same clonal line. Aliases and '
        'linked corals move to the primary record; the secondary is archived.',
        style: TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildBaseGenetCard(ProvenanceRecord base) {
    return Card(
      child: ListTile(
        title: Text(base.name),
        subtitle: Text(
          'Species: ${base.speciesId} | Provenance ID: ${base.provenanceId}',
        ),
        trailing: const Icon(Icons.merge_type),
      ),
    );
  }

  Widget _buildPrimaryCheckbox() {
    return CheckboxListTile(
      value: _useSelectedAsPrimary,
      onChanged: _isSubmitting ? null : _onPrimaryToggled,
      title: const Text('Treat selected genet as the primary record'),
      subtitle: const Text(
        'If checked, the selected genet stays active and this record is archived.',
      ),
    );
  }

  void _onPrimaryToggled(bool? value) {
    setState(() => _useSelectedAsPrimary = value ?? false);
    // Reload coral count since source genet changed
    _loadCoralCount(_selectedGenet);
  }

  Widget _buildErrorRow() {
    return Row(
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
    );
  }

  void _onGenetSelected(Genet? genet) {
    setState(() {
      _selectedGenet = genet;
      _error = null;
    });
    _loadCoralCount(genet);
  }

  int _calculateMergedAliasCount() {
    if (_selectedGenet == null) return widget.record.aliasEntries.length;
    final sourceAliases = _useSelectedAsPrimary
        ? widget.record.aliasEntries
        : _selectedGenet!.aliasEntries;
    final targetAliases = _useSelectedAsPrimary
        ? _selectedGenet!.aliasEntries
        : widget.record.aliasEntries;
    return _mergeService.calculateMergedAliasCount(
      targetAliases: targetAliases,
      sourceAliases: sourceAliases,
    );
  }

  Future<void> _loadCoralCount(Genet? genet) async {
    if (genet == null) {
      setState(() => _coralCount = null);
      return;
    }
    setState(() => _isLoadingCoralCount = true);
    final sourceGenetId = _useSelectedAsPrimary ? widget.record.id : genet.id;
    final count = await _mergeService.loadCoralCount(sourceGenetId);
    if (mounted) {
      setState(() {
        _coralCount = count;
        _isLoadingCoralCount = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedGenet == null) {
      setState(() => _error = 'Select a genet to merge.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final provenanceRepository = context.read<ProvenanceRepository>();

    // Convert selected Genet to ProvenanceRecord
    final selectedRecord = await provenanceRepository.getRecordForId(
      _selectedGenet!.id,
    );
    if (selectedRecord == null) {
      setState(() {
        _error = 'Could not load selected record.';
        _isSubmitting = false;
      });
      return;
    }

    final target = _useSelectedAsPrimary ? selectedRecord : widget.record;
    final source = _useSelectedAsPrimary ? widget.record : selectedRecord;

    if (target.speciesId != source.speciesId) {
      setState(() {
        _error = 'Genets must share the same species to merge.';
        _isSubmitting = false;
      });
      return;
    }
    if (target.id == source.id) {
      setState(() {
        _error = 'Select a different genet to merge.';
        _isSubmitting = false;
      });
      return;
    }

    try {
      final result = await _mergeService.executeMerge(
        target: target,
        source: source,
      );

      widget.onUpdated?.call();
      if (!mounted) return;
      popDialog(
        GenetManagementResult(
          record: result.persistedTarget,
          primaryRecord: result.persistedTarget,
          archivedGenetIds: [result.archivedSourceId],
          reassignedCoralCount: result.reassignedCoralCount,
        ),
      );
      final successMessage = StringBuffer(
        'Merged into ${result.persistedTarget.displayName}.',
      );
      if (result.reassignedCoralCount > 0) {
        successMessage
            .write(' Reassigned ${result.reassignedCoralCount} corals.');
      }
      showDialogSnackBar(successMessage.toString(), isSuccess: true);
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to merge genets',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isSubmitting = false;
      });
      // Attempt to restore source aliases if we cleared them before failing.
      await _mergeService.restoreSourceAliases(source);
    }
  }
}
