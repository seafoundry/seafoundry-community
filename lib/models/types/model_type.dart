enum ModelType {
  user(collectionPath: 'users'),
  organization(collectionPath: 'organizations'),
  site(collectionPath: 'sites'),
  zone(collectionPath: 'zones'),
  subplot(collectionPath: 'subplots'),
  group(collectionPath: 'groups'),
  cohort(collectionPath: 'cohorts'),
  holding(collectionPath: 'holdings'),
  genet(collectionPath: 'genets'),
  recordType(collectionPath: 'recordTypes'),
  event(collectionPath: 'events'),
  invitation(collectionPath: 'invitations'),
  organismRecord(collectionPath: 'organismRecords'),
  brandProfile(collectionPath: 'brand_profiles'),
  permit(collectionPath: 'permits'),
  deliverable(collectionPath: 'deliverables'),
  unknown(collectionPath: '');

  final String collectionPath;

  const ModelType({required this.collectionPath});

  String get displayName {
    switch (this) {
      case ModelType.user:
        return 'user';
      case ModelType.organization:
        return 'organization';
      case ModelType.site:
        return 'site';
      case ModelType.zone:
        return 'zone';
      case ModelType.subplot:
        return 'subplot';
      case ModelType.group:
        return 'group';
      case ModelType.cohort:
        return 'cohort';
      case ModelType.holding:
        return 'holding';
      case ModelType.genet:
        return 'genet';
      case ModelType.recordType:
        return 'record type';
      case ModelType.event:
        return 'event';
      case ModelType.invitation:
        return 'invitation';
      case ModelType.organismRecord:
        return 'organism record';
      case ModelType.brandProfile:
        return 'brand profile';
      case ModelType.permit:
        return 'permit';
      case ModelType.deliverable:
        return 'deliverable';
      case ModelType.unknown:
        return 'unknown';
    }
  }

  static const Map<String, ModelType> _segmentHints = {
    'users': ModelType.user,
    'user': ModelType.user,
    'organizations': ModelType.organization,
    'organization': ModelType.organization,
    'sites': ModelType.site,
    'site': ModelType.site,
    'zones': ModelType.zone,
    'zone': ModelType.zone,
    'subplots': ModelType.subplot,
    'subplot': ModelType.subplot,
    'groups': ModelType.group,
    'group': ModelType.group,
    'structures': ModelType.group,
    'structure': ModelType.group,
    'cohorts': ModelType.cohort,
    'cohort': ModelType.cohort,
    'holdings': ModelType.holding,
    'holding': ModelType.holding,
    'genets': ModelType.genet,
    'genet': ModelType.genet,
    'recordtypes': ModelType.recordType,
    'recordtype': ModelType.recordType,
    'events': ModelType.event,
    'event': ModelType.event,
    'invitations': ModelType.invitation,
    'invitation': ModelType.invitation,
    'organism_records': ModelType.organismRecord,
    'organismRecords': ModelType.organismRecord,
    'organismrecord': ModelType.organismRecord,
    'brand_profiles': ModelType.brandProfile,
    'brand_profile': ModelType.brandProfile,
    'permits': ModelType.permit,
    'permit': ModelType.permit,
    'deliverables': ModelType.deliverable,
    'deliverable': ModelType.deliverable,
  };

  static ModelType fromPath(String path) {
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    ModelType? fallback;
    for (final segment in segments.reversed) {
      final hint = _segmentHints[segment.toLowerCase()];
      if (hint != null) {
        if (hint != ModelType.event && hint != ModelType.unknown) {
          return hint;
        }
        fallback ??= hint;
      }
    }
    final lastSegment = segments.isNotEmpty ? segments.last : path;
    return fallback ?? fromSlug(lastSegment);
  }

  static ModelType fromSlug(String slug) {
    // Extract the model type name by removing trailing digits from the slug
    final modelTypeName = slug.replaceFirst(RegExp(r'\d+$'), '');
    try {
      return ModelType.values.byName(modelTypeName);
    } catch (_) {
      return ModelType.unknown;
    }
  }
}
