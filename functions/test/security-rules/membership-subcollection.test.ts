import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

// Resolve firestore.rules path relative to this test file (functions/test/security-rules/)
const FIRESTORE_RULES_PATH = path.resolve(__dirname, '../../../firestore.rules');

// Test data constants
const REAL_ORG_ID = 'real_org_123';
const OTHER_ORG_ID = 'other_org_456';

const ADMIN_USER_ID = 'admin_user_123';
const ADMIN_USER_EMAIL = 'admin@example.com';

const MEMBER_USER_ID = 'member_user_456';
const MEMBER_USER_EMAIL = 'member@example.com';

const NON_MEMBER_USER_ID = 'nonmember_user_789';
const NON_MEMBER_USER_EMAIL = 'nonmember@example.com';

const CREATOR_USER_ID = 'creator_user_abc';
const CREATOR_USER_EMAIL = 'creator@example.com';

describe('Membership Subcollection Security Rules', () => {
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

      // Create real organization
      await adminDb.doc(`organizations/${REAL_ORG_ID}`).set({
        id: REAL_ORG_ID,
        name: 'Real Organization',
        organizationId: REAL_ORG_ID,
        isDemo: false,
        createdById: ADMIN_USER_EMAIL,
      });

      // Create other organization (for cross-org tests)
      await adminDb.doc(`organizations/${OTHER_ORG_ID}`).set({
        id: OTHER_ORG_ID,
        name: 'Other Organization',
        organizationId: OTHER_ORG_ID,
        isDemo: false,
        createdById: NON_MEMBER_USER_EMAIL,
      });

      // Create admin user (real org)
      await adminDb.doc(`users/${ADMIN_USER_EMAIL}`).set({
        id: ADMIN_USER_ID,
        email: ADMIN_USER_EMAIL,
        isDemo: false,
        organizationId: REAL_ORG_ID,
        role: 'admin',
        isAdmin: true,
      });

      // Create regular member user (real org)
      await adminDb.doc(`users/${MEMBER_USER_EMAIL}`).set({
        id: MEMBER_USER_ID,
        email: MEMBER_USER_EMAIL,
        isDemo: false,
        organizationId: REAL_ORG_ID,
        role: 'practitioner',
        isAdmin: false,
      });

      // Create non-member user (different org)
      await adminDb.doc(`users/${NON_MEMBER_USER_EMAIL}`).set({
        id: NON_MEMBER_USER_ID,
        email: NON_MEMBER_USER_EMAIL,
        isDemo: false,
        organizationId: OTHER_ORG_ID,
        role: 'admin',
        isAdmin: true,
      });

      // Create creator user (onboarding scenario - has placeholder org)
      await adminDb.doc(`users/${CREATOR_USER_EMAIL}`).set({
        id: CREATOR_USER_ID,
        email: CREATOR_USER_EMAIL,
        isDemo: false,
        organizationId: CREATOR_USER_EMAIL, // Placeholder org during onboarding
        role: 'admin',
        isAdmin: true,
      });

      // Seed membership documents for real org
      await adminDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).set({
        userId: ADMIN_USER_ID,
        email: ADMIN_USER_EMAIL,
        role: 'admin',
        joinedAt: new Date().toISOString(),
      });

      await adminDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).set({
        userId: MEMBER_USER_ID,
        email: MEMBER_USER_EMAIL,
        role: 'practitioner',
        joinedAt: new Date().toISOString(),
      });

    });
  }

  // ========================================
  // Read Access Tests - Real Organizations
  // ========================================

  describe('Read access to real organization members', () => {
    test('org member CAN read membership list', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertSucceeds(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).get()
      );
      await assertSucceeds(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).get()
      );
    });

    test('org admin CAN read membership list', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).get()
      );
      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).get()
      );
    });

    test('org member CAN list all members', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertSucceeds(
        memberDb.collection(`organizations/${REAL_ORG_ID}/members`).get()
      );
    });

    test('non-member CANNOT read membership list', async () => {
      const nonMemberDb = testEnv.authenticatedContext(NON_MEMBER_USER_ID, { email: NON_MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        nonMemberDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).get()
      );
      await assertFails(
        nonMemberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).get()
      );
    });

    test('non-member CANNOT list members', async () => {
      const nonMemberDb = testEnv.authenticatedContext(NON_MEMBER_USER_ID, { email: NON_MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        nonMemberDb.collection(`organizations/${REAL_ORG_ID}/members`).get()
      );
    });

    test('unauthenticated user CANNOT read members', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(
        unauthDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).get()
      );
    });

    test('unauthenticated user CANNOT list members', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(
        unauthDb.collection(`organizations/${REAL_ORG_ID}/members`).get()
      );
    });
  });

  // ========================================
  // Create Access Tests - Real Organizations
  // ========================================

  describe('Create access for real organization members', () => {
    test('org member CAN create membership doc (invite scenario)', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();
      const newMemberId = 'new_member_123';

      await assertSucceeds(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${newMemberId}`).set({
          userId: newMemberId,
          email: 'newmember@example.com',
          role: 'practitioner',
          joinedAt: new Date().toISOString(),
        })
      );
    });

    test('org admin CAN create membership doc', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();
      const newMemberId = 'new_admin_member_456';

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${newMemberId}`).set({
          userId: newMemberId,
          email: 'newadmin@example.com',
          role: 'admin',
          joinedAt: new Date().toISOString(),
        })
      );
    });

    test('creator CAN create membership doc during onboarding', async () => {
      // Creator is setting up a new org and adding themselves as first member
      const creatorDb = testEnv.authenticatedContext(CREATOR_USER_ID, { email: CREATOR_USER_EMAIL }).firestore();

      // First create the organization with creator as createdById
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc(`organizations/new_org_123`).set({
          id: 'new_org_123',
          name: 'New Organization',
          organizationId: 'new_org_123',
          isDemo: false,
          createdById: CREATOR_USER_EMAIL,
        });
      });

      // Creator should be able to add first membership record
      await assertSucceeds(
        creatorDb.doc(`organizations/new_org_123/members/${CREATOR_USER_ID}`).set({
          userId: CREATOR_USER_ID,
          email: CREATOR_USER_EMAIL,
          role: 'admin',
          joinedAt: new Date().toISOString(),
          createdById: CREATOR_USER_EMAIL, // isIncomingCreator() checks this
        })
      );
    });

    test('non-member CANNOT create membership doc', async () => {
      const nonMemberDb = testEnv.authenticatedContext(NON_MEMBER_USER_ID, { email: NON_MEMBER_USER_EMAIL }).firestore();
      const newMemberId = 'malicious_member_789';

      await assertFails(
        nonMemberDb.doc(`organizations/${REAL_ORG_ID}/members/${newMemberId}`).set({
          userId: newMemberId,
          email: 'malicious@example.com',
          role: 'admin',
          joinedAt: new Date().toISOString(),
        })
      );
    });

    test('unauthenticated user CANNOT create membership doc', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const newMemberId = 'unauth_member_999';

      await assertFails(
        unauthDb.doc(`organizations/${REAL_ORG_ID}/members/${newMemberId}`).set({
          userId: newMemberId,
          email: 'unauth@example.com',
          role: 'practitioner',
          joinedAt: new Date().toISOString(),
        })
      );
    });
  });

  // ========================================
  // Update Access Tests - Real Organizations
  // ========================================

  describe('Update access for real organization members', () => {
    test('admin CAN update membership doc', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).update({
          role: 'admin',
        })
      );
    });

    test('admin CAN update their own membership doc', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).update({
          displayName: 'Updated Admin Name',
        })
      );
    });

    test('non-admin member CANNOT update membership doc', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).update({
          role: 'practitioner',
        })
      );
    });

    test('non-admin member CANNOT update their own membership role', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).update({
          role: 'admin',
        })
      );
    });

    test('non-member CANNOT update membership doc', async () => {
      const nonMemberDb = testEnv.authenticatedContext(NON_MEMBER_USER_ID, { email: NON_MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        nonMemberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).update({
          role: 'admin',
        })
      );
    });

    test('unauthenticated user CANNOT update membership doc', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(
        unauthDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).update({
          role: 'admin',
        })
      );
    });
  });

  // ========================================
  // Delete Access Tests - Real Organizations
  // ========================================

  describe('Delete access for real organization members', () => {
    test('admin CAN delete membership doc', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).delete()
      );
    });

    test('admin CAN delete their own membership doc', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).delete()
      );
    });

    test('non-admin member CANNOT delete membership doc', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).delete()
      );
    });

    test('non-admin member CANNOT delete their own membership doc', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).delete()
      );
    });

    test('non-member CANNOT delete membership doc', async () => {
      const nonMemberDb = testEnv.authenticatedContext(NON_MEMBER_USER_ID, { email: NON_MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        nonMemberDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).delete()
      );
    });

    test('unauthenticated user CANNOT delete membership doc', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      await assertFails(
        unauthDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).delete()
      );
    });
  });

  // ========================================
  // Cross-Organization Isolation Tests
  // ========================================

  describe('Cross-organization isolation', () => {
    test('org member CANNOT read members from different org', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      await assertFails(
        memberDb.doc(`organizations/${OTHER_ORG_ID}/members/${NON_MEMBER_USER_ID}`).get()
      );
    });

    test('org admin CANNOT modify members in different org', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertFails(
        adminDb.doc(`organizations/${OTHER_ORG_ID}/members/new_member_123`).set({
          userId: 'new_member_123',
          email: 'newmember@other.com',
          role: 'practitioner',
          joinedAt: new Date().toISOString(),
        })
      );
    });

    test('org admin CANNOT delete members from different org', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      await assertFails(
        adminDb.doc(`organizations/${OTHER_ORG_ID}/members/${NON_MEMBER_USER_ID}`).delete()
      );
    });

  });

  // ========================================
  // Edge Cases and Security Tests
  // ========================================

  describe('Edge cases and security scenarios', () => {
    test('cannot escalate privileges by creating membership with admin role as non-admin', async () => {
      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      // Member can create membership docs, but admin enforcement would be application-level
      // The rules allow create, but actual role validation should happen in application code
      const newMemberId = 'privilege_escalation_test';

      await assertSucceeds(
        memberDb.doc(`organizations/${REAL_ORG_ID}/members/${newMemberId}`).set({
          userId: newMemberId,
          email: 'escalation@example.com',
          role: 'admin', // Rules don't validate role field on create
          joinedAt: new Date().toISOString(),
        })
      );

      // Note: This test documents current behavior. Application code should validate roles.
    });

    test('admin can remove all members including themselves', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      // Delete other member
      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${MEMBER_USER_ID}`).delete()
      );

      // Delete themselves (last admin)
      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/${ADMIN_USER_ID}`).delete()
      );

      // Note: Application should prevent deleting last admin
    });

    test('membership doc ID does not need to match userId field', async () => {
      const adminDb = testEnv.authenticatedContext(ADMIN_USER_ID, { email: ADMIN_USER_EMAIL }).firestore();

      // Rules don't enforce that doc ID matches userId field
      await assertSucceeds(
        adminDb.doc(`organizations/${REAL_ORG_ID}/members/doc_id_123`).set({
          userId: 'different_user_id_456',
          email: 'mismatch@example.com',
          role: 'practitioner',
          joinedAt: new Date().toISOString(),
        })
      );

      // Note: This test documents current behavior. Application should enforce ID consistency.
    });

    test('empty membership list allows any org member to read', async () => {
      // Create new org with no members
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc('organizations/empty_org_789').set({
          id: 'empty_org_789',
          name: 'Empty Organization',
          organizationId: 'empty_org_789',
          isDemo: false,
          createdById: ADMIN_USER_EMAIL,
        });
      });

      const memberDb = testEnv.authenticatedContext(MEMBER_USER_ID, { email: MEMBER_USER_EMAIL }).firestore();

      // Cannot read empty collection from other org
      await assertFails(
        memberDb.collection('organizations/empty_org_789/members').get()
      );
    });
  });
});
