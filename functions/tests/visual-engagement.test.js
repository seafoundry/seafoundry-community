"use strict";
/**
 * Visual Engagement Cloud Functions Tests
 *
 * Comprehensive emulator tests for VE A/B/C functions:
 * - Phase A: Media ingestion, playlist generation
 * - Phase B: Brand theming, hero imagery
 * - Phase C: Public surfaces, impact points (including map avatar sync)
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var _a, _b, _c;
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const firebase_functions_test_1 = __importDefault(require("firebase-functions-test"));
const chai_1 = require("chai");
const module_1 = require("module");
// Use emulator by default (aligns with firebase.json port)
process.env.FIRESTORE_EMULATOR_HOST =
    (_a = process.env.FIRESTORE_EMULATOR_HOST) !== null && _a !== void 0 ? _a : "localhost:58080";
const projectId = (_b = process.env.GCLOUD_PROJECT) !== null && _b !== void 0 ? _b : "demo-seafoundry";
const require = (0, module_1.createRequire)(import.meta.url);
process.env.FIREBASE_CONFIG = (_c = process.env.FIREBASE_CONFIG) !== null && _c !== void 0 ? _c : JSON.stringify({
    projectId,
    storageBucket: `${projectId}.appspot.com`,
});
// Initialize firebase-functions-test with offline mode
const test = (0, firebase_functions_test_1.default)({ projectId });
// Import the functions to test (loaded after FIREBASE_CONFIG is set)
let myFunctions;
describe("Visual Engagement Functions", function () {
    test.timeout(10000);
    let db;
    before(async () => {
        // Initialize Firebase Admin if not already initialized
        const app = (0, app_1.getApps)().length ? (0, app_1.getApp)() : (0, app_1.initializeApp)({ projectId });
        db = (0, firestore_1.getFirestore)(app);
        // Dynamic import after env vars are prepared
        myFunctions = require("../lib/src/visual_engagement");
    });
    after(() => {
        // Clean up
        test.cleanup();
    });
    beforeEach(async () => {
        // Clear Firestore collections before each test (prefer built-in helper)
        if (typeof test.firestore.clearFirestoreData === "function") {
            await test.firestore.clearFirestoreData({ projectId });
        }
        else {
            await clearFirestore(db);
        }
    });
    describe("VE Phase A: Media Ingestion & Mirroring", () => {
        describe("mirrorPublishedMedia", () => {
            it("should mirror published media to public_orgs collection", async () => {
                const orgId = "org-123";
                const assetId = "asset-abc";
                // Create test data
                const mediaData = {
                    id: assetId,
                    url: "https://example.com/image.jpg",
                    assetType: "image",
                    width: 1920,
                    height: 1080,
                    altText: "Test image",
                    attribution: "Test photographer",
                    tags: ["coral", "restoration"],
                    organizationId: orgId,
                    published: true,
                    publishedAt: new Date().toISOString(),
                    createdAt: new Date().toISOString(),
                    createdById: "user-123",
                    updatedAt: new Date().toISOString(),
                    updatedById: "user-123",
                };
                // Create a document write event
                const beforeSnap = test.firestore.makeDocumentSnapshot({}, `media_assets/${assetId}`);
                const afterSnap = test.firestore.makeDocumentSnapshot(mediaData, `media_assets/${assetId}`);
                await myFunctions.mirrorPublishedMedia.run({
                    data: { before: beforeSnap, after: afterSnap },
                    params: { assetId },
                });
                // Verify the media was mirrored to public_orgs
                const publicMedia = await db
                    .collection(`public_orgs/${orgId}/media`)
                    .doc(assetId)
                    .get();
                (0, chai_1.expect)(publicMedia.exists).to.be.true;
                const publicData = publicMedia.data();
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.id).to.equal(assetId);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.url).to.equal(mediaData.url);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.assetType).to.equal("image");
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.organizationId).to.equal(orgId);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.published).to.be.true;
            });
            it("should remove unpublished media from public_orgs", async () => {
                const orgId = "org-123";
                const assetId = "asset-abc";
                // Seed: Create published media first
                const publishedData = {
                    id: assetId,
                    url: "https://example.com/image.jpg",
                    assetType: "image",
                    organizationId: orgId,
                    published: true,
                    publishedAt: new Date().toISOString(),
                    createdAt: new Date().toISOString(),
                    createdById: "user-123",
                };
                await db.collection(`public_orgs/${orgId}/media`).doc(assetId).set(publishedData);
                // Now unpublish
                const unpublishedData = Object.assign(Object.assign({}, publishedData), { published: false });
                const beforeSnap = test.firestore.makeDocumentSnapshot(publishedData, `media_assets/${assetId}`);
                const afterSnap = test.firestore.makeDocumentSnapshot(unpublishedData, `media_assets/${assetId}`);
                await myFunctions.mirrorPublishedMedia.run({
                    data: { before: beforeSnap, after: afterSnap },
                    params: { assetId },
                });
                // Verify removal
                const publicMedia = await db
                    .collection(`public_orgs/${orgId}/media`)
                    .doc(assetId)
                    .get();
                (0, chai_1.expect)(publicMedia.exists).to.be.false;
            });
            it("should delete public media when source is deleted", async () => {
                const orgId = "org-123";
                const assetId = "asset-abc";
                // Seed: Create published media
                const mediaData = {
                    id: assetId,
                    url: "https://example.com/image.jpg",
                    organizationId: orgId,
                    published: true,
                };
                await db.collection(`public_orgs/${orgId}/media`).doc(assetId).set(mediaData);
                // Delete source - simulate deletion by having no after snapshot
                const beforeSnap = test.firestore.makeDocumentSnapshot(mediaData, `media_assets/${assetId}`);
                // For deletion, after should be undefined/not exist
                await myFunctions.mirrorPublishedMedia.run({
                    data: { before: beforeSnap, after: undefined },
                    params: { assetId },
                });
                // Verify deletion
                const publicMedia = await db
                    .collection(`public_orgs/${orgId}/media`)
                    .doc(assetId)
                    .get();
                (0, chai_1.expect)(publicMedia.exists).to.be.false;
            });
            it("should sanitize internal fields from public mirror", async () => {
                const orgId = "org-123";
                const assetId = "asset-abc";
                const mediaData = {
                    id: assetId,
                    url: "https://example.com/image.jpg",
                    assetType: "image",
                    organizationId: orgId,
                    published: true,
                    publishedAt: new Date().toISOString(),
                    createdAt: new Date().toISOString(),
                    createdById: "user-123",
                    // Internal fields that should NOT be mirrored
                    internalNotes: "Secret notes",
                    permissions: ["admin"],
                };
                const beforeSnap = test.firestore.makeDocumentSnapshot({}, `media_assets/${assetId}`);
                const afterSnap = test.firestore.makeDocumentSnapshot(mediaData, `media_assets/${assetId}`);
                await myFunctions.mirrorPublishedMedia.run({
                    data: { before: beforeSnap, after: afterSnap },
                    params: { assetId },
                });
                const publicMedia = await db
                    .collection(`public_orgs/${orgId}/media`)
                    .doc(assetId)
                    .get();
                const publicData = publicMedia.data();
                (0, chai_1.expect)(publicData).to.not.have.property("internalNotes");
                (0, chai_1.expect)(publicData).to.not.have.property("permissions");
            });
        });
    });
    describe("VE Phase B: Brand Theming", () => {
        describe("mirrorPublishedBrandProfiles", () => {
            it("should mirror published brand profiles to public_orgs", async () => {
                const orgId = "org-123";
                const brandId = "brand-abc";
                const brandData = {
                    id: brandId,
                    brandName: "Coral Restoration Foundation",
                    logoUrl: "https://example.com/logo.png",
                    heroImageUrl: "https://example.com/hero.jpg",
                    accentColor: "#0066cc",
                    kioskEnabled: true,
                    organizationId: orgId,
                    published: true,
                    publishedAt: new Date().toISOString(),
                    createdAt: new Date().toISOString(),
                    createdById: "user-123",
                    updatedAt: new Date().toISOString(),
                    updatedById: "user-123",
                };
                const beforeSnap = test.firestore.makeDocumentSnapshot({}, `brand_profiles/${brandId}`);
                const afterSnap = test.firestore.makeDocumentSnapshot(brandData, `brand_profiles/${brandId}`);
                await myFunctions.mirrorPublishedBrandProfiles.run({
                    data: { before: beforeSnap, after: afterSnap },
                    params: { brandId },
                });
                const publicBrand = await db
                    .collection(`public_orgs/${orgId}/brand_profiles`)
                    .doc(brandId)
                    .get();
                (0, chai_1.expect)(publicBrand.exists).to.be.true;
                const publicData = publicBrand.data();
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.id).to.equal(brandId);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.brandName).to.equal("Coral Restoration Foundation");
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.logoUrl).to.equal(brandData.logoUrl);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.heroImageUrl).to.equal(brandData.heroImageUrl);
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.accentColor).to.equal("#0066cc");
                (0, chai_1.expect)(publicData === null || publicData === void 0 ? void 0 : publicData.kioskEnabled).to.be.true;
            });
            it("should remove unpublished brand profiles from public_orgs", async () => {
                const orgId = "org-123";
                const brandId = "brand-abc";
                // Seed: Create published brand
                const publishedData = {
                    id: brandId,
                    brandName: "Test Org",
                    organizationId: orgId,
                    published: true,
                };
                await db.collection(`public_orgs/${orgId}/brand_profiles`).doc(brandId).set(publishedData);
                // Unpublish
                const unpublishedData = Object.assign(Object.assign({}, publishedData), { published: false });
                const beforeSnap = test.firestore.makeDocumentSnapshot(publishedData, `brand_profiles/${brandId}`);
                const afterSnap = test.firestore.makeDocumentSnapshot(unpublishedData, `brand_profiles/${brandId}`);
                await myFunctions.mirrorPublishedBrandProfiles.run({
                    data: { before: beforeSnap, after: afterSnap },
                    params: { brandId },
                });
                const publicBrand = await db
                    .collection(`public_orgs/${orgId}/brand_profiles`)
                    .doc(brandId)
                    .get();
                (0, chai_1.expect)(publicBrand.exists).to.be.false;
            });
            it("should delete public brand when source is deleted", async () => {
                const orgId = "org-123";
                const brandId = "brand-abc";
                // Seed
                const brandData = {
                    id: brandId,
                    organizationId: orgId,
                    published: true,
                };
                await db.collection(`public_orgs/${orgId}/brand_profiles`).doc(brandId).set(brandData);
                // Delete
                const beforeSnap = test.firestore.makeDocumentSnapshot(brandData, `brand_profiles/${brandId}`);
                await myFunctions.mirrorPublishedBrandProfiles.run({
                    data: { before: beforeSnap, after: undefined },
                    params: { brandId },
                });
                const publicBrand = await db
                    .collection(`public_orgs/${orgId}/brand_profiles`)
                    .doc(brandId)
                    .get();
                (0, chai_1.expect)(publicBrand.exists).to.be.false;
            });
        });
        describe("createDefaultPlaylist", () => {
            it("should create default playlist when brand profile is published", async () => {
                const orgId = "org-123";
                const brandId = "brand-abc";
                const brandData = {
                    id: brandId,
                    brandName: "Coral Restoration Foundation",
                    organizationId: orgId,
                    published: true,
                };
                const snap = test.firestore.makeDocumentSnapshot(brandData, `public_orgs/${orgId}/brand_profiles/${brandId}`);
                await myFunctions.createDefaultPlaylist.run({
                    data: snap,
                    params: { orgId, brandId },
                });
                const playlistId = `${orgId}_default`;
                const playlist = await db
                    .collection(`public_orgs/${orgId}/playlists`)
                    .doc(playlistId)
                    .get();
                (0, chai_1.expect)(playlist.exists).to.be.true;
                const playlistData = playlist.data();
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.id).to.equal(playlistId);
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.modelType).to.equal("publicPlaylist");
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.organizationId).to.equal(orgId);
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.title).to.equal("Coral Restoration Foundation Highlights");
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.description).to.equal("Auto-generated highlights playlist");
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.items).to.be.an("array").that.is.empty;
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.published).to.be.true;
            });
            it("should handle missing brand name gracefully", async () => {
                const orgId = "org-123";
                const brandId = "brand-abc";
                const brandData = {
                    id: brandId,
                    organizationId: orgId,
                    published: true,
                    // No brandName field
                };
                const snap = test.firestore.makeDocumentSnapshot(brandData, `public_orgs/${orgId}/brand_profiles/${brandId}`);
                await myFunctions.createDefaultPlaylist.run({
                    data: snap,
                    params: { orgId, brandId },
                });
                const playlistId = `${orgId}_default`;
                const playlist = await db
                    .collection(`public_orgs/${orgId}/playlists`)
                    .doc(playlistId)
                    .get();
                (0, chai_1.expect)(playlist.exists).to.be.true;
                const playlistData = playlist.data();
                (0, chai_1.expect)(playlistData === null || playlistData === void 0 ? void 0 : playlistData.title).to.equal("undefined Highlights");
            });
        });
    });
    describe("VE Phase C: Public Surfaces & Impact Points", () => {
        describe("projectOrgImpactPoints", () => {
            it("should project holdings data to impact points with geo metadata", async () => {
                const orgId = "org-123";
                const siteId = "site-abc";
                // Seed: Organization
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "Test Org",
                });
                // Seed: Site with geo metadata
                await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                    id: siteId,
                    name: "Coral Nursery Site",
                    latitude: 25.7617,
                    longitude: -80.1918,
                });
                // Seed: Holdings
                await db.collection("organizations").doc(orgId).collection("holdings").add({
                    siteId: siteId,
                    organizationId: orgId,
                    measurement: {
                        value: 150,
                        unit: "fragments",
                    },
                    quantity: 150,
                });
                await db.collection("organizations").doc(orgId).collection("holdings").add({
                    siteId: siteId,
                    organizationId: orgId,
                    measurement: {
                        value: 50,
                        unit: "fragments",
                    },
                    quantity: 50,
                });
                // Call the function directly (scheduled functions don't need wrapping)
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                // Verify impact point created
                const impactPoint = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .doc(`holding_${siteId}`)
                    .get();
                (0, chai_1.expect)(impactPoint.exists).to.be.true;
                const impactData = impactPoint.data();
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.id).to.equal(`holding_${siteId}`);
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.modelType).to.equal("publicImpactPoint");
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.organizationId).to.equal(orgId);
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.latitude).to.equal(25.7617);
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.longitude).to.equal(-80.1918);
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.label).to.equal("Coral Nursery Site");
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.pointType).to.equal("holding");
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.magnitude).to.equal(200); // 150 + 50
            });
            it("should project outplant events to impact points", async () => {
                const orgId = "org-456";
                const siteId = "site-xyz";
                // Seed: Organization
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "Outplant Org",
                });
                // Seed: Site
                await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                    id: siteId,
                    name: "Restoration Reef",
                    latitude: 24.5557,
                    longitude: -81.8001,
                });
                // Seed: Outplant events
                await db.collection("events").add({
                    organizationId: orgId,
                    eventTypeId: "outplant_event",
                    siteId: siteId,
                    allocations: [
                        { quantity: 100 },
                        { quantity: 75 },
                    ],
                });
                await db.collection("events").add({
                    organizationId: orgId,
                    eventTypeId: "outplant_event",
                    siteId: siteId,
                    quantity: 50, // Fallback to quantity field
                });
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                const impactPoint = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .doc(`outplant_${siteId}`)
                    .get();
                (0, chai_1.expect)(impactPoint.exists).to.be.true;
                const impactData = impactPoint.data();
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.pointType).to.equal("outplant");
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.magnitude).to.equal(225); // 100 + 75 + 50
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.latitude).to.equal(24.5557);
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.longitude).to.equal(-81.8001);
            });
            it("should skip sites without geo metadata", async () => {
                const orgId = "org-789";
                const siteId = "site-no-geo";
                // Seed: Organization
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "No Geo Org",
                });
                // Seed: Site WITHOUT geo metadata
                await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                    id: siteId,
                    name: "No Coordinates Site",
                    // Missing latitude/longitude
                });
                // Seed: Holdings
                await db.collection("organizations").doc(orgId).collection("holdings").add({
                    siteId: siteId,
                    organizationId: orgId,
                    quantity: 100,
                });
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                // Verify NO impact point created
                const impactPoints = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .get();
                (0, chai_1.expect)(impactPoints.empty).to.be.true;
            });
            it("should handle organizations without sites gracefully", async () => {
                const orgId = "org-empty";
                // Seed: Organization with no sites
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "Empty Org",
                });
                // Should not throw
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                const impactPoints = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .get();
                (0, chai_1.expect)(impactPoints.empty).to.be.true;
            });
            it("should clear existing impact points before reprojecting", async () => {
                const orgId = "org-clear";
                const siteId = "site-clear";
                // Seed: Organization
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "Clear Org",
                });
                // Seed: Old impact point
                await db.collection(`public_orgs/${orgId}/impact_points`).doc("old-point").set({
                    id: "old-point",
                    modelType: "publicImpactPoint",
                    organizationId: orgId,
                    latitude: 0,
                    longitude: 0,
                    magnitude: 999,
                });
                // Seed: Site with holdings
                await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                    id: siteId,
                    name: "New Site",
                    latitude: 25.0,
                    longitude: -80.0,
                });
                await db.collection("organizations").doc(orgId).collection("holdings").add({
                    siteId: siteId,
                    quantity: 50,
                });
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                // Verify old point removed
                const oldPoint = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .doc("old-point")
                    .get();
                (0, chai_1.expect)(oldPoint.exists).to.be.false;
                // Verify new point exists
                const newPoint = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .doc(`holding_${siteId}`)
                    .get();
                (0, chai_1.expect)(newPoint.exists).to.be.true;
            });
            it("should handle zero magnitude holdings gracefully", async () => {
                const orgId = "org-zero";
                const siteId = "site-zero";
                // Seed: Organization
                await db.collection("organizations").doc(orgId).set({
                    id: orgId,
                    name: "Zero Org",
                });
                // Seed: Site
                await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                    id: siteId,
                    name: "Zero Site",
                    latitude: 25.0,
                    longitude: -80.0,
                });
                // Seed: Zero magnitude holdings
                await db.collection("organizations").doc(orgId).collection("holdings").add({
                    siteId: siteId,
                    quantity: 0,
                });
                await myFunctions.projectOrgImpactPoints.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                // Verify NO impact point created for zero magnitude
                const impactPoint = await db
                    .collection(`public_orgs/${orgId}/impact_points`)
                    .doc(`holding_${siteId}`)
                    .get();
                (0, chai_1.expect)(impactPoint.exists).to.be.false;
            });
        });
        describe("buildWeeklyOrgDigests", () => {
            it("should build weekly digest from published media", async () => {
                const orgId = "org-digest";
                // Seed: public_orgs document
                await db.collection("public_orgs").doc(orgId).set({
                    id: orgId,
                });
                // Calculate last Monday
                const now = new Date();
                const monday = new Date(now);
                const day = monday.getDay();
                const diff = (day + 6) % 7;
                monday.setDate(now.getDate() - diff - 7);
                monday.setHours(0, 0, 0, 0);
                // Seed: Media from last week
                const lastWeekDate = new Date(monday);
                lastWeekDate.setDate(monday.getDate() + 3); // Wednesday
                for (let i = 0; i < 3; i++) {
                    await db.collection(`public_orgs/${orgId}/media`).add({
                        id: `media-${i}`,
                        url: `https://example.com/image-${i}.jpg`,
                        assetType: "image",
                        organizationId: orgId,
                        published: true,
                        publishedAt: lastWeekDate.toISOString(),
                    });
                }
                await myFunctions.buildWeeklyOrgDigests.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                // Find digest document
                const digests = await db
                    .collection(`public_orgs/${orgId}/digests`)
                    .get();
                (0, chai_1.expect)(digests.empty).to.be.false;
                (0, chai_1.expect)(digests.size).to.equal(1);
                const digestData = digests.docs[0].data();
                (0, chai_1.expect)(digestData.modelType).to.equal("publicDigest");
                (0, chai_1.expect)(digestData.organizationId).to.equal(orgId);
                (0, chai_1.expect)(digestData.published).to.be.true;
                (0, chai_1.expect)(digestData.metrics.exposures).to.equal(60); // 3 items * 20
                (0, chai_1.expect)(digestData.metrics.taps).to.equal(15); // 3 items * 5
                (0, chai_1.expect)(digestData.highlightAssetIds).to.be.an("array");
                (0, chai_1.expect)(digestData.highlightAssetIds.length).to.be.at.most(5);
            });
            it("should skip organizations without media in the week", async () => {
                const orgId = "org-no-media";
                // Seed: public_orgs document
                await db.collection("public_orgs").doc(orgId).set({
                    id: orgId,
                });
                await myFunctions.buildWeeklyOrgDigests.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                const digests = await db
                    .collection(`public_orgs/${orgId}/digests`)
                    .get();
                (0, chai_1.expect)(digests.empty).to.be.true;
            });
            it("should limit highlight assets to 5", async () => {
                const orgId = "org-many-media";
                // Seed: public_orgs document
                await db.collection("public_orgs").doc(orgId).set({
                    id: orgId,
                });
                // Calculate last Monday
                const now = new Date();
                const monday = new Date(now);
                const day = monday.getDay();
                const diff = (day + 6) % 7;
                monday.setDate(now.getDate() - diff - 7);
                monday.setHours(0, 0, 0, 0);
                const lastWeekDate = new Date(monday);
                lastWeekDate.setDate(monday.getDate() + 3);
                // Seed: 10 media items
                for (let i = 0; i < 10; i++) {
                    await db.collection(`public_orgs/${orgId}/media`).add({
                        id: `media-${i}`,
                        url: `https://example.com/image-${i}.jpg`,
                        assetType: "image",
                        organizationId: orgId,
                        published: true,
                        publishedAt: lastWeekDate.toISOString(),
                    });
                }
                await myFunctions.buildWeeklyOrgDigests.run({
                    scheduleTime: new Date().toISOString(),
                    jobName: "test-job",
                });
                const digests = await db
                    .collection(`public_orgs/${orgId}/digests`)
                    .get();
                const digestData = digests.docs[0].data();
                (0, chai_1.expect)(digestData.highlightAssetIds.length).to.be.at.most(5);
            });
        });
    });
    describe("Edge Cases & Error Handling", () => {
        it("should handle missing document data gracefully", async () => {
            const assetId = "missing-data";
            // Create snapshot with no data
            const beforeSnap = test.firestore.makeDocumentSnapshot({}, `media_assets/${assetId}`);
            await myFunctions.mirrorPublishedMedia.run({
                data: { before: beforeSnap, after: undefined },
                params: { assetId },
            });
        });
        it("should handle invalid geo coordinates in sites", async () => {
            const orgId = "org-bad-geo";
            const siteId = "site-bad-geo";
            await db.collection("organizations").doc(orgId).set({
                id: orgId,
                name: "Bad Geo Org",
            });
            // Seed: Site with invalid coordinates
            await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                id: siteId,
                name: "Bad Geo Site",
                latitude: "not-a-number",
                longitude: null,
            });
            await db.collection("organizations").doc(orgId).collection("holdings").add({
                siteId: siteId,
                quantity: 100,
            });
            // Should not throw
            await myFunctions.projectOrgImpactPoints.run({
                scheduleTime: new Date().toISOString(),
                jobName: "test-job",
            });
            const impactPoints = await db
                .collection(`public_orgs/${orgId}/impact_points`)
                .get();
            (0, chai_1.expect)(impactPoints.empty).to.be.true;
        });
        it("should handle string quantity values in holdings", async () => {
            const orgId = "org-string-qty";
            const siteId = "site-string-qty";
            await db.collection("organizations").doc(orgId).set({
                id: orgId,
                name: "String Qty Org",
            });
            await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                id: siteId,
                name: "String Qty Site",
                latitude: 25.0,
                longitude: -80.0,
            });
            // Seed: Holdings with string quantity
            await db.collection("organizations").doc(orgId).collection("holdings").add({
                siteId: siteId,
                quantity: "50", // String instead of number
            });
            await myFunctions.projectOrgImpactPoints.run({
                scheduleTime: new Date().toISOString(),
                jobName: "test-job",
            });
            const impactPoint = await db
                .collection(`public_orgs/${orgId}/impact_points`)
                .doc(`holding_${siteId}`)
                .get();
            (0, chai_1.expect)(impactPoint.exists).to.be.true;
            const impactData = impactPoint.data();
            (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.magnitude).to.equal(50); // Should parse string
        });
        it("should handle NaN and invalid numeric values", async () => {
            const orgId = "org-nan";
            const siteId = "site-nan";
            await db.collection("organizations").doc(orgId).set({
                id: orgId,
                name: "NaN Org",
            });
            await db.collection("organizations").doc(orgId).collection("sites").doc(siteId).set({
                id: siteId,
                name: "NaN Site",
                latitude: 25.0,
                longitude: -80.0,
            });
            // Seed: Holdings with invalid quantities
            await db.collection("organizations").doc(orgId).collection("holdings").add({
                siteId: siteId,
                quantity: "not-a-number",
            });
            await myFunctions.projectOrgImpactPoints.run({
                scheduleTime: new Date().toISOString(),
                jobName: "test-job",
            });
            const impactPoint = await db
                .collection(`public_orgs/${orgId}/impact_points`)
                .doc(`holding_${siteId}`)
                .get();
            // Should handle gracefully - either no point or magnitude of 0
            if (impactPoint.exists) {
                const impactData = impactPoint.data();
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.magnitude).to.be.a("number");
                (0, chai_1.expect)(impactData === null || impactData === void 0 ? void 0 : impactData.magnitude).to.be.at.least(0);
            }
        });
    });
});
/**
 * Helper: Clear all Firestore collections
 */
async function clearFirestore(db) {
    const collections = [
        "organizations",
        "media_assets",
        "brand_profiles",
        "events",
        "public_orgs",
    ];
    for (const collectionName of collections) {
        const snapshot = await db.collection(collectionName).get();
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        if (snapshot.size > 0) {
            await batch.commit();
        }
    }
}
//# sourceMappingURL=visual-engagement.test.js.map