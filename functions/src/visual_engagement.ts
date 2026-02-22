import * as admin from "firebase-admin";
import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onObjectFinalized} from "firebase-functions/v2/storage";
import {isFeatureEnabledForOrg} from "./feature_access";

const firebaseConfig = (() => {
  try {
    return process.env.FIREBASE_CONFIG ?
      JSON.parse(process.env.FIREBASE_CONFIG) :
      {};
  } catch (error) {
    console.warn("Unable to parse FIREBASE_CONFIG:", error);
    return {};
  }
})();

const DEFAULT_STORAGE_BUCKET =
  firebaseConfig.storageBucket ??
  process.env.DEFAULT_STORAGE_BUCKET ??
  `${process.env.GCLOUD_PROJECT ?? "demo-seafoundry"}.appspot.com`;

// Helper: sanitize public payloads (omit internal metadata)
function sanitize(
  data: FirebaseFirestore.DocumentData,
  fields: string[]
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const f of fields) {
    if (data[f] !== undefined) out[f] = data[f];
  }
  return out;
}

// Mirror: media_assets -> public_media when published == true
export const mirrorPublishedMedia = onDocumentWritten(
  "media_assets/{assetId}",
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    const before = beforeSnap?.data();
    const after = afterSnap?.data();
    const assetId = event.params.assetId as string;

    // Deleted
    if (!afterSnap?.exists && beforeSnap?.exists && before) {
      const orgId = before.organizationId as string;
      try {
        await admin
          .firestore()
          .collection(`public_orgs/${orgId}/media`)
          .doc(assetId)
          .delete();
      } catch (error) {
        console.error(
          "Failed to delete mirrored media",
          {orgId, assetId},
          error
        );
      }
      return;
    }
    if (!after) return;

    const isPublished = !!after.published;
    const orgId = after.organizationId as string;
    if (!isPublished) {
      await admin
        .firestore()
        .collection(`public_orgs/${orgId}/media`)
        .doc(assetId)
        .delete()
        .catch(() => undefined);
      return;
    }
    const publicFields = [
      "id",
      "url",
      "assetType",
      "width",
      "height",
      "durationSeconds",
      "altText",
      "attribution",
      "tags",
      "organizationId",
      "published",
      "publishedAt",
      "createdAt",
      "createdById",
      "updatedAt",
      "updatedById",
    ];
    const payload = sanitize(after, publicFields);
    await admin
      .firestore()
      .collection(`public_orgs/${orgId}/media`)
      .doc(assetId)
      .set(payload, {merge: false});
  }
);

// Mirror: brand_profiles -> public_brand_profiles when published == true
export const mirrorPublishedBrandProfiles = onDocumentWritten(
  "brand_profiles/{brandId}",
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    const before = beforeSnap?.data();
    const after = afterSnap?.data();
    const brandId = event.params.brandId as string;

    if (!afterSnap?.exists && beforeSnap?.exists && before) {
      const beforeOrg = before.organizationId as string;
      try {
        await admin
          .firestore()
          .collection(`public_orgs/${beforeOrg}/brand_profiles`)
          .doc(brandId)
          .delete();
      } catch (error) {
        console.error(
          "Failed to delete mirrored brand profile",
          {brandId, organizationId: beforeOrg},
          error
        );
      }
      return;
    }
    if (!after) return;
    const isPublished = !!after.published;
    const orgId = after.organizationId as string;
    if (!isPublished) {
      await admin
        .firestore()
        .collection(`public_orgs/${orgId}/brand_profiles`)
        .doc(brandId)
        .delete()
        .catch(() => undefined);
      return;
    }
    const publicFields = [
      "id",
      "brandName",
      "logoUrl",
      "heroImageUrl",
      "accentColor",
      "kioskEnabled",
      "organizationId",
      "published",
      "publishedAt",
      "createdAt",
      "createdById",
      "updatedAt",
      "updatedById",
    ];
    const payload = sanitize(after, publicFields);
    await admin
      .firestore()
      .collection(`public_orgs/${orgId}/brand_profiles`)
      .doc(brandId)
      .set(payload, {merge: false});
  }
);

