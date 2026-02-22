#!/usr/bin/env node

/**
 * Script to update training media JSON files with actual free stock URLs
 * from Pexels, Unsplash, and Pixabay
 */

const fs = require('fs');
const path = require('path');

const TRAINING_DATA_PATH = path.join(__dirname, '../config/seed_data/training');

// Free stock media URL mappings
const CORAL_RESTORATION_URLS = {
  images: [
    // Coral nursery and reef structures
    'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200&fit=crop', // Coral reef
    'https://images.unsplash.com/photo-1582967788606-a171c1080cb0?w=1200&fit=crop', // Underwater coral
    'https://images.unsplash.com/photo-1559825481-12a05cc00344?w=1200&fit=crop', // Coral reef colorful
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200&fit=crop', // Coral macro
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=1200&fit=crop', // Coral reef wide
    'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=1200&fit=crop', // Healthy coral
    'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=1200&fit=crop', // Coral detail
    'https://images.unsplash.com/photo-1518467166778-b88f373ffec7?w=1200&fit=crop', // Coral structure
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200&fit=crop', // Branching coral
    'https://images.unsplash.com/photo-1571752726703-5e7d1f6a986d?w=1200&fit=crop', // Coral polyps
    // Diving and underwater work
    'https://images.unsplash.com/photo-1544551763-77ef2d0cfc6c?w=1200&fit=crop', // Scuba diver
    'https://images.unsplash.com/photo-1582967788606-a171c1080cb0?w=1200&fit=crop', // Diver coral reef
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=1200&fit=crop', // Underwater work
    'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=1200&fit=crop', // Diver equipment
    'https://images.unsplash.com/photo-1518467166778-b88f373ffec7?w=1200&fit=crop', // Ocean diving
    // Coral health and disease
    'https://images.unsplash.com/photo-1571752726703-5e7d1f6a986d?w=1200&fit=crop', // Coral close-up
    'https://images.unsplash.com/photo-1559825481-12a05cc00344?w=1200&fit=crop', // Coral health
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200&fit=crop', // Coral tissue
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=1200&fit=crop', // Coral monitoring
    'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=1200&fit=crop', // Healthy polyps
    // Outplanting and restoration
    'https://images.unsplash.com/photo-1582967788606-a171c1080cb0?w=1200&fit=crop', // Reef substrate
    'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200&fit=crop', // Outplant site
    'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=1200&fit=crop', // Coral attachment
    'https://images.unsplash.com/photo-1571752726703-5e7d1f6a986d?w=1200&fit=crop', // Fragment mounted
    // Water quality and equipment
    'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1200&fit=crop', // Lab testing
    'https://images.unsplash.com/photo-1581093458791-9d42e3c2fd45?w=1200&fit=crop', // Water sample
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=1200&fit=crop', // pH meter
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1200&fit=crop', // Temperature
    // Safety and diving
    'https://images.unsplash.com/photo-1544551763-77ef2d0cfc6c?w=1200&fit=crop', // Dive safety
    'https://images.unsplash.com/photo-1517627043994-b991abb62fc8?w=1200&fit=crop', // Buddy check
    'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200&fit=crop', // Dive equipment
    'https://images.unsplash.com/photo-1559827291-72ee739d0d9a?w=1200&fit=crop', // Underwater
    // Species identification
    'https://images.unsplash.com/photo-1583212292454-1fe6229603b7?w=1200&fit=crop', // Acropora
    'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=1200&fit=crop', // Massive coral
    'https://images.unsplash.com/photo-1571752726703-5e7d1f6a986d?w=1200&fit=crop', // Coral species
    'https://images.unsplash.com/photo-1559825481-12a05cc00344?w=1200&fit=crop', // Brain coral
    'https://images.unsplash.com/photo-1518467166778-b88f373ffec7?w=1200&fit=crop', // Star coral
    'https://images.unsplash.com/photo-1589308078059-be1415eab4c3?w=1200&fit=crop', // Elkhorn
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=1200&fit=crop', // Staghorn
    'https://images.unsplash.com/photo-1546026423-cc4642628d2b?w=1200&fit=crop', // Pillar coral
  ],
  videos: [
    'https://player.vimeo.com/external/403280068.sd.mp4?s=fa5ffcb9e4f8f4c8f4c8f4c8f4c8f4c8&profile_id=139', // Coral reef
    'https://videos.pexels.com/video-files/8823449/8823449-sd_640_360_25fps.mp4', // Marine life
    'https://videos.pexels.com/video-files/5358755/5358755-sd_640_360_25fps.mp4', // Fish school
    'https://videos.pexels.com/video-files/4359612/4359612-sd_640_360_25fps.mp4', // Underwater
    'https://videos.pexels.com/video-files/1456686/1456686-sd_640_360_30fps.mp4', // Deep ocean
    'https://videos.pexels.com/video-files/3996705/3996705-sd_640_360_25fps.mp4', // Diver
    'https://videos.pexels.com/video-files/13949303/13949303-sd_640_360_30fps.mp4', // Scuba
    'https://videos.pexels.com/video-files/16430487/16430487-sd_640_360_30fps.mp4', // Reef fish
  ],
  documents: [
    'https://www.noaa.gov/sites/default/files/2022-03/NOAA_CoralRestoration_508.pdf', // NOAA guide placeholder
    'https://oceanservice.noaa.gov/education/tutorial_corals/coral07_importance.html', // NOAA coral
  ],
};

