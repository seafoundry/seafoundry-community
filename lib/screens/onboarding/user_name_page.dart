// @tier: community
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/onboarding/onboarding_cubit.dart';
import '../../models/organization.dart';
import '../../models/records/record.dart';
import '../../repositories/brand_profile_repository.dart';
import '../../repositories/organization_repository.dart';
import '../../services/image_service.dart';
import '../../services/logging_service.dart';

class UserNamePage extends StatefulWidget {
  final String? nameValue;
  final String? taglineValue;
  final String? initialUserImageUrl;
  final bool isInviteFlow;
  final bool isPure;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onTaglineChanged;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const UserNamePage({
    super.key,
    required this.nameValue,
    this.taglineValue,
    required this.initialUserImageUrl,
    required this.isInviteFlow,
    required this.isPure,
    required this.onChanged,
    this.onTaglineChanged,
    required this.onNext,
    this.onBack,
  });

  factory UserNamePage.empty() {
    return UserNamePage(
      nameValue: '',
      taglineValue: null,
      initialUserImageUrl: null,
      isInviteFlow: false,
      isPure: true,
      onChanged: (_) {},
      onTaglineChanged: null,
      onNext: () {},
    );
  }

  @override
  State<UserNamePage> createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  
  // For native platforms (File-based)
  File? _userImageFile;
  File? _orgLogoFile;
  
  // For web platform (bytes-based)
  PickedImageData? _userImageBytes;
  PickedImageData? _orgLogoBytes;
  
