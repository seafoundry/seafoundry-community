#!/usr/bin/env node

/**
 * Runs inventory CSV exports for each step defined in a plan file by invoking
 * the Dart `InventoryExportJob` script. Use this to batch downloads for
 * backfills or partner deliveries without duplicating export logic.
 *
 * Usage:
 *   node scripts/migrations/run_inventory_export_plan.js [--plan <path>] [--from-step <n>] [--report <path>]
 *
 * Plan format (JSON):
 * {
 *   "steps": [
 *     {
 *       "label": "staging kelp export",
 *       "organizationId": "org_123",
 *       "userId": "user_abc",
 *       "organismKind": "kelp",
 *       "out": "exports/org_123_kelp.csv",
 *       "filename": "inventory_org_123_kelp.csv",
 *       "stdout": false,
 *       "extraArgs": ["--stdout"],
 *       "env": { "GOOGLE_APPLICATION_CREDENTIALS": "/path/to/key.json" }
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
  'inventory_export.plan.json',
);

let planPath = defaultPlanPath;
let startIndex = 0;
let reportPath = null;
let dartExecutable = process.env.DART_BIN || 'dart';

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
  } else if (arg === '--dart-bin') {
    dartExecutable = args[i + 1] || dartExecutable;
    i += 1;
  }
}

const timestamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0];
if (!reportPath) {
  reportPath = path.join(
    migrationsDir,
    'reports',
    `inventory_export_${timestamp}.json`,
  );
}

if (!fs.existsSync(planPath)) {
  console.error(
    `❌ Plan file not found at ${planPath}. Copy the template:\n` +
      `cp scripts/migrations/inventory_export.plan.template.json ${planPath}`,
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

function resolveOutputPath(outPath) {
  if (!outPath || outPath.trim().length === 0) {
    return null;
  }
  return path.resolve(process.cwd(), outPath);
}

function buildArgs(step) {
  if (!step.organizationId) {
    throw new Error('Plan step missing required organizationId');
  }
  if (!step.userId) {
    throw new Error('Plan step missing required userId');
  }

  const cmdArgs = [
    'run',
    'scripts/export_inventory_csv.dart',
    '--org',
    step.organizationId,
    '--user',
    step.userId,
  ];

  if (step.organismKind) {
    cmdArgs.push('--organism', step.organismKind);
  }
  if (step.filename) {
    cmdArgs.push('--filename', step.filename);
  }
  if (step.stdout) {
    cmdArgs.push('--stdout');
  }
  const resolvedOut = resolveOutputPath(step.out);
  if (resolvedOut) {
    const folder = path.dirname(resolvedOut);
    fs.mkdirSync(folder, { recursive: true });
    cmdArgs.push('--out', resolvedOut);
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
  let argsForStep;
  try {
    argsForStep = buildArgs(step);
  } catch (error) {
    throw new Error(`${label}: ${error.message}`);
  }

  const startedAt = Date.now();
  console.log(`\n🚀 [${index + startIndex}] ${label}`);
  console.log(
    `   ↪ ${dartExecutable} ${argsForStep.join(' ')}`,
  );

  return new Promise((resolve, reject) => {
    const child = spawn(dartExecutable, argsForStep, {
      stdio: 'inherit',
      env: { ...process.env, ...(step.env || {}) },
    });

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
    `📝 Inventory export report saved to ${path.relative(process.cwd(), reportPath)}`,
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
  writeReport('success');
  console.log('\n✅ Inventory export plan completed successfully.');
}

runPlan();
