import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_community/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_community/models/user.dart';
import 'package:seafoundry_community/widgets/dialogs/components/safe_dialog_mixin.dart';
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
  bool _isSaving = false;

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

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<CurrentUser>().updateProfile(
        name: _nameController.text.trim(),
        tagline: _taglineController.text.trim().isNotEmpty
            ? _taglineController.text.trim()
            : null,
      );

      if (mounted) {
        popDialog();
      }
    } catch (e) {
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxContentHeight = screenHeight - keyboardHeight - 200;

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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Initials avatar (display only, no upload)
                CircleAvatar(
                  radius: 40,
                  child: Text(
                    widget.user.name.isNotEmpty
                        ? widget.user.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 32),
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
            onPressed: _isSaving ? null : () => popDialog(),
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