// Build weekly digest per organization from published media (simple heuristic)
export const buildWeeklyOrgDigests = onSchedule("21 3 * * 1", async () => {
  const db = admin.firestore();

  // Determine last week range
  const now = new Date();
  const monday = new Date(now);
  const day = monday.getDay();
  const diff = (day + 6) % 7; // days since Monday
  monday.setDate(now.getDate() - diff - 7); // previous Monday
  monday.setHours(0, 0, 0, 0);
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);

  const mondayIso = monday.toISOString();
  const sundayIso = sunday.toISOString();

  // Gather organizations from media in window
  // Enumerate orgs by scanning top-level public_orgs to limit fan-out
  const orgsSnap = await db.collection("public_orgs").get();
  const byOrg = new Map<string, FirebaseFirestore.DocumentData[]>();
  for (const orgDoc of orgsSnap.docs) {
    const orgId = orgDoc.id;
    const mediaSnap = await db
      .collection(`public_orgs/${orgId}/media`)
      .where("publishedAt", ">=", mondayIso)
      .where("publishedAt", "<=", sundayIso)
      .get();
    if (mediaSnap.empty) continue;
    byOrg.set(orgId, mediaSnap.docs.map((d) => d.data()));
  }

  const batch = db.batch();
  for (const [orgId, items] of byOrg.entries()) {
    // Simple metrics: exposures == items count * 20 (placeholder), taps == items count * 5
    const exposures = items.length * 20;
    const taps = items.length * 5;
    const digestId = `${orgId}_${mondayIso.substring(0, 10)}`;
    const digestDoc = db.doc(`public_orgs/${orgId}/digests/${digestId}`);
    batch.set(digestDoc, {
      id: digestId,
      modelType: "publicDigest",
      organizationId: orgId,
      createdAt: new Date().toISOString(),
      createdById: "system",
      updatedAt: new Date().toISOString(),
      updatedById: "system",
      weekOf: mondayIso.substring(0, 10),
      highlightAssetIds: items.slice(0, 5).map((d) => d.id).filter(Boolean),
      metrics: {
        exposures,
        taps,
        shares: 0,
        followClicks: 0,
        qrScans: 0,
      },
      published: true,
      publishedAt: new Date().toISOString(),
    });
  }

  if (!byOrg.size) return;
  await batch.commit();
});

// Create a default playlist on first brand_profile publish
export const createDefaultPlaylist = onDocumentCreated(
  "public_orgs/{orgId}/brand_profiles/{brandId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const orgId = event.params.orgId as string;
    const playlistId = `${orgId}_default`;
    await admin
      .firestore()
      .doc(`public_orgs/${orgId}/playlists/${playlistId}`)
      .set(
        {
          id: playlistId,
          modelType: "publicPlaylist",
          organizationId: orgId,
          createdAt: new Date().toISOString(),
          createdById: "system",
          updatedAt: new Date().toISOString(),
          updatedById: "system",
          title: `${data.brandName} Highlights`,
          description: "Auto-generated highlights playlist",
          items: [],
          published: true,
          publishedAt: new Date().toISOString(),
        },
        {merge: true}
      );
  }
);

// Scheduled projection of holdings/outplant impact points for the public map
export const projectOrgImpactPoints = onSchedule("30 4 * * *", async () => {
  const db = admin.firestore();
  const orgs = await db.collection("organizations").get();
  for (const orgDoc of orgs.docs) {
    const orgId = orgDoc.id;
    const orgRef = orgDoc.ref;
    const sites = await _loadSiteMeta(orgRef);
    if (!sites.size) {
      continue;
    }

    const holdings = await _aggregateHoldings(orgRef);
    const outplants = await _aggregateOutplants(orgId);

    const impactCollection = db.collection(`public_orgs/${orgId}/impact_points`);
    const batch = db.batch();
    let writeCount = 0;
    const existing = await impactCollection.get();
    existing.forEach((doc) => {
      batch.delete(doc.ref);
      writeCount += 1;
    });

    for (const [siteId, siteData] of holdings.entries()) {
      if (siteData.magnitude <= 0) continue;
      const site = sites.get(siteId);
      if (!site) continue;
      batch.set(impactCollection.doc(`holding_${siteId}`), {
        id: `holding_${siteId}`,
        modelType: "publicImpactPoint",
        organizationId: orgId,
        siteId: siteId,
        latitude: site.latitude,
        longitude: site.longitude,
        label: site.name,
        pointType: "holding",
        magnitude: siteData.magnitude,
        // New: genet and provenance ID breakdowns for public map genetics display
        genetBreakdown: siteData.genetBreakdown,
        provenanceIdBreakdown: siteData.provenanceIdBreakdown,
        speciesBreakdown: siteData.speciesBreakdown,
        createdAt: new Date().toISOString(),
        createdById: "system",
        updatedAt: new Date().toISOString(),
        updatedById: "system",
      });
      writeCount += 1;
    }

    outplants.forEach((siteData, siteId) => {
      if (siteData.magnitude <= 0) return;
      const site = sites.get(siteId);
      if (!site) return;
      batch.set(impactCollection.doc(`outplant_${siteId}`), {
        id: `outplant_${siteId}`,
        modelType: "publicImpactPoint",
        organizationId: orgId,
        siteId: siteId,
        latitude: site.latitude,
        longitude: site.longitude,
        label: site.name,
        pointType: "outplant",
        magnitude: siteData.magnitude,
        genetBreakdown: siteData.genetBreakdown,
        provenanceIdBreakdown: siteData.provenanceIdBreakdown,
        speciesBreakdown: siteData.speciesBreakdown,
        createdAt: new Date().toISOString(),
        createdById: "system",
        updatedAt: new Date().toISOString(),
        updatedById: "system",
      });
      writeCount += 1;
    });

    if (writeCount > 0) {
      await batch.commit();
    }
  }
});

