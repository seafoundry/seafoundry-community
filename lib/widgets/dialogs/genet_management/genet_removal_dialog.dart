// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genet_removal/genet_removal_cubit.dart';
import 'package:seafoundry_app/cubits/genet_removal/genet_removal_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/dialogs/components/dialog_message_box.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_removal_preview.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dropdown.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';
import '../components/dialog_scroll_view.dart';

/// Dialog for removing/archiving a genet with reason tracking.
///
/// Uses [GenetRemovalCubit] for state management and requires
/// a removal reason before archiving.
class GenetRemovalDialog extends StatelessWidget {
  const GenetRemovalDialog({super.key, required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GenetRemovalCubit, GenetRemovalState>(
      builder: (context, _) {
        return _GenetRemovalDialogContent(record: record, onUpdated: onUpdated);
      },
    );
  }
}

class _GenetRemovalDialogContent extends StatefulWidget {
  const _GenetRemovalDialogContent({required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  State<_GenetRemovalDialogContent> createState() =>
      _GenetRemovalDialogContentState();
}

class _GenetRemovalDialogContentState extends State<_GenetRemovalDialogContent>
    with SafeDialogMixin<_GenetRemovalDialogContent> {
  late final TextEditingController _commentController;
  bool _isUpdatingComment = false;
  int? _coralCount;
  bool _isLoadingCoralCount = true;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<GenetRemovalCubit>().state;
    _commentController = TextEditingController(text: cubitState.comment);
    _commentController.addListener(_onCommentChanged);
    _loadCoralCount();
  }

  Future<void> _loadCoralCount() async {
    try {
      final organismRecordRepository = context.read<OrganismRecordRepository>();
      final organisms = await organismRecordRepository.getAll();
      final count = organisms
          .where(
            (o) =>
                o.organismKind == OrganismKind.coral &&
                GenetIdResolver.resolve(o) == widget.record.id,
          )
          .length;
      if (mounted) {
        setState(() {
          _coralCount = count;
          _isLoadingCoralCount = false;
        });
      }
    } catch (error) {
      LoggingService.instance.error('Failed to load coral count', error);
      if (mounted) {
        setState(() {
          _coralCount = 0;
          _isLoadingCoralCount = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (_isUpdatingComment) return;
    context.read<GenetRemovalCubit>().commentChanged(_commentController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GenetRemovalCubit, GenetRemovalState>(
      builder: (context, cubitState) {
        // Sync controller with cubit state if changed externally
        if (_commentController.text != cubitState.comment) {
          _isUpdatingComment = true;
          _commentController.value = _commentController.value.copyWith(
            text: cubitState.comment,
            selection: TextSelection.collapsed(
              offset: cubitState.comment.length,
            ),
          );
          _isUpdatingComment = false;
        }

        final canSubmit = cubitState.isValid && !cubitState.isSubmitting;

        return OceanicDialog(
          title: 'Remove Genet',
          icon: Icons.delete_forever,
          iconColor: Colors.red,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cubitState.error != null) ...[
                    DialogMessageBox(
                      tone: DialogMessageTone.error,
                      child: Text(
                        cubitState.error!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildGenetInfoCard(),
                  const SizedBox(height: 16),
                  GenetRemovalPreview(
                    coralCount: _coralCount,
                    isLoadingCoralCount: _isLoadingCoralCount,
                  ),
                  const SizedBox(height: 16),
                  const DialogMessageBox(
                    tone: DialogMessageTone.info,
                    child: Text(
                      'Removal reason and comment will appear in the activity '
                      'history for this genet.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReasonDropdown(cubitState),
                  const SizedBox(height: 16),
                  OceanicTextFormField(
                    controller: _commentController,
                    label: 'Comment',
                    hint: 'Add details about this removal...',
                    maxLines: 3,
                  ),
                  if (!canSubmit && !cubitState.isSubmitting) ...[
                    const SizedBox(height: 12),
                    DialogMessageBox(
                      tone: DialogMessageTone.neutral,
                      icon: Icons.info_outline,
                      child: Text(_getValidationMessage(cubitState)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OceanicSecondaryButton(
              onPressed: () => popDialog(null),
              label: 'Cancel',
            ),
            OceanicPrimaryButton(
              onPressed:
                  cubitState.isSubmitting ? null : () => _submit(context),
              label: 'Archive',
              isLoading: cubitState.isSubmitting,
              icon: Icons.delete_forever,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGenetInfoCard() {
    final clonalId = ClonalIdDisplayService.resolveForProvenanceRecord(
      widget.record,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.record.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Species: ${SpeciesRegistry.globalById(widget.record.speciesId)?.genus ?? "Unknown"}',
            ),
            Text('Provenance ID: ${widget.record.provenanceId}'),
            if (clonalId != null) Text('Clonal ID: $clonalId'),
            if (widget.record.accessionNumber != null)
              Text('Accession: ${widget.record.accessionNumber}'),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonDropdown(GenetRemovalState cubitState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Removal Reason',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        OceanicDropdown<PopulationLossReason>(
          value: _getPrimaryReason(cubitState.selectedReason),
          hint: 'Select reason',
          items: PopulationLossReason.primaryNurseryLossReasons.map((reason) {
            return DropdownMenuItem(
              value: reason,
              child: Text(reason.name),
            );
          }).toList(),
          onChanged: (reason) {
            if (reason != null) {
              context.read<GenetRemovalCubit>().reasonChanged(reason);
            }
          },
        ),
        if (_getPrimaryReason(cubitState.selectedReason) ==
            PopulationLossReason.mortality) ...[
          const SizedBox(height: 16),
          const Text(
            'Mortality Cause',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          OceanicDropdown<MortalityReason>(
            value: cubitState.selectedReason is MortalityReason
                ? cubitState.selectedReason as MortalityReason
                : null,
            hint: 'Select cause',
            items: MortalityReason.builtins.values.map((reason) {
              return DropdownMenuItem(
                value: reason,
                child: Text(reason.name),
              );
            }).toList(),
            onChanged: (reason) {
              if (reason != null) {
                context.read<GenetRemovalCubit>().reasonChanged(reason);
              }
            },
          ),
        ],
      ],
    );
  }

  String _getValidationMessage(GenetRemovalState state) {
    if (state.selectedReason == null) {
      return 'Select a removal reason to continue.';
    }
    if (state.selectedReason?.id == PopulationLossReason.mortality.id) {
      return 'Select a mortality cause to continue.';
    }
    return 'Unknown error.';
  }

  PopulationLossReason? _getPrimaryReason(PopulationLossReason? reason) {
    if (reason == null) return null;
    if (reason is MortalityReason) return PopulationLossReason.mortality;
    return reason;
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<GenetRemovalCubit>();
    final state = cubit.state;

    if (!cubit.validate()) {
      return;
    }

    if (state.selectedReason?.id == PopulationLossReason.mortality.id) {
      cubit.setError('Please specify a mortality cause.');
      return;
    }

    cubit.setSubmitting(true);
    cubit.clearError();

    try {
      final genetRepo = context.read<ProvenanceRepository>();

      // Build comment with reason included
      final reasonName = state.selectedReason?.name ?? 'Unknown';
      final userComment = state.comment.trim();
      final archiveComment = userComment.isEmpty
          ? 'Reason: $reasonName'
          : 'Reason: $reasonName. $userComment';

      // Archive the genet
      await genetRepo.archiveGenet(
        widget.record.id,
        lossReason: state.selectedReason,
        comment: archiveComment,
      );

      LoggingService.instance.info(
        'Archived genet ${widget.record.id} (${widget.record.displayName}): '
        'reason=${state.selectedReason!.name} comment=${state.comment.trim()}',
      );

      cubit.setSubmitting(false);
      if (!mounted) return;

      widget.onUpdated?.call();

      if (!context.mounted) return;
      popDialog(GenetManagementResult(archivedGenetIds: [widget.record.id]));
      showDialogSnackBar(
        'Genet "${widget.record.displayName}" archived successfully',
        isSuccess: true,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to archive genet', e, stackTrace);
      if (mounted) {
        cubit.setError('Failed to archive genet: ${e.toString()}');
      }
    }
  }
}