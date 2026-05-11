import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

// Helper to convert UploadTask to Promise (Firebase UploadTask is thenable but TypeScript types don't match)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function uploadFile(ref: any, data: Buffer): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const task = ref.put(data);
    task.on('state_changed', null, reject, () => resolve(task.snapshot));
  });
}

// Resolve storage.rules path relative to this test file (functions/test/security-rules/)
const STORAGE_RULES_PATH = path.resolve(__dirname, '../../../storage.rules');

// Test data constants
const REAL_ORG_ID = 'real_org_123';
const OTHER_ORG_ID = 'other_org_456';
const REAL_USER_ID = 'real_user_456';
const OTHER_USER_ID = 'other_user_789';
const REAL_USER_EMAIL = 'real@example.com';
const OTHER_USER_EMAIL = 'other@example.com';

// TODO: Re-enable these tests once storage emulator configuration is fixed
// The emulator environment has issues with Firestore lookups from storage rules
describe.skip('Storage Access Security Rules', () => {
  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'seafoundry-test',
      storage: {
        rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
        host: 'localhost',
        port: process.env.STORAGE_EMULATOR_PORT ? parseInt(process.env.STORAGE_EMULATOR_PORT) : 59199,
      },
      // Firestore is needed for user document lookups in storage rules
      firestore: {
        rules: fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8'),
        host: 'localhost',
        port: process.env.FIRESTORE_EMULATOR_PORT ? parseInt(process.env.FIRESTORE_EMULATOR_PORT) : 58080,
      },
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
      const adminDb = context.firestore();

      // Users in users collection (storage rules use this)
      await adminDb.doc(`users/${REAL_USER_EMAIL}`).set({
        id: REAL_USER_ID,
        email: REAL_USER_EMAIL,
        isDemo: false,
        organizationId: REAL_ORG_ID,
        role: 'admin',
      });

      await adminDb.doc(`users/${OTHER_USER_EMAIL}`).set({
        id: OTHER_USER_ID,
        email: OTHER_USER_EMAIL,
        isDemo: false,
        organizationId: OTHER_ORG_ID,
        role: 'admin',
      });

      // Create organizations
      await adminDb.doc(`organizations/${REAL_ORG_ID}`).set({
        id: REAL_ORG_ID,
        name: 'Real Organization',
        organizationId: REAL_ORG_ID,
        isDemo: false,
      });

      await adminDb.doc(`organizations/${OTHER_ORG_ID}`).set({
        id: OTHER_ORG_ID,
        name: 'Other Organization',
        organizationId: OTHER_ORG_ID,
        isDemo: false,
      });

    });
  }

  // ========================================
  // Email-Based User Lookup Tests
  // ========================================

  describe('Storage access uses email-based user lookup', () => {
    test('user CAN access their org storage folder (email lookup)', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const filePath = `organizations/${REAL_ORG_ID}/test-file.txt`;

      // Should be able to read
      await assertSucceeds(userStorage.ref(filePath).getMetadata());

      // Should be able to write
      await assertSucceeds(
        uploadFile(userStorage.ref(filePath), Buffer.from('test content'))
      );
    });

    test('user CANNOT access other org storage folder (email lookup)', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const otherOrgFilePath = `organizations/${OTHER_ORG_ID}/test-file.txt`;

      // Should not be able to read
      await assertFails(userStorage.ref(otherOrgFilePath).getMetadata());

      // Should not be able to write
      await assertFails(
        uploadFile(userStorage.ref(otherOrgFilePath), Buffer.from('malicious content'))
      );
    });

    test('storage rules use lowercase email for user doc lookup', async () => {
      // Test with uppercase email in auth token (should still work)
      const UPPERCASE_EMAIL = 'REAL@EXAMPLE.COM';
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: UPPERCASE_EMAIL }).storage();
      const filePath = `organizations/${REAL_ORG_ID}/test-file.txt`;

      // Should work because rules use .lower() on email
      await assertSucceeds(userStorage.ref(filePath).getMetadata());
    });
  });

  // ========================================
  // User-Specific Storage Tests
  // ========================================

  describe('User-specific storage access', () => {
    test('user CAN access their own user storage folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const userFilePath = `users/${REAL_USER_EMAIL}/profile.jpg`;

      // Should be able to read and write
      await assertSucceeds(
        uploadFile(userStorage.ref(userFilePath), Buffer.from('profile image'))
      );
      await assertSucceeds(userStorage.ref(userFilePath).getMetadata());
    });

    test('user CANNOT access another user storage folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const otherUserFilePath = `users/${OTHER_USER_EMAIL}/profile.jpg`;

      // Should not be able to read or write
      await assertFails(userStorage.ref(otherUserFilePath).getMetadata());
      await assertFails(
        uploadFile(userStorage.ref(otherUserFilePath), Buffer.from('malicious content'))
      );
    });

    test('user storage access uses lowercase email', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const userFilePath = `users/${REAL_USER_EMAIL.toLowerCase()}/profile.jpg`;

      // Should work with lowercase email path
      await assertSucceeds(
        uploadFile(userStorage.ref(userFilePath), Buffer.from('profile image'))
      );
    });
  });

  // ========================================
  // Public Storage Tests
  // ========================================

  describe('Public storage access', () => {
    test('authenticated user CAN read public files', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const publicFilePath = 'public/logo.png';

      // Should be able to read
      await assertSucceeds(userStorage.ref(publicFilePath).getMetadata());
    });

    test('authenticated user CAN write to public folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const publicFilePath = 'public/new-file.jpg';

      // Should be able to write
      await assertSucceeds(
        uploadFile(userStorage.ref(publicFilePath), Buffer.from('public content'))
      );
    });

    test('unauthenticated user CAN read public files', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const publicFilePath = 'public/logo.png';

      // Should be able to read
      await assertSucceeds(unauthStorage.ref(publicFilePath).getMetadata());
    });

    test('unauthenticated user CANNOT write to public folder', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const publicFilePath = 'public/malicious.exe';

      // Should not be able to write
      await assertFails(
        uploadFile(unauthStorage.ref(publicFilePath), Buffer.from('malicious'))
      );
    });
  });

  // ========================================
  // Training Media Storage Tests
  // ========================================

  describe('Training media storage access', () => {
    test('authenticated user CAN read training files', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const trainingFilePath = 'training/module1/video.mp4';

      // Should be able to read
      await assertSucceeds(userStorage.ref(trainingFilePath).getMetadata());
    });

    test('authenticated user CAN write to training folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const trainingFilePath = 'training/module2/slides.pdf';

      // Should be able to write
      await assertSucceeds(
        uploadFile(userStorage.ref(trainingFilePath), Buffer.from('training content'))
      );
    });

    test('unauthenticated user CANNOT read training files', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const trainingFilePath = 'training/module1/video.mp4';

      // Should not be able to read
      await assertFails(unauthStorage.ref(trainingFilePath).getMetadata());
    });

    test('unauthenticated user CANNOT write to training folder', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const trainingFilePath = 'training/malicious.exe';

      // Should not be able to write
      await assertFails(
        uploadFile(unauthStorage.ref(trainingFilePath), Buffer.from('malicious'))
      );
    });
  });

  // ========================================
  // Temporary Upload Storage Tests
  // ========================================

  describe('Temporary upload storage access', () => {
    test('user CAN access their own temp folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const tempFilePath = `temp/${REAL_USER_EMAIL}/upload.jpg`;

      // Should be able to read and write
      await assertSucceeds(
        uploadFile(userStorage.ref(tempFilePath), Buffer.from('temporary upload'))
      );
      await assertSucceeds(userStorage.ref(tempFilePath).getMetadata());
    });

    test('user CANNOT access another user temp folder', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const otherTempFilePath = `temp/${OTHER_USER_EMAIL}/upload.jpg`;

      // Should not be able to read or write
      await assertFails(userStorage.ref(otherTempFilePath).getMetadata());
      await assertFails(
        uploadFile(userStorage.ref(otherTempFilePath), Buffer.from('malicious content'))
      );
    });

    test('temp storage uses lowercase email', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const tempFilePath = `temp/${REAL_USER_EMAIL.toLowerCase()}/upload.jpg`;

      // Should work with lowercase email path
      await assertSucceeds(
        uploadFile(userStorage.ref(tempFilePath), Buffer.from('temporary upload'))
      );
    });
  });

  // ========================================
  // Unauthenticated Access Tests
  // ========================================

  describe('Unauthenticated storage access', () => {
    test('unauthenticated user CANNOT access organization storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const orgFilePath = `organizations/${REAL_ORG_ID}/test-file.txt`;

      await assertFails(unauthStorage.ref(orgFilePath).getMetadata());
      await assertFails(
        uploadFile(unauthStorage.ref(orgFilePath), Buffer.from('malicious'))
      );
    });

    test('unauthenticated user CANNOT access user storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const userFilePath = `users/${REAL_USER_EMAIL}/profile.jpg`;

      await assertFails(unauthStorage.ref(userFilePath).getMetadata());
      await assertFails(
        uploadFile(unauthStorage.ref(userFilePath), Buffer.from('malicious'))
      );
    });

    test('unauthenticated user CANNOT access temp storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const tempFilePath = `temp/${REAL_USER_EMAIL}/upload.jpg`;

      await assertFails(unauthStorage.ref(tempFilePath).getMetadata());
      await assertFails(
        uploadFile(unauthStorage.ref(tempFilePath), Buffer.from('malicious'))
      );
    });
  });

  // ========================================
  // Default Deny Tests
  // ========================================

  describe('Default deny for unlisted paths', () => {
    test('authenticated user CANNOT access arbitrary paths', async () => {
      const userStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const arbitraryPath = 'random-folder/file.txt';

      await assertFails(userStorage.ref(arbitraryPath).getMetadata());
      await assertFails(
        uploadFile(userStorage.ref(arbitraryPath), Buffer.from('content'))
      );
    });

    test('admin user CANNOT access arbitrary paths without explicit rules', async () => {
      // Even if user is admin, they can't access paths without explicit rules
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`users/${REAL_USER_EMAIL}`).update({
          isAdmin: true,
        });
      });

      const adminStorage = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).storage();
      const arbitraryPath = 'admin-only/config.json';

      // No admin-specific storage path defined, so this should fail
      await assertFails(adminStorage.ref(arbitraryPath).getMetadata());
    });
  });
});
