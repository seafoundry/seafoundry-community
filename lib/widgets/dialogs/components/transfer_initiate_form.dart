import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/recipient_mode.dart';
import 'package:seafoundry_app/models/types/transfer_ownership_type.dart';
import 'package:seafoundry_app/utils/validation_utils.dart';
import 'package:seafoundry_app/widgets/common/five_axis_editor.dart';
import 'package:seafoundry_app/widgets/dialogs/components/five_axis_dialog_section.dart';
import 'dialog_scroll_view.dart';

/// Form component for initiating a genet transfer.
/// Stateless form used by [TransferDialog] initiate/edit flows. Keeps the UI
/// wiring isolated from the async logic handled in the dialog state.
class TransferInitiateForm extends StatelessWidget {
  const TransferInitiateForm({
    super.key,
    required this.genetName,
    this.localIdSelector,
    required this.selectedOrganization,
    required this.quantityController,
    required this.commentController,
    required this.isSelectingOrganization,
    required this.isBusy,
    this.quantitySection,
    this.isEditMode = false,
    required this.onSelectOrganization,
    required this.provenanceSelection,
    required this.onFiveAxisChanged,
    required this.selectedPhysicalFormId,
    required this.sizeSpec,
    required this.measurement,
    this.isFiveAxisReadOnly = false,
    this.recipientMode = RecipientMode.organization,
    this.onRecipientModeChanged,
    this.recipientEmailController,
    this.recipientEmail = '',
    this.ownershipType = TransferOwnershipType.fullTransfer,
    this.isThirdPartyDetected = false,
    this.onOwnershipTypeChanged,
  });

  final String genetName;
  final Widget? localIdSelector;
  final Organization? selectedOrganization;
  final TextEditingController quantityController;
  final TextEditingController commentController;
  final bool isSelectingOrganization;
  final bool isBusy;
  final Widget? quantitySection;
  final bool isEditMode; // Disable organization selection in edit mode
  final VoidCallback onSelectOrganization;
  final ProvenanceLifeStageSelection provenanceSelection;
  final ValueChanged<FiveAxisSelection> onFiveAxisChanged;
  final String selectedPhysicalFormId;
  final SizeSpec sizeSpec;
  final PopulationMeasurement measurement;
  final bool isFiveAxisReadOnly;

  /// Current recipient mode (organization lookup or direct email)
  final RecipientMode recipientMode;

  /// Callback when recipient mode changes
  final ValueChanged<RecipientMode>? onRecipientModeChanged;

  /// Controller for email input (used when recipientMode is email)
  final TextEditingController? recipientEmailController;

  /// Current recipient email value (for validation display)
  final String recipientEmail;

  /// Current ownership type for the transfer
  final TransferOwnershipType ownershipType;

  /// Whether a third-party transfer has been detected
  final bool isThirdPartyDetected;

  /// Callback when ownership type changes
  final ValueChanged<TransferOwnershipType>? onOwnershipTypeChanged;

