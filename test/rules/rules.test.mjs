import { test, describe, before, after, beforeEach } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  deleteDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { makeEnv, authed, seed } from './helpers.mjs';

let env;

const UID_A = 'uidA'; // org O1 creator / admin
const UID_B = 'uidB'; // org O2 member / invitee
const UID_C = 'uidC'; // arbitrary member of O1
const UID_Z = 'uidZ'; // outsider / attacker

before(async () => {
  env = await makeEnv();
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// ---- seeding helpers (rules disabled) ----
async function seedOrg(orgId, createdById) {
  await seed(env, (db) =>
    setDoc(doc(db, 'organizations', orgId), {
      organizationId: orgId,
      createdById,
      name: `${orgId} Org`,
    }),
  );
}
async function seedMember(orgId, uid, role, createdById = uid) {
  await seed(env, (db) =>
    setDoc(doc(db, 'organizations', orgId, 'members', uid), {
      organizationId: orgId,
      createdById,
      role,
    }),
  );
}
async function seedTransfer(id, fromOrg, toOrg, createdById, extra = {}) {
  await seed(env, (db) =>
    setDoc(doc(db, 'events', id), {
      id,
      organizationId: fromOrg,
      toOrganizationId: toOrg,
      createdById,
      status: 'pending',
      quantity: 5,
      ...extra,
    }),
  );
}
async function seedIndex(indexId, orgId, emailLower) {
  await seed(env, (db) =>
    setDoc(doc(db, 'invitation_index', indexId), {
      organizationId: orgId,
      email: emailLower,
    }),
  );
}

// ============================================================
describe('POSITIVES (must succeed)', () => {
  test('P1: onboarding batch member-create commits', async () => {
    const db = authed(env, UID_A, { email: 'a@x.io' });
    const batch = writeBatch(db);
    batch.set(doc(db, 'organizations', 'O1'), {
      organizationId: 'O1',
      createdById: UID_A,
      name: 'O1 Org',
    });
    batch.set(doc(db, 'events', 'E1'), {
      id: 'E1',
      organizationId: 'O1',
      createdById: UID_A,
    });
    batch.set(doc(db, 'users', UID_A), {
      organizationId: 'O1',
      email: 'a@x.io',
    });
    batch.set(doc(db, 'organizations', 'O1', 'members', UID_A), {
      organizationId: 'O1',
      createdById: UID_A,
      role: 'admin',
    });
    batch.set(doc(db, 'organizations', 'O1', 'slugCounts', 'acer'), {
      count: 0,
    });
    await assertSucceeds(batch.commit());
  });

  test('P2: creator bootstrap member-create', async () => {
    await seedOrg('O1', UID_A);
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      setDoc(doc(db, 'organizations', 'O1', 'members', UID_A), {
        organizationId: 'O1',
        createdById: UID_A,
        role: 'admin',
      }),
    );
  });

  test('P3: invited accept self-creates member + clears own index', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    await seedIndex('O1_bob@x.io', 'O1', 'bob@x.io');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertSucceeds(
      setDoc(doc(db, 'organizations', 'O1', 'members', UID_B), {
        organizationId: 'O1',
        createdById: UID_B,
        role: 'practitioner',
      }),
    );
    await assertSucceeds(deleteDoc(doc(db, 'invitation_index', 'O1_bob@x.io')));
  });

  test('P4: existing member adds another member', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      setDoc(doc(db, 'organizations', 'O1', 'members', UID_C), {
        organizationId: 'O1',
        createdById: UID_A,
        role: 'view_only',
      }),
    );
  });

  test('P5: sender edits pending quantity on transfer event', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O1', UID_A, 'admin');
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      setDoc(
        doc(db, 'events', 'T1'),
        { quantity: 3, status: 'pending' },
        { merge: true },
      ),
    );
  });

  test('P6: recipient receives + sets targetUrlPath', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O2', UID_B, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertSucceeds(
      setDoc(
        doc(db, 'events', 'T1'),
        {
          status: 'received',
          targetUrlPath: 'o2/site1/g1',
          receivedById: UID_B,
        },
        { merge: true },
      ),
    );
  });

  test('P7: recipient reads inbound transfer event', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O2', UID_B, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertSucceeds(getDoc(doc(db, 'events', 'T1')));
  });

  test('P8: admin promotes a member (role update)', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    await seedMember('O1', UID_C, 'view_only', UID_A);
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      updateDoc(doc(db, 'organizations', 'O1', 'members', UID_C), {
        role: 'practitioner',
      }),
    );
  });

  test('P9: admin removes a member (delete)', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    await seedMember('O1', UID_C, 'view_only', UID_A);
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      deleteDoc(doc(db, 'organizations', 'O1', 'members', UID_C)),
    );
  });

  test('P10: self-leave (delete own member doc)', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_C, 'view_only', UID_A);
    const db = authed(env, UID_C, { email: 'c@x.io' });
    await assertSucceeds(
      deleteDoc(doc(db, 'organizations', 'O1', 'members', UID_C)),
    );
  });

  test('P11: member renames org (createdById unchanged)', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertSucceeds(
      updateDoc(doc(db, 'organizations', 'O1'), { name: 'Renamed Org' }),
    );
  });
});

