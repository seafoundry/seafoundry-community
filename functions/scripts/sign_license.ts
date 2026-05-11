/* eslint-disable no-console */
import {signLicensePayload, Tier} from "../src/feature_access";

type FeatureMap = Record<string, boolean>;

function parseArgs(argv: string[]): {
  tier?: Tier;
  expiresAt?: string;
  upgradeUrl?: string;
  features: FeatureMap;
} {
  const args: FeatureMap = {};
  let tier: Tier | undefined;
  let expiresAt: string | undefined;
  let upgradeUrl: string | undefined;

  argv.forEach((raw) => {
    if (raw.startsWith("--tier=")) {
      const value = raw.replace("--tier=", "").toLowerCase();
      if (value === "community" || value === "pro" || value === "scale") {
        tier = value;
      }
    } else if (raw.startsWith("--expires=")) {
      expiresAt = raw.replace("--expires=", "");
    } else if (raw.startsWith("--upgradeUrl=")) {
      upgradeUrl = raw.replace("--upgradeUrl=", "");
    } else if (raw.startsWith("--features=")) {
      const featurePairs = raw.replace("--features=", "");
      featurePairs.split(",").forEach((pair) => {
        const [key, val] = pair.split("=");
        if (!key) return;
        args[key.trim()] = val?.toLowerCase() === "true";
      });
    }
  });

  return {tier, expiresAt, upgradeUrl, features: args};
}

function main() {
  const secret = process.env.SF_LICENSE_SECRET;
  if (!secret) {
    console.error("SF_LICENSE_SECRET must be set");
    process.exit(1);
  }

  const {tier, expiresAt, upgradeUrl, features} = parseArgs(process.argv.slice(2));
  if (!tier) {
    console.error("Missing required --tier=community|pro|scale");
    process.exit(1);
  }

  const license: Record<string, unknown> = {
    tier,
    features,
  };
  if (expiresAt) license.expiresAt = expiresAt;
  if (upgradeUrl) license.upgradeUrl = upgradeUrl;

  const signature = signLicensePayload(license, secret);
  const payload = {...license, signature};

  console.log(JSON.stringify(payload, null, 2));
}

main();
