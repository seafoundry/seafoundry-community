import * as admin from "firebase-admin";
import * as crypto from "crypto";

export type Tier = "community" | "pro" | "scale";

interface LicenseShape {
  tier?: Tier;
  features: Record<string, boolean>;
  expiresAt?: Date;
  upgradeUrl?: string;
  valid: boolean;
  reason?: string;
}

export interface FeatureAccessOptions {
  requiredTiers?: Tier[];
  licenseSecret?: string;
}

interface FeatureAccessResult {
  tier: Tier;
  enabled: boolean;
  reason?: string;
}

const DEFAULT_TIER: Tier = "community";
const PRO_FEATURES: Record<string, Tier[]> = {
  imagery_attachments: ["pro", "scale"],
  team_invitations: ["pro", "scale"],
  media_publishing: ["pro", "scale"],
  brand_profiles: ["scale"],
};

const ORGANIZATION_COLLECTION = "organizations";

function parseTier(value: unknown): Tier | undefined {
  if (!value) return undefined;
  const normalized = value.toString().trim().toLowerCase();
  if (normalized === "community" || normalized === "pro" || normalized === "scale") {
    return normalized;
  }
  return undefined;
}

function canonicalMillis(value: unknown): number | undefined {
  if (value == null) return undefined;
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return undefined;
}

function parseExpiration(value: unknown): Date | undefined {
  const millis = canonicalMillis(value);
  if (millis == null) return undefined;
  const dt = new Date(millis);
  return Number.isNaN(dt.getTime()) ? undefined : dt;
}

function extractFeatureOverrides(raw: unknown): Record<string, boolean> {
  if (raw == null || typeof raw !== "object") return {};
  const overrides: Record<string, boolean> = {};
  Object.entries(raw as Record<string, unknown>).forEach(([key, val]) => {
    if (typeof val === "boolean") {
      overrides[key] = val;
    }
  });
  return overrides;
}

function normalizeUpgradeUrl(raw: unknown): string | undefined {
  if (!raw) return undefined;
  const url = raw.toString().trim();
  let parsed: URL | undefined;
  try {
    parsed = new URL(url);
  } catch (_) {
    parsed = undefined;
  }
  if (!parsed) {
    return undefined;
  }
  return parsed.toString();
}

export function signLicensePayload(
  license: Record<string, unknown>,
  secret: string,
  opts?: { includeUpgradeUrl?: boolean }
): string {
  const includeUpgradeUrl = opts?.includeUpgradeUrl !== false;
  const tier = (license["tier"] ?? "").toString();
  const expiresAt = canonicalMillis(license["expiresAt"]) ?? 0;
  const upgradeUrl = includeUpgradeUrl ?
    normalizeUpgradeUrl(license["upgradeUrl"]) ?? "" :
    "";
  const features = extractFeatureOverrides(license["features"]);
  const featurePairs = Object.keys(features)
    .sort()
    .map((key) => `${key}=${features[key] ? 1 : 0}`)
    .join(";");
  const payload = `${tier}|${expiresAt}|${upgradeUrl}|${featurePairs}`;
  const hmac = crypto.createHmac("sha256", secret);
  hmac.update(payload);
  return hmac.digest("base64url");
}

function resolveLicense(
  license: unknown,
  licenseSecret?: string
): LicenseShape {
  if (!license || typeof license !== "object") {
    return {valid: false, features: {}};
  }

  const data = license as Record<string, unknown>;
  const expiresAt = parseExpiration(data["expiresAt"]);
  const now = Date.now();
  if (expiresAt && expiresAt.getTime() <= now) {
    return {
      valid: false,
      features: {},
      expiresAt,
      reason: "expired",
    };
  }

  const features = extractFeatureOverrides(data["features"]);
  const tier = parseTier(data["tier"]);
  const normalizedUpgradeUrl = normalizeUpgradeUrl(
    data["upgradeUrl"]
  );
  let upgradeUrlSigned = true;

  if (licenseSecret) {
    const providedSignature = data["signature"]?.toString();
    if (!providedSignature) {
      return {
        valid: false,
        features: {},
        expiresAt,
        reason: "missing_signature",
      };
    }
    const expected = signLicensePayload(
      data,
      licenseSecret,
      {includeUpgradeUrl: true}
    );
    if (expected !== providedSignature) {
      // Legacy licenses signed without upgradeUrl
      const legacyExpected = signLicensePayload(
        data,
        licenseSecret,
        {includeUpgradeUrl: false}
      );
      if (legacyExpected !== providedSignature) {
        return {
          valid: false,
          features: {},
          expiresAt,
          reason: "invalid_signature",
        };
      }
      upgradeUrlSigned = false;
    }
  }

  return {
    valid: true,
    tier,
    features,
    expiresAt,
    upgradeUrl: upgradeUrlSigned ? normalizedUpgradeUrl : undefined,
  };
}

async function getOrganization(orgId: string): Promise<Record<string, unknown>> {
  const doc = await admin
    .firestore()
    .collection(ORGANIZATION_COLLECTION)
    .doc(orgId)
    .get();

  if (!doc.exists) return {};
  return doc.data() ?? {};
}

export async function isFeatureEnabledForOrg(
  orgId: string,
  featureKey: string,
  opts?: FeatureAccessOptions
): Promise<FeatureAccessResult> {
  const organization = await getOrganization(orgId);
  return evaluateFeatureAccess(organization, featureKey, opts);
}

export function evaluateFeatureAccess(
  organization: Record<string, unknown>,
  featureKey: string,
  opts?: FeatureAccessOptions
): FeatureAccessResult {
  const baseTier = parseTier(organization["tier"] ?? organization["plan"]) ?? DEFAULT_TIER;
  const license = resolveLicense(
    organization["license"],
    opts?.licenseSecret ?? process.env.SF_LICENSE_SECRET
  );

  const tier = license.valid && license.tier ? license.tier : baseTier;
  const requiredTiers = opts?.requiredTiers ?? PRO_FEATURES[featureKey] ?? [];
  const tierAllowsFeature =
    requiredTiers.length === 0 || requiredTiers.includes(tier);
  const licenseOverride =
    license.valid && license.features[featureKey] === true;
  const enabled = licenseOverride || tierAllowsFeature;
  const orgId = organization["id"]?.toString() ?? "unknown";

  return {
    tier,
    enabled,
    reason: enabled ?
      undefined :
      `Feature ${featureKey} disabled for tier ${tier} (org ${orgId})`,
  };
}
