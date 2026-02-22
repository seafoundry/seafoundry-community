#!/usr/bin/env node

/**
 * Populates the event metadata backfill plan file with real organization IDs
 * from Firestore using Firebase CLI/Admin SDK.
 *
 * Usage:
 *   node scripts/migrations/populate_backfill_plan.js [--project <project-id>]
 */

const { db } = require('../config-json');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let projectId = 'seafoundryapp';

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--project' || arg === '-p') {
    projectId = args[i + 1] || 'seafoundryapp';
    i += 1;
  }
}

const planPath = path.join(__dirname, 'event_metadata_backfill.plan.json');
const templatePath = path.join(__dirname, 'event_metadata_backfill.plan.template.json');

async function populatePlan() {
  try {
    console.log(`🔍 Querying organizations from Firestore (project: ${projectId})...`);
    
    const orgsSnapshot = await db.collection('organizations').get();
    
    if (orgsSnapshot.empty) {
      console.warn('⚠️  No organizations found in Firestore.');
      console.log('📝 Creating plan file from template (you can manually edit organization IDs)...');
      if (fs.existsSync(templatePath)) {
        const template = JSON.parse(fs.readFileSync(templatePath, 'utf8'));
        fs.writeFileSync(planPath, JSON.stringify(template, null, 2));
        console.log(`✅ Created ${planPath} from template`);
      }
      return;
    }

    const organizations = [];
    orgsSnapshot.forEach(doc => {
      const data = doc.data();
      organizations.push({
        id: doc.id,
        name: data.name || data.displayName || doc.id,
        status: data.status || 'unknown'
      });
    });

    console.log(`✅ Found ${organizations.length} organization(s):`);
    organizations.forEach(org => {
      console.log(`   - ${org.name} (${org.id}) [${org.status}]`);
    });

    // Determine project environments
    const isProduction = projectId === 'seafoundryapp';
    const projectEnv = isProduction ? 'production' : 'staging';

    // Build plan steps
    const steps = [];
    
    // Add dry-run steps for each organization
    organizations.forEach(org => {
      if (org.status === 'active' || org.status === 'unknown') {
        // Dry-run step
        steps.push({
          label: `${projectEnv} dry-run – ${org.name}`,
          organizationId: org.id,
          dryRun: true,
          force: true,
          batchSize: 250,
          limit: 1000, // Start with a small limit for testing
          env: {
            FIREBASE_PROJECT_ID: projectId
          }
        });

        // Live step (commented out by default for safety)
        steps.push({
          label: `${projectEnv} live – ${org.name}`,
          organizationId: org.id,
          force: false, // Require confirmation
          batchSize: 400,
          env: {
            FIREBASE_PROJECT_ID: projectId
          }
        });
      }
    });

    const plan = { steps };

    // Write plan file
    fs.writeFileSync(planPath, JSON.stringify(plan, null, 2));
    console.log(`\n✅ Populated ${planPath} with ${steps.length} step(s)`);
    console.log(`\n⚠️  IMPORTANT: Review the plan file before running migrations!`);
    console.log(`   - Dry-run steps are set to force=true (skip confirmation)`);
    console.log(`   - Live steps are set to force=false (require confirmation)`);
    console.log(`   - Adjust limits, batch sizes, and organization IDs as needed`);
    console.log(`\n📖 To run the plan:`);
    console.log(`   npm run migrate:event-organism-kind:plan`);

  } catch (error) {
    console.error('❌ Error populating plan:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

populatePlan();












