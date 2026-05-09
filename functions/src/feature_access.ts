import * as admin from "firebase-admin";

// Community-only fork: all features return community tier.
export type Tier = "community";

export interface FeatureAccessOptions {
  requiredTiers?: Tier[];
}

interface FeatureAccessResult {
  tier: Tier;
  enabled: boolean;
  reason?: string;
}

const DEFAULT_TIER: Tier = "community";
const ORGANIZATION_COLLECTION = "organizations";

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
  _opts?: FeatureAccessOptions
): Promise<FeatureAccessResult> {
  // Verify org exists but always return community/enabled.
  await getOrganization(orgId);
  return { tier: DEFAULT_TIER, enabled: true };
}

export function evaluateFeatureAccess(
  _organization: Record<string, unknown>,
  _featureKey: string,
  _opts?: FeatureAccessOptions
): FeatureAccessResult {
  return { tier: DEFAULT_TIER, enabled: true };
}
