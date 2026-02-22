// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genet_alias/genet_alias_cubit.dart';
import 'package:seafoundry_app/cubits/genet_alias/genet_alias_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/widgets/common/alias_editor.dart';
import 'package:seafoundry_app/widgets/common/pid_status_chip.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management_dialog.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_field.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';

/// Quick alias editing dialog to avoid the full profile editor.
class GenetAliasDialog extends StatefulWidget {
  const GenetAliasDialog({super.key, required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  State<GenetAliasDialog> createState() => _GenetAliasDialogState();
}

class _GenetAliasDialogState extends State<GenetAliasDialog>
    with SafeDialogMixin<GenetAliasDialog> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GenetAliasCubit, GenetAliasState>(
      builder: (context, cubitState) {
        final cubit = context.read<GenetAliasCubit>();
        final views = WidgetsBinding.instance.platformDispatcher.views;
        final viewInsets = views.isNotEmpty
            ? MediaQueryData.fromView(views.first).viewInsets
            : MediaQuery.of(context).viewInsets;
        final activeField = cubitState.provenanceSearch.activeField;
        final pidLocked = cubitState.provenanceIdSearchValue.trim().isNotEmpty;
        final hasResolvedPid =
            cubitState.provenanceSearch.resolvedProvenanceId != null;

        return OceanicDialog(
          title: 'Edit aliases',
          icon: Icons.label,
          iconColor: Colors.blue,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'Tag Tracks, ZIMS, CSR, Galaxy STAG, or custom IDs. Aliases stay tied to the Provenance ID and are validated across the organization.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (cubitState.errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cubitState.errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ExpansionTile(
                      key: const PageStorageKey('genet_alias_external_ids'),
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 12),
                      title: Text(
                        'Select External Aliases & IDs',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      children: [
                        ProvenanceAutocompleteField(
                          label: 'Provenance ID (PID)',
                          hintText: 'e.g., PID-APAL-0007',
                          icon: Icons.fingerprint,
                          value: cubitState.provenanceIdSearchValue,
                          suggestions: cubitState
                              .provenanceSearch
                              .provenanceIdSuggestions,
                          isSearching: cubitState
                              .provenanceSearch
                              .isSearchingProvenanceId,
                          displayValueBuilder: (suggestion) =>
                              suggestion.provenanceId,
                          showOtherAliases: false,
                          enabled:
                              !hasResolvedPid &&
                              (activeField == null ||
                                  activeField ==
                                      ProvenanceMatchField.provenanceId),
                          onTextChanged: cubit.updateProvenanceIdSearchValue,
                          onSuggestionSelected: (suggestion) =>
                              cubit.selectProvenanceSuggestion(
                                suggestion,
                                ProvenanceMatchField.provenanceId,
                              ),
                          onEditingComplete: () {
                            if (cubitState.provenanceIdSearchValue
                                .trim()
                                .isNotEmpty) {
                              cubit.setActiveProvenanceField(
                                ProvenanceMatchField.provenanceId,
                              );
                            }
                          },
                          onDisabledTap:
                              (hasResolvedPid ||
                                  (activeField != null &&
                                      activeField !=
                                          ProvenanceMatchField.provenanceId))
                              ? cubit.clearProvenanceSelection
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ProvenanceAutocompleteField(
                          label: 'Alias',
                          hintText: 'e.g., APAL-001',
                          icon: Icons.label_outline,
                          value: cubitState.aliasSearchValue,
                          suggestions:
                              cubitState.provenanceSearch.aliasSuggestions,
                          isSearching:
                              cubitState.provenanceSearch.isSearchingAlias,
                          displayValueBuilder: (suggestion) =>
                              ClonalIdDisplayService.resolveAliasDisplay(
                                suggestion,
                              ),
                          showOtherAliases: false,
                          enabled:
                              !pidLocked &&
                              (activeField == null ||
                                  activeField == ProvenanceMatchField.alias),
                          onTextChanged: cubit.updateAliasSearchValue,
                          onSuggestionSelected: (suggestion) =>
                              cubit.selectProvenanceSuggestion(
                                suggestion,
                                ProvenanceMatchField.alias,
                              ),
                          onEditingComplete: () {
                            if (cubitState.aliasSearchValue.trim().isNotEmpty) {
                              cubit.setActiveProvenanceField(
                                ProvenanceMatchField.alias,
                              );
                            }
                          },
                          onDisabledTap:
                              (pidLocked ||
                                  (activeField != null &&
                                      activeField !=
                                          ProvenanceMatchField.alias))
                              ? cubit.clearProvenanceSelection
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ProvenanceAutocompleteField(
                          label: 'Clonal ID',
                          hintText: 'e.g., Apal-025',
                          icon: Icons.content_copy,
                          value: cubitState.clonalId.value ?? '',
                          errorText: cubitState.clonalId.displayError?.message,
                          suggestions:
                              cubitState.provenanceSearch.clonalIdSuggestions,
                          isSearching:
                              cubitState.provenanceSearch.isSearchingClonalId,
                          enabled:
                              !pidLocked &&
                              (activeField == null ||
                                  activeField == ProvenanceMatchField.clonalId),
                          onTextChanged: cubit.updateClonalId,
                          onSuggestionSelected: (suggestion) =>
                              cubit.selectProvenanceSuggestion(
                                suggestion,
                                ProvenanceMatchField.clonalId,
                              ),
                          onEditingComplete: () {
                            if ((cubitState.clonalId.value ?? '')
                                .trim()
                                .isNotEmpty) {
                              cubit.setActiveProvenanceField(
                                ProvenanceMatchField.clonalId,
                              );
                            }
                          },
                          onDisabledTap:
                              (pidLocked ||
                                  (activeField != null &&
                                      activeField !=
                                          ProvenanceMatchField.clonalId))
                              ? cubit.clearProvenanceSelection
                              : null,
                        ),
                        const SizedBox(height: 12),
                        ProvenanceAutocompleteField(
                          label: 'Accession Number',
                          hintText: 'e.g., ACC-2024-001',
                          icon: Icons.confirmation_number,
                          value: cubitState.accessionNumber.value ?? '',
                          errorText:
                              cubitState.accessionNumber.displayError?.message,
                          suggestions:
                              cubitState.provenanceSearch.accessionSuggestions,
                          isSearching:
                              cubitState.provenanceSearch.isSearchingAccession,
                          displayValueBuilder: (suggestion) =>
                              ClonalIdDisplayService.resolveAliasDisplay(
                                suggestion,
                              ),
                          showOtherAliases: false,
                          enabled:
                              !pidLocked &&
                              (activeField == null ||
                                  activeField ==
                                      ProvenanceMatchField.accessionNumber),
                          onTextChanged: cubit.updateAccessionNumber,
                          onSuggestionSelected: (suggestion) =>
                              cubit.selectProvenanceSuggestion(
                                suggestion,
                                ProvenanceMatchField.accessionNumber,
                              ),
                          onEditingComplete: () {
                            if ((cubitState.accessionNumber.value ?? '')
                                .trim()
                                .isNotEmpty) {
                              cubit.setActiveProvenanceField(
                                ProvenanceMatchField.accessionNumber,
                              );
                            }
                          },
                          onDisabledTap:
                              (pidLocked ||
                                  (activeField != null &&
                                      activeField !=
                                          ProvenanceMatchField.accessionNumber))
                              ? cubit.clearProvenanceSelection
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PidStatusChip(searchState: cubitState.provenanceSearch),
                  const SizedBox(height: 16),
                  AliasEditorList(
                    aliases: cubitState.aliases,
                    onAddAlias: cubit.addAlias,
                    onRemoveAlias: cubit.removeAlias,
                    onValueChanged: cubit.updateAliasValue,
                    onSourceChanged: cubit.updateAliasSource,
                    onLabelChanged: cubit.updateAliasLabel,
                    errorMap: cubitState.aliasErrors,
                    excludedSystems: kReservedAliasSystems,
                    emptyLabel: 'No aliases yet',
                    addButtonLabel: 'Add alias',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OceanicSecondaryButton(
              onPressed: cubitState.isSubmitting ? null : () => popDialog(null),
              label: 'Cancel',
            ),
            OceanicPrimaryButton(
              onPressed: cubitState.isSubmitting ? null : _submit,
              label: 'Save aliases',
              isLoading: cubitState.isSubmitting,
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final cubit = context.read<GenetAliasCubit>();
    final persisted = await cubit.submit();

    if (!mounted || persisted == null) return;

    widget.onUpdated?.call();
    popDialog(
      GenetManagementResult(record: persisted, primaryRecord: persisted),
    );
    showDialogSnackBar('Aliases updated', isSuccess: true);
  }
}
