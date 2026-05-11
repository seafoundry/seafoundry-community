#!/usr/bin/env node

/**
 * Upload taxonomy images to shared Cloud Storage and update Firestore.
 *
 * Usage:
 *   # Upload single image for a species
 *   node scripts/upload-taxonomy-images.js --species=species_acropora_cervicornis --image=./images/acer.jpg
 *
 *   # Upload from a directory (expects files named by species ID or code)
 *   node scripts/upload-taxonomy-images.js --dir=./taxonomy-images
 *
 *   # Dry run (shows what would be uploaded)
 *   node scripts/upload-taxonomy-images.js --dir=./taxonomy-images --dry-run
 *
 *   # Generate thumbnails (requires sharp)
 *   node scripts/upload-taxonomy-images.js --dir=./taxonomy-images --generate-thumbs
 *
 * Expected file naming in directory mode:
 *   - species_acropora_cervicornis.jpg (by full ID)
 *   - ACER.jpg (by species code, case-insensitive)
 *   - acropora_cervicornis.jpg (by genus_species)
 */

const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const fs = require('node:fs');
const path = require('node:path');

const BUCKET_NAME = 'seafoundryapp.firebasestorage.app';
const STORAGE_PATH = 'shared/taxonomy';
const THUMB_PATH = 'shared/taxonomy/thumbs';
const THUMB_SIZE = 200;

const args = process.argv.slice(2);

function hasFlag(flag) {
  return args.some((arg) => arg === flag || arg.startsWith(`${flag}=`));
}

function getFlagValue(flag) {
  const arg = args.find((a) => a.startsWith(`${flag}=`));
  return arg ? arg.split('=')[1] : null;
}

const dryRun = hasFlag('--dry-run');
const generateThumbs = hasFlag('--generate-thumbs');
const speciesId = getFlagValue('--species');
const imagePath = getFlagValue('--image');
const imageDir = getFlagValue('--dir');

function initializeFirebase() {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (serviceAccountPath) {
    const absolute = path.resolve(serviceAccountPath);
    const credentials = JSON.parse(fs.readFileSync(absolute, 'utf8'));
    return initializeApp({ credential: cert(credentials), storageBucket: BUCKET_NAME });
  }
  return initializeApp({ credential: applicationDefault(), storageBucket: BUCKET_NAME });
}

async function loadSpeciesMap(db) {
  const snapshot = await db.collection('taxonomy_species').get();
  const byId = new Map();
  const byCode = new Map();
  const byGenusSpecies = new Map();

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const id = doc.id;
    byId.set(id, { id, ...data });
    if (data.code) {
      byCode.set(data.code.toLowerCase(), { id, ...data });
    }
    if (data.genus && data.species) {
      const key = `${data.genus.toLowerCase()}_${data.species.toLowerCase()}`;
      byGenusSpecies.set(key, { id, ...data });
    }
  });

  return { byId, byCode, byGenusSpecies };
}

function matchSpecies(filename, speciesMap) {
  const basename = path.basename(filename, path.extname(filename)).toLowerCase();

  // Try exact ID match
  if (speciesMap.byId.has(basename)) {
    return speciesMap.byId.get(basename);
  }

  // Try with species_ prefix
  const withPrefix = `species_${basename}`;
  if (speciesMap.byId.has(withPrefix)) {
    return speciesMap.byId.get(withPrefix);
  }

  // Try code match
  if (speciesMap.byCode.has(basename)) {
    return speciesMap.byCode.get(basename);
  }

  // Try genus_species match
  if (speciesMap.byGenusSpecies.has(basename)) {
    return speciesMap.byGenusSpecies.get(basename);
  }

  return null;
}

async function generateThumbnail(inputPath, outputPath) {
  try {
    const sharp = require('sharp');
    await sharp(inputPath)
      .resize(THUMB_SIZE, THUMB_SIZE, { fit: 'cover' })
      .jpeg({ quality: 80 })
      .toFile(outputPath);
    return true;
  } catch (error) {
    if (error.code === 'MODULE_NOT_FOUND') {
      console.warn('  ⚠️  sharp not installed. Run: npm install sharp');
      return false;
    }
    throw error;
  }
}

async function uploadFile(bucket, localPath, storagePath, contentType = 'image/jpeg') {
  const file = bucket.file(storagePath);
  await bucket.upload(localPath, {
    destination: storagePath,
    metadata: {
      contentType,
      cacheControl: 'public, max-age=31536000', // 1 year cache
    },
  });
  return `https://storage.googleapis.com/${BUCKET_NAME}/${storagePath}`;
}

async function updateSpeciesUrls(db, speciesId, imageUrl, thumbnailUrl) {
  const updateData = {};
  if (imageUrl) updateData.imageUrl = imageUrl;
  if (thumbnailUrl) updateData.thumbnailUrl = thumbnailUrl;

  await db.collection('taxonomy_species').doc(speciesId).update(updateData);
}