  bool _isUploading = false;
  bool _isLoadingOrg = true;
  Organization? _organization;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.nameValue);
    _taglineController = TextEditingController(text: widget.taglineValue ?? '');
    _loadOrganization();
  }

  Future<void> _loadOrganization() async {
    // We need the organization to get the domain for image uploads
    // and to know the context
    try {
      final cubit = context.read<OnboardingCubit>();
      if (cubit.state is OnboardingUserProfile) {
        final user = (cubit.state as OnboardingUserProfile).user;
        final orgRepo = context.read<OrganizationRepository>();
        final org = await orgRepo.getById(user.organizationId);
        if (mounted) {
          setState(() {
            _organization = org;
            _isLoadingOrg = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingOrg = false);
        }
      }
    } catch (e) {
      LoggingService.instance.warning('Failed to load organization during onboarding', e);
      if (mounted) {
        setState(() => _isLoadingOrg = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UserNamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nameValue != oldWidget.nameValue &&
        widget.nameValue != _nameController.text) {
      _nameController.text = widget.nameValue ?? '';
    }
    if (widget.taglineValue != oldWidget.taglineValue &&
        widget.taglineValue != _taglineController.text) {
      _taglineController.text = widget.taglineValue ?? '';
    }
  }

  /// Cross-platform image picker that works on both web and native
  Future<void> _pickUserImage() async {
    final imageService = context.read<ImageService>();
    
    if (kIsWeb) {
      // On web, use bytes-based picker
      final pickedData = await imageService.pickImageBytes();
      if (pickedData != null && mounted) {
        setState(() {
          _userImageBytes = pickedData;
          _userImageFile = null; // Clear file if any
        });
      }
    } else {
      // On native, use file-based picker
      final file = await imageService.pickImageFile();
      if (file != null && mounted) {
        setState(() {
          _userImageFile = file;
          _userImageBytes = null; // Clear bytes if any
        });
      }
    }
  }

  /// Cross-platform image picker for org logo
  Future<void> _pickOrgLogo() async {
    final imageService = context.read<ImageService>();
    
    if (kIsWeb) {
      final pickedData = await imageService.pickImageBytes();
      if (pickedData != null && mounted) {
        setState(() {
          _orgLogoBytes = pickedData;
          _orgLogoFile = null;
        });
      }
    } else {
      final file = await imageService.pickImageFile();
      if (file != null && mounted) {
        setState(() {
          _orgLogoFile = file;
          _orgLogoBytes = null;
        });
      }
    }
  }
  
  /// Check if user has selected an image (works for both web and native)
  bool get _hasUserImage => _userImageFile != null || _userImageBytes != null;
  
  /// Check if user has selected an org logo
  bool get _hasOrgLogo => _orgLogoFile != null || _orgLogoBytes != null;
  
  /// Get image provider for user photo preview
  ImageProvider? get _userImageProvider {
    if (_userImageBytes != null) {
      return MemoryImage(_userImageBytes!.bytes);
    } else if (_userImageFile != null) {
      return FileImage(_userImageFile!);
    }
    return null;
  }
  
  /// Get image provider for org logo preview
  ImageProvider? get _orgLogoProvider {
    if (_orgLogoBytes != null) {
      return MemoryImage(_orgLogoBytes!.bytes);
    } else if (_orgLogoFile != null) {
      return FileImage(_orgLogoFile!);
    }
    return null;
  }

  Future<void> _handleNext() async {
    // Basic validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final cubit = context.read<OnboardingCubit>();
      final imageService = context.read<ImageService>();
      final user = (cubit.state as OnboardingUserProfile).user;
      final authUser = await imageService.ensureAuthenticated();
      if (!mounted) return;
      final canUploadImages = authUser != null;
      if (!canUploadImages && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Authentication is not ready. Skipping image upload for now.',
            ),
          ),
        );
      }
      
      // Get organization ID - retry fetch if not loaded yet
      Organization? org = _organization;
      if (org == null && !widget.isInviteFlow) {
        // Try to fetch organization one more time
        final orgRepo = context.read<OrganizationRepository>();
        org = await orgRepo.getById(user.organizationId);
      }
      
      // 1. Upload User Image (cross-platform)
      if (_hasUserImage && canUploadImages) {
        String? userUrl;
        
        if (_userImageBytes != null) {
          // Web: upload bytes
          try {
            userUrl = await imageService.uploadUserImageBytes(
              bytes: _userImageBytes!.bytes,
              fileName: _userImageBytes!.name,
              userId: user.id,
              organizationId: (!user.organizationId.isMissing)
                  ? user.organizationId
                  : org?.id,
            );
          } catch (e) {
            LoggingService.instance.warning('User image upload failed', e);
          }
        } else if (_userImageFile != null) {
          // Native: upload file
          try {
            userUrl = await imageService.uploadUserImage(
              imageFile: _userImageFile!,
              userId: user.id,
              organizationId: (!user.organizationId.isMissing)
                  ? user.organizationId
                  : org?.id,
            );
          } catch (e) {
            LoggingService.instance.warning('User image upload failed', e);
          }
        }
        
        if (userUrl != null) {
          cubit.setUserImage(userUrl);
        }
      }

      // 2. Upload Org Logo (if applicable and org is available)
      if (!widget.isInviteFlow &&
          _hasOrgLogo &&
          org != null &&
          canUploadImages) {
        String? logoUrl;
        final storageKey = ImageService.resolveOrganizationStorageKey(
          organizationId: org.id,
        );
        
        if (_orgLogoBytes != null) {
          try {
            logoUrl = await imageService.uploadImageBytes(
              bytes: _orgLogoBytes!.bytes,
              fileName: _orgLogoBytes!.name,
              organizationId: storageKey,
              recordType: 'brand',
              recordId: 'logo',
              uploadedById: user.id,
              extraCustomMetadata: const {'onboarding': 'true'},
            );
          } catch (e) {
            LoggingService.instance.warning('Org logo upload failed', e);
          }
        } else if (_orgLogoFile != null) {
          try {
            logoUrl = await imageService.uploadImage(
              imageFile: _orgLogoFile!,
              organizationId: storageKey,
              recordType: 'brand',
              recordId: 'logo',
              uploadedById: user.id,
              extraCustomMetadata: const {'onboarding': 'true'},
            );
          } catch (e) {
            LoggingService.instance.warning('Org logo upload failed', e);
          }
        }
        
        if (logoUrl != null && mounted) {
          // Update BrandProfile
          final brandRepo = context.read<BrandProfileRepository>();
          await brandRepo.upsertBrandProfile(
            organizationId: org.id,
            brandName: org.name,
            logoUrl: logoUrl,
            published: true,
          );
        }
      }

      // Proceed to next step
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onNext();
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error uploading images during onboarding', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload images: $e')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use the basic layout structure but customize content
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to SeaFoundry!'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Let\'s get started by setting up your profile.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Profile Photos Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User Photo
                _buildPhotoPicker(
                  context,
                  label: 'You',
                  imageProvider: _userImageProvider,
                  imageUrl: widget.initialUserImageUrl,
                  onTap: _pickUserImage,
                  initials: _getInitials(_nameController.text),
                ),

                if (!widget.isInviteFlow) ...[
                  const SizedBox(width: 32),
                  // Organization Logo
                  _buildPhotoPicker(
                    context,
                    label: 'Organization',
                    imageProvider: _orgLogoProvider,
                    imageUrl: null, // Org logo not passed in props usually
                    onTap: _isLoadingOrg ? null : _pickOrgLogo,
                    initials: _organization != null ? _getInitials(_organization!.name) : 'ORG',
                    icon: Icons.business,
                    isLoading: _isLoadingOrg,
                  ),
                ],
              ],
            ),
             const SizedBox(height: 32),

            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your full name',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onChanged,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Tagline Input
            TextField(
              controller: _taglineController,
              decoration: const InputDecoration(
                labelText: 'Tagline (optional)',
                hintText: 'e.g., "Marine Biologist | Coral Restoration"',
                helperText: 'A short bio or description',
                border: OutlineInputBorder(),
              ),
              onChanged: widget.onTaglineChanged,
              maxLength: 100,
            ),

            const SizedBox(height: 24),

            // Next Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _handleNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker(
    BuildContext context, {
    required String label,
    required ImageProvider? imageProvider,
    required String? imageUrl,
    required VoidCallback? onTap,
    required String initials,
    IconData icon = Icons.camera_alt,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    
    // Priority: picked image > existing URL > initials
    ImageProvider? bgImage = imageProvider;
    if (bgImage == null && imageUrl != null && imageUrl.isNotEmpty) {
      bgImage = NetworkImage(imageUrl);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: bgImage,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : bgImage == null
                        ? Text(
                            initials,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: onTap != null 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.outline,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