  @override
  Widget build(BuildContext context) {
    final hasRecordSelection = quantitySection != null;
    return DialogScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGenetBanner(context),
          const SizedBox(height: 20),
          if (hasRecordSelection) ...[
            quantitySection!,
            const SizedBox(height: 20),
          ],
          _buildRecipientSection(context),
          const SizedBox(height: 20),
          _buildOwnershipTypeSection(context),
          const SizedBox(height: 20),
          if (!hasRecordSelection) ...[
            _buildQuantityField(),
            const SizedBox(height: 20),
          ],
          _buildFiveAxisSection(),
          const SizedBox(height: 20),
          _buildCommentField(),
        ],
      ),
    );
  }

  Widget _buildRecipientSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipient',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (!isEditMode && onRecipientModeChanged != null) ...[
          _buildRecipientModeToggle(context),
          const SizedBox(height: 12),
        ],
        if (recipientMode == RecipientMode.organization)
          _buildOrganizationSelector(context)
        else
          _buildEmailField(context),
      ],
    );
  }

  Widget _buildOwnershipTypeSection(BuildContext context) {
    if (isThirdPartyDetected) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Third-party transfer detected. The original owner will be notified.',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ownership', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<TransferOwnershipType>(
          segments: const [
            ButtonSegment(
              value: TransferOwnershipType.fullTransfer,
              label: Text('Full Transfer'),
              icon: Icon(Icons.swap_horiz),
            ),
            ButtonSegment(
              value: TransferOwnershipType.retainedOwnership,
              label: Text('Retain Ownership'),
              icon: Icon(Icons.bookmark_outline),
            ),
          ],
          selected: {ownershipType},
          onSelectionChanged: isBusy
              ? null
              : (selected) {
                  onOwnershipTypeChanged?.call(selected.first);
                },
        ),
        const SizedBox(height: 8),
        Text(
          ownershipType.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildRecipientModeToggle(BuildContext context) {
    return SegmentedButton<RecipientMode>(
      segments: [
        ButtonSegment<RecipientMode>(
          value: RecipientMode.organization,
          label: Text(RecipientMode.organization.displayName),
          icon: const Icon(Icons.business, size: 18),
        ),
        ButtonSegment<RecipientMode>(
          value: RecipientMode.email,
          label: Text(RecipientMode.email.displayName),
          icon: const Icon(Icons.email, size: 18),
        ),
      ],
      selected: {recipientMode},
      onSelectionChanged: isBusy
          ? null
          : (Set<RecipientMode> selection) {
              if (selection.isNotEmpty) {
                onRecipientModeChanged?.call(selection.first);
              }
            },
    );
  }

  Widget _buildEmailField(BuildContext context) {
    final isValid = ValidationUtils.isValidEmail(recipientEmail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: recipientEmailController,
          enabled: !isBusy && !isEditMode,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'recipient@organization.com',
            helperText: 'Email address of the recipient organization',
            prefixIcon: const Icon(Icons.email_outlined),
            suffixIcon: recipientEmail.isNotEmpty
                ? Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                  )
                : null,
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter recipient email';
            }
            if (!ValidationUtils.isValidEmail(value)) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        if (isEditMode)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Recipient email cannot be changed',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildGenetBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transferring',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.blue[900]),
          ),
          const SizedBox(height: 4),
          if (localIdSelector != null)
            localIdSelector!
          else
            Text(
              genetName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrganizationSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isSelectingOrganization || isBusy || isEditMode)
                ? null
                : onSelectOrganization,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectedOrganization == null
                      ? Colors.grey[400]!
                      : Theme.of(context).primaryColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedOrganization == null
                        ? Icons.business
                        : Icons.check_circle,
                    color: selectedOrganization == null
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedOrganization?.name ?? 'Select organization...',
                      style: TextStyle(
                        color:
                            selectedOrganization == null ? Colors.grey[600] : null,
                        fontWeight: selectedOrganization == null
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelectingOrganization || isBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isEditMode)
                    Icon(Icons.lock, size: 16, color: Colors.grey[600])
                  else
                    const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        ),
        if (selectedOrganization == null && !isEditMode)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (isEditMode)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Destination organization cannot be changed',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: quantityController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Number of fragments',
            helperText: 'How many fragments to transfer',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter quantity';
            }
            final qty = int.tryParse(value);
            if (qty == null || qty < 1) {
              return 'Must be at least 1';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCommentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer Notes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: commentController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Optional notes about this transfer',
            helperText: 'e.g., Research collaboration, breeding program',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildFiveAxisSection() {
    final section = FiveAxisDialogSection(
      fieldKeyPrefix: 'transfer-initiate',
      organismKind: OrganismKind.coral,
      initialSelection: provenanceSelection,
      initialPhysicalFormId: selectedPhysicalFormId,
      initialSizeSpec: sizeSpec,
      measurement: measurement,
      title: 'Five-axis Metadata',
      helpText:
          isFiveAxisReadOnly
              ? 'Locked for transfers. Update the organism record with a reason (creates an event), then return to transfer.'
              : 'Record provenance, life stage, physical form, and size so the receiving org gets canonical metadata.',
      onChanged: onFiveAxisChanged,
    );

    if (!isFiveAxisReadOnly) {
      return section;
    }

    return AbsorbPointer(
      child: Opacity(
        opacity: 0.6,
        child: section,
      ),
    );
  }
}
