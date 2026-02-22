# Firestore Rules Migration Runbook

**Migration Type**: UID + Separate Demo Project
**Date Created**: 2026-01-07
**Status**: Pre-deployment preparation
**Estimated Total Duration**: 10-15 days across 5 phases

## Overview

This runbook guides the phased migration from email-based identity to UID-based identity with a separate demo Firebase project. The migration eliminates ~73% of rules complexity, removes all demo prefix logic, and aligns with standard Firebase patterns.

### Migration Goals

1. **UID as canonical identifier**: Remove email/UID mismatch bugs
2. **Separate demo project**: Eliminate ~600 lines of demo_ rules
3. **Membership subcollection**: Enable future multi-org support
4. **Simplified rules**: Reduce from ~1,476 lines to ~400 lines

### Current State (Pre-Migration)

| Aspect | Current Implementation |
|--------|----------------------|
| User doc ID | Lowercase email |
| Identity lookups | Email-based with complex fallbacks |
| Demo data | Same project, prefixed with `demo_` |
| Org membership | Implicit via `user.organizationId` field |
| Helper functions | 25 functions with demo variants |

### Target State (Post-Migration)

| Aspect | Target Implementation |
|--------|---------------------|
| User doc ID | Firebase UID |
| Identity lookups | UID-based, single `getUserDoc()` helper |
| Demo data | Separate `seafoundryapp-demo` project |
| Org membership | Explicit via `/organizations/{orgId}/members/{uid}` |
| Helper functions | 8 core functions, no demo variants |

---

## Pre-Flight Checklist

Before starting ANY phase, verify:

- [ ] **Firebase CLI installed**: `firebase --version` (require v12.0.0+)
- [ ] **Authenticated to Firebase**: `firebase login` with admin account
- [ ] **Project access verified**: `firebase projects:list` shows `seafoundryapp`
- [ ] **Rules backup created**: `docs/migration/deployed-rules-backup-2026-01-07.txt` exists
- [ ] **Firestore emulator working**: `firebase emulators:start --only firestore` succeeds
- [ ] **Test suite passing**: `flutter test` shows 0 failures
- [ ] **Code analyzer clean**: `flutter analyze` shows 0 errors/warnings
- [ ] **Git status clean**: No uncommitted changes that could interfere with rollback

### Required Service Accounts

- [ ] Production Firebase admin: `firebase-service-account.json`
- [ ] Demo project admin (Phase R1+): `firebase-service-account-demo.json`

### Communication Plan

- [ ] Team notified of migration schedule
- [ ] Maintenance window scheduled (if downtime required)
- [ ] Rollback decision-maker identified
- [ ] Emergency contact list confirmed

---

## Phase R0: Preparation (Duration: 1-2 days)

**Risk Level**: Low
**Rollback Impact**: None (additive changes only)

### R0-A: Create Demo Firebase Project

#### Steps

1. **Create new Firebase project**:
   ```bash
   # Via Firebase Console
   # 1. Go to https://console.firebase.google.com
   # 2. Click "Add Project"
   # 3. Name: "SeaFoundry Demo"
   # 4. Project ID: seafoundryapp-demo
   # 5. Disable Google Analytics (demo doesn't need it)
   ```

2. **Enable Authentication**:
   ```bash
   # Via Console > Authentication > Sign-in method
   # Enable: Email/Password, Google
   # Match production provider configuration
   ```

3. **Enable Firestore**:
   ```bash
   # Via Console > Firestore Database > Create Database
   # Mode: Production mode (rules deployed via CLI)
   # Region: us-central1 (match production)
   ```

4. **Enable Storage**:
   ```bash
   # Via Console > Storage > Get Started
   # Security rules: Deploy via CLI
   # Region: us-central1 (match production)
   ```

5. **Download service account**:
   ```bash
   # Via Console > Project Settings > Service Accounts
   # Click "Generate new private key"
   # Save as: firebase-service-account-demo.json
   # Add to .gitignore if not already present
   ```

6. **Update Firebase project configuration**:
   ```bash
   # Edit firebase.json to add demo target
   firebase target:apply hosting demo seafoundryapp-demo
   firebase target:apply firestore demo seafoundryapp-demo
   firebase target:apply storage demo seafoundryapp-demo
   ```

7. **Generate demo Firebase options**:
   ```bash
   # Use FlutterFire CLI to generate options for demo project
   flutterfire configure --project=seafoundryapp-demo \
     --out=lib/firebase_options_demo.dart \
     --platforms=web,android,ios
   ```

#### Verification

```bash
# Verify project exists
firebase projects:list | grep seafoundryapp-demo

# Verify Firestore accessible
firebase firestore:indexes --project=seafoundryapp-demo

# Verify Storage accessible
firebase storage:buckets:list --project=seafoundryapp-demo
```

**Expected Output**: All commands succeed, demo project visible in Firebase Console.

#### Rollback (if needed)

```bash
# Delete demo project entirely (data is disposable)
# Via Console > Project Settings > General > Delete Project
```

---

### R0-B: Add Membership Subcollection (CRITICAL FOUNDATION)

**IMPORTANT**: This is the foundation for Phase R2. All org-scoped operations will eventually require membership docs.

#### Steps