// ============================================================
describe('NEGATIVES (must fail)', () => {
  test('N1: view_only self-promote to admin', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_C, 'view_only', UID_A);
    const db = authed(env, UID_C, { email: 'c@x.io' });
    await assertFails(
      updateDoc(doc(db, 'organizations', 'O1', 'members', UID_C), {
        role: 'admin',
      }),
    );
  });

  test('N2: random user self-joins org (no invite index)', async () => {
    await seedOrg('O1', UID_A);
    const db = authed(env, UID_Z, { email: 'z@x.io' });
    await assertFails(
      setDoc(doc(db, 'organizations', 'O1', 'members', UID_Z), {
        organizationId: 'O1',
        createdById: UID_Z,
        role: 'admin',
      }),
    );
  });

  test('N3: spoof users.organizationId then read org-scoped data denied', async () => {
    await seedOrg('O1', UID_A);
    await seed(env, (db) =>
      setDoc(doc(db, 'organizations', 'O1', 'organism_records', 'R1'), {
        organizationId: 'O1',
        localGenetId: 'ACER-001',
      }),
    );
    const db = authed(env, UID_Z, { email: 'z@x.io' });
    // self-write of own user doc is allowed...
    await assertSucceeds(
      setDoc(doc(db, 'users', UID_Z), { organizationId: 'O1' }),
    );
    // ...but it must NOT grant read of org-scoped protected data.
    await assertFails(
      getDoc(doc(db, 'organizations', 'O1', 'organism_records', 'R1')),
    );
  });

  test('N3b: spoof then read inbound transfer event denied', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    const db = authed(env, UID_Z, { email: 'z@x.io' });
    await assertSucceeds(
      setDoc(doc(db, 'users', UID_Z), { organizationId: 'O2' }),
    );
    await assertFails(getDoc(doc(db, 'events', 'T1')));
  });

  test('N4a: recipient rewrites organizationId denied', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O2', UID_B, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertFails(
      setDoc(doc(db, 'events', 'T1'), { organizationId: 'O2' }, { merge: true }),
    );
  });

  test('N4b: recipient rewrites createdById denied', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O2', UID_B, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertFails(
      setDoc(doc(db, 'events', 'T1'), { createdById: UID_B }, { merge: true }),
    );
  });

  test('N4c: recipient rewrites id denied', async () => {
    await seedTransfer('T1', 'O1', 'O2', UID_A);
    await seedMember('O2', UID_B, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertFails(
      setDoc(doc(db, 'events', 'T1'), { id: 'X' }, { merge: true }),
    );
  });

  test('N5: non-owner admin deletes org denied', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_B, 'admin', UID_A);
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertFails(deleteDoc(doc(db, 'organizations', 'O1')));
  });

  test('N6: member rewrites org createdById denied', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    const db = authed(env, UID_A, { email: 'a@x.io' });
    await assertFails(
      updateDoc(doc(db, 'organizations', 'O1'), { createdById: UID_Z }),
    );
  });

  test('N7: uninvited accept (no invitation_index) denied', async () => {
    await seedOrg('O1', UID_A);
    await seedMember('O1', UID_A, 'admin');
    const db = authed(env, UID_B, { email: 'bob@x.io' });
    await assertFails(
      setDoc(doc(db, 'organizations', 'O1', 'members', UID_B), {
        organizationId: 'O1',
        createdById: UID_B,
        role: 'practitioner',
      }),
    );
  });

  test('N8: stranger deletes invitation_index doc denied', async () => {
    await seedIndex('O1_bob@x.io', 'O1', 'bob@x.io');
    const db = authed(env, UID_Z, { email: 'zoe@x.io' });
    await assertFails(deleteDoc(doc(db, 'invitation_index', 'O1_bob@x.io')));
  });
});
