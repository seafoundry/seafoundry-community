#!/usr/bin/env node

/**
 * Species Image Verification Script
 *
 * Verifies that all species in the taxonomy have valid Wikipedia pages
 * and optionally checks if they have images/thumbnails configured.
 *
 * Usage:
 *   node scripts/verify-species-images.js
 *   node scripts/verify-species-images.js --verbose
 *   node scripts/verify-species-images.js --check-wikipedia
 *
 * Options:
 *   --verbose, -v          Show detailed output
 *   --check-wikipedia      Actually call Wikipedia API to verify pages exist
 *   --help, -h             Show this help message
 */

require('dotenv').config();
const { admin, db } = require('./config-json');
const https = require('https');

const args = process.argv.slice(2);
const options = {
  verbose: args.includes('--verbose') || args.includes('-v'),
  checkWikipedia: args.includes('--check-wikipedia'),
  help: args.includes('--help') || args.includes('-h'),
};

if (options.help) {
  console.log(`
🔍 Species Image Verification Script

Verifies species taxonomy data and Wikipedia page availability.

Usage: node scripts/verify-species-images.js [options]

Options:
  --verbose, -v          Show detailed output
  --check-wikipedia      Call Wikipedia API to verify pages exist
  --help, -h             Show this help message
`);
  process.exit(0);
}

/**
 * Format a species name for Wikipedia URL (proper binomial nomenclature)
 * - Genus: First letter uppercase, rest lowercase
 * - Species: All lowercase
 */
function formatWikipediaTitle(genus, species) {
  const formattedGenus = genus.trim().charAt(0).toUpperCase() +
    genus.trim().slice(1).toLowerCase();
  const formattedSpecies = species.trim().toLowerCase();
  return `${formattedGenus}_${formattedSpecies}`;
}

/**
 * Check if a Wikipedia page exists
 */
function checkWikipediaPage(title) {
  return new Promise((resolve) => {
    const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`;
    
    https.get(url, {
      headers: {
        'User-Agent': 'SeaFoundryApp/1.0 (verification script)',
        'Accept': 'application/json',
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({
            exists: res.statusCode === 200,
            status: res.statusCode,
            hasImage: !!(json.thumbnail?.source),
            thumbnailUrl: json.thumbnail?.source || null,
            title: json.title || title,
          });
        } catch (e) {
          resolve({ exists: false, status: res.statusCode, error: e.message });
        }
      });
    }).on('error', (e) => {
      resolve({ exists: false, error: e.message });
    });
  });
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║          Species Image Verification Script                     ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');

  try {
    // Load all species from taxonomy
    console.log('📊 Loading species from taxonomy_species collection...\n');
    const speciesSnap = await db.collection('taxonomy_species').get();

    if (speciesSnap.empty) {
      console.log('❌ No species found in taxonomy_species collection.');
      console.log('   Run: npm run seed:taxonomy');
      process.exit(1);
    }

    const species = speciesSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    console.log(`Found ${species.length} species in taxonomy.\n`);

    // Group by organism kind
    const byKind = {};
    species.forEach((sp) => {
      const kind = sp.organismKind || 'unknown';
      if (!byKind[kind]) byKind[kind] = [];
      byKind[kind].push(sp);
    });

    console.log('Species by organism kind:');
    for (const [kind, list] of Object.entries(byKind)) {
      console.log(`  ${kind}: ${list.length}`);
    }
    console.log('');

    // Check for missing image URLs
    const results = {
      total: species.length,
      withImageUrl: 0,
      withThumbnailUrl: 0,
      missingBoth: [],
      wikipediaChecks: [],
    };

    console.log('Checking species image configuration...\n');

    for (const sp of species) {
      const hasImage = sp.imageUrl && sp.imageUrl.trim().length > 0;
      const hasThumbnail = sp.thumbnailUrl && sp.thumbnailUrl.trim().length > 0;

      if (hasImage) results.withImageUrl++;
      if (hasThumbnail) results.withThumbnailUrl++;

      if (!hasImage && !hasThumbnail) {
        results.missingBoth.push({
          id: sp.id,
          code: sp.code,
          genus: sp.genus,
          species: sp.species,
          kind: sp.organismKind,
        });
      }

      if (options.verbose) {
        const imageStatus = hasImage ? '✅' : '❌';
        const thumbStatus = hasThumbnail ? '✅' : '❌';
        console.log(`  ${sp.code}: ${sp.genus} ${sp.species} - Image: ${imageStatus} Thumb: ${thumbStatus}`);
      }
    }

    console.log('\n📈 Image Configuration Summary:');
    console.log(`  Total species: ${results.total}`);
    console.log(`  With imageUrl: ${results.withImageUrl}`);
    console.log(`  With thumbnailUrl: ${results.withThumbnailUrl}`);
    console.log(`  Missing both: ${results.missingBoth.length}`);

    if (results.missingBoth.length > 0) {
      console.log('\n⚠️  Species missing image configuration:');
      results.missingBoth.forEach((sp) => {
        console.log(`    ${sp.code}: ${sp.genus} ${sp.species} (${sp.kind})`);
      });
    }

    // Check Wikipedia pages if requested
    if (options.checkWikipedia) {
      console.log('\n🌐 Checking Wikipedia page availability...\n');

      const coralSpecies = species.filter((sp) => sp.organismKind === 'coral');
      console.log(`Checking ${coralSpecies.length} coral species...\n`);

      const wikiResults = {
        found: [],
        notFound: [],
        errors: [],
      };

      for (const sp of coralSpecies) {
        const title = formatWikipediaTitle(sp.genus, sp.species);
        const result = await checkWikipediaPage(title);

        // Rate limiting - 100ms between requests
        await new Promise((resolve) => setTimeout(resolve, 100));

        if (result.exists) {
          wikiResults.found.push({
            code: sp.code,
            title: result.title,
            hasImage: result.hasImage,
            thumbnailUrl: result.thumbnailUrl,
          });
          if (options.verbose) {
            const imgStatus = result.hasImage ? '📷' : '  ';
            console.log(`  ✅ ${sp.code}: ${title} ${imgStatus}`);
          }
        } else if (result.error) {
          wikiResults.errors.push({ code: sp.code, title, error: result.error });
          console.log(`  ⚠️  ${sp.code}: ${title} - Error: ${result.error}`);
        } else {
          wikiResults.notFound.push({ code: sp.code, title, status: result.status });
          console.log(`  ❌ ${sp.code}: ${title} - Not found (${result.status})`);
        }
      }

      console.log('\n📊 Wikipedia Check Summary:');
      console.log(`  Pages found: ${wikiResults.found.length}`);
      console.log(`  Pages not found: ${wikiResults.notFound.length}`);
      console.log(`  Errors: ${wikiResults.errors.length}`);

      const withWikiImages = wikiResults.found.filter((r) => r.hasImage).length;
      console.log(`  With Wikipedia thumbnails: ${withWikiImages}`);

      if (wikiResults.notFound.length > 0) {
        console.log('\n❌ Species with missing Wikipedia pages:');
        wikiResults.notFound.forEach((r) => {
          console.log(`    ${r.code}: ${r.title}`);
        });
        console.log('\n💡 These species may need alternate Wikipedia page titles or manual image URLs.');
      }
    }

    console.log('\n✅ Verification complete!');

  } catch (error) {
    console.error('\n❌ Verification failed:', error.message);
    if (options.verbose) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();