1. **Update Firestore rules** (`firestore.rules`):

   Add membership subcollection rules at line ~305 (after `/organizations/{orgId}` match block):

   ```javascript
   // Membership subcollection - UID-based organization membership
   match /organizations/{orgId}/members/{uid} {
     // Read: Org members can list other members
     allow read: if isMember(orgId);

     // Create: Only during org creation or invitation acceptance
     // Cloud Functions will handle this atomically
     allow create: if isAuthenticated() && (
       // Org creator adding themselves during onboarding
       (request.auth.uid == uid && isIncomingCreator()) ||
       // Inviter adding invitee (invitation must exist)
       exists(/databases/$(database)/documents/invitations/$(request.resource.data.invitationId))
     );

     // Update: Admins can change roles, users can update their own profile
     allow update: if isOrgAdmin(orgId) || request.auth.uid == uid;

     // Delete: Only admins can remove members
     allow delete: if isOrgAdmin(orgId);
   }
   ```

2. **Add helper function** (`firestore.rules`, line ~90):

   ```javascript
   // Check if user is a member of the organization (UID-based)
   // This is the PRIMARY authorization pattern for Phase R2+
   function isMember(orgId) {
     return isAuthenticated() &&
       exists(/databases/$(database)/documents/organizations/$(orgId)/members/$(request.auth.uid));
   }
   ```

3. **Update OnboardingRepository** (`lib/repositories/onboarding_repository.dart`):

   Modify `createOrganization()` to write membership doc:

   ```dart
   Future<void> createOrganization(Organization org, User user) async {
     final batch = firestore.batch();

     // Write organization doc
     batch.set(
       firestore.collection('organizations').doc(org.id),
       org.toMap(),
     );

     // Write membership doc (NEW)
     batch.set(
       firestore
         .collection('organizations')
         .doc(org.id)
         .collection('members')
         .doc(user.uid),  // UID as doc ID
       {
         'role': 'admin',
         'status': 'active',
         'joinedAt': FieldValue.serverTimestamp(),
         'email': user.email?.toLowerCase(),  // For display/search
       },
     );

     await batch.commit();
   }
   ```

4. **Update InvitationRepository** (`lib/repositories/invitation_repository.dart`):

   Modify `acceptInvitationAtomic()` to write membership doc:

   ```dart
   Future<void> acceptInvitationAtomic(
     String invitationId,
     String userId,
     String organizationId,
   ) async {
     final batch = firestore.batch();

     // Update invitation status
     batch.update(
       firestore.collection('invitations').doc(invitationId),
       {
         'status': 'accepted',
         'acceptedAt': FieldValue.serverTimestamp(),
       },
     );

     // Update user's organizationId
     batch.update(
       firestore.collection('users').doc(userId),
       {'organizationId': organizationId},
     );

     // Create membership doc (NEW)
     batch.set(
       firestore
         .collection('organizations')
         .doc(organizationId)
         .collection('members')
         .doc(userId),  // UID as doc ID
       {
         'role': 'practitioner',  // Default role for invited users
         'status': 'active',
         'joinedAt': FieldValue.serverTimestamp(),
         'invitedBy': /* invitation.createdById */,
         'invitedAt': /* invitation.createdAt */,
       },
     );

     await batch.commit();
   }
   ```

5. **Create security tests** (`functions/test/security-rules/membership-subcollection.test.ts`):

   ```typescript
   import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';

   describe('Membership Subcollection Rules', () => {
     it('should allow org member to read members list', async () => {
       const db = getAuthenticatedDb({ uid: 'user1' });
       // ... setup membership doc for user1 in org1

       const membersRef = db
         .collection('organizations/org1/members');
       await assertSucceeds(membersRef.get());
     });

     it('should deny non-member from reading members list', async () => {
       const db = getAuthenticatedDb({ uid: 'user2' });
       // ... user2 is NOT in org1

       const membersRef = db
         .collection('organizations/org1/members');
       await assertFails(membersRef.get());
     });

     // ... more tests for create/update/delete
   });
   ```

6. **Deploy rules to production**:

   ```bash
   # Deploy rules only (no app code changes yet)
   firebase deploy --only firestore:rules

   # Verify deployment
   firebase firestore:rules:get > /tmp/deployed-rules.txt
   diff firestore.rules /tmp/deployed-rules.txt
   ```

#### Verification

```bash
# Run security tests
cd functions
npm test -- membership-subcollection.test.ts

# Test in emulator
firebase emulators:exec --only firestore \
  "npm test -- membership-subcollection.test.ts"

# Manual verification (production)
# 1. Create new org via onboarding flow
# 2. Check Firestore Console > organizations/{orgId}/members/{uid}
# 3. Verify membership doc exists with correct fields
```

**Expected Output**:
- Security tests pass (100%)
- New orgs automatically create membership docs
- Existing orgs still work (membership optional during R0-B)

#### Rollback

```bash
# Revert firestore.rules to backup
cp docs/migration/deployed-rules-backup-2026-01-07.txt firestore.rules

# Redeploy
firebase deploy --only firestore:rules

# Delete any created membership docs (optional - they're harmless)
# Via Firestore Console or script
```

---

### R0-C: Documentation & Backup

#### Steps

1. **Export deployed production rules**:

   ```bash
   # Get currently deployed rules
   firebase firestore:rules:get > docs/migration/deployed-rules-backup-2026-01-07.txt

   # Add header with metadata
   echo "Backup Date: $(date)" | cat - docs/migration/deployed-rules-backup-2026-01-07.txt > temp && mv temp docs/migration/deployed-rules-backup-2026-01-07.txt
   ```

2. **Create migration runbook**: (This document - already complete)

