"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
/* eslint-disable no-console */
const feature_access_1 = require("../src/feature_access");
function parseArgs(argv) {
    const args = {};
    let tier;
    let expiresAt;
    let upgradeUrl;
    argv.forEach((raw) => {
        if (raw.startsWith("--tier=")) {
            const value = raw.replace("--tier=", "").toLowerCase();
            if (value === "community" || value === "pro" || value === "scale") {
                tier = value;
            }
        }
        else if (raw.startsWith("--expires=")) {
            expiresAt = raw.replace("--expires=", "");
        }
        else if (raw.startsWith("--upgradeUrl=")) {
            upgradeUrl = raw.replace("--upgradeUrl=", "");
        }
        else if (raw.startsWith("--features=")) {
            const featurePairs = raw.replace("--features=", "");
            featurePairs.split(",").forEach((pair) => {
                const [key, val] = pair.split("=");
                if (!key)
                    return;
                args[key.trim()] = (val === null || val === void 0 ? void 0 : val.toLowerCase()) === "true";
            });
        }
    });
    return { tier, expiresAt, upgradeUrl, features: args };
}
function main() {
    const secret = process.env.SF_LICENSE_SECRET;
    if (!secret) {
        console.error("SF_LICENSE_SECRET must be set");
        process.exit(1);
    }
    const { tier, expiresAt, upgradeUrl, features } = parseArgs(process.argv.slice(2));
    if (!tier) {
        console.error("Missing required --tier=community|pro|scale");
        process.exit(1);
    }
    const license = {
        tier,
        features,
    };
    if (expiresAt)
        license.expiresAt = expiresAt;
    if (upgradeUrl)
        license.upgradeUrl = upgradeUrl;
    const signature = (0, feature_access_1.signLicensePayload)(license, secret);
    const payload = Object.assign(Object.assign({}, license), { signature });
    console.log(JSON.stringify(payload, null, 2));
}
main();
//# sourceMappingURL=sign_license.js.map