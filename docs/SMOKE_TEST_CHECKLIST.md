# Firestore Permissions Smoke Test Checklist

**Purpose**: Verify Firestore and Storage security rules after Phase 0-2 remediation fixes.
**Context**: FP3-B1 - Demo/Prod Smoke Tests

## Pre-Flight Checks

Before running smoke tests:

- [ ] Firestore rules deployed: `firebase deploy --only firestore:rules`
- [ ] Storage rules deployed: `firebase deploy --only storage:rules`
- [ ] Demo data seeded (if testing demo): `npm run seed:demo`
- [ ] Test user credentials available (see `.env.demo` for demo users)

## Test Environment Setup

### Option A: Firebase Emulators (Recommended for Development)

```bash
# Start emulators
firebase emulators:start --only auth,firestore,storage

# In separate terminal, seed demo data
npm run seed:demo
npm run seed:demo
```

### Option B: Production (Use with Caution)

```bash
# Ensure service account credentials available
export GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json

# Seed production demo data
node scripts/seed-demo.js --reset
```

---

## 1. Onboarding Smoke Tests

### 1.1 New User Account Creation

**Objective**: Verify new users can create accounts and user documents use UID-based identity.

#### Manual Steps (Web App)

1. **Navigate to sign-up page**
   - Open app in incognito/private browsing
   - Click "Sign Up" or "Create Account"

2. **Create account**
   - Email: `Test.User@Example.com`
   - Password: `TestPassword123!`
   - Submit form

3. **Expected Outcomes**:
   - ✅ Account created successfully
   - ✅ Redirected to onboarding/organization creation
   - ✅ No permission denied errors in browser console

#### Automated Verification

```bash
# Run verification script
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

**Expected**:
- User document exists at `/users/{uid}`
- Document has `email`, `organizationId`, `role` fields
- No document at `/users/{email.lower()}` (legacy path should not exist)

### 1.2 Organization Creation

**Objective**: Verify new users can create organizations.

#### Manual Steps

1. **Continue from successful account creation**
2. **Fill organization creation form**:
   - Organization name: "Test Coral Nursery"
   - Submit form

3. **Expected Outcomes**:
   - ✅ Organization created
   - ✅ User's `organizationId` field populated
  - ✅ User role set to `admin`
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify org creation and user membership
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

### 1.3 First Site Creation

**Objective**: Verify org members can create sites.

#### Manual Steps

1. **Navigate to Sites section**
2. **Click "Create Site" or "Add Site"**
3. **Fill site creation form**:
   - Site name: "North Nursery"
   - Site type: "Nursery"
   - Location: Any valid coordinates
   - Submit

4. **Expected Outcomes**:
   - ✅ Site created successfully
   - ✅ Site visible in site list
   - ✅ Site `organizationId` matches user's org
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify site access rules
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

### 1.4 First Organism Record Creation

**Objective**: Verify org members can create organism records.

#### Manual Steps

1. **Navigate to Inventory or Organisms section**
2. **Click "Add Organism" or similar**
3. **Fill organism creation form**:
   - Species: Select any taxonomy species
   - Genet: Create new genet or select existing
   - Life stage: Adult/Juvenile
   - Physical form: Colony/Fragment
   - Submit

4. **Expected Outcomes**:
   - ✅ Organism record created
   - ✅ Record visible in inventory
   - ✅ Record `organizationId` matches user's org
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify organism creation and access
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

### 1.5 Demo User Onboarding

**Objective**: Verify demo users can access demo data without permission errors.

#### Manual Steps

1. **Sign in as demo user** (Community tier):
   - Email: `community@provenance.app`
   - Password: `demo123`

2. **Navigate through demo org**:
   - View sites (should see demo sites)
   - View inventory (should see demo organisms)
   - View events timeline
   - Create a new organism record
   - Create a test event

3. **Expected Outcomes**:
   - ✅ Demo user document in `/users/{uid}`
   - ✅ Demo data visible (sites, organisms, events)
   - ✅ Can create new records in demo org
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify demo user access
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=demo --demo-tier=community
```