3. **Update firestore_collections.md**:

   Add membership subcollection documentation at line ~66:

   ```markdown
   ### Organization-Nested Collections

   | Collection | Full Path | Demo Mode Path |
   |------------|-----------|----------------|
   | `members` | `organizations/{orgId}/members` | `organizations/{orgId}/members` (demo project) |
   | `groups` | `organizations/{orgId}/groups` | `organizations/{orgId}/groups` (demo project) |
   | ... | ... | ... |

   ### Membership Schema

   **Document Path**: `/organizations/{orgId}/members/{uid}`

   ```javascript
   {
     role: "admin" | "practitioner_plus" | "practitioner" | "view_only",
     status: "active" | "invited" | "suspended",
     joinedAt: Timestamp,
     email: "user@example.com",  // Lowercase, for display/search
     invitedBy: "uid_of_inviter", // Optional
     invitedAt: Timestamp         // Optional
   }
   ```

   **Purpose**: Explicit organization membership tracking. Replaces implicit
   membership via `user.organizationId` field. Enables future multi-org support.

   **Access Control**: Org members can read, admins can write.
   ```

4. **Commit changes**:

   ```bash
   git add docs/migration/
   git commit -m "docs(migration): add R0-C documentation and backups for UID migration"
   ```

#### Verification

```bash
# Verify backup exists
test -f docs/migration/deployed-rules-backup-2026-01-07.txt && echo "Backup OK"

# Verify runbook exists
test -f docs/migration/RULES_MIGRATION_RUNBOOK.md && echo "Runbook OK"

# Verify firestore_collections.md updated
grep -q "members.*organizations/{orgId}/members" docs/architecture/firestore_collections.md && echo "Docs updated"
```

**Expected Output**: All files exist and contain expected content.

---

## Phase R1: Demo Project Split (Duration: 2-3 days)

**Risk Level**: Medium (demo only)
**Rollback Impact**: Demo mode stops working; production unaffected
**Depends On**: R0-A complete

### R1-A: Seed Demo Project

#### Steps

1. **Create seeding script** (`scripts/seed-demo-project.js`):

   ```javascript
   const admin = require('firebase-admin');

   // Initialize demo project
   const demoApp = admin.initializeApp({
     credential: admin.credential.cert(
       require('../firebase-service-account-demo.json')
     ),
   }, 'demo');

   const db = demoApp.firestore();

   // NO MORE getDemoCollection() - use raw collection names
   async function seedOrganizations() {
     await db.collection('organizations').doc('demo_org_pro').set({
       id: 'demo_org_pro',
       name: 'Demo Organization (Pro)',
       tier: 'pro',
       // ... rest of org data
     });
   }

   async function seedSites() {
     // Writes to 'sites' not 'demo_sites'
     await db.collection('sites').doc('site1').set({ /* ... */ });
   }

   // ... seed all collections
   ```

2. **Seed taxonomy data**:

   ```bash
   # Copy taxonomy from production OR seed fresh
   node scripts/seed-taxonomy-demo.js --project=seafoundryapp-demo
   ```

3. **Test seed script in emulator**:

   ```bash
   # Start emulator with demo project
   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account-demo.json \
     firebase emulators:start --only firestore --project=seafoundryapp-demo

   # Run seed script against emulator
   node scripts/seed-demo-project.js --emulator

   # Verify data in emulator UI (http://localhost:4000)
   ```

4. **Run seed script in production**:

   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account-demo.json \
     node scripts/seed-demo-project.js --project=seafoundryapp-demo --production
   ```

#### Verification

```bash
# Query demo project Firestore
firebase firestore:read organizations/demo_org_pro --project=seafoundryapp-demo

# Check collection counts
firebase firestore:collections --project=seafoundryapp-demo
```

**Expected Output**:
- `organizations`, `sites`, `events` collections exist (NOT prefixed)
- Taxonomy collections (`taxonomy_species`, etc.) exist
- Demo org `demo_org_pro` readable

#### Rollback

```bash
# Delete all Firestore data in demo project
firebase firestore:delete --all-collections --project=seafoundryapp-demo -f
```

---

### R1-B: Update DemoModeService

#### Steps

1. **Add Firebase app selection** (`lib/services/demo_mode_service.dart`):

   ```dart
   class DemoModeService {
     static FirebaseFirestore get firestore {
       if (_isDemoMode) {
         // Use demo project Firestore instance
         return FirebaseFirestore.instanceFor(app: Firebase.app('demo'));
       }
       return FirebaseFirestore.instance;  // Production
     }

     static FirebaseAuth get auth {
       if (_isDemoMode) {
         return FirebaseAuth.instanceFor(app: Firebase.app('demo'));
       }
       return FirebaseAuth.instance;
     }
   }
   ```

2. **Remove prefix logic**:

   ```dart
   // DELETE getCollectionName() entirely
   // static String getCollectionName(String baseName) { ... }

   // DELETE _globalCollections set
   // static const Set<String> _globalCollections = { ... };
   ```

3. **Update enterDemoMode()**:

   ```dart
   static Future<void> enterDemoMode() async {
     // Initialize demo Firebase app
     await Firebase.initializeApp(
       name: 'demo',
       options: DemoFirebaseOptions.currentPlatform,  // From firebase_options_demo.dart
     );

     _isDemoMode = true;
     // ... rest of demo mode setup
   }
   ```

#### Verification

```bash
# Run tests
flutter test test/services/demo_mode_service_test.dart

