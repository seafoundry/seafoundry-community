// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/events/treatment/treatment_form_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/dialogs/base_event_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/components/event_target_selector_section.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/forms/base_create_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dropdown.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';

/// Dialog for creating treatment events using the established patterns
class TreatmentEventDialog
    extends
        BaseEventDialog<TreatmentEvent, TreatmentFormBloc, TreatmentFormState> {
  const TreatmentEventDialog({super.key});

  @override
  ModelType get modelType => ModelType.event;

  @override
  CreateDialogConfig get config => const CreateDialogConfig(
    title: 'Record Treatment',
    icon: Icons.medical_services,
    iconColor: Colors.red,
    width: 600,
  );

  @override
  bool get showTaskOption => true; // Treatments often need follow-up

  @override
  List<Widget> buildEventContent(
    BuildContext context,
    TreatmentFormState state,
  ) {
    final bloc = context.read<TreatmentFormBloc>();
    return [
      // Treatment Type Dropdown
      // Treatment Type Dropdown
      OceanicDropdown<String>(
        value: state.treatmentType.value?.isEmpty == true
            ? TreatmentType.medication.id
            : state.treatmentType.value,
        label: state.treatmentType.label,
        hint: state.treatmentType.hintText,
        errorText: state.treatmentType.displayError?.toString(),
        items: TreatmentType.values.map((type) {
          return DropdownMenuItem(value: type.id, child: Text(type.label));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            context.read<TreatmentFormBloc>().add(TreatmentTypeChanged(value));
          }
        },
      ),
      const SizedBox(height: 16),

      // Medication Name Field
      OceanicTextFormField(
        label: state.medicationName.label,
        hint: state.medicationName.hintText,
        errorText: state.medicationName.displayError?.toString(),
        onChanged: (value) {
          context.read<TreatmentFormBloc>().add(MedicationNameChanged(value));
        },
      ),
      const SizedBox(height: 16),

      // Dosage and Unit Row
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dosage Field
          Expanded(
            flex: 2,
            child: OceanicTextFormField(
              label: state.dosage.label,
              hint: state.dosage.hintText,
              errorText: state.dosage.displayError?.toString(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (value) {
                final dosage = value.isEmpty ? null : double.tryParse(value);
                context.read<TreatmentFormBloc>().add(DosageChanged(dosage));
              },
            ),
          ),
          const SizedBox(width: 16),

          // Unit Dropdown
          Expanded(
            child: OceanicDropdown<String>(
              value: state.dosageUnit.value,
              label: state.dosageUnit.label,
              errorText: state.dosageUnit.displayError?.toString(),
              items: DosageUnitInput.availableUnits.map((unit) {
                return DropdownMenuItem(value: unit, child: Text(unit));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  context.read<TreatmentFormBloc>().add(
                    DosageUnitChanged(value),
                  );
                }
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Duration Field (for dips/baths)
      OceanicTextFormField(
        label: state.durationMinutes.label,
        hint: state.durationMinutes.hintText,
        errorText: state.durationMinutes.displayError?.toString(),
        suffixText: 'minutes',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          final duration = value.isEmpty ? null : int.tryParse(value);
          context.read<TreatmentFormBloc>().add(
            DurationMinutesChanged(duration),
          );
        },
      ),
      const SizedBox(height: 16),

      // Notes Field
      OceanicTextFormField(
        label: state.notes.label,
        hint: state.notes.hintText,
        errorText: state.notes.displayError?.toString(),
        maxLines: 3,
        onChanged: (value) {
          context.read<TreatmentFormBloc>().add(TreatmentNotesChanged(value));
        },
      ),
      const SizedBox(height: 16),
      _buildPermitSection(context, state),
      const SizedBox(height: 16),
      EventTargetSelectorSection(bloc: bloc),
    ];
  }

  Widget _buildPermitSection(BuildContext context, TreatmentFormState state) {
    final bloc = context.read<TreatmentFormBloc>();
    final site = _resolveActiveSite(bloc);
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);
    final siteName = site?.name ?? 'this site';
    final fieldsEnabled =
        state.submissionStatus != FormzSubmissionStatus.inProgress;
    final permitId = state.permitId.value ?? '';
    final permitType = state.permitType.value ?? '';
    final issuingAuthority = state.issuingAuthority.value ?? '';

    // Capture user context for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId = currentUserState is CurrentUserLoaded
        ? currentUserState.user.id
        : null;
    final isPro = currentUserState is CurrentUserLoaded &&
        (currentUserState.organization.tier == Tier.pro ||
            currentUserState.organization.tier == Tier.scale);

    if (!supportsPermits) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permit metadata is disabled for $siteName.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permit (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        PermitSelectorWidget(
          organizationId: context.read<Organization>().id,
          userId: userId,
          isPro: isPro,
          selectedPermitId: permitId.isNotEmpty ? permitId : null,
          enabled: fieldsEnabled,
          displayOptions: PermitSelectorDisplayOptions.compact,
          onPermitSelected: (permit) {
            if (permit == null) {
              bloc.add(const PermitIdChanged(null));
              bloc.add(const PermitTypeChanged(null));
              bloc.add(const IssuingAuthorityChanged(null));
              bloc.add(const PermitAttachmentUrlsChanged(null));
              bloc.add(const PermitValidFromChanged(null));
              bloc.add(const PermitValidToChanged(null));
            } else {
              bloc.add(PermitIdChanged(permit.permitNumber));
              bloc.add(PermitTypeChanged(permit.type.displayName));
              bloc.add(IssuingAuthorityChanged(permit.issuingAuthority));
              bloc.add(
                PermitAttachmentUrlsChanged(permit.attachmentUrls.join(', ')),
              );
              bloc.add(PermitValidFromChanged(permit.validFrom));
              bloc.add(PermitValidToChanged(permit.validTo));
            }
          },
        ),
        if (permitId.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedPermitDetails(
            permitId: permitId,
            permitType: permitType,
            issuingAuthority: issuingAuthority,
            validFrom: state.permitValidFrom.value,
            validTo: state.permitValidTo.value,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedPermitDetails({
    required String permitId,
    required String permitType,
    required String issuingAuthority,
    required DateTime? validFrom,
    required DateTime? validTo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Selected Permit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPermitDetailRow('Permit #', permitId),
          if (permitType.isNotEmpty) _buildPermitDetailRow('Type', permitType),
          if (issuingAuthority.isNotEmpty)
            _buildPermitDetailRow('Authority', issuingAuthority),
          if (validFrom != null && validTo != null)
            _buildPermitDetailRow(
              'Valid',
              '${_formatPermitDate(validFrom)} - ${_formatPermitDate(validTo)}',
            ),
        ],
      ),
    );
  }

  Widget _buildPermitDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatPermitDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Site? _resolveActiveSite(TreatmentFormBloc bloc) {
    final siteNode = bloc.targetNode?.siteNode;
    if (siteNode == null) return null;
    final siteState = siteNode.state;
    if (siteState is GraphLoadedState<Site>) {
      return siteState.record;
    }
    final initialRecord = siteNode.initialRecord;
    return initialRecord;
  }

  /// Show the treatment dialog
  static Future<TreatmentEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
  }) {
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.read<EventRepository>();
    final propagationService = context.read<EventPropagationService>();

    return showDialog<TreatmentEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => BlocProvider(
        create: (_) => TreatmentFormBloc(
          eventRepository: eventRepository,
          propagationService: propagationService,
          targetNode: targetNode,
        )..add(EventFormTargetChanged(targetNode)),
        child: const TreatmentEventDialog(),
      ),
    );
  }

  /// Show the treatment dialog in edit mode
  static Future<TreatmentEvent?> showForEdit(
    BuildContext context, {
    required GraphNode targetNode,
    required TreatmentEvent originalEvent,
  }) async {
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.read<EventRepository>();
    final propagationService = context.read<EventPropagationService>();

    return showDialog<TreatmentEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => BlocProvider(
        create: (_) {
          final bloc = TreatmentFormBloc(
            eventRepository: eventRepository,
            propagationService: propagationService,
            targetNode: targetNode,
          )..add(EventFormTargetChanged(targetNode));
          // Initialize for edit mode
          bloc.initializeForEdit(originalEvent);
          return bloc;
        },
        child: const TreatmentEventDialog(),
      ),
    );
  }
}

/// Extension to make old API compatible
extension TreatmentDialogCompat on TreatmentEventDialog {
  /// Compatibility method for existing code
  static Future<TreatmentEvent?> showCompat(
    BuildContext context, {
    required GraphNode node,
  }) {
    return TreatmentEventDialog.show(context, targetNode: node);
  }
}
