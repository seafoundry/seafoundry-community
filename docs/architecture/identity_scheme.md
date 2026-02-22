# Identity Scheme Architecture

## Overview

SeaFoundry uses Firebase Auth **UIDs** as the canonical user identity across
Firestore and Storage. User documents are keyed by UID, and organization
membership is stored in UID-keyed subcollections.

```
/users/{uid}
/organizations/{orgId}/members/{uid}
```

**Key points**:
- `createdById` / `updatedById` store the Firebase Auth UID.
- Email is stored as a user profile field, not used as a document ID.
- Invitations use email matching for acceptance only.

## Firestore Rules (UID-Based)

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

Authorization checks use `request.auth.uid` and the UID-keyed membership
subcollection.

## Storage Rules (UID-Based)

```javascript
function getUserOrgId() {
  return request.auth != null
    ? firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.organizationId
    : null;
}

match /organizations/{orgId}/{allPaths=**} {
  allow read, write: if request.auth != null && getUserOrgId() == orgId;
}

match /users/{userId}/{allPaths=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

match /temp/{userId}/{allPaths=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Invitations

Invitation documents store the invited **email** for verification. Rules allow
read/update for invitees when the invitation email matches
`request.auth.token.email.lower()`.

## Testing Strategy

- Confirm user docs are created at `/users/{uid}`.
- Confirm membership docs are created at `/organizations/{orgId}/members/{uid}`.
- Verify `createdById`/`updatedById` values are UIDs.
- Validate storage access paths use UID-based folders.