**Expected**:
- Demo user doc exists at `/users/{uid}`
- Demo org exists (`demo_org_community`)
- Demo sites/organisms accessible

---

## 2. Taxonomy Admin Smoke Tests

**Objective**: Verify taxonomy collections are globally accessible and overrides have correct governance.

### 2.1 Taxonomy Species Read Access

**Identity Scheme Note**: Taxonomy collections are GLOBAL (not demo-prefixed, shared across all orgs).

#### Manual Steps

1. **Sign in as any authenticated user**
2. **Navigate to organism creation or species selection**
3. **Verify species dropdown/list populates**

4. **Expected Outcomes**:
   - ✅ Taxonomy species data loads
   - ✅ No "permission denied" errors
   - ✅ Both demo and prod users see same species list

#### Automated Verification

```bash
# Verify taxonomy read access for regular user
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=taxonomy
```

**Expected**:
- Read succeeds for authenticated users
- Collection is NOT prefixed with `demo_` in demo mode

### 2.2 Taxonomy Provenances Read Access

#### Manual Steps

1. **Navigate to provenance selection (genet creation)**
2. **Verify provenance options load**

3. **Expected Outcomes**:
   - ✅ Provenance data loads
   - ✅ Shows options: Wild, Sexual Cohort, Asexual Fragment, etc.
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify provenance read access
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=taxonomy
```

### 2.3 Taxonomy Lineages Read Access

#### Manual Steps

1. **Navigate to genet or lineage management**
2. **Verify lineage data loads**

3. **Expected Outcomes**:
   - ✅ Lineage data accessible
   - ✅ No permission errors

#### Automated Verification

```bash
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=taxonomy
```

### 2.4 Taxonomy Overrides - Admin Write Access

**Governance Note**: `taxonomy_overrides` is GLOBAL but admin-only for writes (per FP1-B5).

#### Manual Steps (Admin User)

1. **Sign in as admin user** (user with `role: admin` or service account)
2. **Navigate to Taxonomy Admin Panel** (if available)
3. **Attempt to create/modify taxonomy override**

4. **Expected Outcomes**:
   - ✅ Admin can read `taxonomy_overrides`
   - ✅ Admin can write `taxonomy_overrides`
   - ✅ Override documents are NOT prefixed with `demo_`

#### Automated Verification

```bash
# Verify admin write access
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=taxonomy
```

### 2.5 Taxonomy Overrides - Non-Admin Read-Only

#### Manual Steps (Regular User)

1. **Sign in as non-admin user**
2. **Access any feature that reads taxonomy overrides**

3. **Expected Outcomes**:
   - ✅ Regular user CAN read `taxonomy_overrides`
   - ✅ Regular user CANNOT write `taxonomy_overrides` (permission denied expected)

#### Automated Verification

```bash
# Verify non-admin cannot write
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=taxonomy

# Expected: Write attempt fails with permission denied
```

**Expected**:
- Read succeeds
- Write fails with: `FirebaseError: Missing or insufficient permissions`

---

## 3. Training Progress Smoke Tests

**Identity Scheme Note**: Training progress uses **UID-based access**.
**Rationale**: Cross-org user-specific data (persists across org switches).

### 3.1 User Can Read Own Training Progress

#### Manual Steps

1. **Sign in as any user**
2. **Navigate to Training or Onboarding Tour**
3. **Complete a training step or tour step**

4. **Expected Outcomes**:
   - ✅ Training progress saves
   - ✅ Progress persists across sessions
   - ✅ No permission errors

#### Automated Verification

```bash
# Verify UID-based onboarding identity checks
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

**Expected**:
- User document exists at `/users/{uid}`
- `organizationId` and membership documents align with UID-based rules

### 3.2 User Cannot Read Other User's Training Progress

