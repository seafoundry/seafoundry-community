/**
 * Schema validator tests
 */

const { validateDocument, requiredFields } = require('./schema-validator');

describe('Schema Validator', () => {
  describe('validateDocument - Event', () => {
    test('valid event passes', () => {
      const validEvent = {
        id: 'evt_123',
        modelType: 'event',
        eventTypeId: 'event_create',
        recordId: 'org_456',
        recordModelType: 'organismRecord',
        organizationId: 'org_789',
        createdAt: { seconds: 1234567890 },
        createdById: 'user_abc',
        updatedAt: { seconds: 1234567890 },
        updatedById: 'user_abc',
        urlPath: '/orgs/org_789/events/evt_123',
        internalPath: 'organizations/org_789/events/evt_123',
        slug: 'evt_123',
        snapshotData: {
          quantity: 10,
          locationId: 'loc_123',
        },
      };

      const errors = validateDocument(validEvent, 'event');
      expect(errors).toHaveLength(0);
    });

    test('event with eventType instead of eventTypeId fails', () => {
      const invalidEvent = {
        id: 'evt_123',
        modelType: 'event',
        eventType: { id: 'event_create', name: 'Create' }, // Should use eventTypeId
        recordId: 'org_456',
        recordModelType: 'organismRecord',
        organizationId: 'org_789',
        createdAt: { seconds: 1234567890 },
        createdById: 'user_abc',
        updatedAt: { seconds: 1234567890 },
        updatedById: 'user_abc',
        urlPath: '/orgs/org_789/events/evt_123',
        internalPath: 'organizations/org_789/events/evt_123',
        slug: 'evt_123',
      };

      const errors = validateDocument(invalidEvent, 'event');
      expect(errors).toContain('Missing required field: eventTypeId');
      expect(errors).toContain('Use "eventTypeId" not "eventType"');
    });

    test('event with coral recordModelType fails', () => {
      const invalidEvent = {
        id: 'evt_123',
        modelType: 'event',
        eventTypeId: 'event_create',
        recordId: 'coral_456',
        recordModelType: 'coral', // Should use organismRecord
        organizationId: 'org_789',
        createdAt: { seconds: 1234567890 },
        createdById: 'user_abc',
        updatedAt: { seconds: 1234567890 },
        updatedById: 'user_abc',
        urlPath: '/orgs/org_789/events/evt_123',
        internalPath: 'organizations/org_789/events/evt_123',
        slug: 'evt_123',
      };

      const errors = validateDocument(invalidEvent, 'event');
      expect(errors).toContain('Use "organismRecord" not "coral" for recordModelType');
    });

    test('inventory event with snapshot instead of snapshotData warns', () => {
      const invalidEvent = {
        id: 'evt_123',
        modelType: 'event',
        eventTypeId: 'event_create',
        recordId: 'org_456',
        recordModelType: 'organismRecord',
        organizationId: 'org_789',
        createdAt: { seconds: 1234567890 },
        createdById: 'user_abc',
        updatedAt: { seconds: 1234567890 },
        updatedById: 'user_abc',
        urlPath: '/orgs/org_789/events/evt_123',
        internalPath: 'organizations/org_789/events/evt_123',
        slug: 'evt_123',
        snapshot: { // Should use snapshotData
          quantity: 10,
          locationId: 'loc_123',
        },
      };

      const errors = validateDocument(invalidEvent, 'event');
      expect(errors).toContain('Use "snapshotData" not "snapshot" for inventory events');
    });

    test('missing required fields fails', () => {
      const incompleteEvent = {
        id: 'evt_123',
        modelType: 'event',
        // Missing many required fields
      };

      const errors = validateDocument(incompleteEvent, 'event');
      expect(errors.length).toBeGreaterThan(0);
      expect(errors).toContain('Missing required field: eventTypeId');
      expect(errors).toContain('Missing required field: recordId');
      expect(errors).toContain('Missing required field: organizationId');
    });
  });

  describe('validateDocument - OrganismRecord', () => {
    test('valid organismRecord passes', () => {
      const validOrganism = {
        id: 'org_123',
        modelType: 'organismRecord',
        organizationId: 'org_789',
        speciesId: 'species_456',
        organismKind: 'genet',
        provenanceTypeId: 'wild_collected',
      };

      const errors = validateDocument(validOrganism, 'organismRecord');
      expect(errors).toHaveLength(0);
    });

    test('organismRecord with nested provenanceType fails', () => {
      const invalidOrganism = {
        id: 'org_123',
        modelType: 'organismRecord',
        organizationId: 'org_789',
        speciesId: 'species_456',
        organismKind: 'genet',
        provenanceType: { // Should use flat provenanceTypeId
          id: 'wild_collected',
          name: 'Wild Collected',
        },
      };

      const errors = validateDocument(invalidOrganism, 'organismRecord');
      expect(errors).toContain('Use flat "provenanceTypeId" string, not nested "provenanceType" object');
    });

    test('missing required fields fails', () => {
      const incompleteOrganism = {
        id: 'org_123',
        modelType: 'organismRecord',
        // Missing organizationId, speciesId, organismKind
      };

      const errors = validateDocument(incompleteOrganism, 'organismRecord');
      expect(errors).toContain('Missing required field: organizationId');
      expect(errors).toContain('Missing required field: speciesId');
      expect(errors).toContain('Missing required field: organismKind');
    });
  });

  describe('validateDocument - Other Types', () => {
    test('valid genet passes', () => {
      const validGenet = {
        id: 'genet_123',
        modelType: 'genet',
        organizationId: 'org_789',
      };

      const errors = validateDocument(validGenet, 'genet');
      expect(errors).toHaveLength(0);
    });

    test('valid site passes', () => {
      const validSite = {
        id: 'site_123',
        modelType: 'site',
        organizationId: 'org_789',
        name: 'Main Site',
      };

      const errors = validateDocument(validSite, 'site');
      expect(errors).toHaveLength(0);
    });

    test('valid group passes', () => {
      const validGroup = {
        id: 'group_123',
        modelType: 'group',
        organizationId: 'org_789',
        siteId: 'site_456',
        name: 'Tank A',
      };

      const errors = validateDocument(validGroup, 'group');
      expect(errors).toHaveLength(0);
    });

    test('unknown document type returns no errors', () => {
      const unknownDoc = {
        id: 'unknown_123',
        someField: 'value',
      };

      const errors = validateDocument(unknownDoc, 'unknownType');
      expect(errors).toHaveLength(0);
    });
  });

  describe('requiredFields export', () => {
    test('requiredFields contains expected types', () => {
      expect(requiredFields).toHaveProperty('event');
      expect(requiredFields).toHaveProperty('organismRecord');
      expect(requiredFields).toHaveProperty('genet');
      expect(requiredFields).toHaveProperty('site');
      expect(requiredFields).toHaveProperty('group');
    });

    test('event requiredFields includes all expected fields', () => {
      expect(requiredFields.event).toContain('id');
      expect(requiredFields.event).toContain('modelType');
      expect(requiredFields.event).toContain('eventTypeId');
      expect(requiredFields.event).toContain('organizationId');
    });
  });
});
