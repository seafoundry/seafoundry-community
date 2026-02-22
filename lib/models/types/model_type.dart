// @tier: community
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
  reproductiveEvent(collectionPath: 'reproductive_events'),
  recordType(collectionPath: 'recordTypes'),
  event(collectionPath: 'events'),
  invitation(collectionPath: 'invitations'),
  organismRecord(collectionPath: 'organismRecords'),
  // Visual Engagement (Community Tier) public read models
  brandProfile(collectionPath: 'brand_profiles'),
  mediaAsset(collectionPath: 'media_assets'),
  publicPlaylist(collectionPath: 'public_playlists'),
  publicDigest(collectionPath: 'public_digests'),
  publicImpactPoint(collectionPath: 'public_impact_points'),
  visualKpiSnapshot(collectionPath: 'visual_kpi_snapshots'),
  environmentalEvent(collectionPath: 'environmental_events'),
  monitoringSchedule(collectionPath: 'monitoring_schedules'),
  mission(collectionPath: 'missions'),
  vessel(collectionPath: 'vessels'),
  permit(collectionPath: 'permits'),
  deliverable(collectionPath: 'deliverables'),
  post(collectionPath: 'posts'),
  funder(collectionPath: 'funders'),
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
      case ModelType.reproductiveEvent:
        return 'reproductive event';
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
      case ModelType.mediaAsset:
        return 'media asset';
      case ModelType.publicPlaylist:
        return 'public playlist';
      case ModelType.publicDigest:
        return 'public digest';
      case ModelType.publicImpactPoint:
        return 'public impact point';
      case ModelType.visualKpiSnapshot:
        return 'visual kpi snapshot';
      case ModelType.environmentalEvent:
        return 'environmental event';
      case ModelType.monitoringSchedule:
        return 'monitoring schedule';
      case ModelType.mission:
        return 'mission';
      case ModelType.vessel:
        return 'vessel';
      case ModelType.permit:
        return 'permit';
      case ModelType.deliverable:
        return 'deliverable';
      case ModelType.post:
        return 'post';
      case ModelType.funder:
        return 'funder';
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
    'reproductive_events': ModelType.reproductiveEvent,
    'reproductive_event': ModelType.reproductiveEvent,
    'recordtypes': ModelType.recordType,
    'recordtype': ModelType.recordType,
    'events': ModelType.event,
    'event': ModelType.event,
    'invitations': ModelType.invitation,
    'invitation': ModelType.invitation,
    'organism_records': ModelType.organismRecord,
    'organismRecords': ModelType.organismRecord,
    'organismrecord': ModelType.organismRecord,
    // Visual Engagement public read model hints
    'brand_profiles': ModelType.brandProfile,
    'brand_profile': ModelType.brandProfile,
    'media_assets': ModelType.mediaAsset,
    'media_asset': ModelType.mediaAsset,
    'public_playlists': ModelType.publicPlaylist,
    'public_playlist': ModelType.publicPlaylist,
    'public_digests': ModelType.publicDigest,
    'public_digest': ModelType.publicDigest,
    'public_impact_points': ModelType.publicImpactPoint,
    'public_impact_point': ModelType.publicImpactPoint,
    'visual_kpi_snapshots': ModelType.visualKpiSnapshot,
    'visual_kpi_snapshot': ModelType.visualKpiSnapshot,
    'environmental_events': ModelType.environmentalEvent,
    'environmental_event': ModelType.environmentalEvent,
    'monitoring_schedules': ModelType.monitoringSchedule,
    'monitoring_schedule': ModelType.monitoringSchedule,
    'missions': ModelType.mission,
    'mission': ModelType.mission,
    'vessels': ModelType.vessel,
    'vessel': ModelType.vessel,
    'permits': ModelType.permit,
    'permit': ModelType.permit,
    'deliverables': ModelType.deliverable,
    'deliverable': ModelType.deliverable,
    'posts': ModelType.post,
    'post': ModelType.post,
    'funders': ModelType.funder,
    'funder': ModelType.funder,
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
