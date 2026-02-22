#!/usr/bin/env node

/**
 * Backfill geometry payloads for legacy Site and OutplantEvent documents.
 *
 * The script performs the following steps:
 *  1. Loads Site records that are missing the `geometry` payload but still have
 *     legacy `latitude`/`longitude` values and creates a point geometry record.
 *  2. Loads OutplantEvent records (events collection) that are missing geometry
 *     and assigns a best-effort point geometry derived from explicit latitude/
 *     longitude values or, as a fallback, from the owning Site centroid.
 *
 * Geometry objects follow the same structure produced by the Flutter client:
 *  {
 *    type: 'point' | 'multipoint' | 'polygon' | 'bounding_box',
 *    coordinates: [{'lat': 0, 'lng': 0}, ...],
 *    centroid: {'lat': 0, 'lng': 0},
 *    centroidGeohash: 'abc1234',
 *    bounds: {
 *      southWest: {'lat': 0, 'lng': 0},
 *      northEast: {'lat': 0, 'lng': 0}
 *    },
 *    source: 'manual' | 'site_centroid',
 *    updatedAt: '2025-01-01T00:00:00.000Z'
 *  }
 *
 * Usage:
 *   npm run migrate:geometry -- [options]
 *
 * Options:
 *   --dry-run            Preview actions without writing to Firestore
 *   --limit <number>     Maximum number of outplant events to update
 *   --org <id>           Restrict to a single organizationId
 *   --site <id>          Restrict to a single siteId (implies organization scope)
 *   --batch-size <n>     Firestore batch size (default 400)
 *   --verbose            Print detailed progress information
 *   --help               Display usage information
 */

const path = require('path');
const fs = require('fs').promises;
const { db } = require('./config-json');

const args = process.argv.slice(2);
const options = {
  dryRun: false,
  limit: null,
  organizationId: null,
  siteId: null,
  batchSize: 400,
  verbose: false,
  help: false,
};

for (let idx = 0; idx < args.length; idx += 1) {
  const arg = args[idx];
  switch (arg) {
    case '--dry-run':
      options.dryRun = true;
      break;
    case '--limit':
      options.limit = parseInt(args[idx + 1], 10);
      idx += 1;
      break;
    case '--org':
      options.organizationId = args[idx + 1];
      idx += 1;
      break;
    case '--site':
      options.siteId = args[idx + 1];
      idx += 1;
      break;
    case '--batch-size':
      options.batchSize = parseInt(args[idx + 1], 10);
      idx += 1;
      break;
    case '--verbose':
      options.verbose = true;
      break;
    case '--help':
    case '-h':
      options.help = true;
      break;
    default:
      // ignore unknown flags to keep compatibility with npm scripts
      break;
  }
}

if (options.help) {
  console.log(`
🌊 SeaFoundry Geometry Backfill

Backfill legacy Site + OutplantEvent records with the new GeoJSON-style geometry payloads.

Usage:
  node ${path.basename(__filename)} [options]

Options:
  --dry-run            Preview without writing to Firestore
  --limit <number>     Limit number of outplant events processed
  --org <id>           Restrict to a single organizationId
  --site <id>          Restrict to a single siteId (requires --org)
  --batch-size <n>     Firestore batch size (default 400)
  --verbose            Show per-record output
  --help               Show this message
`);
  process.exit(0);
}

const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function encodeGeohash(lat, lng, precision = 7) {
  let geohash = '';
  let minLat = -90;
  let maxLat = 90;
  let minLng = -180;
  let maxLng = 180;
  let idx = 0;
  let bit = 0;
  let evenBit = true;

  while (geohash.length < precision) {
    if (evenBit) {
      const mid = (minLng + maxLng) / 2;
      if (lng >= mid) {
        idx |= 1 << (4 - bit);
        minLng = mid;
      } else {
        maxLng = mid;
      }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (lat >= mid) {
        idx |= 1 << (4 - bit);
        minLat = mid;
      } else {
        maxLat = mid;
      }
    }

    evenBit = !evenBit;

    if (bit < 4) {
      bit += 1;
    } else {
      geohash += BASE32[idx];
      bit = 0;
      idx = 0;
    }
  }

  return geohash;
}

