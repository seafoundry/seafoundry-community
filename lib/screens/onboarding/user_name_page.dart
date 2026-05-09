import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.nameValue);
    _taglineController = TextEditingController(text: widget.taglineValue ?? '');
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

  void _handleNext() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Initials avatar (display only)
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                _getInitials(_nameController.text),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
              onChanged: (value) {
                widget.onChanged(value);
                setState(() {}); // Update initials avatar
              },
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
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
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
