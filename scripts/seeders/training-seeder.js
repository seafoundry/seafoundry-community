const BaseSeeder = require('./base-seeder');
const fs = require('fs');
const path = require('path');

const TRAINING_DATA_PATH = path.join(__dirname, '../../config/seed_data/training');

class TrainingSeeder {
  constructor() {
    this.sopSeeder = new BaseSeeder('sops');
    this.mediaSeeder = new BaseSeeder('training_media');
    this.sopIds = [];
    this.mediaIds = [];
  }

  loadJsonFile(filename) {
    const filePath = path.join(TRAINING_DATA_PATH, filename);
    if (!fs.existsSync(filePath)) {
      console.log(`  ⚠️  File not found: ${filename}`);
      return null;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(content);
  }

  loadAllSops() {
    const sopFiles = fs.readdirSync(TRAINING_DATA_PATH)
      .filter(f => f.startsWith('sop_') && f.endsWith('.json'));

    const sops = [];
    for (const file of sopFiles) {
      const sop = this.loadJsonFile(file);
      if (sop && sop.id) {
        sops.push({
          ...sop,
          createdAt: sop.createdAt || new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });
        this.sopIds.push(sop.id);
      }
    }
    return sops;
  }

  loadAllMedia() {
    const mediaFiles = fs.readdirSync(TRAINING_DATA_PATH)
      .filter(f => f.startsWith('media_') && f.endsWith('.json'));

    const allMedia = [];
    for (const file of mediaFiles) {
      const mediaLibrary = this.loadJsonFile(file);
      if (!mediaLibrary) continue;

      // Handle different media file structures
      const mediaArrays = [
        mediaLibrary.media,
        mediaLibrary.mediaReferences,
        mediaLibrary.workflowDiagrams,
        mediaLibrary.exampleReports,
      ].filter(Boolean);

      for (const mediaArray of mediaArrays) {
        for (const item of mediaArray) {
          // Normalize type field (some files use 'mediaType' instead of 'type')
          // Also ensure isPublished is set for template content
          const normalizedItem = {
            ...item,
            type: item.type || item.mediaType || 'image',
            isPublished: item.isPublished !== false, // Default to true for template content
            createdAt: item.createdAt || new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          };
          allMedia.push(normalizedItem);
          this.mediaIds.push(item.id);
        }
      }
    }
    return allMedia;
  }

  async seed(options = {}) {
    console.log('\n📚 Seeding training content...');

    // Load and seed SOPs
    const sops = this.loadAllSops();
    if (sops.length > 0) {
      console.log(`\n📋 Found ${sops.length} SOPs to seed`);
      await this.sopSeeder.seed(sops, options);
    } else {
      console.log('  ⚠️  No SOPs found in training data');
    }

    // Load and seed media
    const media = this.loadAllMedia();
    if (media.length > 0) {
      console.log(`\n🎬 Found ${media.length} media items to seed`);
      await this.mediaSeeder.seed(media, options);
    } else {
      console.log('  ⚠️  No media found in training data');
    }

    console.log('\n✅ Training content seeding completed');
  }

  async clear(options = {}) {
    console.log('\n🗑️  Clearing training content...');

    // Reload IDs to ensure we have the full list
    this.loadAllSops();
    this.loadAllMedia();

    if (this.sopIds.length > 0) {
      await this.sopSeeder.deleteByIds(this.sopIds, options);
    }
    if (this.mediaIds.length > 0) {
      await this.mediaSeeder.deleteByIds(this.mediaIds, options);
    }

    console.log('✅ Training content cleared');
  }

  async count() {
    const sopCount = await this.sopSeeder.count();
    const mediaCount = await this.mediaSeeder.count();
    return { sops: sopCount, media: mediaCount };
  }
}

module.exports = TrainingSeeder;
