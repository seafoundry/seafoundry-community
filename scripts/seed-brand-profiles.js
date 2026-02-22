#!/usr/bin/env node

/**
 * Seeds test brand profiles for Visual Engagement testing.
 * Creates brand profiles in both:
 *   - brand_profiles/{id} (root collection - primary, read by BrandProfileRepository)
 *   - public_orgs/{orgId}/brand_profiles/{id} (mirror for public access)
 *
 * Usage:
 *   node scripts/seed-brand-profiles.js [--org <org-id>]
 */

const { db } = require('./config-json');

const args = process.argv.slice(2);
let targetOrgId = null;

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === '--org' || arg === '-o') {
    targetOrgId = args[i + 1];
    i += 1;
  }
}

// Sample hero images from Unsplash (ocean/coral/marine themes)
const sampleHeroImages = [
  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200', // Coral reef
  'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200', // Ocean waves
  'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200', // Underwater coral
  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200', // Tropical fish
];

const sampleAccentColors = [
  '#00AEEF', // Aqua blue
  '#00BCD4', // Cyan
  '#0288D1', // Ocean blue
  '#26C6DA', // Light cyan
  '#00897B', // Teal
];

async function seedBrandProfiles() {
  try {
    console.log('🎨 Seeding brand profiles...\n');

    let organizations = [];

    if (targetOrgId) {
      // Seed specific org
      const orgDoc = await db.collection('organizations').doc(targetOrgId).get();
      if (!orgDoc.exists) {
        console.error(`❌ Organization ${targetOrgId} not found`);
        process.exit(1);
      }
      organizations = [{ id: targetOrgId, name: orgDoc.data().name || 'Test Org' }];
    } else {
      // Seed all orgs
      const orgsSnapshot = await db.collection('organizations').get();
      if (orgsSnapshot.empty) {
        console.warn('⚠️  No organizations found in Firestore.');
        return;
      }
      orgsSnapshot.forEach(doc => {
        const data = doc.data();
        organizations.push({
          id: doc.id,
          name: data.name || data.displayName || 'Unnamed Org',
        });
      });
    }

    console.log(`📝 Found ${organizations.length} organization(s) to seed\n`);

    let seededCount = 0;
    let skippedCount = 0;

    for (const org of organizations) {
      const collectionPath = `public_orgs/${org.id}/brand_profiles`;

      const rootPath = 'brand_profiles';

      // Check if brand profile already exists (check root collection)
      const existingRoot = await db.collection(rootPath)
        .where('organizationId', '==', org.id)
        .limit(1)
        .get();

      if (!existingRoot.empty) {
        console.log(`⏭️  Skipping ${org.name} (${org.id}) - brand profile exists`);
        skippedCount++;
        continue;
      }

      // Create brand profile
      const brandProfileId = `brand-${org.id}`;
      const heroImage = sampleHeroImages[seededCount % sampleHeroImages.length];
      const accentColor = sampleAccentColors[seededCount % sampleAccentColors.length];
      const now = new Date().toISOString();

      const brandProfile = {
        id: brandProfileId,
        organizationId: org.id,
        modelType: 'brandProfile',
        brandName: org.name,
        heroImageUrl: heroImage,
        logoUrl: null, // Can be set later via UI
        accentColor: accentColor,
        published: true,
        kioskEnabled: false,
        createdAt: now,
        createdById: 'seed-script',
        updatedAt: now,
        updatedById: 'seed-script',
      };

      // Write to root collection (primary - read by BrandProfileRepository)
      await db.collection(rootPath).doc(brandProfileId).set(brandProfile);
      // Write to public_orgs mirror (for public access)
      await db.collection(collectionPath).doc(brandProfileId).set(brandProfile);
      console.log(`✅ Created brand profile for ${org.name} (${org.id})`);
      console.log(`   - Hero: ${heroImage}`);
      console.log(`   - Color: ${accentColor}\n`);
      seededCount++;
    }

    console.log(`\n🎉 Brand profile seeding complete!`);
    console.log(`   - Seeded: ${seededCount}`);
    console.log(`   - Skipped: ${skippedCount}`);
    console.log(`   - Total: ${organizations.length}\n`);

  } catch (error) {
    console.error('❌ Error seeding brand profiles:', error);
    process.exit(1);
  }
}

seedBrandProfiles()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });
