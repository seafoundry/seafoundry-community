# Comment Notifications Deployment Guide

## Pre-Deployment Checklist

- [x] TypeScript compiles without errors
- [x] Function exported in `functions/src/index.ts`
- [x] Documentation created (README.md)
- [x] Example tests created
- [ ] Firestore security rules updated for comments collection
- [ ] Flutter app updated to save FCM tokens
- [ ] Flutter app updated to handle notification types

## Deployment Steps

### 1. Verify Build
```bash
cd functions
npm run build
```

Expected: Build succeeds (ignore mocha type warnings in node_modules)

### 2. Deploy Function
```bash
# Option A: Deploy only this function
firebase deploy --only functions:onCommentCreated

# Option B: Deploy all functions
firebase deploy --only functions
```

### 3. Verify Deployment
```bash
# Check function exists in Firebase Console
firebase functions:list | grep onCommentCreated

# View logs
firebase functions:log --only onCommentCreated
```

Expected output:
```
✔ functions: all necessary APIs are enabled
✔ functions[onCommentCreated]: Successful create operation
✔ functions: deployed successfully
```

## Testing After Deployment

### 1. Create Test Comment
Use Firebase Console or Firestore UI:

1. Navigate to Firestore
2. Go to `organizations/{your-org-id}/comments`
3. Add document with:
   ```json
   {
     "authorUid": "firebase-auth-uid-here",
     "authorName": "Test User",
     "content": "Testing @alice mention",
     "mentions": ["alice@example.com"],
     "targetType": "organism_record",
     "targetId": "test-123",
     "createdAt": "<server_timestamp>"
   }
   ```

### 2. Check Logs
```bash
firebase functions:log --only onCommentCreated --limit 50
```

Look for:
- "Processed comment {id}: X mentions"
- "Sent mention notification to {email}"
- Or skip messages if user doesn't exist/has no token

### 3. Test with Flutter App
1. Ensure user has FCM token saved: `users/{email}/fcmToken`
2. Create comment with mention from another user
3. Verify notification appears on device
4. Tap notification and verify navigation works

## Firestore Security Rules

Add rules for the comments collection in `firestore.rules`:

```javascript
match /organizations/{orgId}/comments/{commentId} {
  // Read: Organization members only
  allow read: if isOrgMember(orgId);

  // Create: Authenticated users who are org members
  allow create: if request.auth != null
    && isOrgMember(orgId)
    && request.resource.data.authorUid == request.auth.uid;

  // Update/Delete: Only comment author or org admin
  allow update, delete: if request.auth != null
    && (request.auth.uid == resource.data.authorUid
        || isOrgAdmin(orgId));
}
```

## Monitoring

### Key Metrics to Watch
1. **Function Invocations**: Should match comment creation rate
2. **Error Rate**: Should be low (< 1%)
3. **Execution Time**: Should be < 1 second per comment
4. **FCM Success Rate**: Track via logs

### Common Issues

#### No Notifications Received
- **Check**: User has FCM token in Firestore
- **Check**: FCM token is valid (not expired)
- **Check**: User is not the comment author
- **Check**: Function logs for errors

#### Function Timeout
- **Cause**: Too many mentions in single comment
- **Solution**: Consider batching or limiting mentions per comment

#### Permission Denied
- **Cause**: Function doesn't have permission to read users collection
- **Solution**: Verify Firebase Admin SDK initialization

## Rollback Procedure

If issues occur after deployment:

```bash
# Delete the function
firebase functions:delete onCommentCreated

# Or redeploy previous version
git checkout <previous-commit>
cd functions
npm run build
firebase deploy --only functions
```

## Environment Variables

None required - function uses Firebase Admin SDK with default credentials.

## Cost Estimation

Based on Firebase Functions pricing:
- **Invocations**: $0.40 per million
- **Compute**: $0.0000025 per GB-second
- **Network**: $0.12 per GB

Example: 10,000 comments/day with 2 mentions each
- 10,000 invocations/day = $0.004/day = $0.12/month
- Compute time ~0.5s per invocation = negligible
- Total: ~$0.15/month

## Support Resources

- Firebase Functions Docs: https://firebase.google.com/docs/functions
- FCM Docs: https://firebase.google.com/docs/cloud-messaging
- Function logs: `firebase functions:log`
- Firebase Console: https://console.firebase.google.com

## Post-Deployment Verification

Run through this checklist after deployment:

- [ ] Function appears in Firebase Console
- [ ] Function logs show successful initialization
- [ ] Test comment with mention sends notification
- [ ] Test comment reply sends notification
- [ ] Self-mentions/replies don't send notifications
- [ ] Missing FCM tokens handled gracefully
- [ ] Error rate is acceptable (< 1%)
- [ ] Flutter app navigation works from notification

## Next Phase

After successful deployment of Phase 1 (notifications), consider:
- Phase 2: Comment threads UI in Flutter
- Phase 3: Comment reactions/likes
- Phase 4: Notification preferences
- Phase 5: Email digest of mentions
