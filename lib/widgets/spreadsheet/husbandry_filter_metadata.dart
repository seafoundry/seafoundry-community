// @tier: community
class HusbandryFilterMetadata {
  const HusbandryFilterMetadata({
    required this.siteNames,
    required this.structurePaths,
    required this.speciesIds,
    required this.genetIds,
    this.lifeStageIds = const {},
    this.provenanceTypes = const {},
    this.issueTypeIds = const {},
  });

  final Map<String, String> siteNames;
  final Set<String> structurePaths;
  final Set<String> speciesIds;
  final Set<String> genetIds;
  final Set<String> lifeStageIds;
  final Set<String> provenanceTypes;
  final Set<String> issueTypeIds;
}
