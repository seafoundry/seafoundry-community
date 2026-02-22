import { assertFails, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

// Resolve firestore.rules path relative to this test file (functions/test/security-rules/)
const FIRESTORE_RULES_PATH = path.resolve(__dirname, '../../../firestore.rules');

// Test data constants
const REAL_ORG_ID = 'real_org_123';
const REAL_USER_ID = 'real_user_456';
const REAL_USER_EMAIL = 'real@example.com';
const ADMIN_USER_ID = 'admin_user_789';
const ADMIN_USER_EMAIL = 'admin@seafoundry.app';

describe('Deprecated Collections Security Rules', () => {
  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: 'seafoundry-test',
      firestore: {
        rules: fs.readFileSync(FIRESTORE_RULES_PATH, 'utf8'),
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
    await seedTestData();
  });

  async function seedTestData() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();

      // Create regular user in users collection
      await adminDb.doc(`users/${REAL_USER_EMAIL}`).set({
        id: REAL_USER_ID,
        email: REAL_USER_EMAIL,
        isDemo: false,
        organizationId: REAL_ORG_ID,
        role: 'practitioner',
        isAdmin: false,
      });

      // Create admin user
      await adminDb.doc(`users/${ADMIN_USER_EMAIL}`).set({
        id: ADMIN_USER_ID,
        email: ADMIN_USER_EMAIL,
        isDemo: false,
        organizationId: REAL_ORG_ID,
        role: 'admin',
        isAdmin: true,
      });

      // Create organization
      await adminDb.doc(`organizations/${REAL_ORG_ID}`).set({
        id: REAL_ORG_ID,
        name: 'Real Organization',
        organizationId: REAL_ORG_ID,
        isDemo: false,
        createdById: REAL_USER_EMAIL,
      });

      // Seed deprecated collections (these should be inaccessible)
      // These collections existed in older versions but are now deprecated
      await adminDb.doc('groups/deprecated_group_1').set({
        id: 'deprecated_group_1',
        organizationId: REAL_ORG_ID,
        name: 'Deprecated Group',
        createdAt: new Date().toISOString(),
      });

      await adminDb.doc('messages/deprecated_message_1').set({
        id: 'deprecated_message_1',
        organizationId: REAL_ORG_ID,
        content: 'Old message',
        createdAt: new Date().toISOString(),
      });
    });
  }

  // ========================================
  // Root /groups Collection - DEPRECATED
  // ========================================
  // The app now uses nested organizations/{orgId}/groups subcollection
  // Root /groups collection should deny all access

  describe('Root /groups collection access (DEPRECATED)', () => {
    test('authenticated user CANNOT read root /groups collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(userDb.doc('groups/deprecated_group_1').get());
    });

    test('authenticated user CANNOT write to root /groups collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(
        userDb.doc('groups/new_group').set({
          id: 'new_group',
          organizationId: REAL_ORG_ID,
          name: 'New Group',
        })
      );
    });

    test('authenticated user CANNOT update root /groups collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(
        userDb.doc('groups/deprecated_group_1').update({
          name: 'Updated Name',
        })
      );
    });

    test('authenticated user CANNOT delete from root /groups collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(userDb.doc('groups/deprecated_group_1').delete());
    });

    test('admin user CANNOT read root /groups collection (admin override disabled)', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();
      await assertFails(adminDb.doc('groups/deprecated_group_1').get());
    });

    test('admin user CANNOT write to root /groups collection', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();
      await assertFails(
        adminDb.doc('groups/admin_group').set({
          id: 'admin_group',
          organizationId: REAL_ORG_ID,
          name: 'Admin Group',
        })
      );
    });

    test('unauthenticated user CANNOT read root /groups collection', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.doc('groups/deprecated_group_1').get());
    });

    test('unauthenticated user CANNOT write to root /groups collection', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauthDb.doc('groups/anon_group').set({
          id: 'anon_group',
          name: 'Anonymous Group',
        })
      );
    });

    test('list operation CANNOT succeed on root /groups collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      // Attempt to list all groups
      await assertFails(userDb.collection('groups').get());
    });
  });

  // ========================================
  // Root /messages Collection - DEPRECATED
  // ========================================
  // Invitations now use /invitations collection with proper scoping
  // Chat messages use organizations/{orgId}/chat_messages subcollection
  // Root /messages collection should deny all access

  describe('Root /messages collection access (DEPRECATED)', () => {
    test('authenticated user CANNOT read root /messages collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(userDb.doc('messages/deprecated_message_1').get());
    });

    test('authenticated user CANNOT write to root /messages collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(
        userDb.doc('messages/new_message').set({
          id: 'new_message',
          organizationId: REAL_ORG_ID,
          content: 'New Message',
        })
      );
    });

    test('authenticated user CANNOT update root /messages collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(
        userDb.doc('messages/deprecated_message_1').update({
          content: 'Updated Message',
        })
      );
    });

    test('authenticated user CANNOT delete from root /messages collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      await assertFails(userDb.doc('messages/deprecated_message_1').delete());
    });

    test('admin user CANNOT read root /messages collection (admin override disabled)', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();
      await assertFails(adminDb.doc('messages/deprecated_message_1').get());
    });

    test('admin user CANNOT write to root /messages collection', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();
      await assertFails(
        adminDb.doc('messages/admin_message').set({
          id: 'admin_message',
          organizationId: REAL_ORG_ID,
          content: 'Admin Message',
        })
      );
    });

    test('unauthenticated user CANNOT read root /messages collection', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.doc('messages/deprecated_message_1').get());
    });

    test('unauthenticated user CANNOT write to root /messages collection', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauthDb.doc('messages/anon_message').set({
          id: 'anon_message',
          content: 'Anonymous Message',
        })
      );
    });

    test('list operation CANNOT succeed on root /messages collection', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      // Attempt to list all messages
      await assertFails(userDb.collection('messages').get());
    });
  });

  // ========================================
  // Verify Replacement Collections Work
  // ========================================
  // Ensure the new collections that replace deprecated ones still work

  describe('Replacement collections work correctly', () => {
    test('user CAN access nested groups under organizations/{orgId}/groups', async () => {
      // Seed a nested group
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`organizations/${REAL_ORG_ID}/groups/group1`).set({
          id: 'group1',
          organizationId: REAL_ORG_ID,
          name: 'Active Group',
          createdById: REAL_USER_EMAIL,
        });
      });

      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();

      // Should be able to access nested groups
      const groupDoc = await userDb.doc(`organizations/${REAL_ORG_ID}/groups/group1`).get();
      expect(groupDoc.exists).toBe(true);
    });

    test('user CAN access chat messages under organizations/{orgId}/chat_messages', async () => {
      // Seed organization tier to Pro (required for chat messages)
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`organizations/${REAL_ORG_ID}`).update({
          tier: 'pro',
        });

        await context.firestore().doc(`organizations/${REAL_ORG_ID}/chat_messages/msg1`).set({
          id: 'msg1',
          organizationId: REAL_ORG_ID,
          senderId: REAL_USER_EMAIL,
          content: 'Active Message',
          createdAt: new Date().toISOString(),
        });
      });

      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();

      // Should be able to access nested chat messages
      const messageDoc = await userDb.doc(`organizations/${REAL_ORG_ID}/chat_messages/msg1`).get();
      expect(messageDoc.exists).toBe(true);
    });

    test('user CAN access invitations collection (replacement for message-based invites)', async () => {
      // Seed an invitation
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc('invitations/invite1').set({
          id: 'invite1',
          organizationId: REAL_ORG_ID,
          email: REAL_USER_EMAIL,
          status: 'pending',
          createdAt: new Date().toISOString(),
        });
      });

      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();

      // Should be able to access invitations
      const inviteDoc = await userDb.doc('invitations/invite1').get();
      expect(inviteDoc.exists).toBe(true);
    });
  });

  // ========================================
  // Edge Cases
  // ========================================

  describe('Deprecated collections edge cases', () => {
    test('attempting batch writes to deprecated collections fails', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();
      const batch = userDb.batch();

      batch.set(userDb.doc('groups/batch_group_1'), {
        id: 'batch_group_1',
        name: 'Batch Group',
      });

      batch.set(userDb.doc('messages/batch_message_1'), {
        id: 'batch_message_1',
        content: 'Batch Message',
      });

      // Batch should fail because rules deny access
      await assertFails(batch.commit());
    });

    test('querying deprecated collections with where clauses fails', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();

      // Attempt complex query on deprecated collection
      await assertFails(
        userDb.collection('groups')
          .where('organizationId', '==', REAL_ORG_ID)
          .get()
      );
    });

    test('subcollections under deprecated collections also denied', async () => {
      const userDb = testEnv.authenticatedContext(REAL_USER_ID, { email: REAL_USER_EMAIL }).firestore();

      // Even if there were subcollections under deprecated root collections
      await assertFails(
        userDb.doc('groups/deprecated_group_1/members/member1').get()
      );

      await assertFails(
        userDb.doc('messages/deprecated_message_1/reactions/reaction1').get()
      );
    });
  });
});