#### Automated Verification

Community build note: training-progress flows are not part of this fork.

### 3.3 Demo Training Progress Isolation

#### Manual Steps

1. **Sign in as demo user**
2. **Complete onboarding + initial inventory flow**
3. **Verify all created documents remain UID-keyed and org-scoped**

#### Automated Verification

```bash
# Verify demo-mode checks for community org
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=demo --demo-tier=community
```

**Expected**:
- Demo user identity remains UID-based
- Demo org routing targets `demo_org_community`

---

## 4. Storage Upload Smoke Tests

**Identity Scheme Fix**: Storage rules now use **UID-based user lookup**.

### 4.1 Organization-Scoped Storage Upload

**Fixed Issue**: `storage.rules` uses `request.auth.uid` for user lookups.

#### Manual Steps

1. **Sign in as org member**
2. **Navigate to any upload feature** (organism images, site photos, etc.)
3. **Upload a test image**
   - File path will be: `/organizations/{orgId}/{file}`

4. **Expected Outcomes**:
   - ✅ Upload succeeds
   - ✅ File accessible via download URL
   - ✅ No permission denied errors

#### Automated Verification

```bash
# Verify storage upload with UID-based lookup
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=storage --uid="test_uid"
```

**Expected**:
- User document lookup at `/users/{uid}` succeeds
- User's `organizationId` matches upload path `orgId`
- Upload succeeds

### 4.2 User Cannot Upload to Other Org's Storage

#### Automated Verification

```bash
# Verify cross-org upload protection
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=storage --uid="user1_uid"
```

**Expected**:
- Upload attempt fails with permission denied
- User's `organizationId` does NOT match target `orgId`

### 4.3 User-Specific Storage Upload

**Path**: `/users/{userId}/{file}` (where `userId` is Firebase UID)

#### Manual Steps

1. **Trigger user-specific upload** (profile photo, temp files)
2. **Upload file**

3. **Expected Outcomes**:
   - ✅ Upload succeeds to `/users/{uid}/...`
   - ✅ User can read their own files

#### Automated Verification

```bash
# Verify user-specific storage
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=storage --uid="test_uid"
```

**Expected**:
- Upload to `/users/{uid}/{file}` succeeds
- Rule compares `request.auth.uid == userId`

### 4.4 Demo User Storage Upload

#### Manual Steps

1. **Sign in as demo user**
2. **Upload image to demo org**

3. **Expected Outcomes**:
   - ✅ Upload succeeds to `/organizations/demo_org_community/...`
   - ✅ Demo user document lookup succeeds via UID

#### Automated Verification

```bash
# Verify demo storage access
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=storage --uid="demo_uid"
```

**Expected**:
- Demo user doc at `/users/{uid}`
- User's `organizationId == 'demo_org_community'`
- Upload succeeds

---

## 5. Cross-Cutting Verification Tests

### 5.1 UID Identity Stability

**Objective**: Verify user lookups use UID regardless of email casing or changes.

#### Automated Verification

```bash
# Verify onboarding with UID-based identity
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=onboarding --uid="test_uid"
```

**Test Cases**:
- Create user with any email casing
- Verify doc at `/users/{uid}`
- Confirm permissions keyed to UID remain stable

### 5.2 Demo Prefixing Consistency

**Objective**: Verify global collections are NOT prefixed in demo mode.

#### Automated Verification

```bash
# Verify demo collection routing
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=demo --demo-tier=community
```

**Expected**:
- `taxonomy_species` → NOT prefixed (global collection)
- `taxonomy_provenances` → NOT prefixed (global collection)
- `taxonomy_lineages` → NOT prefixed (global collection)
- `taxonomy_overrides` → NOT prefixed (global collection)
- `sites` → PREFIXED to `demo_sites` (org-scoped)
- `events` → PREFIXED to `demo_events` (org-scoped)

### 5.3 Dead Rules Verification

**Objective**: Verify dead demo taxonomy rules are unreachable (removed in FP1-B).

