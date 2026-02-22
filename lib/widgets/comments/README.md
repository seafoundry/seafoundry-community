# Comment Widgets

Phase 1 implementation of the Chat/Comments system for SeaFoundry Pro.

## Overview

This package contains three core widgets for displaying and managing threaded comments:

1. **CommentThreadWidget** - Main container widget for comment threads
2. **CommentBubble** - Individual comment display with reactions and actions
3. **CommentInput** - Text input field for creating and replying to comments

## Features

- Real-time comment updates via Firestore streams
- Nested reply support with visual indentation
- Emoji reactions with toggle behavior
- Edit/delete actions for comment authors
- Reply mode with cancel functionality
- Character limit (2000 chars) with counter
- Loading, error, and empty states
- Relative timestamps ("2h ago", "yesterday")
- Smooth animations and transitions

## Usage

### Basic Example

```dart
import 'package:seafoundry_app/widgets/comments/comments.dart';

// In your widget tree:
CommentThreadWidget(
  targetType: 'event',
  targetId: event.id,
  organizationId: organization.id,
  currentUserId: user.email,
  currentUserName: user.name,
)
```

### Full Dialog Example

```dart
void _showCommentsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 600,
        height: 800,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Comments', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Comment thread
            Expanded(
              child: CommentThreadWidget(
                targetType: 'organism_record',
                targetId: recordId,
                organizationId: organizationId,
                currentUserId: currentUser.email,
                currentUserName: currentUser.name,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

## Target Types

Comments can be attached to any entity type:

- `'event'` - Event records
- `'organism_record'` - Organism records
- `'site'` - Site nodes
- `'group'` - Group nodes

## Dependencies

### Required Repositories

The `CommentThreadWidget` requires `CommentRepository` to be available via `context.read<CommentRepository>()`.

Make sure to provide it in your widget tree:

```dart
RepositoryProvider<CommentRepository>(
  create: (context) => CommentRepository(firestore: firestore),
  child: YourApp(),
)
```

### Required Models

- `Comment` - Comment data model (`lib/models/comments/comment.dart`)
- `CommentState` - Cubit state classes (`lib/cubits/comments/comment_state.dart`)
- `CommentCubit` - Business logic (`lib/cubits/comments/comment_cubit.dart`)

## Styling

All widgets use the SeaFoundry theme system:

- Colors from `AppColors` (lib/theme/app_colors.dart)
- Spacing from `Spacing` constants (lib/theme/spacing.dart)
- Consistent with Sebastian chat styling patterns

## Accessibility

- Proper semantics labels for screen readers
- Keyboard navigation support
- Visual feedback for all interactive elements
- High contrast colors for readability

## Future Enhancements (Phase 2+)

- @mentions with autocomplete
- Rich text formatting (markdown)
- File attachments
- Comment search/filter
- Comment moderation tools
- Notification integration
- Offline support with sync

## File Structure

```
lib/widgets/comments/
├── comment_bubble.dart          # Individual comment display (282 lines)
├── comment_input.dart           # Comment input field (279 lines)
├── comment_thread_widget.dart   # Main thread container (359 lines)
├── comments.dart                # Barrel export
└── README.md                    # This file
```

## Testing

To test the comment widgets:

```bash
# Run widget tests
flutter test test/widget/comments/

# Run full test suite
flutter test

# Analyze for issues
flutter analyze lib/widgets/comments/
```

## Tier

All files are marked `// @tier: pro` as this is a Pro-tier feature.

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