function computeBounds(coordinates) {
  if (!coordinates.length) {
    return null;
  }
  let minLat = 90;
  let maxLat = -90;
  let minLng = 180;
  let maxLng = -180;

  coordinates.forEach(({ lat, lng }) => {
    minLat = Math.min(minLat, lat);
    maxLat = Math.max(maxLat, lat);
    minLng = Math.min(minLng, lng);
    maxLng = Math.max(maxLng, lng);
  });

  return {
    southWest: { lat: minLat, lng: minLng },
    northEast: { lat: maxLat, lng: maxLng },
  };
}

function computeCentroid(coordinates) {
  if (!coordinates.length) {
    return null;
  }
  const totals = coordinates.reduce(
    (acc, coord) => ({
      lat: acc.lat + coord.lat,
      lng: acc.lng + coord.lng,
    }),
    { lat: 0, lng: 0 },
  );
  return {
    lat: totals.lat / coordinates.length,
    lng: totals.lng / coordinates.length,
  };
}

function buildGeometry({
  coordinates,
  source,
  updatedAtIso,
}) {
  if (!coordinates.length) {
    return null;
  }

  let type = 'point';
  if (coordinates.length === 1) {
    type = 'point';
  } else if (coordinates.length === 2) {
    type = 'multipoint';
  } else {
    type = 'multipoint';
  }

  const centroid = computeCentroid(coordinates);
  const bounds = computeBounds(coordinates);
  const geohash = centroid ? encodeGeohash(centroid.lat, centroid.lng) : null;

  const geometry = {
    type,
    coordinates: coordinates.map(({ lat, lng }) => ({
      lat: Number(lat.toFixed(6)),
      lng: Number(lng.toFixed(6)),
    })),
    source,
    updatedAt: updatedAtIso,
  };

  if (centroid) {
    geometry.centroid = {
      lat: Number(centroid.lat.toFixed(6)),
      lng: Number(centroid.lng.toFixed(6)),
    };
  }

  if (bounds) {
    geometry.bounds = {
      southWest: {
        lat: Number(bounds.southWest.lat.toFixed(6)),
        lng: Number(bounds.southWest.lng.toFixed(6)),
      },
      northEast: {
        lat: Number(bounds.northEast.lat.toFixed(6)),
        lng: Number(bounds.northEast.lng.toFixed(6)),
      },
    };
  }

  if (geohash) {
    geometry.centroidGeohash = geohash;
  }

  return geometry;
}

function resolveSiteCoordinate(site) {
  if (!site) {
    return null;
  }
  const geometry = site.geometry || {};
  if (
    geometry.centroid &&
    typeof geometry.centroid.lat === 'number' &&
    typeof geometry.centroid.lng === 'number'
  ) {
    return geometry.centroid;
  }
  if (Array.isArray(geometry.coordinates) && geometry.coordinates.length) {
    const coord = geometry.coordinates[0];
    if (coord && typeof coord.lat === 'number' && typeof coord.lng === 'number') {
      return coord;
    }
  }
  if (
    geometry.bounds &&
    geometry.bounds.southWest &&
    geometry.bounds.northEast &&
    typeof geometry.bounds.southWest.lat === 'number' &&
    typeof geometry.bounds.southWest.lng === 'number' &&
    typeof geometry.bounds.northEast.lat === 'number' &&
    typeof geometry.bounds.northEast.lng === 'number'
  ) {
    const { southWest, northEast } = geometry.bounds;
    return {
      lat: (southWest.lat + northEast.lat) / 2,
      lng: (southWest.lng + northEast.lng) / 2,
    };
  }
  if (
    site.data &&
    typeof site.data.latitude === 'number' &&
    typeof site.data.longitude === 'number'
  ) {
    return {
      lat: site.data.latitude,
      lng: site.data.longitude,
    };
  }
  return null;
}

async function commitBatch(batch, stats) {
  if (!batch || !batch.ops) {
    return;
  }
  await batch.commit();
  stats.batchesCommitted += 1;
  batch.ops = 0;
}