#### Manual Check

```bash
# Search for dead rules in firestore.rules
grep -n "demo_taxonomy_species" firestore.rules
grep -n "demo_taxonomy_provenances" firestore.rules
grep -n "demo_taxonomy_lineages" firestore.rules
```

**Expected**:
- These rules should be REMOVED (Phase 1 cleanup)
- If present, they are unreachable (never hit due to `_globalCollections`)

---

## 6. Regression Tests

### 6.1 Community Rules Identity Consistency

**Fixed Issue**: `firestore.rules` updated to UID-based identity (email only for invitations).

#### Automated Verification

```bash
# Verify community rules use UID-based identity
FIRESTORE_EMULATOR_HOST=localhost:58080 node scripts/verify-permissions.js --category=all
```

**Expected**:
- Invitation rules use email matching for invitee access only
- Message rules use UID-based membership checks
- UID is the primary identity in all non-invitation rules

### 6.2 Resolver Bypass Audit

**Objective**: Verify no direct Firestore access bypasses `FirestoreCollectionResolver`.

#### Manual Check

```bash
# Audit codebase for direct Firestore access
grep -r "FirebaseFirestore.instance.collection" lib/ --include="*.dart" | grep -v resolver | grep -v "// OK:"
```

**Expected**:
- Zero results (all access goes through resolver)
- If results found, verify they are safe or fix in Phase 2

---

## 7. Production Deployment Checklist

### Pre-Deployment

- [ ] All smoke tests pass in emulator environment
- [ ] `flutter analyze` reports 0 errors, 0 warnings
- [ ] Firestore rules diff reviewed (`firebase deploy --only firestore:rules --dry-run`)
- [ ] Storage rules diff reviewed (`firebase deploy --only storage:rules --dry-run`)

### Deployment Steps

```bash
# 1. Deploy Firestore rules
firebase deploy --only firestore:rules

# 2. Deploy Storage rules
firebase deploy --only storage:rules

# 3. Verify deployment
firebase deploy --only firestore:rules,storage:rules --dry-run
```

### Post-Deployment Verification

- [ ] Run production smoke tests (use production credentials)
- [ ] Verify demo users can access demo data
- [ ] Verify new user onboarding works
- [ ] Check Firebase Console for permission denied errors (last 1 hour)

---

## Troubleshooting

### Permission Denied on User Lookup

**Symptom**: `get(/users/{uid})` fails with permission denied
**Cause**: User doc missing or rules not using UID-based lookup
**Fix**: Ensure user docs are keyed by UID and rules use `request.auth.uid`

### Taxonomy Collections Empty in Demo

**Symptom**: Demo users see no taxonomy species/provenances
**Cause**: Collections incorrectly prefixed with `demo_`
**Fix**: Verify `DemoModeService._globalCollections` includes taxonomy collections

### Storage Upload Fails for Org Member

**Symptom**: `FirebaseError: Permission denied` on storage upload
**Cause**: Storage rules using email instead of UID for user lookup
**Fix**: Verify `storage.rules` uses `request.auth.uid` and `/users/{uid}`

### Training Progress Not Persisting

**Symptom**: Training progress resets on reload
**Cause**: Incorrect collection prefix or UID mismatch
**Fix**: Verify `userId` field stores Firebase UID (not email)

---

## Related Documentation

- **Identity Scheme**: `docs/architecture/identity_scheme.md`
- **Demo Mode**: `docs/DEMO_RESEED.md`
- **Firestore Collections**: `docs/architecture/firestore_collections.md`

---

## Automated Test Suite

All automated verification scripts are located in `/scripts/` directory:

```bash
# Run full smoke test suite
npm run test:smoke

# Run individual test categories
npm run test:smoke:onboarding
npm run test:smoke:taxonomy
npm run test:smoke:training
npm run test:smoke:storage
```

**Note**: Automated scripts to be created in Phase 3 implementation.
