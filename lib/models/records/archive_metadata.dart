// @tier: community
/// Shared metadata keys for archived inventory records.
///
/// These live in record metadata to avoid schema changes across models.
const String kArchivedFlagKey = 'archived';
const String kArchivedAtKey = 'archivedAt';
const String kArchivedByIdKey = 'archivedById';
const String kArchivedReasonTypeKey = 'archivedReasonType';
const String kArchivedReasonIdKey = 'archivedReasonId';

const String kArchiveReasonTypeMortality = 'mortality';
const String kArchiveReasonTypeDeleted = 'deleted';
const String kArchiveReasonTypeFertilization = 'fertilization';