async function processSiteGeometry(options) {
  let query = db.collection('sites');
  if (options.organizationId) {
    query = query.where('organizationId', '==', options.organizationId);
  }
  if (options.siteId) {
    query = query.where('id', '==', options.siteId);
  }

  const snapshot = await query.get();
  const stats = {
    scanned: snapshot.size,
    updated: 0,
    skipped: 0,
    missingCoordinates: 0,
    batchesCommitted: 0,
    entries: [],
  };

  let batch = db.batch();
  batch.ops = 0;

  const isoNow = new Date().toISOString();
  const siteCache = {};

  const docs = snapshot.docs;
  for (const doc of docs) {
    const data = doc.data() || {};
    const siteId = data.id || doc.id;
    const existingGeometry = data.geometry || null;

    siteCache[siteId] = {
      ref: doc.ref,
      data,
      geometry: existingGeometry,
    };

    if (existingGeometry) {
      stats.skipped += 1;
      return;
    }

    const lat = typeof data.latitude === 'number'
      ? data.latitude
      : typeof data.createdEvent?.latitude === 'number'
        ? data.createdEvent.latitude
        : null;
    const lng = typeof data.longitude === 'number'
      ? data.longitude
      : typeof data.createdEvent?.longitude === 'number'
        ? data.createdEvent.longitude
        : null;

    if (lat == null || lng == null) {
      stats.missingCoordinates += 1;
      if (options.verbose) {
        console.log(`⚠️  Site ${siteId} missing lat/lng; skipping geometry backfill.`);
      }
      return;
    }

    const geometry = buildGeometry({
      coordinates: [{ lat, lng }],
      source: 'manual',
      updatedAtIso: isoNow,
    });

    siteCache[siteId].geometry = geometry;

    stats.updated += 1;
    stats.entries.push({
      siteId,
      organizationId: data.organizationId,
      latitude: lat,
      longitude: lng,
    });

    if (!options.dryRun) {
      batch.update(doc.ref, { geometry });
      batch.ops += 1;
      if (batch.ops >= options.batchSize) {
        await commitBatch(batch, stats);
        batch = db.batch();
        batch.ops = 0;
      }
    } else if (options.verbose) {
      console.log(`📝 [dry-run] Would backfill geometry for site ${siteId}`);
    }
  }

  if (!options.dryRun && batch.ops > 0) {
    await commitBatch(batch, stats);
  }

  return { stats, siteCache };
}

function deriveEventCoordinates(eventData) {
  const coords = [];
  if (typeof eventData.latitude === 'number' && typeof eventData.longitude === 'number') {
    coords.push({ lat: eventData.latitude, lng: eventData.longitude });
  }

  if (coords.length === 0 && eventData.snapshotData) {
    const snapshot = eventData.snapshotData;
    if (typeof snapshot.latitude === 'number' && typeof snapshot.longitude === 'number') {
      coords.push({ lat: snapshot.latitude, lng: snapshot.longitude });
    } else if (Array.isArray(snapshot.coordinates)) {
      snapshot.coordinates
        .filter((value) => value && typeof value.lat === 'number' && typeof value.lng === 'number')
        .forEach((value) => coords.push({ lat: value.lat, lng: value.lng }));
    }
  }

  return coords;
}