async function _loadSiteMeta(orgRef: FirebaseFirestore.DocumentReference) {
  const snapshot = await orgRef.collection("sites").select("latitude", "longitude", "name").get();
  const map = new Map<string, { latitude: number; longitude: number; name: string }>();
  snapshot.forEach((doc) => {
    const data = doc.data();
    const lat = typeof data.latitude === "number" ? data.latitude : null;
    const lng = typeof data.longitude === "number" ? data.longitude : null;
    if (lat == null || lng == null) {
      return;
    }
    map.set(doc.id, {
      latitude: lat,
      longitude: lng,
      name: typeof data.name === "string" && data.name.length > 0 ? data.name : doc.id,
    });
  });
  return map;
}

interface SiteHoldingData {
  magnitude: number;
  genetBreakdown: Record<string, number>;
  provenanceIdBreakdown: Record<string, number>;
  speciesBreakdown: Record<string, number>;
}

interface SiteOutplantData {
  magnitude: number;
  genetBreakdown: Record<string, number>;
  provenanceIdBreakdown: Record<string, number>;
  speciesBreakdown: Record<string, number>;
}

async function _aggregateHoldings(orgRef: FirebaseFirestore.DocumentReference) {
  const siteData = new Map<string, SiteHoldingData>();
  const genetIds = new Set<string>();

  const ensureSite = (siteId: string): SiteHoldingData => {
    let site = siteData.get(siteId);
    if (!site) {
      site = {
        magnitude: 0,
        genetBreakdown: {},
        provenanceIdBreakdown: {},
        speciesBreakdown: {},
      };
      siteData.set(siteId, site);
    }
    return site;
  };

  // 1) Coral holdings live in organismRecords (canonical for coral).
  const organismSnapshot = await orgRef
    .collection("organismRecords")
    .select("siteId", "measurement", "quantity", "genetId", "speciesId", "organismKind")
    .get();

  organismSnapshot.forEach((doc) => {
    const data = doc.data() ?? {};
    const siteId = data.siteId;
    if (typeof siteId !== "string" || siteId.length === 0) {
      return;
    }
    // Only coral uses organismRecords for holdings today (non-coral uses holdings collection).
    if (data.organismKind && data.organismKind !== "coral") {
      return;
    }

    const measurement = data.measurement;
    const measurementValue =
      measurement && typeof measurement.value === "number"
        ? measurement.value
        : _parseNumber(data.quantity);
    const qty = Math.max(0, measurementValue);

    const genetId = typeof data.genetId === "string" ? data.genetId : undefined;
    const speciesId =
      typeof data.speciesId === "string" ? data.speciesId : undefined;

    const site = ensureSite(siteId);
    site.magnitude += qty;

    if (genetId) {
      site.genetBreakdown[genetId] = (site.genetBreakdown[genetId] ?? 0) + qty;
      genetIds.add(genetId);
    }

    if (speciesId) {
      site.speciesBreakdown[speciesId] =
        (site.speciesBreakdown[speciesId] ?? 0) + qty;
    }
  });

  // 2) Non-coral holdings live in holdings collection.
  const holdingsSnapshot = await orgRef
    .collection("holdings")
    .select(
      "siteId",
      "measurement",
      "quantity",
      "provenanceId",
      "speciesId",
      "attributes",
      "organismRecord"
    )
    .get();

  holdingsSnapshot.forEach((doc) => {
    const data = doc.data() ?? {};
    const siteId = data.siteId;
    if (typeof siteId !== "string" || siteId.length === 0) {
      return;
    }

    const measurement = data.measurement;
    const measurementValue =
      measurement && typeof measurement.value === "number"
        ? measurement.value
        : _parseNumber(data.quantity);
    const qty = Math.max(0, measurementValue);

    const provenanceId =
      typeof data.provenanceId === "string" ? data.provenanceId : undefined;
    const speciesId = _extractSpeciesId(data);

    const site = ensureSite(siteId);
    site.magnitude += qty;

    if (provenanceId) {
      site.provenanceIdBreakdown[provenanceId] =
        (site.provenanceIdBreakdown[provenanceId] ?? 0) + qty;
    }

    if (speciesId) {
      site.speciesBreakdown[speciesId] =
        (site.speciesBreakdown[speciesId] ?? 0) + qty;
    }
  });

  // Map genet IDs to provenance IDs for coral holdings.
  if (genetIds.size > 0) {
    const provenanceByGenet = await _loadProvenanceIdByGenetId(
      orgRef.id,
      genetIds
    );
    siteData.forEach((site) => {
      Object.entries(site.genetBreakdown).forEach(([genetId, qty]) => {
        const provenanceId = provenanceByGenet.get(genetId);
        if (!provenanceId) return;
        site.provenanceIdBreakdown[provenanceId] =
          (site.provenanceIdBreakdown[provenanceId] ?? 0) + qty;
      });
    });
  }

  return siteData;
}

