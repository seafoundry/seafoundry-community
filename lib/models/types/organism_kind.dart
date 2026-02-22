// @tier: community
/// Defines the organisms SeaFoundry is targeting as part of the multi-organism
/// roadmap. Metadata is sourced from
/// `docs/taxonomy/README.md` (lifecycles, canonical
/// CSV fields, and preferred measurement units).
enum OrganismKind {
  coral,
  oyster,
  seagrass,
  kelp,
  mangrove,
  echinoid,
  crab,
  finfish,
  seaCucumber,
}

/// Per-organism metadata that helps repositories, dialogs, and CSV pipelines
/// pick sensible defaults while SeaFoundry transitions away from coral-only
/// assumptions.
class OrganismKindMetadata {
  const OrganismKindMetadata({
    required this.displayName,
    required this.pluralDisplayName,
    required this.defaultMeasurementUnit,
    required this.lifeStages,
    required this.supportedStructureTypes,
    required this.defaultSiteTypes,
  });

  final String displayName;
  final String pluralDisplayName; // Proper plural form (handles uncountable nouns)
  final String defaultMeasurementUnit;
  final List<String> lifeStages;
  final List<String> supportedStructureTypes;
  final List<String> defaultSiteTypes;
}

extension OrganismKindX on OrganismKind {
  OrganismKindMetadata get metadata => _metadata[this]!;

  static OrganismKind? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final kind in OrganismKind.values) {
      if (kind.name.toLowerCase() == normalized) {
        return kind;
      }
    }
    return null;
  }

  static const Map<OrganismKind, OrganismKindMetadata> _metadata = {
    OrganismKind.coral: OrganismKindMetadata(
      displayName: 'Coral',
      pluralDisplayName: 'corals',
      defaultMeasurementUnit: 'count',
      lifeStages: [
        'gamete',
        'larvae',
        'recruit',
        'juvenile',
        'colony',
        'fragment',
      ],
      supportedStructureTypes: ['tank', 'tray', 'tree', 'grid', 'tag'],
      defaultSiteTypes: [
        'site_type_nursery_ex_situ',
        'site_type_nursery_in_situ',
        'site_type_outplanting',
      ],
    ),
    OrganismKind.oyster: OrganismKindMetadata(
      displayName: 'Oyster',
      pluralDisplayName: 'oysters',
      defaultMeasurementUnit: 'count',
      lifeStages: ['larvae', 'spat', 'growOut', 'reef'],
      supportedStructureTypes: ['reefPatch', 'bag', 'rack', 'cage'],
      defaultSiteTypes: ['site_type_reef_aquaculture', 'site_type_outplanting'],
    ),
    OrganismKind.seagrass: OrganismKindMetadata(
      displayName: 'Seagrass',
      pluralDisplayName: 'seagrass', // Uncountable noun
      defaultMeasurementUnit: 'shoots_per_m2',
      lifeStages: ['seed', 'shoot', 'plot'],
      supportedStructureTypes: ['plot', 'grid', 'quadrat', 'transect'],
      defaultSiteTypes: ['site_type_seagrass_plot', 'site_type_outplanting'],
    ),
    OrganismKind.kelp: OrganismKindMetadata(
      displayName: 'Kelp',
      pluralDisplayName: 'kelp', // Uncountable noun
      defaultMeasurementUnit: 'kg_per_m',
      lifeStages: ['spore', 'seededTwine', 'longline', 'harvest'],
      supportedStructureTypes: ['longline', 'raft', 'dropperLine'],
      defaultSiteTypes: ['site_type_kelp_farm'],
    ),
    OrganismKind.mangrove: OrganismKindMetadata(
      displayName: 'Mangrove',
      pluralDisplayName: 'mangroves',
      defaultMeasurementUnit: 'count',
      lifeStages: ['propagule', 'nursery', 'sapling', 'adult'],
      supportedStructureTypes: ['plot', 'beltTransect'],
      defaultSiteTypes: ['site_type_mangrove_outplant'],
    ),
    OrganismKind.echinoid: OrganismKindMetadata(
      displayName: 'Urchin',
      pluralDisplayName: 'urchins',
      defaultMeasurementUnit: 'count',
      lifeStages: ['broodstock', 'larvae', 'juvenile', 'adult'],
      supportedStructureTypes: ['tank', 'pen', 'plot'],
      defaultSiteTypes: ['site_type_nursery_ex_situ', 'site_type_grow_out_pond'],
    ),
    OrganismKind.crab: OrganismKindMetadata(
      displayName: 'Crab',
      pluralDisplayName: 'crabs',
      defaultMeasurementUnit: 'count',
      lifeStages: [
        'broodstock',
        'larvae',
        'zoea',
        'megalopa',
        'juvenile',
        'adult',
      ],
      supportedStructureTypes: ['tank', 'pond', 'pen'],
      defaultSiteTypes: ['site_type_nursery_ex_situ', 'site_type_grow_out_pond'],
    ),
    OrganismKind.finfish: OrganismKindMetadata(
      displayName: 'Finfish',
      pluralDisplayName: 'finfish', // Collective noun (same as singular)
      defaultMeasurementUnit: 'count',
      lifeStages: ['egg', 'larvae', 'fry', 'fingerling', 'juvenile', 'adult'],
      supportedStructureTypes: ['raceway', 'tank', 'pen'],
      defaultSiteTypes: ['site_type_raceway', 'site_type_release'],
    ),
    OrganismKind.seaCucumber: OrganismKindMetadata(
      displayName: 'Sea Cucumber',
      pluralDisplayName: 'sea cucumbers',
      defaultMeasurementUnit: 'count',
      lifeStages: ['broodstock', 'larvae', 'juvenile', 'adult'],
      supportedStructureTypes: ['tank', 'plot'],
      defaultSiteTypes: ['site_type_nursery_ex_situ', 'site_type_outplanting'],
    ),
  };
}
