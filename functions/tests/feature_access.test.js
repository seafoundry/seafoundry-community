"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const feature_access_1 = require("../src/feature_access");
const COMMUNITY_ORG = { tier: "community" };
describe("feature access evaluation", () => {
    it("blocks imagery attachments for Community by default", () => {
        const result = (0, feature_access_1.evaluateFeatureAccess)(COMMUNITY_ORG, "imagery_attachments");
        (0, chai_1.expect)(result.enabled).to.equal(false);
        (0, chai_1.expect)(result.tier).to.equal("community");
    });
    it("honors a signed Pro license and enables feature overrides", () => {
        const secret = "test-secret";
        const license = {
            tier: "pro",
            features: { imagery_attachments: true },
            upgradeUrl: "https://upgrade.test/pro",
        };
        const signature = (0, feature_access_1.signLicensePayload)(license, secret);
        const result = (0, feature_access_1.evaluateFeatureAccess)({
            tier: "community",
            license: Object.assign(Object.assign({}, license), { signature }),
        }, "imagery_attachments", { licenseSecret: secret });
        (0, chai_1.expect)(result.enabled).to.equal(true);
        (0, chai_1.expect)(result.tier).to.equal("pro");
    });
    it("drops upgrade URL when signature does not cover it", () => {
        const secret = "test-secret";
        const license = {
            tier: "pro",
            features: { imagery_attachments: true },
        };
        // Legacy signature that omits upgradeUrl
        const signature = (0, feature_access_1.signLicensePayload)(license, secret, { includeUpgradeUrl: false });
        const result = (0, feature_access_1.evaluateFeatureAccess)({
            tier: "community",
            license: Object.assign(Object.assign({}, license), { upgradeUrl: "https://malicious.example/phish", signature }),
        }, "imagery_attachments", { licenseSecret: secret });
        (0, chai_1.expect)(result.enabled).to.equal(true);
        (0, chai_1.expect)(result.tier).to.equal("pro");
    });
    it("rejects expired licenses and falls back to base tier", () => {
        const secret = "test-secret";
        const license = {
            tier: "pro",
            features: { imagery_attachments: true },
            expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
        };
        const signature = (0, feature_access_1.signLicensePayload)(license, secret);
        const result = (0, feature_access_1.evaluateFeatureAccess)({
            tier: "community",
            license: Object.assign(Object.assign({}, license), { signature }),
        }, "imagery_attachments", { licenseSecret: secret });
        (0, chai_1.expect)(result.enabled).to.equal(false);
        (0, chai_1.expect)(result.tier).to.equal("community");
    });
    it("rejects invalid signatures even when the license grants access", () => {
        const secret = "test-secret";
        const license = {
            tier: "pro",
            features: { imagery_attachments: true },
        };
        const result = (0, feature_access_1.evaluateFeatureAccess)({
            tier: "community",
            license: Object.assign(Object.assign({}, license), { signature: "bogus" }),
        }, "imagery_attachments", { licenseSecret: secret });
        (0, chai_1.expect)(result.enabled).to.equal(false);
        (0, chai_1.expect)(result.tier).to.equal("community");
    });
});
//# sourceMappingURL=feature_access.test.js.map