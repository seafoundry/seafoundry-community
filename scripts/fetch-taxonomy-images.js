#!/usr/bin/env node

/**
 * Fetch public domain taxonomy images from Wikimedia Commons API.
 * Downloads images to a local directory for review before uploading.
 *
 * Usage:
 *   node scripts/fetch-taxonomy-images.js
 *   node scripts/fetch-taxonomy-images.js --output=./taxonomy-images
 *   node scripts/fetch-taxonomy-images.js --dry-run
 */

const fs = require('node:fs');
const path = require('node:path');
const https = require('node:https');

const args = process.argv.slice(2);

function hasFlag(flag) {
  return args.some((arg) => arg === flag || arg.startsWith(`${flag}=`));
}

function getFlagValue(flag) {
  const arg = args.find((a) => a.startsWith(`${flag}=`));
  return arg ? arg.split('=')[1] : null;
}

const dryRun = hasFlag('--dry-run');
const outputDir = getFlagValue('--output') || './taxonomy-images';

// Species list with scientific names for Wikimedia search
const SPECIES_LIST = [
  { id: 'acer', scientificName: 'Acropora cervicornis', searchTerms: ['Staghorn coral', 'Acropora cervicornis'] },
  { id: 'apal', scientificName: 'Acropora palmata', searchTerms: ['Elkhorn coral', 'Acropora palmata'] },
  { id: 'apro', scientificName: 'Acropora prolifera', searchTerms: ['Fused staghorn coral', 'Acropora prolifera'] },
  { id: 'oann', scientificName: 'Orbicella annularis', searchTerms: ['Boulder star coral', 'Orbicella annularis'] },
  { id: 'ofav', scientificName: 'Orbicella faveolata', searchTerms: ['Mountainous star coral', 'Orbicella faveolata'] },
  { id: 'ofra', scientificName: 'Orbicella franksi', searchTerms: ['Orbicella franksi', 'boulder star coral'] },
  { id: 'dcyl', scientificName: 'Dendrogyra cylindrus', searchTerms: ['Pillar coral', 'Dendrogyra cylindrus'] },
  { id: 'dlab', scientificName: 'Diploria labyrinthiformis', searchTerms: ['Grooved brain coral', 'Diploria labyrinthiformis'] },
  { id: 'pcli', scientificName: 'Pseudodiploria clivosa', searchTerms: ['Knobby brain coral', 'Pseudodiploria clivosa'] },
  { id: 'pstr', scientificName: 'Pseudodiploria strigosa', searchTerms: ['Symmetrical brain coral', 'Pseudodiploria strigosa'] },
  { id: 'cnat', scientificName: 'Colpophyllia natans', searchTerms: ['Boulder brain coral', 'Colpophyllia natans'] },
  { id: 'mcav', scientificName: 'Montastraea cavernosa', searchTerms: ['Great star coral', 'Montastraea cavernosa'] },
  { id: 'ssid', scientificName: 'Siderastrea siderea', searchTerms: ['Massive starlet coral', 'Siderastrea siderea'] },
  { id: 'ppor', scientificName: 'Porites porites', searchTerms: ['Finger coral', 'Porites porites'] },
  { id: 'past', scientificName: 'Porites astreoides', searchTerms: ['Mustard hill coral', 'Porites astreoides'] },
  { id: 'pdiv', scientificName: 'Porites divaricata', searchTerms: ['Thin finger coral', 'Porites divaricata'] },
  { id: 'pfur', scientificName: 'Porites furcata', searchTerms: ['Branched finger coral', 'Porites furcata'] },
  { id: 'dsto', scientificName: 'Dichocoenia stokesii', searchTerms: ['Elliptical star coral', 'Dichocoenia stokesii'] },
  { id: 'mmea', scientificName: 'Meandrina meandrites', searchTerms: ['Maze coral', 'Meandrina meandrites'] },
  { id: 'aaga', scientificName: 'Agaricia agaricites', searchTerms: ['Lettuce coral', 'Agaricia agaricites'] },
  { id: 'alam', scientificName: 'Agaricia lamarcki', searchTerms: ['Lamarck sheet coral', 'Agaricia lamarcki'] },
  { id: 'aten', scientificName: 'Agaricia tenuifolia', searchTerms: ['Thin leaf lettuce coral', 'Agaricia tenuifolia'] },
  { id: 'efas', scientificName: 'Eusmilia fastigiata', searchTerms: ['Smooth flower coral', 'Eusmilia fastigiata'] },
  { id: 'myla', scientificName: 'Mycetophyllia lamarckiana', searchTerms: ['Ridged cactus coral', 'Mycetophyllia lamarckiana'] },
  { id: 'myfe', scientificName: 'Mycetophyllia ferox', searchTerms: ['Rough cactus coral', 'Mycetophyllia ferox'] },
  { id: 'maur', scientificName: 'Madracis auretenra', searchTerms: ['Yellow pencil coral', 'Madracis auretenra'] },
  { id: 'mdec', scientificName: 'Madracis decactis', searchTerms: ['Ten-ray star coral', 'Madracis decactis'] },
  { id: 'sbou', scientificName: 'Solenastrea bournoni', searchTerms: ['Smooth star coral', 'Solenastrea bournoni'] },
  { id: 'shy', scientificName: 'Solenastrea hyades', searchTerms: ['Knobby star coral', 'Solenastrea hyades'] },
  { id: 'ffra', scientificName: 'Favia fragum', searchTerms: ['Golfball coral', 'Favia fragum'] },
  { id: 'isin', scientificName: 'Isophyllia sinuosa', searchTerms: ['Sinuous cactus coral', 'Isophyllia sinuosa'] },
  { id: 'scub', scientificName: 'Scolymia cubensis', searchTerms: ['Artichoke coral', 'Scolymia cubensis'] },
  { id: 'sala', scientificName: 'Saccharina latissima', searchTerms: ['Sugar kelp', 'Saccharina latissima'] },
  { id: 'crvi', scientificName: 'Crassostrea virginica', searchTerms: ['Eastern oyster', 'Crassostrea virginica'] },
  { id: 'thte', scientificName: 'Thalassia testudinum', searchTerms: ['Turtle grass', 'Thalassia testudinum'] },
  { id: 'casa', scientificName: 'Callinectes sapidus', searchTerms: ['Blue crab', 'Callinectes sapidus'] },
  { id: 'onmy', scientificName: 'Oncorhynchus mykiss', searchTerms: ['Rainbow trout', 'Oncorhynchus mykiss'] },
  { id: 'mefr', scientificName: 'Mesocentrotus franciscanus', searchTerms: ['Red sea urchin', 'Mesocentrotus franciscanus'] },
  { id: 'rhma', scientificName: 'Rhizophora mangle', searchTerms: ['Red mangrove', 'Rhizophora mangle'] },
  { id: 'hosc', scientificName: 'Holothuria scabra', searchTerms: ['Sandfish', 'Holothuria scabra'] },
];

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: {
        'User-Agent': 'SeaFoundry-TaxonomyImageFetcher/1.0 (https://seafoundry.app; contact@seafoundry.app)'
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data, headers: res.headers }));
    }).on('error', reject);
  });
}

