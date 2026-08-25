import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';

// Boot a rules-test environment against the Firestore emulator on 58080.
// projectId matches the emulators:exec --project flag (demo-seafoundry).
export async function makeEnv() {
  return initializeTestEnvironment({
    projectId: 'demo-seafoundry',
    firestore: {
      host: 'localhost',
      port: 58080,
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
}

// Firestore handle for an authenticated identity.
// token carries custom claims the rules read (notably request.auth.token.email).
export const authed = (env, uid, token = {}) =>
  env.authenticatedContext(uid, token).firestore();

// Seed committed pre-state with security rules disabled.
export const seed = (env, fn) =>
  env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
