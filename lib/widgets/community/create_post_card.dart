// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/community_events/community_events.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/theme/spacing.dart';

/// A card that allows the user to post a new community update
///
/// Mimics a social media input field
class CreatePostCard extends StatefulWidget {
  const CreatePostCard({
    super.key,
    this.communityChannelId,
  });

  final String? communityChannelId;

  @override
  State<CreatePostCard> createState() => _CreatePostCardState();
}

class _CreatePostCardState extends State<CreatePostCard> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submitPost(BuildContext context) {
    if (_contentController.text.trim().isEmpty) return;

    try {
      final user = context.read<User>();
      final org = context.read<Organization>();

      context.read<CommunityEventsBloc>().createPost(
            title: _titleController.text.trim().isEmpty
                ? 'Community Update'
                : _titleController.text.trim(),
            description: _contentController.text.trim(),
            organizationId: org.id,
            organizationName: org.name,
            // Use UID for createdById (matches Firestore rules)
            userId: user.id,
            userName: user.name,
            communityChannelId: widget.communityChannelId,
          );

      // Immediately collapse and clear - optimistic update shows post instantly
      setState(() {
        _isExpanded = false;
      });
      _titleController.clear();
      _contentController.clear();
    } on ProviderNotFoundException catch (_) {
      // Handle missing providers
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create post. Please try again.')),
        );
      }
    }
  }

  void _onBlocStateChanged(CommunityEventsState state) {
    // Show error snackbar only for post-specific errors (not feed loading errors)
    if (state.postError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.postError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final user = context.watch<User>();

      return BlocListener<CommunityEventsBloc, CommunityEventsState>(
        listener: (context, state) => _onBlocStateChanged(state),
        child: Card(
          margin: EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          child: Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isExpanded)
                  Semantics(
                    label: 'Create a new post',
                    button: true,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isExpanded = true;
                        });
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: user.imageUrl != null
                                ? NetworkImage(user.imageUrl!)
                                : null,
                            child: user.imageUrl == null
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name.substring(0, 1).toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: Spacing.md),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Spacing.md,
                                vertical: Spacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Text(
                                "What's on your mind?",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Expanded View with Title and Description
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: user.imageUrl != null
                            ? NetworkImage(user.imageUrl!)
                            : null,
                        child: user.imageUrl == null
                            ? Text(
                                user.name.isNotEmpty
                                    ? user.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close post editor',
                        onPressed: () {
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.md),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Title (optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  SizedBox(height: Spacing.sm),
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      SizedBox(width: Spacing.sm),
                      ElevatedButton(
                        onPressed: () => _submitPost(context),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } on ProviderNotFoundException catch (_) {
      // Fallback if User/Org not found in context
      return Card(
        margin: EdgeInsets.all(Spacing.md),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Please sign in to post updates.'),
        ),
      );
    }
  }
}
