// @tier: community
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/brand_profile_repository.dart';
import 'package:seafoundry_app/repositories/user_repository.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../notifications/toast_overlay.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for viewing organization settings and managing brand profile
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.organization});

  final Organization organization;

  static Future<void> show(BuildContext context) {
    // Read current user state from parent context
    final currentUserState = context.read<CurrentUser>().state;

    if (currentUserState is! CurrentUserLoaded) {
      // Handle case where user is not loaded
      return Future.value();
    }

    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      builder: (dialogContext) =>
          SettingsDialog(organization: currentUserState.organization),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog>
    with SafeDialogMixin<SettingsDialog> {
  late TextEditingController _heroImageController;
  late TextEditingController _logoUrlController;
  late TextEditingController _accentColorController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _linkedinController;
  late TextEditingController _youtubeController;
  bool _isSaving = false;
  bool _isUploadingHero = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _heroImageController = TextEditingController();
    _logoUrlController = TextEditingController();
    _accentColorController = TextEditingController();
    _facebookController = TextEditingController();
    _instagramController = TextEditingController();
    _twitterController = TextEditingController();
    _linkedinController = TextEditingController();
    _youtubeController = TextEditingController();
    _loadBrandProfile();
  }

  @override
  void dispose() {
    _heroImageController.dispose();
    _logoUrlController.dispose();
    _accentColorController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _linkedinController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandProfile() async {
    final service = PublicReadModelsService();
    final profile = await service.fetchBrandProfile(
      widget.organization.id,
      preview: true,
    );
    if (profile != null && mounted) {
      setState(() {
        _heroImageController.text = profile.heroImageUrl ?? '';
        _logoUrlController.text = profile.logoUrl ?? '';
        _accentColorController.text = profile.accentColor ?? '';
        final social = profile.socialMediaLinks ?? {};
        _facebookController.text = social['facebook'] ?? '';
        _instagramController.text = social['instagram'] ?? '';
        _twitterController.text = social['twitter'] ?? '';
        _linkedinController.text = social['linkedin'] ?? '';
        _youtubeController.text = social['youtube'] ?? '';
      });
    }
  }

  Future<void> _uploadImage({required bool isHero}) async {
    // Capture ImageService before any async gaps
    final imageService = context.read<ImageService>();

    try {
      setState(() {
        if (isHero) {
          _isUploadingHero = true;
        } else {
          _isUploadingLogo = true;
        }
      });

      // Pick image file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No file data');
      }

      // Upload via ImageService for consistent cross-platform behavior
      final fileName = file.name;
      final storageKey =
          ImageService.resolveOrganizationStorageKeyFromOrganization(
            widget.organization,
          );

      final downloadUrl = await imageService.uploadImageBytes(
        bytes: bytes,
        fileName: fileName,
        organizationId: storageKey,
        recordType: 'brand',
        recordId: isHero ? 'hero' : 'logo',
      );

      if (downloadUrl == null) {
        throw Exception('Failed to get download URL');
      }

      // Update text field
      if (mounted) {
        setState(() {
          if (isHero) {
            _heroImageController.text = downloadUrl;
          } else {
            _logoUrlController.text = downloadUrl;
          }
        });
      }

      if (mounted) {
        ToastOverlay.showSnackBar(context,
          SnackBar(
            content: Text(
              '${isHero ? 'Hero image' : 'Logo'} uploaded successfully',
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error uploading image', e, stackTrace);
      if (mounted) {
        ToastOverlay.showSnackBar(
          context,
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isHero) {
            _isUploadingHero = false;
          } else {
            _isUploadingLogo = false;
          }
        });
      }
    }
  }

  Future<void> _saveBrandProfile() async {
    setState(() => _isSaving = true);

    try {
      final repository = BrandProfileRepository();
      await repository.upsertBrandProfile(
        organizationId: widget.organization.id,
        brandName: widget.organization.name,
        heroImageUrl: _heroImageController.text.trim().isEmpty
            ? null
            : _heroImageController.text.trim(),
        logoUrl: _logoUrlController.text.trim().isEmpty
            ? null
            : _logoUrlController.text.trim(),
        accentColor: _accentColorController.text.trim().isEmpty
            ? null
            : _accentColorController.text.trim(),
        published: true,
        socialMediaLinks: {
          if (_facebookController.text.trim().isNotEmpty)
            'facebook': _facebookController.text.trim(),
          if (_instagramController.text.trim().isNotEmpty)
            'instagram': _instagramController.text.trim(),
          if (_twitterController.text.trim().isNotEmpty)
            'twitter': _twitterController.text.trim(),
          if (_linkedinController.text.trim().isNotEmpty)
            'linkedin': _linkedinController.text.trim(),
          if (_youtubeController.text.trim().isNotEmpty)
            'youtube': _youtubeController.text.trim(),
        },
      );

      if (mounted) {
        ToastOverlay.showSnackBar(context,
          const SnackBar(content: Text('Brand profile saved successfully')),
        );
        popDialog();
      }
    } catch (e) {
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text('Error saving brand profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final dialogWidth = isMobile ? screenWidth * 0.9 : 600.0;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.settings, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Organization Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => popDialog(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scrollable content
            Expanded(
              child: DialogScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReadOnlyField(
                      'Organization Name',
                      widget.organization.name,
                    ),
                    const SizedBox(height: 16),
                    _buildReadOnlyField('Domain', widget.organization.domain),
                    const SizedBox(height: 16),
                    _buildReadOnlyField(
                      'Organization ID',
                      widget.organization.id,
                    ),
                    const SizedBox(height: 32),

                    // Brand Profile Section
                    const Text(
                      'Brand Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize your organization\'s visual identity',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    _buildEditableField(
                      'Hero Image URL',
                      _heroImageController,
                      hint: 'https://example.com/hero.jpg',
                      onUpload: () => _uploadImage(isHero: true),
                      isUploading: _isUploadingHero,
                      showPreview: true,
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'Logo URL',
                      _logoUrlController,
                      hint: 'https://example.com/logo.png',
                      onUpload: () => _uploadImage(isHero: false),
                      isUploading: _isUploadingLogo,
                      showPreview: true,
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'Accent Color',
                      _accentColorController,
                      hint: '#00AEEF',
                    ),
                    const SizedBox(height: 32),

                    // Social Media Section
                    const Text(
                      'Social Media',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Link your social media profiles',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'Facebook',
                      _facebookController,
                      hint: 'https://facebook.com/yourpage',
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'Instagram',
                      _instagramController,
                      hint: 'https://instagram.com/yourprofile',
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'Twitter / X',
                      _twitterController,
                      hint: 'https://twitter.com/yourhandle',
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'LinkedIn',
                      _linkedinController,
                      hint: 'https://linkedin.com/company/yourcompany',
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField(
                      'YouTube',
                      _youtubeController,
                      hint: 'https://youtube.com/@yourchannel',
                    ),
                    const SizedBox(height: 32),

                    // Tour Section
                    const Text(
                      'Tour',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Restart the first-time login tour',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    _buildTourRestartButton(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => popDialog(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isSaving ? null : _saveBrandProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Brand Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourRestartButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restart Tour',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Show the first-time login tour again',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final currentUserCubit = context.read<CurrentUser>();
                final currentUserState = currentUserCubit.state;
                if (currentUserState is! CurrentUserLoaded) {
                  return;
                }

                final user = currentUserState.user;
                final userRepository = RepositoryProvider.of<UserRepository>(
                  context,
                );

                // Clear tour completion metadata
                final updatedMetadata = {
                  ...?user.metadata,
                  'hasCompletedTour': false,
                  'tourCompletedAt': null,
                  'tourVersion': null,
                };

                await userRepository.updateUserMetadata(
                  userId: user.id,
                  metadata: updatedMetadata,
                );

                // Reload user to refresh state
                currentUserCubit.loadUser(user.id);

                if (mounted) {
                  popDialog(); // Close settings dialog
                  ToastOverlay.showSnackBar(context,
                    const SnackBar(
                      content: Text('Tour will restart on next navigation'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ToastOverlay.showSnackBar(context,
                    SnackBar(
                      content: Text('Failed to restart tour: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    String? hint,
    VoidCallback? onUpload,
    bool isUploading = false,
    bool showPreview = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            if (onUpload != null) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload, size: 18),
                label: const Text('Upload'),
              ),
            ],
          ],
        ),
        if (showPreview) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  value.text.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text(
                          'Invalid Image URL',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
