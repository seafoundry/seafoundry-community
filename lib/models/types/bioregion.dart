// @tier: community
/// Geographic bioregions that drive species and organism availability.
///
/// Organizations select one or more bioregions during onboarding; the union
/// of organism kinds across selected bioregions determines which
/// [OrganismKind] values are available.
enum Bioregion {
  caribbean('caribbean'),
  gulfOfMexico('gulfOfMexico'),
  usAtlanticTemperate('usAtlanticTemperate'),
  usPacificTemperate('usPacificTemperate'),
  hawaiianPacificIslands('hawaiianPacificIslands'),
  indoPacific('indoPacific'),
  mediterranean('mediterranean'),
  redSea('redSea'),
  eastAsian('eastAsian'),
  southeastAsian('southeastAsian'),
  oceania('oceania'),
  eastAfrican('eastAfrican'),
  westAfrican('westAfrican'),
  southAmericanAtlantic('southAmericanAtlantic'),
  southAmericanPacific('southAmericanPacific'),
  northernEuropean('northernEuropean'),
  arcticSubArctic('arcticSubArctic');

  const Bioregion(this.id);
  final String id;

  static Bioregion fromId(String value) {
    final normalized = value.trim().toLowerCase();
    for (final region in Bioregion.values) {
      if (region.id.toLowerCase() == normalized) return region;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown Bioregion. Expected one of: '
          '${Bioregion.values.map((r) => r.id).join(', ')}',
    );
  }
}

extension BioregionX on Bioregion {
  String get displayName => _metadata[this]!.displayName;
  String get description => _metadata[this]!.description;

  static Bioregion? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final region in Bioregion.values) {
      if (region.id.toLowerCase() == normalized) return region;
    }
    return null;
  }

  /// Returns bioregions ordered for selection UIs:
  /// 1) key tropical regions first, 2) remaining regions alphabetically.
  static List<Bioregion> orderedForSelection() {
    const priority = <Bioregion>[
      Bioregion.caribbean,
      Bioregion.indoPacific,
      Bioregion.redSea,
      Bioregion.oceania,
    ];
    final ordered = <Bioregion>[...priority];
    final remaining =
        Bioregion.values.where((region) => !priority.contains(region)).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    ordered.addAll(remaining);
    return List<Bioregion>.unmodifiable(ordered);
  }

  static const Map<Bioregion, _BioregionMeta> _metadata = {
    Bioregion.caribbean: _BioregionMeta(
      displayName: 'Caribbean',
      description: 'Florida, Bahamas, USVI, Puerto Rico, wider Caribbean',
    ),
    Bioregion.gulfOfMexico: _BioregionMeta(
      displayName: 'Gulf of Mexico',
      description: 'US Gulf Coast, Mexico, Cuba',
    ),
    Bioregion.usAtlanticTemperate: _BioregionMeta(
      displayName: 'US Atlantic (Temperate)',
      description: 'Mid-Atlantic and New England coasts',
    ),
    Bioregion.usPacificTemperate: _BioregionMeta(
      displayName: 'US Pacific (Temperate)',
      description: 'California, Oregon, Washington',
    ),
    Bioregion.hawaiianPacificIslands: _BioregionMeta(
      displayName: 'Hawaiian & Pacific Islands',
      description: 'Hawaii, Micronesia, Palau, Marshall Islands',
    ),
    Bioregion.indoPacific: _BioregionMeta(
      displayName: 'Indo-Pacific',
      description: 'Indian Ocean, western and central Pacific tropics',
    ),
    Bioregion.mediterranean: _BioregionMeta(
      displayName: 'Mediterranean',
      description: 'Mediterranean Sea and Black Sea coasts',
    ),
    Bioregion.redSea: _BioregionMeta(
      displayName: 'Red Sea & Arabian Gulf',
      description: 'Red Sea, Gulf of Aden, Arabian/Persian Gulf',
    ),
    Bioregion.eastAsian: _BioregionMeta(
      displayName: 'East Asian',
      description: 'Japan, Korea, China coastlines',
    ),
    Bioregion.southeastAsian: _BioregionMeta(
      displayName: 'Southeast Asian',
      description: 'Coral Triangle, Philippines, Indonesia, Malaysia',
    ),
    Bioregion.oceania: _BioregionMeta(
      displayName: 'Oceania',
      description: 'Australia (GBR, temperate), New Zealand, Pacific Islands',
    ),
    Bioregion.eastAfrican: _BioregionMeta(
      displayName: 'East African',
      description: 'Kenya, Tanzania, Mozambique, Madagascar',
    ),
    Bioregion.westAfrican: _BioregionMeta(
      displayName: 'West African',
      description: 'Senegal to Angola coastlines',
    ),
    Bioregion.southAmericanAtlantic: _BioregionMeta(
      displayName: 'South American Atlantic',
      description: 'Brazil, Argentina, Uruguay coasts',
    ),
    Bioregion.southAmericanPacific: _BioregionMeta(
      displayName: 'South American Pacific',
      description: 'Chile, Peru, Ecuador coasts',
    ),
    Bioregion.northernEuropean: _BioregionMeta(
      displayName: 'Northern European',
      description: 'UK, Scandinavia, North Sea, Baltic',
    ),
    Bioregion.arcticSubArctic: _BioregionMeta(
      displayName: 'Arctic & Sub-Arctic',
      description: 'Arctic Ocean, Barents Sea, Bering Sea',
    ),
  };
}

class _BioregionMeta {
  const _BioregionMeta({required this.displayName, required this.description});
  final String displayName;
  final String description;
}
