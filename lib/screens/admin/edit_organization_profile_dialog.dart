import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/brand_profile_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import '../../widgets/dialogs/components/dialog_scroll_view.dart';

class EditOrganizationProfileDialog extends StatefulWidget {
  final Organization organization;
  final OrganizationRepository organizationRepository;
  final CurrentUser currentUser;

  const EditOrganizationProfileDialog({
    super.key,
    required this.organization,
    required this.organizationRepository,
    required this.currentUser,
  });

  static Future<void> show(BuildContext context, Organization organization) async {
    final organizationRepository = context.read<OrganizationRepository>();
    final currentUser = context.read<CurrentUser>();

    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => EditOrganizationProfileDialog(
        organization: organization,
        organizationRepository: organizationRepository,
        currentUser: currentUser,
      ),
    );
  }

  @override
  State<EditOrganizationProfileDialog> createState() => _EditOrganizationProfileDialogState();
}

class _EditOrganizationProfileDialogState extends State<EditOrganizationProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.organization.name);
    _taglineController = TextEditingController();
    _loadBrandProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandProfile() async {
    try {
      final service = PublicReadModelsService();
      final profile = await service.fetchBrandProfile(
        widget.organization.id,
        preview: true,
      );

      if (mounted && profile != null) {
        setState(() {
          _taglineController.text = profile.tagline ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final orgRepo = widget.organizationRepository;
      final brandRepo = BrandProfileRepository();
      final currentUser = widget.currentUser;

      // Update Organization Name
      if (_nameController.text.trim() != widget.organization.name) {
        await orgRepo.updateOrganization(
          organizationId: widget.organization.id,
          name: _nameController.text.trim(),
          updatedById: currentUser.state is CurrentUserLoaded
              ? (currentUser.state as CurrentUserLoaded).user.id
              : null,
        );
      }

      // Update Brand Profile
      await brandRepo.upsertBrandProfile(
        organizationId: widget.organization.id,
        brandName: _nameController.text.trim(),
        tagline: _taglineController.text.trim().isNotEmpty
            ? _taglineController.text.trim()
            : null,
        published: true,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization profile updated')),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error saving organization profile', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxContentHeight = screenHeight - keyboardHeight - 200;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight * 0.3 : 0),
      child: AlertDialog(
        title: const Text('Edit Organization Profile'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxContentHeight.clamp(200, 400),
            minWidth: 280,
          ),
          child: DialogScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Org icon (display only)
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.business, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Organization Name',
                    border: OutlineInputBorder(),
                    helperText: 'Your organization\'s display name',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _taglineController,
                  decoration: const InputDecoration(
                    labelText: 'Tagline (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'A short description or slogan for your organization',
                    hintText: 'e.g., "Restoring coral reefs since 2015"',
                  ),
                  maxLength: 100,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
