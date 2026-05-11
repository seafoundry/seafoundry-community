import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

// Helper to convert UploadTask to Promise (Firebase UploadTask is thenable but TypeScript types don't match)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function uploadFile(ref: any, data: Buffer, metadata?: { contentType: string }): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const task = ref.put(data, metadata);
    task.on('state_changed', null, reject, () => resolve(task.snapshot));
  });
}

// Resolve storage.rules path relative to this test file (functions/test/security-rules/)
const STORAGE_RULES_PATH = path.resolve(__dirname, '../../../storage.rules');

// Test data constants
const ORG_A_ID = 'org_a_123';
const ORG_B_ID = 'org_b_456';
const USER_A_ID = 'user_a_123';
const USER_B_ID = 'user_b_456';
const USER_A_EMAIL = 'user-a@example.com';
const USER_B_EMAIL = 'user-b@example.com';

// TODO: Re-enable these tests once storage emulator configuration is fixed
// The emulator environment has issues with Firestore lookups from storage rules
describe.skip('Storage Email-Based Org Lookup Security', () => {
  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'seafoundry-test',
      firestore: {
        // Storage rules reference Firestore for user lookups, so we need both
        rules: fs.readFileSync(path.resolve(__dirname, '../../../firestore.rules'), 'utf8'),
        host: 'localhost',
        port: process.env.FIRESTORE_EMULATOR_PORT ? parseInt(process.env.FIRESTORE_EMULATOR_PORT) : 58080,
      },
      storage: {
        rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
        host: 'localhost',
        port: process.env.STORAGE_EMULATOR_PORT ? parseInt(process.env.STORAGE_EMULATOR_PORT) : 59199,
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seedTestData();
  });

  async function seedTestData() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();

      // Create users keyed by lowercase email (not UID)
      // This is critical - storage rules look up users by email
      await adminDb.doc(`users/${USER_A_EMAIL.toLowerCase()}`).set({
        id: USER_A_ID,
        email: USER_A_EMAIL,
        organizationId: ORG_A_ID,
        role: 'admin',
      });

      await adminDb.doc(`users/${USER_B_EMAIL.toLowerCase()}`).set({
        id: USER_B_ID,
        email: USER_B_EMAIL,
        organizationId: ORG_B_ID,
        role: 'admin',
      });

      // Create organizations
      await adminDb.doc(`organizations/${ORG_A_ID}`).set({
        id: ORG_A_ID,
        name: 'Organization A',
      });

      await adminDb.doc(`organizations/${ORG_B_ID}`).set({
        id: ORG_B_ID,
        name: 'Organization B',
      });
    });
  }

  // ========================================
  // Organization Storage Access with Email Lookup
  // ========================================

  describe('Organization storage access via email lookup', () => {
    test('user with valid email CAN access their organization storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`organizations/${ORG_A_ID}/test-file.txt`);

      // Attempt to read - should succeed because user lookup finds organizationId matches
      await assertSucceeds(fileRef.getMetadata());
    });

    test('user lookup uses email (not UID) to verify org membership', async () => {
      // This test verifies the storage rule does:
      // firestore.get(/databases/(default)/documents/users/$(request.auth.token.email.lower()))
      // NOT: firestore.get(/databases/(default)/documents/users/$(request.auth.uid))

      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`organizations/${ORG_A_ID}/folder/document.pdf`);

      // Upload should succeed - user doc is keyed by email
      await assertSucceeds(
        uploadFile(fileRef, Buffer.from('test content'), { contentType: 'application/pdf' })
      );
    });

    test('user CANNOT access other organization storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      // Attempt to access Organization B's storage (user A belongs to Org A)
      const fileRef = userAStorage.ref(`organizations/${ORG_B_ID}/secret-file.txt`);

      await assertFails(fileRef.getMetadata());
    });

    test('user CANNOT write to other organization storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`organizations/${ORG_B_ID}/malicious.txt`);

      await assertFails(
        uploadFile(fileRef, Buffer.from('malicious content'), { contentType: 'text/plain' })
      );
    });
  });

  // ========================================
  // User-Specific Storage Access
  // ========================================

  describe('User-specific storage access', () => {
    test('user CAN access their own user storage (keyed by email)', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      // User storage path uses lowercase email as userId
      const fileRef = userAStorage.ref(`users/${USER_A_EMAIL.toLowerCase()}/profile.jpg`);

      await assertSucceeds(
        uploadFile(fileRef, Buffer.from('image data'), { contentType: 'image/jpeg' })
      );
    });

    test('user CANNOT access other user storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`users/${USER_B_EMAIL.toLowerCase()}/private.txt`);

      await assertFails(fileRef.getMetadata());
    });
  });

  // ========================================
  // Public and Training Storage
  // ========================================

  describe('Public and training storage access', () => {
    test('authenticated user CAN read public storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref('public/logo.png');
      await assertSucceeds(fileRef.getMetadata());
    });

    test('authenticated user CAN write to public storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref('public/upload.jpg');
      await assertSucceeds(
        uploadFile(fileRef, Buffer.from('public image'), { contentType: 'image/jpeg' })
      );
    });

    test('authenticated user CAN access training materials', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref('training/module1/video.mp4');
      await assertSucceeds(fileRef.getMetadata());
    });
  });

  // ========================================
  // Unauthenticated Access
  // ========================================

  describe('Unauthenticated storage access', () => {
    test('unauthenticated user CANNOT access organization storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const fileRef = unauthStorage.ref(`organizations/${ORG_A_ID}/file.txt`);

      await assertFails(fileRef.getMetadata());
    });

    test('unauthenticated user CANNOT access user storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const fileRef = unauthStorage.ref(`users/${USER_A_EMAIL.toLowerCase()}/profile.jpg`);

      await assertFails(fileRef.getMetadata());
    });

    test('unauthenticated user CAN read public storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const fileRef = unauthStorage.ref('public/logo.png');

      // Public storage allows read: if true
      await assertSucceeds(fileRef.getMetadata());
    });

    test('unauthenticated user CANNOT write to public storage', async () => {
      const unauthStorage = testEnv.unauthenticatedContext().storage();
      const fileRef = unauthStorage.ref('public/malicious.txt');

      await assertFails(
        uploadFile(fileRef, Buffer.from('malicious'), { contentType: 'text/plain' })
      );
    });
  });

  // ========================================
  // Temp Storage Access
  // ========================================

  describe('Temporary storage access', () => {
    test('user CAN access their temp storage (keyed by email)', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`temp/${USER_A_EMAIL.toLowerCase()}/upload.tmp`);

      await assertSucceeds(
        uploadFile(fileRef, Buffer.from('temp data'), { contentType: 'application/octet-stream' })
      );
    });

    test('user CANNOT access other user temp storage', async () => {
      const userAStorage = testEnv
        .authenticatedContext(USER_A_ID, { email: USER_A_EMAIL })
        .storage();

      const fileRef = userAStorage.ref(`temp/${USER_B_EMAIL.toLowerCase()}/processing.tmp`);

      await assertFails(fileRef.getMetadata());
    });
  });
});
