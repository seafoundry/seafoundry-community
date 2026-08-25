/**
 * Canonical Species Registry
 *
 * Single source of truth for species code-to-ID mappings used across all
 * crosswalk and import scripts. Each entry contains the CRC database numeric
 * ID, the 4-letter species code, the canonical Firestore document ID (short format),
 * taxonomy fields, and an optional common name.
 *
 * IMPORTANT: Species IDs use the canonical short format (e.g., 'acer', 'apal')
 * that matches the taxonomy_species collection. Legacy IDs are preserved in
 * the legacyId field for backward compatibility with historical data.
 *
 * Consumers import the derived lookup that fits their access pattern:
 *   - SPECIES_BY_CRC_ID   keyed by CRC DB numeric ID ('1', '2', ...)
 *   - SPECIES_BY_CODE     keyed by 4-letter code ('APAL', 'ACER', ...)
 *   - SPECIES_LIST         ordered array (for iteration / PID generation)
 */

// ============================================================================
// Canonical Registry (ordered by CRC DB ID)
// ============================================================================

const SPECIES_REGISTRY = [
  {
    crcId: '1',
    code: 'ACER',
    id: 'acer',
    legacyId: 'species_acropora_cervicornis',
    name: 'Acropora cervicornis',
    genus: 'Acropora',
    species: 'cervicornis',
    commonName: 'Staghorn Coral',
  },
  {
    crcId: '2',
    code: 'APAL',
    id: 'apal',
    legacyId: 'species_acropora_palmata',
    name: 'Acropora palmata',
    genus: 'Acropora',
    species: 'palmata',
    commonName: 'Elkhorn Coral',
  },
  {
    crcId: '3',
    code: 'OFRA',
    id: 'ofra',
    legacyId: 'species_orbicella_franksi',
    name: 'Orbicella franksi',
    genus: 'Orbicella',
    species: 'franksi',
    commonName: 'Boulder Star Coral',
  },
  {
    crcId: '4',
    code: 'OFAV',
    id: 'ofav',
    legacyId: 'species_orbicella_faveolata',
    name: 'Orbicella faveolata',
    genus: 'Orbicella',
    species: 'faveolata',
    commonName: 'Mountainous Star Coral',
  },
  {
    crcId: '5',
    code: 'OANN',
    id: 'oann',
    legacyId: 'species_orbicella_annularis',
    name: 'Orbicella annularis',
    genus: 'Orbicella',
    species: 'annularis',
    commonName: 'Boulder Star Coral',
  },
  {
    crcId: '6',
    code: 'MYFE',
    id: 'myfe',
    legacyId: 'species_mycetophyllia_ferox',
    name: 'Mycetophyllia ferox',
    genus: 'Mycetophyllia',
    species: 'ferox',
    commonName: 'Rough Cactus Coral',
  },
  {
    crcId: '7',
    code: 'DCYL',
    id: 'dcyl',
    legacyId: 'species_dendrogyra_cylindrus',
    name: 'Dendrogyra cylindrus',
    genus: 'Dendrogyra',
    species: 'cylindrus',
    commonName: 'Pillar Coral',
  },
  {
    crcId: '8',
    code: 'APRO',
    id: 'apro',
    legacyId: 'species_acropora_prolifera',
    name: 'Acropora prolifera',
    genus: 'Acropora',
    species: 'prolifera',
    commonName: 'Fused Staghorn',
  },
];

// ============================================================================
// Derived Lookups
// ============================================================================

/** Keyed by CRC database numeric ID (string). Used by build-species-crosswalk.js. */
const SPECIES_BY_CRC_ID = Object.fromEntries(
  SPECIES_REGISTRY.map(s => [s.crcId, s]),
);

/** Keyed by 4-letter species code. Used by import scripts. */
const SPECIES_BY_CODE = Object.fromEntries(
  SPECIES_REGISTRY.map(s => [s.code, s]),
);

/** Keyed by legacy ID for backward compatibility. */
const SPECIES_BY_LEGACY_ID = Object.fromEntries(
  SPECIES_REGISTRY.map(s => [s.legacyId, s]),
);

/** Ordered array. Used by generate-pid-crosswalk.js. */
const SPECIES_LIST = SPECIES_REGISTRY;

// ============================================================================
// Exports
// ============================================================================

module.exports = {
  SPECIES_REGISTRY,
  SPECIES_BY_CRC_ID,
  SPECIES_BY_CODE,
  SPECIES_BY_LEGACY_ID,
  SPECIES_LIST,
};
