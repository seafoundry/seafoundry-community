import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';
import * as path from 'path';

let testEnv: RulesTestEnvironment;

// Resolve firestore.rules path relative to this test file (functions/test/security-rules/)
const FIRESTORE_RULES_PATH = path.resolve(__dirname, '../../../firestore.rules');

// Test data constants
const ORG_A_ID = 'org_a_123';
const ORG_B_ID = 'org_b_456';
const USER_A_ID = 'user_a_123';
const USER_B_ID = 'user_b_456';
const USER_A_EMAIL = 'user-a@example.com';
const USER_B_EMAIL = 'user-b@example.com';

describe('Taxonomy Shared Collections Security', () => {
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

      // Create users in users collection
      await adminDb.doc(`users/${USER_A_EMAIL}`).set({
        id: USER_A_ID,
        email: USER_A_EMAIL,
        organizationId: ORG_A_ID,
        role: 'admin',
      });

      await adminDb.doc(`users/${USER_B_EMAIL}`).set({
        id: USER_B_ID,
        email: USER_B_EMAIL,
        organizationId: ORG_B_ID,
        role: 'admin',
      });

      // Seed shared taxonomy collections (unprefixed - globally shared)
      await adminDb.doc('taxonomy_species/species1').set({
        id: 'species1',
        scientificName: 'Test species',
        commonName: 'Common Test',
      });

      await adminDb.doc('taxonomy_provenances/prov1').set({
        id: 'prov1',
        speciesId: 'species1',
        provenance: 'Test Provenance',
      });

      await adminDb.doc('taxonomy_lineages/lineage1').set({
        id: 'lineage1',
        speciesId: 'species1',
        lineage: 'Test Lineage',
      });

      // Seed taxonomy_overrides (regular collection - org-specific)
      await adminDb.doc('taxonomy_overrides/override1').set({
        id: 'override1',
        organizationId: ORG_A_ID,
        speciesId: 'species1',
        customName: 'Custom Species Name',
      });
    });
  }

  // ========================================
  // User A Access to Shared Taxonomy Collections
  // ========================================

  describe('User A access to shared taxonomy collections', () => {
    test('authenticated user CAN read taxonomy_species (shared)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertSucceeds(demoUserDb.doc('taxonomy_species/species1').get());
    });

    test('authenticated user CAN read taxonomy_provenances (shared)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertSucceeds(demoUserDb.doc('taxonomy_provenances/prov1').get());
    });

    test('authenticated user CAN read taxonomy_lineages (shared)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertSucceeds(demoUserDb.doc('taxonomy_lineages/lineage1').get());
    });

    test('authenticated user CANNOT write to taxonomy_species (server-only)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertFails(
        demoUserDb.doc('taxonomy_species/new_species').set({
          id: 'new_species',
          scientificName: 'Malicious species',
        })
      );
    });

    test('authenticated user CANNOT write to taxonomy_provenances (server-only)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertFails(
        demoUserDb.doc('taxonomy_provenances/new_prov').set({
          id: 'new_prov',
          provenance: 'Malicious provenance',
        })
      );
    });

    test('authenticated user CANNOT write to taxonomy_lineages (server-only)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertFails(
        demoUserDb.doc('taxonomy_lineages/new_lineage').set({
          id: 'new_lineage',
          lineage: 'Malicious lineage',
        })
      );
    });
  });

  // ========================================
  // User B Access to Shared Taxonomy Collections
  // ========================================

  describe('User B access to shared taxonomy collections', () => {
    test('authenticated user CAN read taxonomy_species', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(realUserDb.doc('taxonomy_species/species1').get());
    });

    test('authenticated user CAN read taxonomy_provenances', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(realUserDb.doc('taxonomy_provenances/prov1').get());
    });

    test('authenticated user CAN read taxonomy_lineages', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(realUserDb.doc('taxonomy_lineages/lineage1').get());
    });

    test('non-admin user CANNOT write to taxonomy_species (server-only)', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertFails(
        realUserDb.doc('taxonomy_species/new_species').set({
          id: 'new_species',
          scientificName: 'Malicious species',
        })
      );
    });

    test('non-admin user CANNOT write to taxonomy_provenances (server-only)', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertFails(
        realUserDb.doc('taxonomy_provenances/new_prov').set({
          id: 'new_prov',
          provenance: 'Malicious provenance',
        })
      );
    });

    test('non-admin user CANNOT write to taxonomy_lineages (server-only)', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertFails(
        realUserDb.doc('taxonomy_lineages/new_lineage').set({
          id: 'new_lineage',
          lineage: 'Malicious lineage',
        })
      );
    });
  });

  // ========================================
  // Taxonomy Overrides Access
  // ========================================

  describe('Taxonomy overrides access control', () => {
    test('authenticated user CAN read taxonomy_overrides', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(realUserDb.doc('taxonomy_overrides/override1').get());
    });

    test('non-admin user CANNOT write taxonomy_overrides (admin-only)', async () => {
      const realUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      // Rules require isAdmin() for write access to taxonomy_overrides (global config)
      await assertFails(
        realUserDb.doc('taxonomy_overrides/new_override').set({
          id: 'new_override',
          organizationId: ORG_A_ID,
          speciesId: 'species1',
          customName: 'User Custom Name',
        })
      );
    });

    test('admin user CAN write taxonomy_overrides', async () => {
      // First seed an admin user document
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await adminDb.doc(`users/${USER_B_EMAIL}`).set({
          id: USER_B_EMAIL,
          email: USER_B_EMAIL,
          organizationId: ORG_A_ID,
          isAdmin: true,
        });
      });

      const adminUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(
        adminUserDb.doc('taxonomy_overrides/admin_override').set({
          id: 'admin_override',
          organizationId: ORG_A_ID,
          speciesId: 'species1',
          customName: 'Admin Custom Name',
        })
      );
    });

    test('non-admin user CAN read taxonomy_overrides (global read access)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertSucceeds(demoUserDb.doc('taxonomy_overrides/override1').get());
    });

    test('non-admin user CANNOT write taxonomy_overrides (admin-only)', async () => {
      const demoUserDb = testEnv.authenticatedContext(USER_A_ID, { email: USER_A_EMAIL }).firestore();
      await assertFails(
        demoUserDb.doc('taxonomy_overrides/user_a_override').set({
          id: 'user_a_override',
          organizationId: ORG_A_ID,
          speciesId: 'species1',
          customName: 'User A Override',
        })
      );
    });

    test('admin user CAN update taxonomy_overrides', async () => {
      // Seed admin user
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await adminDb.doc(`users/${USER_B_EMAIL}`).set({
          id: USER_B_EMAIL,
          email: USER_B_EMAIL,
          organizationId: ORG_A_ID,
          isAdmin: true,
        });
      });

      const adminUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(
        adminUserDb.doc('taxonomy_overrides/override1').update({
          customName: 'Updated Custom Name',
        })
      );
    });

    test('admin user CAN delete taxonomy_overrides', async () => {
      // Seed admin user
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminDb = context.firestore();
        await adminDb.doc(`users/${USER_B_EMAIL}`).set({
          id: USER_B_EMAIL,
          email: USER_B_EMAIL,
          organizationId: ORG_A_ID,
          isAdmin: true,
        });
      });

      const adminUserDb = testEnv.authenticatedContext(USER_B_ID, { email: USER_B_EMAIL }).firestore();
      await assertSucceeds(adminUserDb.doc('taxonomy_overrides/override1').delete());
    });
  });

  // ========================================
  // Unauthenticated Access
  // ========================================

  describe('Unauthenticated access to taxonomy collections', () => {
    test('unauthenticated user CANNOT read taxonomy_species', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.doc('taxonomy_species/species1').get());
    });

    test('unauthenticated user CANNOT read taxonomy_provenances', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.doc('taxonomy_provenances/prov1').get());
    });

    test('unauthenticated user CANNOT read taxonomy_lineages', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.doc('taxonomy_lineages/lineage1').get());
    });

    test('unauthenticated user CANNOT write to any taxonomy collection', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(
        unauthDb.doc('taxonomy_species/new_species').set({
          id: 'new_species',
          scientificName: 'Unauthenticated species',
        })
      );
    });
  });
});
