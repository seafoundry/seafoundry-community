// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/cleaning/cleaning_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
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

/// Dialog for creating cleaning events using the established patterns
class CleaningEventDialog
    extends
        BaseEventDialog<CleaningEvent, CleaningFormBloc, CleaningFormState> {
  const CleaningEventDialog({
    super.key,
    this.userId,
    this.isPro = false,
  });

  final String? userId;
  final bool isPro;

  @override
  ModelType get modelType => ModelType.event;

  @override
  CreateDialogConfig get config => const CreateDialogConfig(
    title: 'Record Cleaning',
    icon: Icons.cleaning_services,
    iconColor: Colors.blue,
    width: 500,
  );

  @override
  bool get showTaskOption => false;

  @override
  List<Widget> buildEventContent(
    BuildContext context,
    CleaningFormState state,
  ) {
    final bloc = context.read<CleaningFormBloc>();
    return [
      // Cleaning Type Dropdown (filtered by site environment)
      OceanicDropdown<String>(
        value: state.cleaningType.value?.isEmpty == true
            ? CleaningType.algaeScraping.id
            : state.cleaningType.value,
        label: state.cleaningType.label,
        hint: state.cleaningType.hintText,
        errorText: state.cleaningType.displayError?.toString(),
        items: _getApplicableCleaningTypes(bloc).map((type) {
          return DropdownMenuItem(value: type.id, child: Text(type.label));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            context.read<CleaningFormBloc>().add(CleaningTypeChanged(value));
          }
        },
      ),
      const SizedBox(height: 16),

      // Duration Field
      OceanicTextFormField(
        label: state.duration.label,
        hint: state.duration.hintText,
        errorText: state.duration.displayError?.toString(),
        suffixText: 'minutes',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          final duration = value.isEmpty ? null : int.tryParse(value);
          context.read<CleaningFormBloc>().add(DurationChanged(duration));
        },
      ),
      const SizedBox(height: 16),

      // Area/Equipment Field
      OceanicTextFormField(
        label: state.area.label,
        hint: state.area.hintText,
        errorText: state.area.displayError?.toString(),
        onChanged: (value) {
          context.read<CleaningFormBloc>().add(AreaChanged(value));
        },
      ),
      const SizedBox(height: 16),
      // Comments Field
      OceanicTextFormField(
        label: state.comment.label,
        hint: state.comment.hintText,
        errorText: state.comment.displayError?.toString(),
        maxLines: 3,
        onChanged: (value) {
          context.read<CleaningFormBloc>().add(CommentChanged(value));
        },
      ),
      const SizedBox(height: 16),
      _buildPermitSection(context, state),
      const SizedBox(height: 16),
      EventTargetSelectorSection(bloc: bloc),
    ];
  }

  Widget _buildPermitSection(BuildContext context, CleaningFormState state) {
    final bloc = context.read<CleaningFormBloc>();
    final site = _resolveActiveSite(bloc);
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(site);
    final siteName = site?.name ?? 'this site';
    final fieldsEnabled =
        state.submissionStatus != FormzSubmissionStatus.inProgress;
    final permitId = state.permitId.value ?? '';
    final permitType = state.permitType.value ?? '';
    final issuingAuthority = state.issuingAuthority.value ?? '';

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

  Site? _resolveActiveSite(CleaningFormBloc bloc) {
    final siteNode = bloc.targetNode?.siteNode;
    if (siteNode == null) return null;
    final siteState = siteNode.state;
    if (siteState is GraphLoadedState<Site>) {
      return siteState.record;
    }
    final initialRecord = siteNode.initialRecord;
    return initialRecord;
  }

  /// Get cleaning types applicable to the current site environment
  List<CleaningType> _getApplicableCleaningTypes(CleaningFormBloc bloc) {
    final site = _resolveActiveSite(bloc);
    if (site == null) {
      // Default to all types if site is unknown
      return CleaningType.values;
    }
    final environment = site.siteType.environment;
    return CleaningType.valuesFor(environment);
  }

  /// Show the cleaning dialog
  static Future<CleaningEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
  }) {
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.read<EventRepository>();
    final propagationService = context.read<EventPropagationService>();

    // Capture userId and isPro from CurrentUser for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId =
        currentUserState is CurrentUserLoaded ? currentUserState.user.id : null;
    final isPro = currentUserState is CurrentUserLoaded &&
        currentUserState.organization.tier.index >= Tier.pro.index;

    return showDialog<CleaningEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => BlocProvider(
        create: (_) => CleaningFormBloc(
          eventRepository: eventRepository,
          propagationService: propagationService,
          targetNode: targetNode,
        )..add(EventFormTargetChanged(targetNode)),
        child: CleaningEventDialog(userId: userId, isPro: isPro),
      ),
    );
  }

  /// Show the cleaning dialog in edit mode
  static Future<CleaningEvent?> showForEdit(
    BuildContext context, {
    required GraphNode targetNode,
    required CleaningEvent originalEvent,
  }) async {
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.read<EventRepository>();
    final propagationService = context.read<EventPropagationService>();

    // Capture userId and isPro from CurrentUser for permit creation
    final currentUserState = context.read<CurrentUser>().state;
    final userId =
        currentUserState is CurrentUserLoaded ? currentUserState.user.id : null;
    final isPro = currentUserState is CurrentUserLoaded &&
        currentUserState.organization.tier.index >= Tier.pro.index;

    return showDialog<CleaningEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) => BlocProvider(
        create: (_) {
          final bloc = CleaningFormBloc(
            eventRepository: eventRepository,
            propagationService: propagationService,
            targetNode: targetNode,
          )..add(EventFormTargetChanged(targetNode));
          // Initialize for edit mode
          bloc.initializeForEdit(originalEvent);
          return bloc;
        },
        child: CleaningEventDialog(userId: userId, isPro: isPro),
      ),
    );
  }
}

/// Extension to make old API compatible
extension CleaningDialogCompat on CleaningEventDialog {
  /// Compatibility method for existing code
  static Future<CleaningEvent?> showCompat(
    BuildContext context, {
    required GraphNode node,
  }) {
    return CleaningEventDialog.show(context, targetNode: node);
  }
}
