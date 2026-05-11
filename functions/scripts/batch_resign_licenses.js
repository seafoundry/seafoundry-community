"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
/* eslint-disable no-console */
const fs = __importStar(require("fs"));
const feature_access_1 = require("../src/feature_access");
function usage() {
    console.error("Usage: SF_LICENSE_SECRET=... npm run sign:batch -- ./path/to/licenses.json");
    process.exit(1);
}
function main() {
    const secret = process.env.SF_LICENSE_SECRET;
    if (!secret) {
        console.error("SF_LICENSE_SECRET must be set");
        process.exit(1);
    }
    const inputPath = process.argv[2];
    if (!inputPath)
        usage();
    if (!fs.existsSync(inputPath)) {
        console.error(`Input file not found: ${inputPath}`);
        process.exit(1);
    }
    const raw = JSON.parse(fs.readFileSync(inputPath, "utf8"));
    if (!Array.isArray(raw)) {
        console.error("Input JSON must be an array of license objects");
        process.exit(1);
    }
    const output = raw.map((entry) => {
        var _a;
        if (!entry.orgId || !entry.tier) {
            throw new Error("Each entry must include orgId and tier");
        }
        const license = {
            tier: entry.tier,
            features: (_a = entry.features) !== null && _a !== void 0 ? _a : {},
        };
        if (entry.upgradeUrl)
            license.upgradeUrl = entry.upgradeUrl;
        if (entry.expiresAt)
            license.expiresAt = entry.expiresAt;
        const signature = (0, feature_access_1.signLicensePayload)(license, secret);
        return {
            orgId: entry.orgId,
            license: Object.assign(Object.assign({}, license), { signature }),
        };
    });
    console.log(JSON.stringify(output, null, 2));
}
main();
//# sourceMappingURL=batch_resign_licenses.js.map