# Manual test: Enter demo mode in app
# 1. Launch app
# 2. Enter demo mode
# 3. Verify data loads (orgs, sites, etc.)
```

**Expected Output**: Demo mode works without `demo_` prefixes.

#### Rollback

```bash
# Revert DemoModeService changes
git checkout lib/services/demo_mode_service.dart

# Restart app (demo mode falls back to prefix logic)
```

---

### R1-C: Update FirestoreCollectionResolver

#### Steps

1. **Simplify resolver** (`lib/services/firestore_collection_resolver.dart`):

   ```dart
   class FirestoreCollectionResolver {
     static CollectionReference collection(
       FirebaseFirestore firestore,
       String collectionName,
     ) {
       // NO MORE prefix logic - firestore instance handles project selection
       return firestore.collection(collectionName);
     }

     static CollectionReference subcollection(
       FirebaseFirestore firestore,
       String parentCollection,
       String parentId,
       String subcollection,
     ) {
       // NO MORE prefix logic
       return firestore
         .collection(parentCollection)
         .doc(parentId)
         .collection(subcollection);
     }
   }
   ```

#### Verification

```bash
# Run repository tests
flutter test test/unit/repositories/

# Ensure demo mode still works after resolver simplification
```

**Expected Output**: All repository tests pass.

---

### R1-D: Deploy Demo Rules & Verify

#### Steps

1. **Deploy current rules to demo project**:

   ```bash
   # Initially deploy WITH demo_ rules for safety
   firebase deploy --only firestore:rules --project=seafoundryapp-demo
   ```

2. **End-to-end demo test**:

   ```bash
   # Launch app in demo mode
   # Verify all features work:
   # - Onboarding creates org
   # - Sites/events readable
   # - Organism creation works
   # - Taxonomy loads correctly
   ```

3. **Deploy simplified rules** (after verification):

   Create `firestore.demo.rules` (copy of production rules without demo_ blocks):

   ```bash
   # Remove all demo_ match blocks from firestore.rules
   # Save as firestore.demo.rules

   # Deploy to demo project
   firebase deploy --only firestore:rules \
     --config firestore.demo.rules \
     --project=seafoundryapp-demo
   ```

#### Verification

```bash
# Check deployed rules
firebase firestore:rules:get --project=seafoundryapp-demo > /tmp/demo-rules.txt

# Verify no demo_ blocks present
! grep -q "match /demo_" /tmp/demo-rules.txt && echo "Simplified rules deployed"
```

**Expected Output**: Demo project uses simplified rules, demo mode works end-to-end.

#### Rollback

```bash
# Redeploy rules with demo_ blocks
firebase deploy --only firestore:rules --project=seafoundryapp-demo

# Revert DemoModeService to use prefix logic
git checkout lib/services/demo_mode_service.dart
git checkout lib/services/firestore_collection_resolver.dart
```

---

## Phase R2: UID-Based Identity Migration (Duration: 3-5 days)

**Risk Level**: High
**Rollback Impact**: Moderate (dual-write provides safety)
**Depends On**: R0-B (membership docs being written)

### R2-A: Add UID User Documents

#### Steps

1. **Update OnboardingRepository** (`lib/repositories/onboarding_repository.dart`):

   ```dart
   Future<void> createUser(User user) async {
     final batch = firestore.batch();

     // Write UID-keyed doc (NEW)
     batch.set(
       firestore.collection('users').doc(user.uid),
       {
         'uid': user.uid,
         'email': user.email,
         'emailLower': user.email?.toLowerCase(),
         'displayName': user.displayName,
         'organizationId': user.organizationId,
         'role': user.role,
         // Note: isAdmin is computed from role == 'admin', not stored
         'createdAt': FieldValue.serverTimestamp(),
         'updatedAt': FieldValue.serverTimestamp(),
       },
     );

     // KEEP writing email-keyed doc for backwards compatibility
     batch.set(
       firestore.collection('users').doc(user.email?.toLowerCase()),
       { /* same data */ },
     );

     await batch.commit();
   }
   ```

2. **Update RecordRepository** (`lib/repositories/record_repository.dart`):

   ```dart
   // Change createdById/updatedById to use UID
   Future<void> createRecord<T>(T record) async {
     final data = record.toMap();
     data['createdById'] = _auth.currentUser?.uid;  // Changed from email
     data['createdAt'] = FieldValue.serverTimestamp();

     await _collection.doc(record.id).set(data);
   }
   ```

3. **Update DemoModeService** (`lib/services/demo_mode_service.dart`):

   ```dart
   static Future<void> _ensureDemoUser() async {
     final user = auth.currentUser;
     if (user == null) return;

     // Write to UID-keyed doc (NEW)
     await firestore.collection('users').doc(user.uid).set({
       'uid': user.uid,
       'emailLower': user.email?.toLowerCase(),
       'organizationId': 'demo_org_pro',
       'isDemo': true,
       // ...
     });
   }
   ```

#### Verification

```bash
# Create new user via onboarding
# Check Firestore Console: /users/{uid} doc exists
# Check Firestore Console: /users/{email} doc ALSO exists (dual-write)

# Run analyzer
flutter analyze

