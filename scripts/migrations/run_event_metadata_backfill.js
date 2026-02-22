#!/usr/bin/env node

/**
 * Sequencer that runs the event metadata backfill script for each step
 * defined in a plan file. Plans allow us to dry-run individual organizations
 * in a dry-run before promoting the same command to live execution.
 *
 * Usage:
 *   node scripts/migrations/run_event_metadata_backfill.js [--plan <path>] [--from-step <n>]
 *
 * Plan format (JSON):
 * {
 *   "steps": [
 *     {
 *       "label": "seafoundryapp dry-run – coral lab",
 *       "organizationId": "org_123",
 *       "dryRun": true,
 *       "force": true,
 *       "limit": 5000,
 *       "batchSize": 200,
 *       "startAfter": "events/abc",
 *       "extraArgs": ["--verbose"],
 *       "env": { "FIREBASE_PROJECT_ID": "seafoundryapp" }
 *     }
 *   ]
 * }
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const args = process.argv.slice(2);
const migrationsDir = __dirname;
const defaultPlanPath = path.join(
  migrationsDir,
  'event_metadata_backfill.plan.json',
);

let planPath = defaultPlanPath;
let startIndex = 0;
let reportPath = null;

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--plan' || arg === '-p') {
    planPath = path.resolve(process.cwd(), args[i + 1] ?? '');
    i += 1;
  } else if (arg === '--from-step') {
    startIndex = parseInt(args[i + 1], 10) || 0;
    i += 1;
  } else if (arg === '--report') {
    const provided = args[i + 1];
    if (provided && !provided.startsWith('--')) {
      reportPath = path.resolve(process.cwd(), provided);
      i += 1;
    }
  }
}

const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
if (!reportPath) {
  reportPath = path.join(
    migrationsDir,
    'reports',
    `event_metadata_backfill_${timestamp}.json`,
  );
}

if (!fs.existsSync(planPath)) {
  console.error(
    `❌ Plan file not found at ${planPath}. Copy the template:\n` +
      `cp scripts/migrations/event_metadata_backfill.plan.template.json ${planPath}`,
  );
  process.exit(1);
}

const planRaw = fs.readFileSync(planPath, 'utf8');
let plan;
try {
  plan = JSON.parse(planRaw);
} catch (error) {
  console.error('❌ Failed to parse plan JSON:', error.message);
  process.exit(1);
}

if (!plan || !Array.isArray(plan.steps) || plan.steps.length === 0) {
  console.error('❌ Plan must define a non-empty "steps" array.');
  process.exit(1);
}

const steps = plan.steps.slice(startIndex);
if (steps.length === 0) {
  console.warn('⚠️  No steps to execute (start index beyond plan length).');
  process.exit(0);
}

const reportEntries = [];

function buildArgs(step) {
  const cmdArgs = [];
  if (step.organizationId) {
    cmdArgs.push('--organization', step.organizationId);
  }
  if (step.dryRun) {
    cmdArgs.push('--dry-run');
  }
  if (step.force) {
    cmdArgs.push('--force');
  }
  if (typeof step.limit === 'number' && !Number.isNaN(step.limit)) {
    cmdArgs.push('--limit', String(step.limit));
  }
  if (typeof step.batchSize === 'number' && !Number.isNaN(step.batchSize)) {
    cmdArgs.push('--batch-size', String(step.batchSize));
  }
  if (step.startAfter) {
    cmdArgs.push('--start-after', step.startAfter);
  }
  if (step.verbose) {
    cmdArgs.push('--verbose');
  }
  if (Array.isArray(step.extraArgs)) {
    cmdArgs.push(
      ...step.extraArgs.map((value) => value.toString()).filter(Boolean),
    );
  }
  return cmdArgs;
}

function summarizeEnvKeys(step) {
  return Object.keys(step.env || {});
}

async function runStep(step, index) {
  const label = step.label || `Step ${index + startIndex}`;
  const argsForStep = buildArgs(step);
  const startedAt = Date.now();
  console.log(`\n🚀 [${index + startIndex}] ${label}`);
  console.log(
    `   ↪ node scripts/backfill_event_metadata.js ${argsForStep.join(' ')}`,
  );

  return new Promise((resolve, reject) => {
    const child = spawn(
      'node',
      ['scripts/backfill_event_metadata.js', ...argsForStep],
      {
        stdio: 'inherit',
        env: { ...process.env, ...(step.env || {}) },
      },
    );

    child.on('error', (error) => reject(error));
    child.on('close', (code) => {
      const durationMs = Date.now() - startedAt;
      reportEntries.push({
        label,
        args: argsForStep,
        envKeys: summarizeEnvKeys(step),
        startedAt: new Date(startedAt).toISOString(),
        durationMs,
        status: code === 0 ? 'success' : 'failed',
      });
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${label} exited with code ${code}`));
      }
    });
  });
}

function writeReport(status) {
  if (!reportPath) return;
  const output = {
    planPath,
    startIndex,
    status,
    generatedAt: new Date().toISOString(),
    steps: reportEntries,
  };
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(output, null, 2));
  console.log(
    `📝 Backfill report saved to ${path.relative(process.cwd(), reportPath)}`,
  );
}

async function runPlan() {
  for (let i = 0; i < steps.length; i += 1) {
    const step = steps[i];
    try {
      await runStep(step, i);
    } catch (error) {
      console.error(`\n❌ Failed at step ${i + startIndex}: ${error.message}`);
      writeReport('failed');
      process.exit(1);
    }
  }
  console.log('\n✅ All backfill steps completed successfully.');
  writeReport('success');
}

runPlan();