async function _aggregateOutplants(orgId: string) {
  const snapshot = await admin
    .firestore()
    .collection("events")
    .where("organizationId", "==", orgId)
    .where("eventTypeId", "==", "outplant_event")
    .select("siteId", "allocations", "quantity")
    .get();

  const siteData = new Map<string, SiteOutplantData>();
  const genetIds = new Set<string>();

  snapshot.forEach((doc) => {
    const siteId = doc.get("siteId");
    if (typeof siteId !== "string" || siteId.length === 0) {
      return;
    }

    let site = siteData.get(siteId);
    if (!site) {
      site = {
        magnitude: 0,
        genetBreakdown: {},
        provenanceIdBreakdown: {},
        speciesBreakdown: {},
      };
      siteData.set(siteId, site);
    }

    const allocations = doc.get("allocations");
    if (Array.isArray(allocations)) {
      for (const allocation of allocations) {
        if (!allocation) continue;
        const qty = Math.max(0, _parseNumber(allocation.quantity));
        site.magnitude += qty;

        const speciesId =
          typeof allocation.speciesId === "string"
            ? allocation.speciesId
            : (allocation.snapshot &&
                typeof allocation.snapshot.speciesId === "string"
                ? allocation.snapshot.speciesId
                : undefined);
        if (speciesId) {
          site.speciesBreakdown[speciesId] =
            (site.speciesBreakdown[speciesId] ?? 0) + qty;
        }

        const provenanceId =
          typeof allocation.provenanceId === "string"
            ? allocation.provenanceId
            : undefined;
        if (provenanceId) {
          site.provenanceIdBreakdown[provenanceId] =
            (site.provenanceIdBreakdown[provenanceId] ?? 0) + qty;
          continue;
        }

        const genetId =
          typeof allocation.genetId === "string" ? allocation.genetId : undefined;
        if (genetId) {
          if (_isProvenanceId(genetId)) {
            site.provenanceIdBreakdown[genetId] =
              (site.provenanceIdBreakdown[genetId] ?? 0) + qty;
          } else {
            site.genetBreakdown[genetId] =
              (site.genetBreakdown[genetId] ?? 0) + qty;
            genetIds.add(genetId);
          }
        }
      }
    } else {
      site.magnitude += Math.max(0, _parseNumber(doc.get("quantity")));
    }
  });

  if (genetIds.size > 0) {
    const provenanceByGenet = await _loadProvenanceIdByGenetId(orgId, genetIds);
    siteData.forEach((site) => {
      Object.entries(site.genetBreakdown).forEach(([genetId, qty]) => {
        const provenanceId = provenanceByGenet.get(genetId);
        if (!provenanceId) return;
        site.provenanceIdBreakdown[provenanceId] =
          (site.provenanceIdBreakdown[provenanceId] ?? 0) + qty;
      });
    });
  }

  return siteData;
}

async function _loadProvenanceIdByGenetId(
  orgId: string,
  genetIds: Set<string>
): Promise<Map<string, string>> {
  const ids = Array.from(genetIds);
  const map = new Map<string, string>();
  if (ids.length === 0) return map;

  for (let i = 0; i < ids.length; i += 10) {
    const chunk = ids.slice(i, i + 10);
    const snapshot = await admin
      .firestore()
      .collection(`organizations/${orgId}/genets`)
      .where(admin.firestore.FieldPath.documentId(), "in", chunk)
      .select("provenanceId")
      .get();
    snapshot.forEach((doc) => {
      const provenanceId = doc.get("provenanceId");
      if (typeof provenanceId === "string" && provenanceId.length > 0) {
        map.set(doc.id, provenanceId);
      }
    });
  }

  return map;
}