# Run tests
flutter test
```

**Expected Output**:
- New users have BOTH `/users/{uid}` and `/users/{email}` docs
- Existing users still work (email docs remain)
- Tests pass

---

### R2-B: Update Firestore Rules Helpers

#### Steps

1. **Add UID-based getUserDoc()** (`firestore.rules`, line ~36):

   ```javascript
   // NEW: UID-based user lookup (primary)
   function getUserDoc() {
     return get(/databases/$(database)/documents/users/$(request.auth.uid));
   }

   // KEEP: Email-based fallback (for transition period)
   function getUserDocByEmail() {
     return get(/databases/$(database)/documents/users/$(getAuthEmailLower()));
   }

   // Wrapper that tries UID first, falls back to email
   function getUserDocSafe() {
     let uidDoc = getUserDoc();
     if (uidDoc.data != null) {
       return uidDoc;
     }
     return getUserDocByEmail();
   }
   ```

2. **Update collection rules**:

   ```javascript
   // Example: Update sites collection
   match /sites/{siteId} {
     allow read: if resourceBelongsToUserOrg();  // Uses getUserDocSafe()
     // ...
   }

   // Update resourceBelongsToUserOrg() to use getUserDocSafe()
   function resourceBelongsToUserOrg() {
     let userDoc = getUserDocSafe();  // Changed
     return isAuthenticated() &&
            userDoc.data != null &&
            resource.data.organizationId == userDoc.data.organizationId;
   }
   ```

3. **Deploy rules**:

   ```bash
   firebase deploy --only firestore:rules
   ```

#### Verification

```bash
# Create new user (UID doc)
# Verify can access org-scoped resources

# Existing user (email doc)
# Verify STILL works via fallback
```

**Expected Output**: Both UID and email-keyed users work.

---

### R2-C: Backfill Script

#### Steps

1. **Create migration script** (`scripts/migrate-users-to-uid.js`):

   ```javascript
   const admin = require('firebase-admin');
   admin.initializeApp();
   const db = admin.firestore();
   const auth = admin.auth();

   async function migrateUsers() {
     // Get all /users/{email} docs
     const usersSnapshot = await db.collection('users').get();

     for (const userDoc of usersSnapshot.docs) {
       const email = userDoc.id;
       const userData = userDoc.data();

       // Skip if already a UID (docs starting with uid_ or Firebase UID format)
       if (email.length < 30 || !email.includes('@')) {
         console.log(`Skipping non-email doc: ${email}`);
         continue;
       }

       // Get Firebase Auth user by email
       let authUser;
       try {
         authUser = await auth.getUserByEmail(email);
       } catch (err) {
         console.error(`No auth user for ${email}:`, err.message);
         continue;
       }

       const uid = authUser.uid;

       // Check if UID doc already exists
       const uidDoc = await db.collection('users').doc(uid).get();
       if (uidDoc.exists) {
         console.log(`UID doc exists for ${email}, skipping`);
         continue;
       }

       // Create UID-keyed doc
       await db.collection('users').doc(uid).set({
         ...userData,
         uid: uid,
         emailLower: email,
         migratedAt: admin.firestore.FieldValue.serverTimestamp(),
       });

       // Create membership doc
       const orgId = userData.organizationId;
       if (orgId) {
         await db
           .collection('organizations')
           .doc(orgId)
           .collection('members')
           .doc(uid)
           .set({
             role: userData.role || 'practitioner',
             status: 'active',
             joinedAt: userData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
             email: email,
           });
       }

       console.log(`Migrated ${email} → ${uid}`);
     }
   }

   // DRY RUN mode
   if (process.argv.includes('--dry-run')) {
     console.log('DRY RUN MODE - no changes will be made');
     migrateUsers().then(() => console.log('Dry run complete'));
   } else {
     migrateUsers().then(() => console.log('Migration complete'));
   }
   ```

2. **Run dry run**:

   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
     node scripts/migrate-users-to-uid.js --dry-run
   ```

3. **Execute migration**:

   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json \
     node scripts/migrate-users-to-uid.js
   ```

#### Verification

```bash
# Check Firestore Console
# - /users/{uid} docs exist for all migrated users
# - /organizations/{orgId}/members/{uid} docs exist
# - /users/{email} docs still exist (not deleted yet)

# Test existing user login
# - Should use UID doc automatically via getUserDocSafe()
```

**Expected Output**: All existing users have UID docs + membership docs.

---

### R2-D: Update Storage Rules

#### Steps

1. **Update storage.rules** (`storage.rules`):

   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       // Organization-scoped files
       match /organizations/{orgId}/{allPaths=**} {
         allow read, write: if request.auth != null && (
           // NEW: Check membership subcollection (primary)
           firestore.exists(
             /databases/(default)/documents/organizations/$(orgId)/members/$(request.auth.uid)
           ) ||
           // FALLBACK: Check email-keyed user doc (during transition)
           firestore.get(
             /databases/(default)/documents/users/$(request.auth.token.email.lower())
           ).data.organizationId == orgId
         );
       }
     }
   }
   ```

2. **Deploy storage rules**:

   ```bash
   firebase deploy --only storage
   ```

#### Verification

```bash
# Upload file as new user (with membership doc)
# - Should succeed via membership check

# Upload file as existing user (email doc only)
# - Should succeed via email fallback

# Upload file as non-member
# - Should fail with permission-denied
```

**Expected Output**: Both UID-based and email-based users can upload.

---

## Phase R3: Rules Cleanup (Duration: 2-3 days)

**Risk Level**: Medium
**Rollback Impact**: High (revert to R0-B backup)
**Depends On**: R1 + R2 complete, verified for 7 days

### R3-A: Remove Demo Rules from Production

#### Steps

