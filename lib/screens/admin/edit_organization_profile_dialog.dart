// @tier: community
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/brand_profile_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import '../../widgets/dialogs/components/dialog_scroll_view.dart';

class EditOrganizationProfileDialog extends StatefulWidget {
  final Organization organization;
  final OrganizationRepository organizationRepository;
  final ImageService imageService;
  final CurrentUser currentUser;

  const EditOrganizationProfileDialog({
    super.key,
    required this.organization,
    required this.organizationRepository,
    required this.imageService,
    required this.currentUser,
  });

  static Future<void> show(BuildContext context, Organization organization) async {
    // Capture providers BEFORE showDialog creates new context
    final organizationRepository = context.read<OrganizationRepository>();
    final imageService = context.read<ImageService>();
    final currentUser = context.read<CurrentUser>();

    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => EditOrganizationProfileDialog(
        organization: organization,
        organizationRepository: organizationRepository,
        imageService: imageService,
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

  File? _selectedLogo;
  File? _selectedHero;
  Uint8List? _selectedLogoBytes;
  Uint8List? _selectedHeroBytes;
  String? _selectedLogoName;
  String? _selectedHeroName;

  String? _existingLogoUrl;
  String? _existingHeroUrl;

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
          _existingLogoUrl = profile.logoUrl;
          _existingHeroUrl = profile.heroImageUrl;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() {
        _selectedLogoBytes = file.bytes;
        _selectedLogoName = file.name;
        _selectedLogo = null;
      });
      return;
    }

    final file = await widget.imageService.pickImageFile();
    if (file != null) {
      setState(() {
        _selectedLogo = file;
        _selectedLogoBytes = null;
        _selectedLogoName = null;
      });
    }
  }

  Future<void> _pickHero() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() {
        _selectedHeroBytes = file.bytes;
        _selectedHeroName = file.name;
        _selectedHero = null;
      });
      return;
    }

    final file = await widget.imageService.pickImageFile();
    if (file != null) {
      setState(() {
        _selectedHero = file;
        _selectedHeroBytes = null;
        _selectedHeroName = null;
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Use providers passed via constructor (captured before dialog opened)
      final imageService = widget.imageService;
      final orgRepo = widget.organizationRepository;
      final brandRepo = BrandProfileRepository();
      final currentUser = widget.currentUser;
      final storageKey =
          ImageService.resolveOrganizationStorageKeyFromOrganization(
            widget.organization,
          );

      String? logoUrl = _existingLogoUrl;
      String? heroUrl = _existingHeroUrl;

      // Upload Logo - use ImageService for consistent behavior
      if (_selectedLogoBytes != null && _selectedLogoName != null) {
        // Web: upload bytes via ImageService
        logoUrl = await imageService.uploadImageBytes(
          bytes: _selectedLogoBytes!,
          fileName: _selectedLogoName!,
          organizationId: storageKey,
          recordType: 'brand',
          recordId: 'logo',
        );
      } else if (_selectedLogo != null) {
        // Native: upload file via ImageService
        logoUrl = await imageService.uploadImage(
          imageFile: _selectedLogo!,
          organizationId: storageKey,
          recordType: 'brand',
          recordId: 'logo',
        );
      }

      // Upload Hero - use ImageService for consistent behavior
      if (_selectedHeroBytes != null && _selectedHeroName != null) {
        // Web: upload bytes via ImageService
        heroUrl = await imageService.uploadImageBytes(
          bytes: _selectedHeroBytes!,
          fileName: _selectedHeroName!,
          organizationId: storageKey,
          recordType: 'brand',
          recordId: 'hero',
        );
      } else if (_selectedHero != null) {
        // Native: upload file via ImageService
        heroUrl = await imageService.uploadImage(
          imageFile: _selectedHero!,
          organizationId: storageKey,
          recordType: 'brand',
          recordId: 'hero',
        );
      }

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
        logoUrl: logoUrl,
        heroImageUrl: heroUrl,
        // Preserve other fields implicitly managed elsewhere or defaults
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
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  ImageProvider? _logoImageProvider() {
    if (_selectedLogoBytes != null) {
      return MemoryImage(_selectedLogoBytes!);
    }
    if (_selectedLogo != null) {
      return FileImage(_selectedLogo!);
    }
    if (_existingLogoUrl != null) {
      return NetworkImage(_existingLogoUrl!);
    }
    return null;
  }

  DecorationImage? _heroDecorationImage() {
    if (_selectedHeroBytes != null) {
      return DecorationImage(
        image: MemoryImage(_selectedHeroBytes!),
        fit: BoxFit.cover,
      );
    }
    if (_selectedHero != null) {
      return DecorationImage(
        image: FileImage(_selectedHero!),
        fit: BoxFit.cover,
      );
    }
    if (_existingHeroUrl != null) {
      return DecorationImage(
        image: NetworkImage(_existingHeroUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
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

    // Get keyboard height to ensure dialog content stays visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate max height for content, leaving room for keyboard and dialog chrome
    final maxContentHeight = screenHeight - keyboardHeight - 200;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight * 0.3 : 0),
      child: AlertDialog(
        title: const Text('Edit Organization Profile'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxContentHeight.clamp(300, 500),
            minWidth: 280,
          ),
          child: DialogScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo Section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _logoImageProvider(),
                        child: (_logoImageProvider() == null)
                            ? const Icon(Icons.business, size: 40, color: Colors.grey)
                            : null,
                      ),
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: UI.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Center(child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Logo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                )),
                
                const SizedBox(height: 24),
                
                // Hero Image Section
                const Text('Cover Image', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickHero,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      image: _heroDecorationImage(),
                    ),
                    child: (_heroDecorationImage() == null)
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                                Text('Add Cover Image', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : null,
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