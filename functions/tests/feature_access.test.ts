import {expect} from "chai";
import {
  evaluateFeatureAccess,
  signLicensePayload,
  Tier,
} from "../src/feature_access";

const COMMUNITY_ORG = {tier: "community"};

describe("feature access evaluation", () => {
  it("blocks imagery attachments for Community by default", () => {
    const result = evaluateFeatureAccess(
      COMMUNITY_ORG,
      "imagery_attachments"
    );
    expect(result.enabled).to.equal(false);
    expect(result.tier).to.equal("community");
  });

  it("honors a signed Pro license and enables feature overrides", () => {
    const secret = "test-secret";
    const license = {
      tier: "pro" as Tier,
      features: {imagery_attachments: true},
      upgradeUrl: "https://upgrade.test/pro",
    };
    const signature = signLicensePayload(license, secret);
    const result = evaluateFeatureAccess(
      {
        tier: "community",
        license: {...license, signature},
      },
      "imagery_attachments",
      {licenseSecret: secret}
    );

    expect(result.enabled).to.equal(true);
    expect(result.tier).to.equal("pro");
  });

  it("drops upgrade URL when signature does not cover it", () => {
    const secret = "test-secret";
    const license = {
      tier: "pro" as Tier,
      features: {imagery_attachments: true},
    };
    // Legacy signature that omits upgradeUrl
    const signature = signLicensePayload(
      license,
      secret,
      {includeUpgradeUrl: false}
    );
    const result = evaluateFeatureAccess(
      {
        tier: "community",
        license: {
          ...license,
          upgradeUrl: "https://malicious.example/phish",
          signature,
        },
      },
      "imagery_attachments",
      {licenseSecret: secret}
    );

    expect(result.enabled).to.equal(true);
    expect(result.tier).to.equal("pro");
  });

  it("rejects expired licenses and falls back to base tier", () => {
    const secret = "test-secret";
    const license = {
      tier: "pro" as Tier,
      features: {imagery_attachments: true},
      expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
    };
    const signature = signLicensePayload(license, secret);
    const result = evaluateFeatureAccess(
      {
        tier: "community",
        license: {...license, signature},
      },
      "imagery_attachments",
      {licenseSecret: secret}
    );

    expect(result.enabled).to.equal(false);
    expect(result.tier).to.equal("community");
  });

  it("rejects invalid signatures even when the license grants access", () => {
    const secret = "test-secret";
    const license = {
      tier: "pro" as Tier,
      features: {imagery_attachments: true},
    };
    const result = evaluateFeatureAccess(
      {
        tier: "community",
        license: {...license, signature: "bogus"},
      },
      "imagery_attachments",
      {licenseSecret: secret}
    );

    expect(result.enabled).to.equal(false);
    expect(result.tier).to.equal("community");
  });
});
