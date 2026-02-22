import functionsTest from "firebase-functions-test";
import * as sinon from "sinon";
import * as admin from "firebase-admin";

// Initialize test environment (no config needed for logic-only test)
const testEnv = functionsTest({projectId: "demo-seafoundry"});

describe("deliverableDeadlineAlerts", () => {
  const sandbox = sinon.createSandbox();

  // Mock a ScheduledEvent
  const mockScheduledEvent: any = {
    data: {},
    // You can add more fields if your function actually uses them
  };

  beforeEach(() => {
    // Stub admin.initializeApp before any functions are imported to avoid error
    sandbox.stub(admin, "initializeApp").returns(
      {} as admin.app.App, // Return a fake App object
    );

    // Fake Firestore query chain returning no deliverables and no users
    const fakeGetEmpty = async () => ({empty: true, docs: []});
    const fakeCollection = () => ({
      where: () => ({
        where: () => ({
          get: fakeGetEmpty,
        }),
        get: fakeGetEmpty,
      }),
      doc: () => ({
        get: async () => ({exists: false}),
        collection: () => ({
          doc: () => ({
            get: async () => ({exists: false}),
          }),
        }),
      }),
    });

    sandbox.stub(admin, "firestore").returns({
      collection: fakeCollection,
    } as unknown as FirebaseFirestore.Firestore);

    // Stub messaging/email so no network calls occur
    sandbox.stub(admin, "messaging").returns({
      send: sandbox.stub().resolves(),
    } as unknown as admin.messaging.Messaging);
  });

  afterEach(async () => {
    sandbox.restore();
    await testEnv.cleanup();
  });

  it("handles empty result set without throwing", async () => {
    const {deliverableDeadlineAlerts} = await import(
      "../src/notifications/deliverable_alerts"
    );
    await deliverableDeadlineAlerts.run(mockScheduledEvent);
  });
});
