// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/operations/funder.dart';
import 'package:seafoundry_app/repositories/funder_repository.dart';
import 'package:seafoundry_app/widgets/common/loading_overlay.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'components/dialog_scroll_view.dart';
import '../notifications/toast_overlay.dart';

class FunderEditDialog extends StatefulWidget {
  final Funder? funder;

  const FunderEditDialog({super.key, this.funder});

  static Future<void> show(BuildContext context, {Funder? funder}) async {
    // Read required providers from parent context before showDialog
    // (showDialog creates a new overlay context that doesn't inherit providers)
    final funderRepo = context.read<FunderRepository>();
    final org = context.read<Organization>();
    final user = context.read<User>();

    await showDialog(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      builder: (dialogContext) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FunderRepository>.value(value: funderRepo),
        ],
        child: MultiProvider(
          providers: [
            Provider<Organization>.value(value: org),
            Provider<User>.value(value: user),
          ],
          child: FunderEditDialog(funder: funder),
        ),
      ),
    );
  }

  @override
  State<FunderEditDialog> createState() => _FunderEditDialogState();
}

class _FunderEditDialogState extends State<FunderEditDialog>
    with SafeDialogMixin<FunderEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactEmailController;
  late TextEditingController _notesController;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final funder = widget.funder;
    _nameController = TextEditingController(text: funder?.name);
    _contactNameController = TextEditingController(text: funder?.contactName);
    _contactEmailController = TextEditingController(text: funder?.contactEmail);
    _notesController = TextEditingController(text: funder?.notes);
    _isActive = funder?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = context.read<FunderRepository>();
      
      final org = context.read<Organization>();
      final user = context.read<User>();

      final name = _nameController.text.trim();
      final contactName = _contactNameController.text.trim();
      final contactEmail = _contactEmailController.text.trim();
      final notes = _notesController.text.trim();

      if (widget.funder == null) {
        // Create
        final funder = Funder.partial(
          organizationId: org.id,
          createdById: user.id,
          updatedById: user.id,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          name: name,
          contactName: contactName.isEmpty ? null : contactName,
          contactEmail: contactEmail.isEmpty ? null : contactEmail,
          notes: notes.isEmpty ? null : notes,
          isActive: _isActive,
        );
        await repo.createFunder(funder);
      } else {
        // Update
        final updated = widget.funder!.copyWith(
          name: name,
          contactName: contactName.isEmpty ? null : contactName,
          contactEmail: contactEmail.isEmpty ? null : contactEmail,
          notes: notes.isEmpty ? null : notes,
          isActive: _isActive,
        );
        await repo.updateFunder(updated);
      }

      if (mounted) {
        popDialog();
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text(widget.funder == null ? 'Funder created' : 'Funder updated')),
        );
      }
    } catch (e) {
      LoggingService.instance.error('Error saving funder', e);
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      child: AlertDialog(
        title: Text(widget.funder == null ? 'Add Funder' : 'Edit Funder'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Funder / Grant Name *'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  UI.spacingVerticalMd,
                  TextFormField(
                    controller: _contactNameController,
                    decoration: const InputDecoration(labelText: 'Contact Name'),
                  ),
                  UI.spacingVerticalMd,
                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(labelText: 'Contact Email'),
                  ),
                  UI.spacingVerticalMd,
                  SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  UI.spacingVerticalMd,
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => popDialog(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