1. **Delete demo_ rules** (`firestore.rules`):

   ```bash
   # Remove all match blocks for:
   # - demo_organizations, demo_users, demo_sites
   # - demo_events, demo_groups, demo_genets
   # - demo_posts, demo_post_comments
   # - All other demo_ collections (~600 lines total)

   # Remove helper functions:
   # - getDemoUserDoc()
   # - resourceBelongsToUserOrgDemo()
   # - incomingBelongsToUserOrgDemo()
   # - isOrgMemberDemo()
   # - isOrgMemberOrCreatorDemo()
   # - isDemoOrg(), isValidDemoTransfer()
   ```

2. **Deploy to production**:

   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Verify production unaffected**:

   ```bash
   # Test production login, org access, file uploads
   # Demo mode should still work (separate project)
   ```

#### Verification

```bash
# Count remaining lines
wc -l firestore.rules
# Expected: ~400 lines (down from ~1,476)

# Verify no demo_ blocks
! grep -q "match /demo_" firestore.rules && echo "Demo rules removed"
```

**Expected Output**: Production rules simplified, demo project unaffected.

#### Rollback

```bash
cp docs/migration/deployed-rules-backup-2026-01-07.txt firestore.rules
firebase deploy --only firestore:rules
```

---

### R3-B: Remove Onboarding Fallbacks

**IMPORTANT**: Only do this AFTER verifying Cloud Functions handle atomic writes.

#### Steps

1. **Verify atomic onboarding**:

   ```bash
   # Create new org via onboarding
   # Check Firestore: user doc + membership doc created in same batch
   # No delay between user doc and membership doc creation
   ```

2. **Remove fallback helpers** (`firestore.rules`):

   ```javascript
   // DELETE these functions:
   // - isUserOnboardingEligible()
   // - isIncomingCreator()
   // - isResourceCreator() (from read rules only)
   ```

3. **Update collection rules**:

   ```javascript
   // BEFORE (with fallbacks):
   allow create: if incomingBelongsToUserOrg() ||
     (isIncomingCreator() && isUserOnboardingEligible());

   // AFTER (membership-only):
   allow create: if isMember(request.resource.data.organizationId);
   ```

4. **Deploy**:

   ```bash
   firebase deploy --only firestore:rules
   ```

#### Verification

```bash
# Test onboarding
# - Should succeed (membership doc created atomically)

# Test org-scoped operations
# - Should succeed only for members (no creator fallback)
```

**Expected Output**: Onboarding still works, no fallback logic triggered.

---

### R3-C: Consolidate Rulesets

#### Steps

1. **Audit firestore.community.rules**:

   ```bash
   # Compare with firestore.rules
   diff firestore.rules firestore.community.rules

   # Document differences
   # - Community: More permissive post/comment rules?
   # - Community: Different tier enforcement?
   ```

2. **Merge unique rules**:

   ```bash
   # Copy any unique community rules into firestore.rules
   # Delete firestore.community.rules

   git rm firestore.community.rules
   ```

3. **Update CI** (`.github/workflows/demo-mode-verification.yml`):

   ```yaml
   # Remove firestore.community.rules from triggers
   paths:
     - 'firestore.rules'  # Single ruleset
     # DELETE: - 'firestore.community.rules'
   ```

4. **Deploy**:

   ```bash
   firebase deploy --only firestore:rules
   ```

#### Verification

```bash
# Test community features (posts, comments)
# - Should work with merged rules

# Test tier enforcement
# - Pro features blocked for community tier
```

**Expected Output**: Single ruleset deployed, community features work.

---

## Phase R4: Cleanup & Documentation (Duration: 1-2 days)

**Risk Level**: Low
**Rollback Impact**: Minimal
**Depends On**: R3 complete, 30-day verification window passed

### R4-A: Remove Dead Code

#### Steps

1. **Remove DemoModeService dead code**:

   ```dart
   // DELETE from lib/services/demo_mode_service.dart:
   // - _globalCollections set
   // - getCollectionName() method (already removed in R1-B)
   ```

2. **Archive deprecated seed scripts**:

   ```bash
   mkdir -p scripts/deprecated
   git mv scripts/enhance-pro-demo.js scripts/deprecated/
   git mv scripts/enhance-community-demo.js scripts/deprecated/

   # Keep only:
   # - scripts/seed-demo-project.js (new demo project seeder)
   # - scripts/migrate-users-to-uid.js (one-time migration)
   ```

3. **Remove email-keyed user writes** (after 30-day verification):

   ```dart
   // OnboardingRepository.createUser() - DELETE dual-write
   // BEFORE:
   batch.set(firestore.collection('users').doc(user.uid), { /* ... */ });
   batch.set(firestore.collection('users').doc(user.email?.toLowerCase()), { /* ... */ });

   // AFTER:
   batch.set(firestore.collection('users').doc(user.uid), { /* ... */ });
   ```

#### Verification

```bash
# Run tests after cleanup
flutter test

# Verify analyzer clean
flutter analyze
```

**Expected Output**: Tests pass, no dead code remains.

---

### R4-B: Update Documentation

#### Steps

1. **Update identity_scheme.md**:

   ```markdown
   # Identity Scheme (Post-Migration)

   **Canonical Identifier**: Firebase UID

   - User documents: `/users/{uid}`
   - createdById/updatedById: UID strings
   - Membership: `/organizations/{orgId}/members/{uid}`

   **Demo Mode**: Separate Firebase project (`seafoundryapp-demo`)
   - No prefix logic
   - Same collection names as production
   - Isolated data
   ```

