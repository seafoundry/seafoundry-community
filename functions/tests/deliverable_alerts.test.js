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
const functionsTest = __importStar(require("firebase-functions-test"));
const sinon = __importStar(require("sinon"));
const admin = __importStar(require("firebase-admin"));
// Initialize test environment (no config needed for logic-only test)
const testEnv = functionsTest();
describe("deliverableDeadlineAlerts", () => {
    const sandbox = sinon.createSandbox();
    beforeEach(() => {
        // Fake Firestore query chain returning no deliverables and no users
        const fakeGetEmpty = async () => ({ empty: true, docs: [] });
        const fakeCollection = () => ({
            where: () => ({
                where: () => ({
                    get: fakeGetEmpty,
                }),
                get: fakeGetEmpty,
            }),
            doc: () => ({
                get: async () => ({ exists: false }),
                collection: () => ({
                    doc: () => ({
                        get: async () => ({ exists: false }),
                    }),
                }),
            }),
        });
        sandbox.stub(admin, "firestore").returns({
            collection: fakeCollection,
        });
        // Stub messaging/email so no network calls occur
        sandbox.stub(admin, "messaging").returns({
            send: sandbox.stub().resolves(),
        });
    });
    afterEach(async () => {
        sandbox.restore();
        await testEnv.cleanup();
    });
    it("handles empty result set without throwing", async () => {
        const { deliverableDeadlineAlerts } = await Promise.resolve().then(() => __importStar(require("../src/notifications/deliverable_alerts")));
        await deliverableDeadlineAlerts.run();
    });
});
//# sourceMappingURL=deliverable_alerts.test.js.map