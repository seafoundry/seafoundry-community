/* eslint-disable no-console */
import * as fs from "fs";
import {signLicensePayload, Tier} from "../src/feature_access";

interface LicenseInput {
  orgId: string;
  tier: Tier;
  features?: Record<string, boolean>;
  upgradeUrl?: string;
  expiresAt?: string;
}

function usage(): never {
  console.error(
    "Usage: SF_LICENSE_SECRET=... npm run sign:batch -- ./path/to/licenses.json"
  );
  process.exit(1);
}

function main() {
  const secret = process.env.SF_LICENSE_SECRET;
  if (!secret) {
    console.error("SF_LICENSE_SECRET must be set");
    process.exit(1);
  }

  const inputPath = process.argv[2];
  if (!inputPath) usage();
  if (!fs.existsSync(inputPath)) {
    console.error(`Input file not found: ${inputPath}`);
    process.exit(1);
  }

  const raw = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  if (!Array.isArray(raw)) {
    console.error("Input JSON must be an array of license objects");
    process.exit(1);
  }

  const output = raw.map((entry: LicenseInput) => {
    if (!entry.orgId || !entry.tier) {
      throw new Error("Each entry must include orgId and tier");
    }
    const license: Record<string, unknown> = {
      tier: entry.tier,
      features: entry.features ?? {},
    };
    if (entry.upgradeUrl) license.upgradeUrl = entry.upgradeUrl;
    if (entry.expiresAt) license.expiresAt = entry.expiresAt;

    const signature = signLicensePayload(license, secret);
    return {
      orgId: entry.orgId,
      license: {
        ...license,
        signature,
      },
    };
  });

  console.log(JSON.stringify(output, null, 2));
}

main();