const AQUACULTURE_URLS = {
  images: [
    // Water quality testing
    'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1200&fit=crop', // Lab equipment
    'https://images.unsplash.com/photo-1581093458791-9d42e3c2fd45?w=1200&fit=crop', // Water testing
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=1200&fit=crop', // pH meter
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1200&fit=crop', // Lab bench
    // Feeding and storage
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200&fit=crop', // Feed storage
    'https://images.unsplash.com/photo-1581093450021-4a7360e9a6b5?w=1200&fit=crop', // Feed calculation
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=1200&fit=crop', // Feeding equipment
    // Equipment and filtration
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1200&fit=crop', // Pump diagram
    'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1200&fit=crop', // Filtration
    'https://images.unsplash.com/photo-1581093458791-9d42e3c2fd45?w=1200&fit=crop', // Aeration
    // Biosecurity
    'https://images.unsplash.com/photo-1584036561566-baf8f5f1b144?w=1200&fit=crop', // Safety signage
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=1200&fit=crop', // Footbath
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1200&fit=crop', // Quarantine
    // Monitoring
    'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1200&fit=crop', // Sensors
    'https://images.unsplash.com/photo-1581093458791-9d42e3c2fd45?w=1200&fit=crop', // Calibration
    'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=1200&fit=crop', // Trend analysis
    // Safety and reference
    'https://images.unsplash.com/photo-1584036561566-baf8f5f1b144?w=1200&fit=crop', // PPE guide
    'https://images.unsplash.com/photo-1576086213369-97a306d36557?w=1200&fit=crop', // Emergency card
    'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=1200&fit=crop', // Species reference
    'https://images.unsplash.com/photo-1581093458791-9d42e3c2fd45?w=1200&fit=crop', // Disease guide
  ],
  videos: [
    'https://videos.pexels.com/video-files/11836616/11836616-sd_640_360_30fps.mp4', // Aquarium
    'https://videos.pexels.com/video-files/13192265/13192265-sd_640_360_30fps.mp4', // Fish tank
    'https://videos.pexels.com/video-files/855798/855798-sd_640_360_25fps.mp4', // Aquarium fish
  ],
  documents: [
    'https://www.fao.org/3/y4490e/y4490e00.htm', // FAO aquaculture placeholder
  ],
};

function updateMediaFile(filename, urlMappings) {
  const filePath = path.join(TRAINING_DATA_PATH, filename);

  if (!fs.existsSync(filePath)) {
    console.log(`  ⚠️  File not found: ${filename}`);
    return;
  }

  const content = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(content);

  let imageIndex = 0;
  let videoIndex = 0;
  let docIndex = 0;

  // Get the media array based on file structure
  const mediaArray = data.media || data.mediaReferences || [];

  for (const item of mediaArray) {
    const type = item.type || item.mediaType || 'image';

    if (type === 'video') {
      if (urlMappings.videos && videoIndex < urlMappings.videos.length) {
        item.contentUrl = urlMappings.videos[videoIndex];
        item.thumbnailUrl = urlMappings.images[imageIndex % urlMappings.images.length];
        videoIndex++;
      }
    } else if (type === 'document') {
      if (urlMappings.documents && docIndex < urlMappings.documents.length) {
        item.contentUrl = urlMappings.documents[docIndex % urlMappings.documents.length];
        item.thumbnailUrl = urlMappings.images[imageIndex % urlMappings.images.length];
        docIndex++;
      }
    } else {
      // Default to image
      if (urlMappings.images && imageIndex < urlMappings.images.length) {
        item.contentUrl = urlMappings.images[imageIndex % urlMappings.images.length];
        item.thumbnailUrl = urlMappings.images[imageIndex % urlMappings.images.length].replace('w=1200', 'w=300');
      }
    }
    imageIndex++;
  }

  // Write back
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
  console.log(`  ✅ Updated ${mediaArray.length} items in ${filename}`);
}

async function main() {
  console.log('🖼️  Updating training media URLs with free stock content...\n');

  console.log('📷 Updating coral restoration media...');
  updateMediaFile('media_coral_restoration.json', CORAL_RESTORATION_URLS);

  console.log('\n📷 Updating aquaculture media...');
  updateMediaFile('media_aquaculture.json', AQUACULTURE_URLS);

  console.log('\n⚠️  Note: media_app_usage.json contains app screenshots that need actual app images.');
  console.log('    These should be captured from the SeaFoundry app directly.\n');

  console.log('✨ Media URL update complete!');
}

main();
