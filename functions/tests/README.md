# Visual Engagement Cloud Functions Tests

## Overview

Comprehensive emulator tests for VE (Visual Engagement) A/B/C Cloud Functions covering:

- **Phase A: Media Ingestion & Mirroring** - `mirrorPublishedMedia` function
- **Phase B: Brand Theming** - `mirrorPublishedBrandProfiles`, `createDefaultPlaylist` functions
- **Phase C: Public Surfaces & Impact Points** - `projectOrgImpactPoints`, `buildWeeklyOrgDigests` functions

## Test Structure

```
tests/
├── visual-engagement.test.ts  # VE functions test suite
├── validators.test.ts          # Model validation tests (existing)
└── README.md                   # This file
```

## Test Coverage

### Phase A: Media Ingestion (4 tests)
- Mirror published media to `public_orgs/{orgId}/media`
- Remove unpublished media from public collections
- Delete public media when source is deleted
- Sanitize internal fields from public mirror

### Phase B: Brand Theming (5 tests)
- Mirror published brand profiles to public collections
- Remove unpublished brand profiles
- Delete public brand when source is deleted
- Create default playlist when brand profile is published
- Handle missing brand name gracefully

### Phase C: Impact Points (9 tests)
- Project holdings data to impact points with geo metadata
- Project outplant events to impact points
- Skip sites without geo metadata
- Handle organizations without sites gracefully
- Clear existing impact points before reprojecting
- Handle zero magnitude holdings
- Build weekly digest from published media
- Skip organizations without media in the week
- Limit highlight assets to 5

### Edge Cases & Error Handling (4 tests)
- Handle missing document data gracefully
- Handle invalid geo coordinates in sites
- Handle string quantity values in holdings
- Handle NaN and invalid numeric values

## Running Tests

### Prerequisites

1. **Install dependencies**:
   ```bash
   cd functions
   npm install
   ```

2. **Firebase Emulators** (Optional - for integration testing):
   ```bash
   # Install Firebase CLI globally
   npm install -g firebase-tools

   # Start emulators
   firebase emulators:start --only firestore
   ```

### Run All Tests

```bash
cd functions
npm test
```

> If a Firestore emulator is already running on port 58080, reuse it with:
> `FIRESTORE_EMULATOR_HOST=localhost:58080 npm run test:unit`

### Run Tests in Watch Mode

```bash
cd functions
npm run test:watch
```

### Run Specific Test File

```bash
cd functions
npx mocha --require ts-node/register tests/visual-engagement.test.ts
```

## Test Configuration

### Environment Setup

Tests use `firebase-functions-test` in offline mode for unit testing:

```typescript
import functionsTest from "firebase-functions-test";
const test = functionsTest();
```

For integration tests against the emulator, set environment variables:

```bash
export FIRESTORE_EMULATOR_HOST="localhost:8080"
export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
```

### Test Isolation

Each test:
1. Clears Firestore collections in `beforeEach` hook
2. Seeds required test data
3. Executes the function
4. Verifies expected outcomes
5. Cleans up in `afterEach`

### Test Data Seeding

Tests seed minimal required data:

```typescript
// Example: Seeding for impact points test
await db.collection("organizations").doc(orgId).set({
  id: orgId,
  name: "Test Org",
});

await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
  id: siteId,
  name: "Test Site",
  latitude: 25.7617,
  longitude: -80.1918,
});
```

## Test Patterns

### Document Write Events (Firestore Triggers)

```typescript
const beforeSnap = test.firestore.makeDocumentSnapshot(beforeData, path);
const afterSnap = test.firestore.makeDocumentSnapshot(afterData, path);

await myFunctions.mirrorPublishedMedia.run({
  data: {before: beforeSnap, after: afterSnap},
  params: {assetId},
});
```

### Scheduled Functions

```typescript
await myFunctions.projectOrgImpactPoints.run({
  scheduleTime: new Date().toISOString(),
  jobName: "test-job",
});
```

### Document Deletion

```typescript
// Simulate deletion by passing undefined as after snapshot
await wrapped({
  data: {before: beforeSnap, after: undefined},
  params: {assetId},
});
```

## Integration with Emulator

For full integration testing with Firebase emulators:

### 1. Start Emulators

```bash
# In project root
firebase emulators:start --only firestore,functions
```

### 2. Run Tests Against Emulator

```bash
# In functions directory
FIRESTORE_EMULATOR_HOST="localhost:8080" npm test
```

### 3. View Emulator UI

Navigate to: http://localhost:4000

## Debugging Tests

### Enable Verbose Logging

```bash
DEBUG=* npm test
```

### Run Single Test

```typescript
it.only("should mirror published media to public_orgs collection", async () => {
  // Test code
});
```

### Skip Test

```typescript
it.skip("should handle complex scenario", async () => {
  // Test code
});
```

## Continuous Integration

Tests are designed to run in CI/CD pipelines:

```yaml
# .github/workflows/test-functions.yml
- name: Install dependencies
  run: cd functions && npm install

- name: Run tests
  run: cd functions && npm test
```

## Known Issues & Limitations

1. **Firestore Offline Mode**: Tests use offline mode by default, which doesn't persist data between tests. For stateful integration tests, use emulators.

2. **Scheduled Function Testing**: Scheduled functions (cron) are tested by calling `.run()` directly rather than waiting for schedule triggers.

3. **Storage Triggers**: The `generateMediaThumbnails` storage trigger is not covered in this test suite (requires Storage emulator and image processing).

4. **Async Cleanup**: Some tests may timeout if Firestore operations don't complete within Mocha's default timeout (2000ms). Increase timeout if needed:
   ```typescript
   it("should handle large dataset", async function() {
     this.timeout(10000); // 10 seconds
     // Test code
   });
   ```

## Test Maintenance

### Adding New Tests

1. Follow existing patterns for consistency
2. Use descriptive test names that explain expected behavior
3. Seed minimal required data
4. Clean up after each test
5. Test both success and failure scenarios

### Updating Tests

When VE functions change:
1. Update corresponding test expectations
2. Add new test cases for new features
3. Keep test data realistic but minimal
4. Document any new test patterns

## Related Documentation

- **VE Architecture**: `/docs/VisualEngagement.md`
- **VE Metrics**: `/docs/analytics/visual_engagement_metrics.md`
- **Cloud Functions**: `/functions/src/visual_engagement.ts`
- **Firebase Emulators**: https://firebase.google.com/docs/emulator-suite

## Support

For issues or questions about tests:
1. Check test output for specific error messages
2. Review Firebase emulator logs
3. Consult firebase-functions-test documentation: https://firebase.google.com/docs/functions/unit-testing

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
