#!/usr/bin/env node

// Seed script specifically for Firebase Emulator during integration testing
// NOTE: Production DB must be wiped/reset after Data Field Unification (SOT)
// to ensure all data uses canonical fields (genetId top-level, physicalFormId,
// SizeSpec format, no legacy fields).
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

// Check if we're connected to emulator BEFORE initializing
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('FIRESTORE_EMULATOR_HOST not set. Make sure Firebase Emulator is running.');
  console.error('Run: export FIRESTORE_EMULATOR_HOST=localhost:8080');
  process.exit(1);
}

// Initialize Firebase Admin for emulator
const app = initializeApp({
  projectId: 'seafoundryapp',
});

const db = getFirestore(app);
const auth = getAuth(app);

const ORG_ID = 'test_org_001';
const NOW = '2025-10-02T23:55:50.667855';

// Auth user UIDs - these are the Firebase Auth UIDs used throughout
const UIDS = {
  user: 'test-user',
  admin: 'test-admin',
  viewer: 'test-viewer',
};

// Test data for integration tests - matches current model structure
// NOTE: groups, genets, organismRecords are org subcollections,
// seeded via seedOrgSubcollections() instead of root collections.
const testData = {
  organizations: [
    {
      id: ORG_ID,
      name: 'Test Research Institute',
      domain: 'test-institute',
      // NOTE: Must use 'activities' field - Organization.fromJson reads from 'activities' not 'siteTypeIds'
      activities: ['nes', 'nis', 'op', 'gb', 'bl', 'ref'],
      speciesIds: [],
      tier: 'pro',
      supportedOrganismKinds: ['coral'],
      urlPath: 'test-institute',
      internalPath: `organizations/${ORG_ID}`,
      slug: 'test-institute',
      modelType: 'organization',
      organizationId: ORG_ID,
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ],
  sites: [
    {
      id: 'test_site_001',
      name: 'Test Research Site',
      organizationId: ORG_ID,
      siteTypeId: 'site_type_nursery_ex_situ',
      groupIdHierarchy: [],
      description: null,
      urlPath: 'test-institute/test-research-site',
      internalPath: 'sites/test_site_001',
      slug: 'test-research-site',
      modelType: 'site',
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ],
  species: [
    {
      id: 'acer',
      species: 'cervicornis',
      genus: 'Acropora',
      name: 'Acropora cervicornis',
      modelType: 'species',
    }
  ],
  users: [
    {
      id: UIDS.user,
      uid: UIDS.user,
      name: 'Test User',
      organizationId: ORG_ID,
      email: 'test-user@seafoundry.test',
      imageUrl: null,
      role: 'practitioner_plus',
      modelType: 'user',
      createdById: UIDS.user,
      updatedById: UIDS.user,
      createdAt: NOW,
      updatedAt: NOW,
    },
    {
      id: UIDS.admin,
      uid: UIDS.admin,
      name: 'Test Admin',
      organizationId: ORG_ID,
      email: 'test-admin@seafoundry.test',
      imageUrl: null,
      role: 'admin',
      modelType: 'user',
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    },
    {
      id: UIDS.viewer,
      uid: UIDS.viewer,
      name: 'Test Viewer',
      organizationId: ORG_ID,
      email: 'test-viewer@seafoundry.test',
      imageUrl: null,
      role: 'view_only',
      modelType: 'user',
      createdById: UIDS.viewer,
      updatedById: UIDS.viewer,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ]
};

// Org-subcollection data: seeded under /organizations/{orgId}/{collection}/
const orgSubcollectionData = {
  groups: [
    {
      id: 'test_group_001',
      name: 'Test Coral Group',
      organizationId: ORG_ID,
      siteId: 'test_site_001',
      parentId: '',  // Root-level group has empty parentId
      groupTypeId: 'patch',
      description: null,
      capacity: null,
      urlPath: 'test-institute/test-research-site/test-coral-group',
      internalPath: `organizations/${ORG_ID}/groups/test_group_001`,
      slug: 'test-coral-group',
      modelType: 'group',
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ],
  genets: [
    {
      id: 'test_genet_001',
      name: 'Test Genet TG001',
      localId: 'TG001',
      provenanceId: 'PID-DMAC-0001',
      clonalId: 'TG001',
      accessionNumber: 'ACC001',
      speciesId: 'acer',
      provenanceTypeId: 'provenance_type_wild',
      organismKind: 'coral',
      organizationId: ORG_ID,
      urlPath: 'test-institute/genets/test-genet-tg001',
      internalPath: `organizations/${ORG_ID}/genets/test_genet_001`,
      slug: 'test-genet-tg001',
      modelType: 'genet',
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ],
  organismRecords: [
    {
      id: 'test_coral_001',
      recordName: 'Test Coral TC001',
      localId: 'TC001',
      organizationId: ORG_ID,
      siteId: 'test_site_001',
      groupId: 'test_group_001',
      genetId: 'test_genet_001',
      speciesId: 'acer',
      organismKind: 'coral',
      lifeStageId: 'life_stage_adult',
      lifeStage: { id: 'life_stage_adult' },
      measurement: { value: 1, unit: 'count' },
      physicalForm: { formId: 'fragment', sizeBandId: 'medium' },
      physicalFormConfigVersion: 'v1',
      provenanceTypeId: 'provenance_type_wild',
      urlPath: 'test-institute/test-research-site/test-coral-group/test-coral-tc001',
      internalPath: `organizations/${ORG_ID}/organismRecords/test_coral_001`,
      slug: 'test-coral-tc001',
      modelType: 'organismRecord',
      createdById: UIDS.admin,
      updatedById: UIDS.admin,
      createdAt: NOW,
      updatedAt: NOW,
    }
  ],
};

// Members subcollection: seeded under /organizations/{orgId}/members/{uid}
const memberData = [
  {
    uid: UIDS.user,
    memberId: UIDS.user,
    email: 'test-user@seafoundry.test',
    role: 'practitioner_plus',
    organizationId: ORG_ID,
    createdById: UIDS.admin,
    joinedAt: NOW,
    createdAt: NOW,
    updatedAt: NOW,
  },
  {
    uid: UIDS.admin,
    memberId: UIDS.admin,
    email: 'test-admin@seafoundry.test',
    role: 'admin',
    organizationId: ORG_ID,
    createdById: UIDS.admin,
    joinedAt: NOW,
    createdAt: NOW,
    updatedAt: NOW,
  },
  {
    uid: UIDS.viewer,
    memberId: UIDS.viewer,
    email: 'test-viewer@seafoundry.test',
    role: 'view_only',
    organizationId: ORG_ID,
    createdById: UIDS.admin,
    joinedAt: NOW,
    createdAt: NOW,
    updatedAt: NOW,
  },
];

const authUsers = [
  {
    uid: UIDS.user,
    email: 'test-user@seafoundry.test',
    password: 'TestPassword123!',
    displayName: 'Test User',
  },
  {
    uid: UIDS.admin,
    email: 'test-admin@seafoundry.test',
    password: 'TestPassword123!',
    displayName: 'Test Admin',
  },
  {
    uid: UIDS.viewer,
    email: 'test-viewer@seafoundry.test',
    password: 'TestPassword123!',
    displayName: 'Test Viewer',
  },
];

async function clearCollection(collectionPath) {
  console.log(`Clearing ${collectionPath}...`);
  const snapshot = await db.collection(collectionPath).get();
  const batch = db.batch();

  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  if (!snapshot.empty) {
    await batch.commit();
  }
}

async function seedCollection(collectionPath, data) {
  console.log(`Seeding ${collectionPath} (${data.length} items)...`);
  const batch = db.batch();

  data.forEach((item) => {
    const docRef = db.collection(collectionPath).doc(item.id);
    batch.set(docRef, item);
  });

  await batch.commit();
  console.log(`  ${collectionPath} seeded successfully`);
}

async function seedOrgSubcollections() {
  console.log('\nSeeding org subcollections...');
  const orgRef = db.collection('organizations').doc(ORG_ID);

  for (const [subcollection, items] of Object.entries(orgSubcollectionData)) {
    const path = `organizations/${ORG_ID}/${subcollection}`;
    console.log(`Seeding ${path} (${items.length} items)...`);
    const batch = db.batch();

    items.forEach((item) => {
      const docRef = orgRef.collection(subcollection).doc(item.id);
      batch.set(docRef, item);
    });

    await batch.commit();
    console.log(`  ${path} seeded successfully`);
  }
}

async function seedMembers() {
  console.log('\nSeeding org members...');
  const membersRef = db.collection('organizations').doc(ORG_ID).collection('members');
  const batch = db.batch();

  memberData.forEach((member) => {
    // Document ID must be the Firebase Auth UID for isMemberByUid() to work
    const docRef = membersRef.doc(member.uid);
    batch.set(docRef, member);
  });

  await batch.commit();
  console.log(`  ${memberData.length} members seeded successfully`);
}

async function seedAuthUsers() {
  console.log('\nSeeding auth users...');
  for (const user of authUsers) {
    try {
      await auth.createUser(user);
      console.log(`  Created auth user ${user.email}`);
    } catch (error) {
      if (error.code === 'auth/uid-already-exists' || error.code === 'auth/email-already-exists') {
        await auth.updateUser(user.uid, {
          email: user.email,
          password: user.password,
          displayName: user.displayName,
        });
        console.log(`  Updated auth user ${user.email}`);
      } else {
        console.warn(`  Skipping auth user ${user.email}:`, error.message || error);
      }
    }
  }
}

async function main() {
  console.log('Seeding Firebase Emulator for Integration Tests');
  console.log('===============================================');

  try {
    // Clear existing data (root collections)
    console.log('\nClearing existing data...');
    for (const collection of Object.keys(testData)) {
      await clearCollection(collection);
    }
    // Clear org subcollections
    for (const subcollection of Object.keys(orgSubcollectionData)) {
      await clearCollection(`organizations/${ORG_ID}/${subcollection}`);
    }
    await clearCollection(`organizations/${ORG_ID}/members`);

    // Seed auth users first so uid values are deterministic (best effort)
    try {
      await seedAuthUsers();
    } catch (error) {
      console.warn('Unable to seed auth users via Admin SDK (continuing):', error.message || error);
    }

    // Seed test data in dependency order
    console.log('\nSeeding test data...');
    await seedCollection('species', testData.species);
    await seedCollection('organizations', testData.organizations);
    await seedCollection('sites', testData.sites);
    await seedCollection('users', testData.users);

    // Seed org subcollections (groups, genets, organismRecords)
    await seedOrgSubcollections();

    // Seed membership documents (required for isOrgMemberOf() in firestore rules)
    await seedMembers();

    console.log('\nIntegration test data seeded successfully!');
    console.log('\nSummary:');
    for (const [collection, data] of Object.entries(testData)) {
      console.log(`  ${collection}: ${data.length} items`);
    }
    for (const [subcollection, items] of Object.entries(orgSubcollectionData)) {
      console.log(`  organizations/${ORG_ID}/${subcollection}: ${items.length} items`);
    }
    console.log(`  organizations/${ORG_ID}/members: ${memberData.length} items`);

  } catch (error) {
    console.error('\nError seeding test data:', error);
    process.exit(1);
  }
}

main().then(() => {
  console.log('\nDone!');
  process.exit(0);
});