async function processImage(db, bucket, species, localImagePath, tempDir) {
  const ext = path.extname(localImagePath).toLowerCase();
  const storageName = `${species.id}${ext}`;
  const thumbName = `${species.id}_thumb.jpg`;

  console.log(`\n📸 Processing: ${species.id} (${species.code})`);
  console.log(`   Source: ${localImagePath}`);

  if (dryRun) {
    console.log(`   [DRY RUN] Would upload to: ${STORAGE_PATH}/${storageName}`);
    if (generateThumbs) {
      console.log(`   [DRY RUN] Would generate thumbnail: ${THUMB_PATH}/${thumbName}`);
    }
    return;
  }

  // Upload full-size image
  const imageUrl = await uploadFile(bucket, localImagePath, `${STORAGE_PATH}/${storageName}`);
  console.log(`   ✅ Uploaded: ${imageUrl}`);

  let thumbnailUrl = null;

  // Generate and upload thumbnail
  if (generateThumbs) {
    const thumbPath = path.join(tempDir, thumbName);
    const generated = await generateThumbnail(localImagePath, thumbPath);
    if (generated) {
      thumbnailUrl = await uploadFile(bucket, thumbPath, `${THUMB_PATH}/${thumbName}`);
      console.log(`   ✅ Thumbnail: ${thumbnailUrl}`);
      fs.unlinkSync(thumbPath); // Clean up temp file
    }
  }

  // Update Firestore
  await updateSpeciesUrls(db, species.id, imageUrl, thumbnailUrl);
  console.log(`   ✅ Firestore updated`);
}

async function processSingleImage(db, bucket, speciesMap, tempDir) {
  if (!speciesId || !imagePath) {
    console.error('❌ --species and --image are required for single image upload');
    process.exit(1);
  }

  const species = speciesMap.byId.get(speciesId);
  if (!species) {
    console.error(`❌ Species not found: ${speciesId}`);
    process.exit(1);
  }

  if (!fs.existsSync(imagePath)) {
    console.error(`❌ Image not found: ${imagePath}`);
    process.exit(1);
  }

  await processImage(db, bucket, species, imagePath, tempDir);
}

async function processDirectory(db, bucket, speciesMap, tempDir) {
  if (!imageDir) {
    console.error('❌ --dir is required for directory mode');
    process.exit(1);
  }

  if (!fs.existsSync(imageDir)) {
    console.error(`❌ Directory not found: ${imageDir}`);
    process.exit(1);
  }

  const files = fs.readdirSync(imageDir).filter((f) => {
    const ext = path.extname(f).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp'].includes(ext);
  });

  console.log(`\n📁 Found ${files.length} image files in ${imageDir}`);

  let matched = 0;
  let unmatched = 0;

  for (const file of files) {
    const species = matchSpecies(file, speciesMap);
    if (species) {
      await processImage(db, bucket, species, path.join(imageDir, file), tempDir);
      matched++;
    } else {
      console.log(`\n⚠️  No matching species for: ${file}`);
      unmatched++;
    }
  }

  console.log(`\n📊 Summary: ${matched} matched, ${unmatched} unmatched`);
}

async function main() {
  if (!speciesId && !imageDir) {
    console.log(`
Usage:
  # Single image
  node scripts/upload-taxonomy-images.js --species=species_acropora_cervicornis --image=./acer.jpg

  # Directory of images
  node scripts/upload-taxonomy-images.js --dir=./taxonomy-images

Options:
  --dry-run         Preview without uploading
  --generate-thumbs Generate ${THUMB_SIZE}px thumbnails (requires sharp)
`);
    process.exit(0);
  }

  console.log('🚀 Taxonomy Image Uploader');
  if (dryRun) console.log('⚠️  DRY RUN MODE - no changes will be made');

  const app = initializeFirebase();
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();

  console.log('\n📚 Loading species catalog...');
  const speciesMap = await loadSpeciesMap(db);
  console.log(`   Found ${speciesMap.byId.size} species`);

  // Create temp directory for thumbnails
  const tempDir = path.join(__dirname, '.temp-thumbs');
  if (generateThumbs && !dryRun) {
    fs.mkdirSync(tempDir, { recursive: true });
  }

  try {
    if (speciesId && imagePath) {
      await processSingleImage(db, bucket, speciesMap, tempDir);
    } else if (imageDir) {
      await processDirectory(db, bucket, speciesMap, tempDir);
    }
  } finally {
    // Clean up temp directory
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true });
    }
  }

  console.log('\n✅ Done!');
}

main().catch((error) => {
  console.error('❌ Error:', error.message);
  process.exit(1);
});