2. **Update firestore_collections.md**:

   ```markdown
   ## Demo Mode Behavior (Updated)

   Demo data is stored in a **separate Firebase project** (`seafoundryapp-demo`).
   Collections use the SAME names as production (no `demo_` prefix).

   DemoModeService selects the Firebase project based on mode:
   - Production: `Firebase.app()` (default)
   - Demo: `Firebase.app('demo')`
   ```

3. **Create demo_project.md**:

   ```markdown
   # Demo Project Architecture

   ## Overview
   Demo mode uses a separate Firebase project for complete data isolation.

   ## Project Details
   - Project ID: `seafoundryapp-demo`
   - Region: `us-central1` (matches production)
   - Purpose: Isolated demo environment for testing/exploration

   ## Seeding
   Run: `node scripts/seed-demo-project.js --production`
   ```

4. **Update DEMO_RESEED.md**:

   ```markdown
   # Demo Reseeding (Updated)

   ## Quick Command
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account-demo.json \
     node scripts/seed-demo-project.js --production
   ```

   No more `--tier` or `--reset` flags - demo project is completely isolated.
   ```

#### Verification

```bash
# Check documentation completeness
grep -l "UID" docs/architecture/*.md
grep -l "seafoundryapp-demo" docs/architecture/*.md
```

**Expected Output**: All docs updated with UID and demo project info.

---

### R4-C: Final Cleanup (After 30-Day Window)

**CRITICAL**: Only run this AFTER verifying 100% of users migrated to UID.

#### Steps

1. **Verify migration complete**:

   ```bash
   # Check Firestore Console metrics
   # - /users collection: Count docs
   # - Filter by doc ID length (UIDs are 28 chars, emails are longer)
   # - If 0 email-keyed docs, safe to proceed

   # Or run query:
   node scripts/check-email-docs.js
   ```

2. **Delete email-keyed user docs**:

   ```bash
   # Create cleanup script
   node scripts/cleanup-email-user-docs.js --dry-run

   # Execute (IRREVERSIBLE)
   node scripts/cleanup-email-user-docs.js
   ```

3. **Remove email fallback from rules**:

   ```javascript
   // DELETE getUserDocByEmail() and getUserDocSafe()

   // CHANGE getUserDoc() to ONLY use UID:
   function getUserDoc() {
     return get(/databases/$(database)/documents/users/$(request.auth.uid));
   }
   ```

4. **Deploy final rules**:

   ```bash
   firebase deploy --only firestore:rules
   ```

#### Verification

```bash
# Test login/org access
# - Should work (UID docs only)

# Check Firestore Console
# - /users collection: Only UID-keyed docs remain
```

**Expected Output**: Email-keyed docs deleted, rules simplified.

**Rollback**: NOT POSSIBLE - email docs are deleted. Only proceed after 30-day verification.

---

## Emergency Rollback Procedures

### R0 Rollback (Preparation Phase)

**Trigger**: Membership rules cause issues

```bash
# Restore backup rules
cp docs/migration/deployed-rules-backup-2026-01-07.txt firestore.rules

# Deploy
firebase deploy --only firestore:rules

# Delete membership docs (optional - they're harmless)
# Via Firestore Console or script
```

**Impact**: Low - app falls back to email-based identity

---

### R1 Rollback (Demo Project Split)

**Trigger**: Demo mode broken after demo project split

```bash
# Revert DemoModeService
git checkout lib/services/demo_mode_service.dart
git checkout lib/services/firestore_collection_resolver.dart

# Rebuild app
flutter clean && flutter build web

# Re-enable demo prefix logic
# (DemoModeService.getCollectionName() restored via git checkout)
```

**Impact**: Low - demo data in separate project is disposable

---

### R2 Rollback (UID Migration)

**Trigger**: UID-based lookups failing, critical production issues

```bash
# Restore backup rules (email-based getUserDoc)
cp docs/migration/deployed-rules-backup-2026-01-07.txt firestore.rules

# Deploy
firebase deploy --only firestore:rules

# Revert app code (dual-write remains, but UID docs ignored)
git checkout lib/repositories/onboarding_repository.dart
git checkout lib/repositories/record_repository.dart

# Rebuild
flutter clean && flutter build web
```

**Impact**: Moderate - UID docs exist but are ignored; email docs used

**Recovery**: Re-run migration after fixing issues

---

### R3 Rollback (Rules Cleanup)

**Trigger**: Production broken after demo rules removed

```bash
# Restore full backup (includes demo_ rules)
cp docs/migration/deployed-rules-backup-2026-01-07.txt firestore.rules

# Deploy
firebase deploy --only firestore:rules
```

**Impact**: High - re-introduces 600 lines of demo rules

---

### R4 Rollback (Final Cleanup)

**Trigger**: Email doc deletion was premature

**Status**: NOT POSSIBLE - email docs are deleted

**Prevention**: Only run R4-C after 30-day verification window

---

## Monitoring & Verification

### Phase Completion Checkpoints

| Phase | Checkpoint | Success Criteria |
|-------|-----------|-----------------|
| R0-A | Demo project created | Firestore + Auth + Storage enabled |
| R0-B | Membership docs written | New orgs have `/organizations/{orgId}/members/{uid}` |
| R0-C | Backups created | `deployed-rules-backup-2026-01-07.txt` exists |
| R1-A | Demo data seeded | Collections exist without `demo_` prefix |
| R1-B | DemoModeService updated | Prefix logic removed |
| R1-D | Demo rules deployed | Demo project uses simplified rules |
| R2-A | UID docs created | New users have `/users/{uid}` docs |
| R2-C | Backfill complete | All users have UID docs + membership docs |
| R2-D | Storage rules updated | File uploads work for UID + email users |
| R3-A | Demo rules removed | Production rules ~400 lines |
| R3-B | Fallbacks removed | Onboarding uses membership checks only |
| R4-C | Email docs deleted | Only UID-keyed docs remain (30 days after R2) |

### Metrics to Track

```bash
# User document distribution
# Expected: 100% UID-keyed after R2-C
firebase firestore:query users --limit=100 | jq '.[] | .id' | wc -l

# Membership doc count
# Expected: Equal to active user count
firebase firestore:query organizations/*/members --limit=1000 | jq '. | length'

