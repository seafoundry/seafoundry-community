import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/models/events/event_permit_metadata.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_cart.dart';

/// Step 3 of the batch transfer wizard: review items and shared config.
///
/// Shows a read-only cart with per-item ownership badges, an optional
/// comment field, an optional permit selector, and the submit button.
class BatchTransferReviewStep extends StatefulWidget {
  const BatchTransferReviewStep({super.key});

  @override
  State<BatchTransferReviewStep> createState() =>
      _BatchTransferReviewStepState();
}

class _BatchTransferReviewStepState extends State<BatchTransferReviewStep> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: context.read<BatchTransferCubit>().state.comment,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BatchTransferCubit, BatchTransferState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            BatchTransferCart(
              items: state.items,
              mode: state.mode,
              editable: false,
              availableInventory: state.availableInventory,
            ),
            const SizedBox(height: 16),
            _buildCommentField(context),
            const SizedBox(height: 16),
            _buildPermitSelector(context, state),
            const SizedBox(height: 24),
            _buildNavigation(context, state),
          ],
        );
      },
    );
  }

  Widget _buildCommentField(BuildContext context) {
    return TextFormField(
      controller: _commentController,
      decoration: const InputDecoration(
        labelText: 'Comment (optional)',
        border: OutlineInputBorder(),
        hintText: 'Add a note for the recipient',
      ),
      textInputAction: TextInputAction.done,
      maxLines: 2,
      onChanged: context.read<BatchTransferCubit>().setComment,
    );
  }

  Widget _buildPermitSelector(
    BuildContext context,
    BatchTransferState state,
  ) {
    final organization = context.read<Organization>();
    return PermitSelectorWidget(
      organizationId: organization.id,
      selectedPermitId: state.permitMetadata.permitId,
      displayOptions: PermitSelectorDisplayOptions.compact,
      onPermitSelected: (permit) {
        final cubit = context.read<BatchTransferCubit>();
        if (permit == null) {
          cubit.setPermit(const EventPermitMetadata.empty());
        } else {
          cubit.setPermit(EventPermitMetadata(
            permitId: permit.id,
            permitType: permit.type.displayName,
            issuingAuthority: permit.issuingAuthority,
            validFrom: permit.validFrom,
            validTo: permit.validTo,
            attachmentUrls: permit.attachmentUrls,
          ));
        }
      },
    );
  }

  Widget _buildNavigation(BuildContext context, BatchTransferState state) {
    final itemCount = state.items.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => context
              .read<BatchTransferCubit>()
              .goToStep(BatchTransferStep.addItems),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: state.canSubmit
              ? () => context.read<BatchTransferCubit>().submitAll()
              : null,
          child: Text('Submit All ($itemCount transfers)'),
        ),
      ],
    );
  }
}
