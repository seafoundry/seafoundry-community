# Comment Notification Functions

This module contains Cloud Functions that handle notifications for the SeaFoundry Pro comment system.

## Overview

The comment notification system sends push notifications to users when:
1. **Mentions**: A user is mentioned in a comment (via `@username`)
2. **Replies**: Someone replies to a user's comment

## Functions

### `onCommentCreated`

**Trigger**: Firestore document created at `organizations/{orgId}/comments/{commentId}`

**What it does**:
- Extracts mentions from the comment's `mentions` array
- Sends push notifications to each mentioned user (except the author)
- If the comment is a reply (has `parentCommentId`), notifies the parent comment author
- Handles errors gracefully (failing to notify one user doesn't block others)

## Comment Document Schema

Comments are stored at: `organizations/{orgId}/comments/{commentId}`

Required fields:
```typescript
{
  authorUid: string;         // Firebase Auth UID of the comment author
  authorName: string;        // Display name for notifications
  content: string;           // Comment text
  mentions: string[];        // Array of user emails to notify
  targetType: string;        // Entity type (e.g., "organism_record", "site")
  targetId: string;          // Entity ID

  // Optional for replies
  parentCommentId?: string;  // ID of parent comment if this is a reply
}
```

## User Document Schema

Users are keyed by email in the `users` collection:

```typescript
{
  email: string;
  name: string;
  fcmToken?: string;  // Firebase Cloud Messaging token for push notifications
}
```

**Important**: Users without an `fcmToken` will not receive push notifications (gracefully skipped with log message).

## Notification Payload

### Mention Notification
```typescript
{
  notification: {
    title: "{authorName} mentioned you",
    body: "{contentPreview}"  // First 100 chars
  },
  data: {
    type: "comment_mention",
    organizationId: string,
    targetType: string,
    targetId: string,
    commentId: string
  }
}
```

### Reply Notification
```typescript
{
  notification: {
    title: "{authorName} replied to your comment",
    body: "{contentPreview}"
  },
  data: {
    type: "comment_reply",
    organizationId: string,
    targetType: string,
    targetId: string,
    commentId: string,
    parentCommentId: string
  }
}
```

## Behavior Rules

1. **No Self-Notification**: Users are never notified about their own comments
2. **Error Isolation**: If sending a notification to one user fails, others still receive notifications
3. **Missing FCM Token**: Users without FCM tokens are skipped with a log message
4. **Missing Users**: If a mentioned user doesn't exist, it's logged and skipped
5. **Parent Comment Not Found**: Reply notifications fail gracefully if parent is missing

## Deployment

The function is automatically exported in `functions/src/index.ts` and deployed with:

```bash
firebase deploy --only functions:onCommentCreated
```

Or deploy all functions:
```bash
cd functions && npm run deploy
```

## Logs

View logs in Firebase Console or via CLI:
```bash
firebase functions:log --only onCommentCreated
```

## Testing

To test locally with Firebase Emulators:

1. Start emulators:
```bash
firebase emulators:start
```

2. Create a test comment document:
```javascript
// In Firestore emulator UI or via code
db.collection('organizations/test-org/comments').add({
  authorUid: 'firebase-auth-uid-here',
  authorName: 'Test Author',
  content: 'Hello @testuser, check this out!',
  mentions: ['testuser@example.com'],
  targetType: 'organism_record',
  targetId: 'record-123'
});
```

3. Check function logs for notification attempts

## Integration with Flutter App

The Flutter app should:

1. **Set FCM Token**: When user logs in, save their FCM token to their user document
2. **Handle Notifications**: Register notification handlers for `comment_mention` and `comment_reply` types
3. **Navigate**: Use the data payload to navigate to the relevant entity

Example Flutter handler:
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.data['type'] == 'comment_mention') {
    // Navigate to targetType/targetId and highlight commentId
  } else if (message.data['type'] == 'comment_reply') {
    // Navigate to thread and show parentCommentId + commentId
  }
});
```

## Security Considerations

1. **User Privacy**: Only organization members receive notifications
2. **FCM Tokens**: Tokens are stored securely in user documents (org-scoped access)
3. **Rate Limiting**: Consider adding rate limiting if spam becomes an issue
4. **Content Preview**: Limited to 100 characters to prevent notification spam

## Future Enhancements

- [ ] Batch notifications for multiple mentions in quick succession
- [ ] User notification preferences (mute mentions, mute replies, etc.)
- [ ] In-app notification history
- [ ] Email fallback for users without FCM tokens
- [ ] Notification grouping/threading

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
