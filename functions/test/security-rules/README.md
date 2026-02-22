# Firestore & Storage Security Rules Tests

Comprehensive test suite for validating Firebase security rules using the Firebase Emulator.

## Test Files

### 1. `taxonomy-shared-collections.test.ts`
Tests for globally shared taxonomy collections:
- `taxonomy_species` - read-only for all authenticated users
- `taxonomy_provenances` - read-only for all authenticated users
- `taxonomy_lineages` - read-only for all authenticated users
- `taxonomy_overrides` - read for all, write for admins only
- Demo user access to shared collections without prefixing

### 2. `demo-prefixing.test.ts`
Tests for demo mode collection prefixing:
- Demo users CAN access `demo_*` prefixed collections
- Demo users CANNOT access unprefixed collections (real org data)
- Real users CANNOT access `demo_*` prefixed collections
- Real users CAN access unprefixed collections
- Cross-collection isolation verification

### 3. `storage-access.test.ts`
Tests for Firebase Storage security rules:
- Email-based user lookup (not UID-based)
- Organization-scoped storage access (`organizations/{orgId}/...`)
- User-specific storage access (`users/{email}/...`)
- Public storage access (`public/...`)
- Training media access (`training/...`)
- Temporary upload storage (`temp/{email}/...`)
- Demo user storage access patterns

### 4. `deprecated-collections.test.ts`
Tests for deprecated root collections that should deny all access:
- Root `/groups` collection (replaced by `organizations/{orgId}/groups`)
- Root `/messages` collection (replaced by `invitations` and `organizations/{orgId}/chat_messages`)
- Verification that replacement collections work correctly

### 5. `demo-mode-security.test.ts`
Tests for demo mode isolation and cross-tier security.
- Demo users isolated to `demo_*` collections
- Real users isolated to unprefixed collections
- Cross-tier demo org isolation (pro vs community)

### 6. `storage-email-lookup.test.ts`
Tests for storage rules email-based user document lookups.
- Email-based user lookup (not UID-based)
- Organization-scoped storage access
- User-specific storage access

## Running the Tests

### Prerequisites

1. **Install dependencies:**
   ```bash
   cd functions
   npm install
   ```

2. **Start Firebase Emulator:**
   ```bash
   # From project root
   npm run emulator:start
   ```

   This starts the emulator on the following ports (configured in `firebase.json`):
   - Firestore: `localhost:58080`
   - Storage: `localhost:59199`
   - Auth: `localhost:9555`
   - UI: `localhost:54001`

### Run All Security Tests

```bash
cd functions
npm run test:security
```

### Run Specific Test File

```bash
cd functions
npx jest test/security-rules/taxonomy-shared-collections.test.ts
npx jest test/security-rules/demo-prefixing.test.ts
npx jest test/security-rules/storage-access.test.ts
npx jest test/security-rules/deprecated-collections.test.ts
```

### Run Tests with Watch Mode

```bash
cd functions
npx jest --watch --testPathPattern=security-rules
```

## Test Structure

Each test file follows this pattern:

```typescript
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';

let testEnv: RulesTestEnvironment;

describe('Test Suite Name', () => {
  beforeAll(async () => {
    // Initialize test environment with rules
    testEnv = await initializeTestEnvironment({
      projectId: 'seafoundry-test',
      firestore: { rules: '...', host: 'localhost', port: 58080 },
      storage: { rules: '...', host: 'localhost', port: 59199 },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.clearStorage();
    await seedTestData();
  });

  async function seedTestData() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      // Seed test data without rules enforcement
    });
  }

  test('description', async () => {
    const userDb = testEnv.authenticatedContext(userId, { email }).firestore();
    await assertSucceeds(userDb.doc('path').get());
    await assertFails(userDb.doc('other-path').get());
  });
});
```

## Key Testing Patterns

### UID-Based User Lookup
Storage rules use UID for user document lookups:
```typescript
// CORRECT: User docs keyed by Firebase Auth UID
await adminDb.doc(`users/${uid}`).set({ ... });

// INCORRECT: Don't use email as key
await adminDb.doc(`users/${email.toLowerCase()}`).set({ ... }); // Won't work
```

### Authenticated Context
Create authenticated contexts for testing user access:
```typescript
const userDb = testEnv.authenticatedContext(userId, { email: userEmail }).firestore();
const userStorage = testEnv.authenticatedContext(userId, { email: userEmail }).storage();
const unauthDb = testEnv.unauthenticatedContext().firestore();
```

### Assertions
Use `assertSucceeds` and `assertFails` for clear test intent:
```typescript
// Should succeed
await assertSucceeds(userDb.doc('path').get());
await assertSucceeds(userDb.doc('path').set({ ... }));

// Should fail
await assertFails(userDb.doc('forbidden-path').get());
await assertFails(userDb.doc('forbidden-path').delete());
```

## Coverage

These tests verify:

1. **Identity & Authentication:**
   - Email-based user lookups (not UID)
   - Authenticated vs unauthenticated access
   - Admin vs regular user permissions

2. **Organization Scoping:**
   - Users can only access their org's data
   - Cross-org access is denied
   - Nested collections under `organizations/{orgId}/...`

3. **Demo Mode Isolation:**
   - Demo users isolated to `demo_*` collections
   - Real users isolated to unprefixed collections
   - Cross-tier demo org isolation (pro vs community)

4. **Shared Resources:**
   - Global taxonomy collections (species, provenances, lineages)
   - Read-only access for authenticated users
   - Admin-only writes to overrides

5. **Storage Access:**
   - Org-scoped storage folders
   - User-specific storage folders
   - Public and training media access
   - Email-based permission checks

6. **Deprecated Collections:**
   - Complete denial of access to `/groups` and `/messages`
   - Verification that replacements work

## Troubleshooting

### Emulator Not Running
```
Error: connect ECONNREFUSED 127.0.0.1:58080
```
**Solution:** Start the emulator with `npm run emulator:start`

### Port Conflicts
If ports are already in use, update `firebase.json` emulator configuration and test files.

### Test Timeouts
Increase Jest timeout if tests are slow:
```javascript
jest.setTimeout(10000); // 10 seconds
```

### Rules Not Loading
Ensure `firestore.rules` and `storage.rules` paths are correct:
```typescript
const FIRESTORE_RULES_PATH = path.resolve(__dirname, '../../../firestore.rules');
const STORAGE_RULES_PATH = path.resolve(__dirname, '../../../storage.rules');
```

## CI/CD Integration

For automated testing in CI pipelines:

```bash
# Start emulator in background
firebase emulators:start --only auth,firestore,storage &
EMULATOR_PID=$!

# Wait for emulator to be ready
sleep 5

# Run tests
cd functions && npm run test:security

# Cleanup
kill $EMULATOR_PID
```

## Related Documentation

- [Firebase Security Rules Testing Guide](https://firebase.google.com/docs/rules/unit-tests)
- [Firestore Security Rules Reference](https://firebase.google.com/docs/firestore/security/rules-structure)
- [Storage Security Rules Reference](https://firebase.google.com/docs/storage/security)
- Phase 0 Documentation: `/docs/phase0/`
  - `FP0-DOC1-taxonomy-contract.md` - Taxonomy collection contract
  - `FP0-DOC2-identity-scheme.md` - Identity and email-based lookups
  - `FP0-DOC3-ruleset-audit.md` - Complete rules audit

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
