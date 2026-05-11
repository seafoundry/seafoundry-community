#!/usr/bin/env node

/**
 * Check if community genetics provenance data exists in Firestore
 */

const { admin, db } = require('./config-json');

const COLLECTIONS = {
  provenances: 'community_genetics_provenances',
  aliases: 'community_genetics_aliases',
};

async function getCollectionCount(collectionName) {
  try {
    const snapshot = await db.collection(collectionName).get();
    return snapshot.size;
  } catch (error) {
    return null;
  }
}

async function getSampleDocument(collectionName) {
  try {
    const snapshot = await db.collection(collectionName).limit(1).get();
    if (snapshot.empty) return null;
    return snapshot.docs[0].data();
  } catch (error) {
    return null;
  }
}

async function getSpeciesBreakdown() {
  try {
    const snapshot = await db.collection(COLLECTIONS.provenances).get();
    const speciesCounts = {};
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const species = data.speciesId || data.species || 'unknown';
      speciesCounts[species] = (speciesCounts[species] || 0) + 1;
    });
    return speciesCounts;
  } catch (error) {
    return null;
  }
}

async function main() {
  console.log('🔍 Checking for community genetics provenance data in Firestore...\n');

  // Check provenances collection
  console.log(`📊 Checking collection: ${COLLECTIONS.provenances}`);
  const provenanceCount = await getCollectionCount(COLLECTIONS.provenances);
  if (provenanceCount !== null) {
    if (provenanceCount > 0) {
      console.log(`  ✅ ${provenanceCount} provenance records`);
      
      // Get species breakdown
      const speciesBreakdown = await getSpeciesBreakdown();
      if (speciesBreakdown) {
        console.log(`\n  Species breakdown:`);
        Object.entries(speciesBreakdown)
          .sort((a, b) => b[1] - a[1])
          .forEach(([species, count]) => {
            console.log(`    - ${species}: ${count}`);
          });
      }
      
      // Get sample document
      const sample = await getSampleDocument(COLLECTIONS.provenances);
      if (sample) {
        console.log(`\n  Sample provenance record:`);
        console.log(`    - Provenance ID: ${sample.provenanceId || 'N/A'}`);
        console.log(`    - Species: ${sample.species || 'N/A'}`);
        console.log(`    - Species ID: ${sample.speciesId || 'N/A'}`);
        console.log(`    - Aliases: ${sample.aliases?.length || 0}`);
      }
    } else {
      console.log(`  ⚠️  Collection exists but is empty (0 documents)`);
    }
  } else {
    console.log(`  ❌ Collection does not exist or error accessing`);
  }

  // Check aliases collection
  console.log(`\n📊 Checking collection: ${COLLECTIONS.aliases}`);
  const aliasCount = await getCollectionCount(COLLECTIONS.aliases);
  if (aliasCount !== null) {
    if (aliasCount > 0) {
      console.log(`  ✅ ${aliasCount} alias records`);
    } else {
      console.log(`  ⚠️  Collection exists but is empty (0 documents)`);
    }
  } else {
    console.log(`  ❌ Collection does not exist or error accessing`);
  }

  console.log('\n✅ Check complete\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  });