async function processOutplantGeometry(options, siteCache) {
  if (options.limit !== null && options.limit <= 0) {
    return {
      stats: {
        scanned: 0,
        updated: 0,
        skipped: 0,
        withoutSite: 0,
        batchesCommitted: 0,
        entries: [],
      },
    };
  }

  let query = db.collection('events')
    .where('eventTypeId', '==', 'outplant_event');

  if (options.organizationId) {
    query = query.where('organizationId', '==', options.organizationId);
  }
  if (options.siteId) {
    query = query.where('siteId', '==', options.siteId);
  }

  const stats = {
    scanned: 0,
    updated: 0,
    skipped: 0,
    withoutSite: 0,
    missingCoordinates: 0,
    batchesCommitted: 0,
    entries: [],
  };

  let batch = db.batch();
  batch.ops = 0;

  const isoNow = new Date().toISOString();
  let processed = 0;
  let lastSnapshot = null;

  do {
    let pagedQuery = query.orderBy('createdAt', 'desc').limit(500);
    if (lastSnapshot) {
      pagedQuery = pagedQuery.startAfter(lastSnapshot);
    }

    const snapshot = await pagedQuery.get();
    if (snapshot.empty) {
      break;
    }

    for (const doc of snapshot.docs) {
      if (options.limit !== null && processed >= options.limit) {
        break;
      }

      processed += 1;
      stats.scanned += 1;
      const data = doc.data() || {};

      if (data.geometry) {
        stats.skipped += 1;
        continue;
      }

      const siteId = data.siteId || data.recordId;
      if (!siteId) {
        stats.withoutSite += 1;
        if (options.verbose) {
          console.log(`⚠️  Outplant event ${doc.id} missing siteId; skipping.`);
        }
        continue;
      }

      const site = siteCache[siteId];
      const coordinates = deriveEventCoordinates(data);
      let geometry = null;

      if (coordinates.length) {
        geometry = buildGeometry({
          coordinates,
          source: 'manual',
          updatedAtIso: isoNow,
        });
      } else {
        const fallbackCoordinate = resolveSiteCoordinate(site);
        if (fallbackCoordinate) {
          geometry = buildGeometry({
            coordinates: [fallbackCoordinate],
            source: 'site_centroid',
            updatedAtIso: isoNow,
          });
        }
      }

      if (!geometry) {
        stats.missingCoordinates += 1;
        if (options.verbose) {
          console.log(`⚠️  Outplant event ${doc.id} has no coordinate information; skipping.`);
        }
        continue;
      }

      stats.updated += 1;
      stats.entries.push({
        eventId: doc.id,
        siteId,
        organizationId: data.organizationId,
        coordinateCount: geometry.coordinates.length,
        source: geometry.source,
      });

      if (options.dryRun) {
        if (options.verbose) {
          console.log(`📝 [dry-run] Would assign geometry to outplant ${doc.id} (site ${siteId}).`);
        }
      } else {
        batch.update(doc.ref, { geometry });
        batch.ops += 1;
        if (batch.ops >= options.batchSize) {
          await commitBatch(batch, stats);
          batch = db.batch();
          batch.ops = 0;
        }
      }
    }

    lastSnapshot = snapshot.docs[snapshot.docs.length - 1];

    if (options.limit !== null && processed >= options.limit) {
      break;
    }
  } while (true);

  if (!options.dryRun && batch.ops > 0) {
    await commitBatch(batch, stats);
  }

  return { stats };
}

async function writeReport(name, payload) {
  const dir = path.join(process.cwd(), 'migration-reports');
  await fs.mkdir(dir, { recursive: true });
  const filePath = path.join(
    dir,
    `${name}_${new Date().toISOString().replace(/[:.]/g, '-')}.json`,
  );
  await fs.writeFile(filePath, JSON.stringify(payload, null, 2));
  console.log(`📝 Report saved to ${filePath}`);
}

async function main() {
  console.log('🚀 Geometry backfill starting...');
  if (options.dryRun) {
    console.log('🔍 Running in dry-run mode (no writes will be performed).');
  }

  const siteResult = await processSiteGeometry(options);
  const siteCache = siteResult?.siteCache ?? {};
  const eventResult = await processOutplantGeometry(options, siteCache);

  console.log('\n=== Geometry Backfill Summary ===');
  console.log(`Sites scanned: ${siteResult.stats.scanned}`);
  console.log(`Sites updated: ${siteResult.stats.updated}`);
  if (siteResult.stats.missingCoordinates) {
    console.log(`Sites missing coordinates: ${siteResult.stats.missingCoordinates}`);
  }
  console.log(`Outplant events scanned: ${eventResult.stats.scanned}`);
  console.log(`Outplant events updated: ${eventResult.stats.updated}`);
  if (eventResult.stats.withoutSite) {
    console.log(`Outplant events missing siteId: ${eventResult.stats.withoutSite}`);
  }
  if (eventResult.stats.missingCoordinates) {
    console.log(`Outplant events without any coordinate source: ${eventResult.stats.missingCoordinates}`);
  }

  if (!options.dryRun) {
    console.log(`Firestore batches committed: ${
      siteResult.stats.batchesCommitted + eventResult.stats.batchesCommitted
    }`);
  }

  await writeReport('geometry_backfill', {
    generatedAt: new Date().toISOString(),
    options,
    sites: siteResult.stats,
    outplantEvents: eventResult.stats,
  });

  console.log('\n✅ Geometry backfill complete.');
}

main().catch((error) => {
  console.error('❌ Geometry backfill failed:', error);
  process.exit(1);
});
