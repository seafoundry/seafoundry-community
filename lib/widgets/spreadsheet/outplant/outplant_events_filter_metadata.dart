// @tier: community
class OutplantEventsFilterMetadata {
  const OutplantEventsFilterMetadata({
    required this.siteNames,
    required this.structurePaths,
    required this.speciesIds,
    required this.speciesLabels,
    required this.genetIds,
    required this.genetLabels,
    this.lifeStageIds = const {},
    this.provenanceTypes = const {},
  });

  final Map<String, String> siteNames;
  final Set<String> structurePaths;
  final Set<String> speciesIds;
  final Map<String, String> speciesLabels;
  final Set<String> genetIds;
  final Map<String, String> genetLabels;
  final Set<String> lifeStageIds;
  final Set<String> provenanceTypes;
}
