/**
 * Shared fail-safe guard for seed/check scripts.
 *
 * Destructive (or real-project-touching) scripts must only run against emulators
 * or demo-* project IDs. This mirrors the canonical guard from seed-demo.js so
 * every script refuses to run against a real Firebase project.
 *
 * SECURITY: The guard is only authoritative when it validates the EXACT project
 * id that the caller passes to admin.initializeApp(). Callers MUST resolve the
 * project id (via resolveProjectId or their own config precedence) and pass that
 * same value both here and into admin.initializeApp({ projectId }). Passing no
 * explicit id falls back to the canonical env precedence, which may NOT match the
 * project the Admin SDK actually targets.
 *
 * Usage:
 *   const { requireEmulatorOrDemo, resolveProjectId } = require('./lib/require-emulator-or-demo');
 *   const projectId = resolveProjectId();
 *   requireEmulatorOrDemo('check-null-fields.js', projectId);
 *   admin.initializeApp({ credential: ..., projectId });
 */

function resolveProjectId(explicit) {
  return (
    explicit ||
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    ''
  );
}

function requireEmulatorOrDemo(scriptName, explicitProjectId) {
  const isEmulator = !!(
    process.env.FIRESTORE_EMULATOR_HOST ||
    process.env.FIREBASE_AUTH_EMULATOR_HOST
  );
  const projectId = resolveProjectId(explicitProjectId);
  const isDemoProject = projectId.startsWith('demo-');

  if (!isEmulator && !isDemoProject) {
    console.error(`❌ SAFETY: ${scriptName} only runs against emulators or demo projects.`);
    console.error('   Detected project:', projectId || '(unknown)');
    console.error('');
    console.error('   To run against emulator:');
    console.error('     FIRESTORE_EMULATOR_HOST=localhost:58080 \\');
    console.error('     FIREBASE_AUTH_EMULATOR_HOST=localhost:9555 \\');
    console.error(`     node scripts/${scriptName}`);
    console.error('');
    console.error('   Or set FIREBASE_PROJECT_ID to a project starting with "demo-".');
    process.exit(1);
  }

  if (isEmulator) {
    console.log('✓ Running against emulator');
  } else {
    console.log(`✓ Running against demo project: ${projectId}`);
  }

  return { isEmulator, projectId };
}

module.exports = { requireEmulatorOrDemo, resolveProjectId };
