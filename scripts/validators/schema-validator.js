/**
 * Schema validation for SeaFoundry Firestore documents
 */

const requiredFields = {
  event: ['id', 'modelType', 'eventTypeId', 'recordId', 'recordModelType',
          'organizationId', 'createdAt', 'createdById', 'updatedAt',
          'updatedById', 'urlPath', 'internalPath', 'slug'],
  organismRecord: ['id', 'modelType', 'organizationId', 'speciesId', 'organismKind'],
  genet: ['id', 'modelType', 'organizationId'],
  site: ['id', 'modelType', 'organizationId'],
  group: ['id', 'modelType', 'organizationId', 'siteId'],
};

function validateDocument(doc, docType) {
  const errors = [];

  // Check required fields
  for (const field of requiredFields[docType] || []) {
    if (!doc[field]) {
      errors.push(`Missing required field: ${field}`);
    }
  }

  // Type-specific validations
  if (docType === 'event') {
    if (doc.eventType && !doc.eventTypeId) {
      errors.push('Use "eventTypeId" not "eventType"');
    }
    if (doc.recordModelType === 'coral') {
      errors.push('Use "organismRecord" not "coral" for recordModelType');
    }
    const inventoryEventTypes = ['event_create', 'event_move_in', 'event_move_out',
                                  'event_frag', 'event_population_gain', 'event_population_loss'];
    if (inventoryEventTypes.includes(doc.eventTypeId)) {
      if (doc.snapshot && !doc.snapshotData) {
        errors.push('Use "snapshotData" not "snapshot" for inventory events');
      }
    }
  }

  if (docType === 'organismRecord') {
    if (doc.provenanceType && typeof doc.provenanceType === 'object') {
      errors.push('Use flat "provenanceTypeId" string, not nested "provenanceType" object');
    }
  }

  return errors;
}

module.exports = { validateDocument, requiredFields };
