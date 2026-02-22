// @tier: community
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../../widgets/dialogs/components/dialog_scroll_view.dart';

class EditUserProfileDialog extends StatefulWidget {
  final User user;

  const EditUserProfileDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, User user) async {
    await showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => EditUserProfileDialog(user: user),
    );
  }

  @override
  State<EditUserProfileDialog> createState() => _EditUserProfileDialogState();
}

class _EditUserProfileDialogState extends State<EditUserProfileDialog>
    with SafeDialogMixin<EditUserProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  
  // For native platforms (File-based)
  File? _selectedImageFile;
  // For web platform (bytes-based)
  PickedImageData? _selectedImageBytes;
  
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _taglineController = TextEditingController(text: widget.user.tagline ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  /// Cross-platform image picker
  Future<void> _pickImage() async {
    final imageService = context.read<ImageService>();
    
    if (kIsWeb) {
      // Web: use bytes-based picker
      final pickedData = await imageService.pickImageBytes();
      if (pickedData != null && mounted) {
        setState(() {
          _selectedImageBytes = pickedData;
          _selectedImageFile = null;
        });
      }
    } else {
      // Native: use file-based picker
      final file = await imageService.pickImageFile();
      if (file != null && mounted) {
        setState(() {
          _selectedImageFile = file;
          _selectedImageBytes = null;
        });
      }
    }
  }
  
  /// Check if user has selected an image
  bool get _hasSelectedImage => _selectedImageFile != null || _selectedImageBytes != null;
  
  /// Get image provider for preview
  ImageProvider? get _selectedImageProvider {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!.bytes);
    } else if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }
    return null;
  }

  Future<void> _save() async {
    // Basic validation
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl = widget.user.imageUrl;

      if (_hasSelectedImage) {
        final imageService = context.read<ImageService>();
        final currentUserState = context.read<CurrentUser>().state;
        final organizationId = currentUserState is CurrentUserLoaded
            ? currentUserState.user.organizationId
            : widget.user.organizationId;
        final authUser = await imageService.ensureAuthenticated();
        if (authUser == null) {
          throw Exception('Authentication not ready. Please try again.');
        }

        if (_selectedImageBytes != null) {
          // Web: upload bytes
          final url = await imageService.uploadUserImageBytes(
            bytes: _selectedImageBytes!.bytes,
            fileName: _selectedImageBytes!.name,
            userId: widget.user.id,
            organizationId: organizationId,
          );
          if (url != null) {
            imageUrl = url;
          }
        } else if (_selectedImageFile != null) {
          // Native: upload file
          final url = await imageService.uploadUserImage(
            imageFile: _selectedImageFile!,
            userId: widget.user.id,
            organizationId: organizationId,
          );
          if (url != null) {
            imageUrl = url;
          }
        }
      }

      if (!mounted) return;

      await context.read<CurrentUser>().updateProfile(
        name: _nameController.text.trim(),
        tagline: _taglineController.text.trim().isNotEmpty
            ? _taglineController.text.trim()
            : null,
        imageUrl: imageUrl,
      );

      if (mounted) {
        popDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error updating profile: $e')),
        );
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get keyboard height to ensure dialog content stays visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate max height for content, leaving room for keyboard and dialog chrome
    final maxContentHeight = screenHeight - keyboardHeight - 200; // 200 for title, actions, padding
    
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? keyboardHeight * 0.3 : 0),
      child: AlertDialog(
        title: const Text('Edit Profile'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxContentHeight.clamp(200, 400),
            minWidth: 280,
          ),
          child: DialogScrollView(
            // Ensure focused TextField is visible when keyboard appears
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _selectedImageProvider ??
                            (widget.user.imageUrl != null
                                ? NetworkImage(widget.user.imageUrl!)
                                : null),
                        child: (!_hasSelectedImage && widget.user.imageUrl == null)
                            ? Text(
                                widget.user.name.isNotEmpty 
                                    ? widget.user.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: UI.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _taglineController,
                  decoration: const InputDecoration(
                    labelText: 'Tagline (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'A short bio or description',
                    hintText: 'e.g., "Marine Biologist | Coral Restoration"',
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
            onPressed: _isUploading ? null : () => popDialog(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isUploading ? null : _save,
            child: _isUploading
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