function _isProvenanceId(value: string): boolean {
  return value.startsWith("PID-") || value.startsWith("SF-");
}

function _extractSpeciesId(data: Record<string, unknown>): string | undefined {
  if (typeof data.speciesId === "string" && data.speciesId.length > 0) {
    return data.speciesId;
  }
  const attributes = data.attributes as Record<string, unknown> | undefined;
  if (
    attributes &&
    typeof attributes.speciesId === "string" &&
    attributes.speciesId.length > 0
  ) {
    return attributes.speciesId;
  }
  const organismRecord = data.organismRecord as Record<string, unknown> | undefined;
  if (
    organismRecord &&
    typeof organismRecord.speciesId === "string" &&
    organismRecord.speciesId.length > 0
  ) {
    return organismRecord.speciesId;
  }
  return undefined;
}

function _parseNumber(value: unknown): number {
  if (typeof value === "number" && !isNaN(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

// Storage trigger to generate 1080p thumbnails for uploaded media assets
// Expects uploads at paths like: organizations/{orgId}/images/{recordType}/{recordId}/{fileName}
// Writes a downscaled copy to: organizations/{orgId}/public/1080p/{recordType}/{recordId}/{fileName}
// Note: requires 'sharp' dependency and appropriate memory settings in firebase.json if large images
export const generateMediaThumbnails = onObjectFinalized({
  region: "us-east1", // Must match bucket region
  bucket: DEFAULT_STORAGE_BUCKET,
}, async (event) => {
  const fileBucket = event.data.bucket;
  const filePath = event.data.name as string | undefined;
  if (!filePath) return;
  // Skip non-image files
  if (!/\.(jpg|jpeg|png|tif|tiff)$/i.test(filePath)) return;
  // Skip already processed thumbnails
  if (filePath.includes("/public/1080p/")) return;

  const match = filePath.match(/^organizations\/(.+?)\/images\//);
  if (!match) return;
  const orgId = match[1];
  const pathParts = filePath.split("/");
  const recordType = pathParts.length > 3 ? pathParts[3] : "";
  const allowWithoutImagery =
    recordType === "users" || recordType === "brand";

  const imageryAccess = await isFeatureEnabledForOrg(
    orgId,
    "imagery_attachments"
  );
  if (!imageryAccess.enabled && !allowWithoutImagery) {
    console.warn(
      `Skipping thumbnail generation for ${filePath} (tier=${imageryAccess.tier})`
    );
    await admin
      .storage()
      .bucket(fileBucket)
      .file(filePath)
      .delete({ignoreNotFound: true})
      .catch((error: unknown) => {
        console.warn(
          `Failed to clean up blocked upload ${filePath}:`,
          error
        );
      });
    return;
  }

  if (!imageryAccess.enabled && allowWithoutImagery) {
    console.info(
      `Allowing image upload without imagery_attachments for ${filePath} (recordType=${recordType})`
    );
    return;
  }

  // Lazy-import sharp to avoid cold start costs when not needed
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const sharp = require("sharp");
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const {Storage} = require("@google-cloud/storage");
  const storage = new Storage();

  const bucket = storage.bucket(fileBucket);
  const tempFile = `/tmp/source_${Date.now()}`;
  const tempOut = `/tmp/out_${Date.now()}.jpg`;

  try {
    // Download, resize, and upload
    await bucket.file(filePath).download({destination: tempFile});
    await sharp(tempFile).rotate().resize({width: 1920, height: 1080, fit: "inside"}).jpeg({quality: 85}).toFile(tempOut);

    const outPath = filePath.replace(
      /organizations\/(.+?)\/images\//,
      `organizations/${orgId}/public/1080p/`
    );
    await bucket.upload(tempOut, {destination: outPath, contentType: "image/jpeg"});

    console.log(`Generated thumbnail for ${filePath} -> ${outPath}`);
  } catch (error) {
    console.error(`Error generating thumbnail for ${filePath}:`, error);
    throw error;
  } finally {
    // Clean up temp files
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const fs = require("fs");
    try {
      fs.rmSync(tempFile, {force: true});
      fs.rmSync(tempOut, {force: true});
    } catch (cleanupError) {
      console.warn("Error cleaning up temp files:", cleanupError);
    }
  }
});
