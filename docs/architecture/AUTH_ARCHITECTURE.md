# Authentication & Authorization Architecture

**Last Updated**: 2026-01-21
**Status**: Production

## Overview

SeaFoundry uses Firebase Authentication for identity and Firestore Security
Rules for authorization. The canonical user identifier is the Firebase Auth UID.

## Architecture Principles

### 1. UID-Based User Identity

User documents are keyed by UID:

```
/users/{uid}
```

**Rationale**:
- Immutable identity (email can change, UID does not)
- Standard Firebase pattern
- Simplifies security rules

### 2. Organization-Scoped Access

Most collections are scoped to organizations. Authorization is based on the
user document and the membership subcollection:

```
/organizations/{orgId}/members/{uid}
```

### 3. Email-Only for Invitations

Invitation documents store the invited email and are readable/updatable by the
invitee when the email matches `request.auth.token.email.lower()`.

## Security Rules Structure

### Helper Functions

```javascript
function isAuthenticated() {
  return request.auth != null;
}

function getUserDoc() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid));
}

function isMemberByUid(orgId) {
  return isAuthenticated() &&
    exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
}
```

### Standard Org-Scoped Collections

```javascript
match /organizations/{orgId}/{collection}/{docId} {
  allow read, update, delete: if isMemberByUid(orgId);
  allow create: if isMemberByUid(request.resource.data.organizationId);
}
```

### Invitations (Email Match)

```javascript
match /invitations/{invitationId} {
  allow read: if isAuthenticated() &&
    resource.data.email.lower() == request.auth.token.email.lower();
  allow update: if isAuthenticated() &&
    resource.data.email.lower() == request.auth.token.email.lower() &&
    resource.data.status == 'pending' &&
    request.resource.data.status == 'accepted';
}
```

### Training Progress (UID-Based)

```javascript
match /training_progress/{progressId} {
  allow read, write: if isAuthenticated() &&
    request.resource.data.userId == request.auth.uid;
}
```

## Client-Side Implementation Notes

- `createdById` and `updatedById` fields store UID values.
- Email is stored on the user document as profile metadata, not used for IDs.
- Membership documents are created during onboarding and verified on login.
- Admin status is computed from `role == 'admin'` - no separate `isAdmin` field is stored.

### Admin Status

Admin users are identified by the `role` field:
- Dart model: `bool get isAdmin => role == 'admin';` (computed getter)
- Firestore rules: `getUserDoc().data.role == 'admin'`

This ensures admin status cannot get out of sync with the role field.

## Testing Strategy

- Verify user doc and membership doc creation on first login.
- Confirm rules enforce org scoping via UID membership.
- Validate invitation acceptance uses email matching only.