# Rules file size
# Expected: ~400 lines after R3-A
wc -l firestore.rules

# Demo prefix usage
# Expected: 0 matches after R1-B
grep -c "demo_" lib/services/demo_mode_service.dart
```

### Error Budget

| Error Type | Acceptable Rate | Alert Threshold |
|------------|----------------|-----------------|
| Permission-denied during R0-R2 | 5% (fallbacks active) | >10% |
| Permission-denied after R3 | 0.1% | >1% |
| Storage upload failures | 2% (dual rules) | >5% |
| Demo mode login failures | 10% (separate project) | >20% |

---

## Emergency Contacts

| Role | Contact | Responsibility |
|------|---------|---------------|
| Migration Lead | [Your Name] | Overall coordination |
| Firebase Admin | [Admin Name] | Project/rules deployment |
| Backend Engineer | [Engineer Name] | Cloud Functions, seed scripts |
| QA Lead | [QA Name] | Verification testing |
| On-Call Engineer | [Rotation] | Production incident response |

---

## Post-Migration Validation

### Day 1 After Each Phase

```bash
# Check error logs
firebase functions:log --limit=100 | grep -i "permission"

# Check user metrics
# - New user signups: Should succeed
# - Org creation: Should create membership docs
# - File uploads: Should succeed for all users

# Monitor Firebase Console > Firestore > Usage
# - Read count: Should be stable (not spiking due to fallbacks)
```

### Week 1 After R2 (UID Migration)

```bash
# Verify fallback usage
# - Run query: How many email-keyed docs still accessed?
# - Goal: <1% of requests use email fallback

# Check membership doc coverage
# - All orgs have members
# - All active users have membership in at least one org
```

### Week 4 After R2 (Before R4-C)

```bash
# Final verification before email doc deletion
# - 0% email-based lookups for 7 consecutive days
# - All users logged in at least once (UID doc verified)
# - No permission-denied errors related to membership

# If all checks pass: Proceed with R4-C (email doc deletion)
```

---

## Appendix: Common Issues & Solutions

### Issue: "Permission denied" during onboarding (Phase R0-R2)

**Symptoms**: New users can't create org/sites

**Cause**: Membership doc not created atomically

**Solution**:
```dart
// Verify OnboardingRepository.createOrganization() uses batch write
// Membership doc MUST be in same batch as org doc
```

---

### Issue: Demo mode shows no data (Phase R1)

**Symptoms**: Empty org list, no sites/events

**Cause**: Data seeded to wrong collection (prefix mismatch)

**Solution**:
```bash
# Re-run seed script targeting demo project
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account-demo.json \
  node scripts/seed-demo-project.js --project=seafoundryapp-demo --production
```

---

### Issue: Storage uploads fail (Phase R2-D)

**Symptoms**: "Permission denied" on file upload

**Cause**: Storage rules don't check membership subcollection

**Solution**:
```javascript
// storage.rules - verify membership check present:
firestore.exists(
  /databases/(default)/documents/organizations/$(orgId)/members/$(request.auth.uid)
)
```

---

### Issue: "User doc not found" errors spike (Phase R2)

**Symptoms**: Permission errors, failed queries

**Cause**: UID-based lookup hitting missing docs

**Solution**:
```bash
# Run backfill script immediately
node scripts/migrate-users-to-uid.js

# Verify all users have UID docs
```

---

### Issue: Community rules diverge from production (Phase R3-C)

**Symptoms**: Features work differently in community build

**Cause**: Separate rulesets maintained manually

**Solution**:
```bash
# Consolidate into single ruleset
# Use feature flags in rules if community needs different logic:

function isCommunityBuild() {
  // Check tier or custom claim
  return request.auth.token.tier == 'community';
}
```

---

## Success Metrics

| Metric | Baseline (Pre-Migration) | Target (Post-Migration) |
|--------|-------------------------|------------------------|
| Rules file size | 1,476 lines | 400 lines (-73%) |
| Helper functions | 25 | 8 (-68%) |
| Demo-specific code | ~600 lines | 0 (-100%) |
| Permission-denied errors | 2-5% | <0.5% (-75%) |
| User onboarding success rate | 95% | >99% |
| Demo mode reliability | 85% | >99% |
| Rules deployment time | 5-10 min (2 rulesets) | 2-3 min (1 ruleset) |

---

**End of Runbook**

For questions or issues during migration, contact Migration Lead or refer to:
- `.github/issues/firestore-permissions-remediation-plan.md`
- `docs/architecture/identity_scheme.md`
- `docs/architecture/firestore_collections.md`
