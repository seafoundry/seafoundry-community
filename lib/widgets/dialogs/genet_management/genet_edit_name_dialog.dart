// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genet_edit_name/genet_edit_name_cubit.dart';
import 'package:seafoundry_app/cubits/genet_edit_name/genet_edit_name_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/dialog_message_box.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_primary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';

/// Dialog for editing a genet's local ID (name).
///
/// This dialog uses [GenetEditNameCubit] for state management and
/// validates uniqueness of the name within the organization via
/// [GenetRepository.updateGenet].
class GenetEditNameDialog extends StatelessWidget {
  const GenetEditNameDialog({super.key, required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  Widget build(BuildContext context) {
    return _GenetEditNameDialogContent(record: record, onUpdated: onUpdated);
  }
}

class _GenetEditNameDialogContent extends StatefulWidget {
  const _GenetEditNameDialogContent({required this.record, this.onUpdated});

  final ProvenanceRecord record;
  final VoidCallback? onUpdated;

  @override
  State<_GenetEditNameDialogContent> createState() =>
      _GenetEditNameDialogContentState();
}

class _GenetEditNameDialogContentState
    extends State<_GenetEditNameDialogContent>
    with SafeDialogMixin<_GenetEditNameDialogContent> {
  late final TextEditingController _nameController;
  bool _isUpdatingName = false;
  Genet? _genet;
  bool _loadingGenet = true;

  @override
  void initState() {
    super.initState();
    final cubitState = context.read<GenetEditNameCubit>().state;
    _nameController = TextEditingController(text: cubitState.name);
    _nameController.addListener(_onNameChanged);
    _loadGenet();
  }

  Future<void> _loadGenet() async {
    try {
      final genetRepository = context.read<GenetRepository>();
      final genet = await genetRepository.getRecordForId(widget.record.id);
      if (!mounted) return;
      setState(() {
        _genet = genet;
        _loadingGenet = false;
      });
    } catch (e) {
      LoggingService.instance.error('Failed to load genet', e);
      if (!mounted) return;
      setState(() => _loadingGenet = false);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_isUpdatingName) return;
    context.read<GenetEditNameCubit>().nameChanged(_nameController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GenetEditNameCubit, GenetEditNameState>(
      builder: (context, cubitState) {
        // Sync controller with cubit state if it changed externally
        if (_nameController.text != cubitState.name) {
          _isUpdatingName = true;
          _nameController.value = _nameController.value.copyWith(
            text: cubitState.name,
            selection: TextSelection.collapsed(offset: cubitState.name.length),
          );
          _isUpdatingName = false;
        }

        return OceanicDialog(
          title: 'Edit Genet Name',
          icon: Icons.edit,
          iconColor: Colors.blue,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DialogMessageBox(
                tone: DialogMessageTone.info,
                child: Text(
                  'Editing the local ID (name). This does not affect the '
                  'immutable Provenance ID, aliases, accession number, or '
                  'clonal ID.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              OceanicTextFormField(
                controller: _nameController,
                enabled: !cubitState.loading && !_loadingGenet,
                label: 'Local ID (Name)',
                hint: 'Enter new name',
                errorText: cubitState.errorMessage,
              ),
              if (cubitState.errorMessage != null) ...[
                const SizedBox(height: 8),
                DialogMessageBox(
                  tone: DialogMessageTone.error,
                  child: Text(
                    cubitState.errorMessage!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OceanicSecondaryButton(
              onPressed: cubitState.loading ? null : () => popDialog(null),
              label: 'Cancel',
            ),
            OceanicPrimaryButton(
              onPressed:
                  cubitState.loading || _loadingGenet
                      ? null
                      : () => _saveChanges(context),
              label: 'Save',
              isLoading: cubitState.loading || _loadingGenet,
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges(BuildContext context) async {
    if (_genet == null) {
      showDialogSnackBar(
        'Could not load genet data. Please try again.',
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;

    final cubit = context.read<GenetEditNameCubit>();

    final success = await cubit.save(original: _genet!);

    if (!context.mounted) return;

    if (success) {
      // Create updated provenance record with new name
      final updatedRecord = widget.record.copyWith(
        displayName: cubit.state.name,
      );

      widget.onUpdated?.call();

      popDialog(
        GenetManagementResult(
          record: updatedRecord,
          primaryRecord: updatedRecord,
        ),
      );
      showDialogSnackBar(
        'Genet renamed to "${cubit.state.name}"',
        isSuccess: true,
      );
    }
  }
}