async function searchWikimediaCommons(searchTerm) {
  const encoded = encodeURIComponent(searchTerm);
  const url = `https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=${encoded}%20filetype:bitmap&srnamespace=6&srlimit=5&format=json`;

  try {
    const response = await httpsGet(url);
    const json = JSON.parse(response.data);
    if (json.query && json.query.search && json.query.search.length > 0) {
      return json.query.search.map(r => r.title);
    }
  } catch (e) {
    console.log(`   ⚠️  Search error: ${e.message}`);
  }
  return [];
}

async function getImageUrl(filename) {
  const encoded = encodeURIComponent(filename);
  const url = `https://commons.wikimedia.org/w/api.php?action=query&titles=${encoded}&prop=imageinfo&iiprop=url|size&iiurlwidth=1280&format=json`;

  try {
    const response = await httpsGet(url);
    const json = JSON.parse(response.data);
    const pages = json.query?.pages;
    if (pages) {
      const page = Object.values(pages)[0];
      if (page.imageinfo && page.imageinfo[0]) {
        const info = page.imageinfo[0];
        // Use thumburl for resized version, or url for original
        return {
          url: info.thumburl || info.url,
          originalUrl: info.url,
          width: info.thumbwidth || info.width,
          height: info.thumbheight || info.height,
        };
      }
    }
  } catch (e) {
    console.log(`   ⚠️  URL fetch error: ${e.message}`);
  }
  return null;
}

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, {
      headers: {
        'User-Agent': 'SeaFoundry-TaxonomyImageFetcher/1.0 (https://seafoundry.app; contact@seafoundry.app)'
      }
    }, (response) => {
      // Handle redirects
      if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
        downloadFile(response.headers.location, destPath).then(resolve).catch(reject);
        return;
      }

      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}`));
        return;
      }

      const file = fs.createWriteStream(destPath);
      response.pipe(file);

      file.on('finish', () => {
        file.close();
        resolve(destPath);
      });

      file.on('error', (err) => {
        fs.unlink(destPath, () => {});
        reject(err);
      });
    });

    request.on('error', reject);
    request.setTimeout(30000, () => {
      request.destroy();
      reject(new Error('Request timeout'));
    });
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function findImageForSpecies(species) {
  for (const term of species.searchTerms) {
    console.log(`   🔍 Searching: "${term}"`);
    const files = await searchWikimediaCommons(term);

    for (const filename of files) {
      const imageInfo = await getImageUrl(filename);
      if (imageInfo && imageInfo.url) {
        return {
          filename,
          ...imageInfo,
          searchTerm: term,
        };
      }
      await sleep(200); // Rate limit
    }
    await sleep(300); // Rate limit between searches
  }
  return null;
}

async function main() {
  console.log('🐠 SeaFoundry Taxonomy Image Fetcher (Wikimedia API)');
  console.log(`   Output directory: ${outputDir}`);
  console.log(`   Species to fetch: ${SPECIES_LIST.length}`);
  if (dryRun) {
    console.log('   ⚠️  DRY RUN - no files will be downloaded\n');
  } else {
    console.log('');
  }

  // Create output directory
  if (!dryRun) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const attributions = [];
  let success = 0;
  let failed = 0;

  for (const species of SPECIES_LIST) {
    console.log(`\n📸 ${species.scientificName} (${species.id})`);

    const imageInfo = await findImageForSpecies(species);

    if (!imageInfo) {
      console.log(`   ❌ No image found`);
      failed++;
      continue;
    }

    console.log(`   ✅ Found: ${imageInfo.filename}`);
    console.log(`   📐 Size: ${imageInfo.width}x${imageInfo.height}`);

    const ext = path.extname(imageInfo.url).split('?')[0] || '.jpg';
    const destPath = path.join(outputDir, `${species.id}${ext}`);

    if (dryRun) {
      console.log(`   [DRY RUN] Would download to: ${destPath}`);
    } else {
      try {
        await downloadFile(imageInfo.url, destPath);
        console.log(`   💾 Downloaded: ${destPath}`);
      } catch (e) {
        console.log(`   ❌ Download failed: ${e.message}`);
        failed++;
        continue;
      }
    }

    attributions.push({
      speciesId: species.id,
      scientificName: species.scientificName,
      source: 'Wikimedia Commons',
      filename: imageInfo.filename,
      originalUrl: imageInfo.originalUrl,
      searchTerm: imageInfo.searchTerm,
      localFile: `${species.id}${ext}`,
    });
    success++;

    await sleep(500); // Rate limit
  }

  // Write attribution file
  const attrPath = path.join(outputDir, 'ATTRIBUTIONS.json');
  if (!dryRun) {
    fs.writeFileSync(attrPath, JSON.stringify(attributions, null, 2));
  }
  console.log(`\n📝 Attributions: ${attrPath}`);

  console.log(`\n📊 Summary: ${success} succeeded, ${failed} failed`);

  if (success > 0 && !dryRun) {
    console.log(`\n✅ Next steps:`);
    console.log(`   1. Review downloaded images in ${outputDir}`);
    console.log(`   2. Upload with: npm run upload:taxonomy-images:thumbs -- --dir=${outputDir}`);
  }
}

main().catch((error) => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});
