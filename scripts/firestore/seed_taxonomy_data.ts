#!/usr/bin/env ts-node

/**
 * Seeds canonical taxonomy documents (species + provenance) into Firestore so
 * CSV v2 import/export and taxonomy-aware dialogs have real data to exercise.
 *
 * Usage:
 *   # Uses GOOGLE_APPLICATION_CREDENTIALS or application default credentials
 *   npx ts-node scripts/firestore/seed_taxonomy_data.ts
 *
 *   # Dry run (prints payloads without writing)
 *   npx ts-node scripts/firestore/seed_taxonomy_data.ts --dry-run
 *
 *   # Explicit service account
 *   FIREBASE_SERVICE_ACCOUNT=./service-account.json \
 *     npx ts-node scripts/firestore/seed_taxonomy_data.ts
 *
 * When FIRESTORE_EMULATOR_HOST is set the script writes to the emulator.
 */

import { applicationDefault, cert, initializeApp } from 'firebase-admin/app';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import fs from 'node:fs';
import path from 'node:path';

type OrganismKindLiteral =
  | 'coral'
  | 'oyster'
  | 'seagrass'
  | 'kelp'
  | 'mangrove'
  | 'echinoid'
  | 'crab'
  | 'finfish'
  | 'seaCucumber';

const ORGANISM_KIND_VALUES: OrganismKindLiteral[] = [
  'coral',
  'oyster',
  'seagrass',
  'kelp',
  'mangrove',
  'echinoid',
  'crab',
  'finfish',
  'seaCucumber',
];

type PropagationModeLiteral =
  | 'asexualFragmentation'
  | 'vegetativeCutting'
  | 'larvalSettlement'
  | 'sexualSpawning'
  | 'hatcheryBreeding'
  | 'clonalExpansion';

type CoralMorphologyLiteral =
  | 'branching'
  | 'plating'
  | 'massive'
  | 'columnar'
  | 'digitate'
  | 'foliose';

interface SpeciesSeed {
  id: string;
  organismKind: OrganismKindLiteral;
  genus: string;
  species: string;
  code: string;
  commonNames?: string[];
  aliases?: string[];
  morphology?: CoralMorphologyLiteral;
  tags?: string[];
  classification?: {
    kingdom?: string;
    phylum?: string;
    class?: string;
    order?: string;
    family?: string;
  };
  propagationModes?: PropagationModeLiteral[];
  /** URL to full-size species reference image in shared Cloud Storage. */
  imageUrl?: string;
  /** URL to thumbnail species image for lists/dropdowns. */
  thumbnailUrl?: string;
  metadata?: Record<string, unknown>;
}

interface ProvenanceSeed {
  id: string;
  organismKind: OrganismKindLiteral;
  provenanceKind: 'genet' | 'broodstock' | 'donorMeadow' | 'hatcheryLot' | 'cohort';
  displayName: string;
  speciesId: string;
  parentProvenanceId?: string;
  siteId?: string;
  aliasLabels?: string[];
  metadata?: Record<string, unknown>;
}

const speciesSeeds: SpeciesSeed[] = [
  // ====== NON-CORAL SPECIES (one per organism kind) ======
  {
    id: 'sala',
    organismKind: 'kelp',
    genus: 'Saccharina',
    species: 'latissima',
    code: 'SALA',
    commonNames: ['Sugar kelp', 'Sea belt'],
    aliases: ['species_saccharina_latissima'],
    classification: {
      kingdom: 'Chromista',
      phylum: 'Ochrophyta',
      class: 'Phaeophyceae',
      order: 'Laminariales',
      family: 'Saccharinaceae',
    },
    propagationModes: ['vegetativeCutting', 'sexualSpawning'],
    metadata: {
      nativeRange: 'North Atlantic',
      preferredTemperatureC: '4-15',
      defaultMeasurementUnit: 'kg_per_m',
    },
  },
  {
    id: 'crvi',
    organismKind: 'oyster',
    genus: 'Crassostrea',
    species: 'virginica',
    code: 'CRVI',
    commonNames: ['Eastern oyster', 'American oyster'],
    aliases: ['species_crassostrea_virginica'],
    classification: {
      kingdom: 'Animalia',
      phylum: 'Mollusca',
      class: 'Bivalvia',
      order: 'Ostreoida',
      family: 'Ostreidae',
    },
    propagationModes: ['hatcheryBreeding', 'larvalSettlement'],
    metadata: {
      habitat: 'Estuarine',
      regulatoryBody: 'NSSP',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'thte',
    organismKind: 'seagrass',
    genus: 'Thalassia',
    species: 'testudinum',
    code: 'THTE',
    commonNames: ['Turtle grass'],
    aliases: ['species_thalassia_testudinum'],
    classification: {
      kingdom: 'Plantae',
      phylum: 'Tracheophyta',
      class: 'Liliopsida',
      order: 'Alismatales',
      family: 'Hydrocharitaceae',
    },
    propagationModes: ['clonalExpansion', 'sexualSpawning'],
    metadata: {
      habitat: 'Shallow coastal lagoons',
      defaultMeasurementUnit: 'm2',
    },
  },
  {
    id: 'casa',
    organismKind: 'crab',
    genus: 'Callinectes',
    species: 'sapidus',
    code: 'CASA',
    commonNames: ['Blue Crab'],
    aliases: ['species_callinectes_sapidus'],
    propagationModes: ['hatcheryBreeding', 'larvalSettlement'],
    metadata: {
      habitat: 'Estuarine',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'onmy',
    organismKind: 'finfish',
    genus: 'Oncorhynchus',
    species: 'mykiss',
    code: 'ONMY',
    commonNames: ['Rainbow trout'],
    aliases: ['species_oncorhynchus_mykiss'],
    propagationModes: ['hatcheryBreeding'],
    metadata: {
      habitat: 'Cold freshwater',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'mefr',
    organismKind: 'echinoid',
    genus: 'Mesocentrotus',
    species: 'franciscanus',
    code: 'MEFR',
    commonNames: ['Red sea urchin'],
    aliases: ['species_mesocentrotus_franciscanus'],
    propagationModes: ['sexualSpawning'],
    metadata: {
      habitat: 'Kelp forests',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'rhma',
    organismKind: 'mangrove',
    genus: 'Rhizophora',
    species: 'mangle',
    code: 'RHMA',
    commonNames: ['Red mangrove'],
    aliases: ['species_rhizophora_mangle'],
    classification: {
      kingdom: 'Plantae',
      phylum: 'Tracheophyta',
      class: 'Magnoliopsida',
      order: 'Malpighiales',
      family: 'Rhizophoraceae',
    },
    propagationModes: ['vegetativeCutting', 'sexualSpawning'],
    metadata: {
      habitat: 'Tropical tidal zones',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'hosc',
    organismKind: 'seaCucumber',
    genus: 'Holothuria',
    species: 'scabra',
    code: 'HOSC',
    commonNames: ['Sandfish sea cucumber'],
    aliases: ['species_holothuria_scabra'],
    classification: {
      kingdom: 'Animalia',
      phylum: 'Echinodermata',
      class: 'Holothuroidea',
      order: 'Aspidochirotida',
      family: 'Holothuriidae',
    },
    propagationModes: ['sexualSpawning'],
    metadata: {
      habitat: 'Shallow seagrass beds',
      defaultMeasurementUnit: 'count',
    },
  },
  // ====== COMPREHENSIVE CORAL SPECIES FOR RESTORATION ======
  // Acropora species (ESA-listed, high restoration priority)
  {
    id: 'apal',
    organismKind: 'coral',
    genus: 'Acropora',
    species: 'palmata',
    code: 'APAL',
    commonNames: ['Elkhorn coral'],
    aliases: ['species_acropora_palmata'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: {
      nativeRange: 'Caribbean',
      growthForm: 'branching',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'acer',
    organismKind: 'coral',
    genus: 'Acropora',
    species: 'cervicornis',
    code: 'ACER',
    commonNames: ['Staghorn coral'],
    aliases: ['species_acropora_cervicornis'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: {
      nativeRange: 'Caribbean',
      growthForm: 'branching',
      defaultMeasurementUnit: 'count',
    },
  },
  {
    id: 'apro',
    organismKind: 'coral',
    genus: 'Acropora',
    species: 'prolifera',
    code: 'APRO',
    commonNames: ['Fused staghorn coral'],
    propagationModes: ['asexualFragmentation'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  // Orbicella species (ESA-listed, high restoration priority)
  {
    id: 'oann',
    organismKind: 'coral',
    genus: 'Orbicella',
    species: 'annularis',
    code: 'OANN',
    commonNames: ['Boulder star coral', 'Lobed star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'ofav',
    organismKind: 'coral',
    genus: 'Orbicella',
    species: 'faveolata',
    code: 'OFAV',
    commonNames: ['Mountainous star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'ofra',
    organismKind: 'coral',
    genus: 'Orbicella',
    species: 'franksi',
    code: 'OFRA',
    commonNames: ['Boulder star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Dendrogyra (ESA-listed, critically endangered)
  {
    id: 'dcyl',
    organismKind: 'coral',
    genus: 'Dendrogyra',
    species: 'cylindrus',
    code: 'DCYL',
    commonNames: ['Pillar coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'columnar' },
  },
  // Diploria/Pseudodiploria (brain corals)
  {
    id: 'dlab',
    organismKind: 'coral',
    genus: 'Diploria',
    species: 'labyrinthiformis',
    code: 'DLAB',
    commonNames: ['Grooved brain coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'pcli',
    organismKind: 'coral',
    genus: 'Pseudodiploria',
    species: 'clivosa',
    code: 'PCLI',
    commonNames: ['Knobby brain coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'pstr',
    organismKind: 'coral',
    genus: 'Pseudodiploria',
    species: 'strigosa',
    code: 'PSTR',
    commonNames: ['Symmetrical brain coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Colpophyllia
  {
    id: 'cnat',
    organismKind: 'coral',
    genus: 'Colpophyllia',
    species: 'natans',
    code: 'CNAT',
    commonNames: ['Boulder brain coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Montastraea
  {
    id: 'mcav',
    organismKind: 'coral',
    genus: 'Montastraea',
    species: 'cavernosa',
    code: 'MCAV',
    commonNames: ['Great star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Siderastrea
  {
    id: 'ssid',
    organismKind: 'coral',
    genus: 'Siderastrea',
    species: 'siderea',
    code: 'SSID',
    commonNames: ['Massive starlet coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Porites species
  {
    id: 'ppor',
    organismKind: 'coral',
    genus: 'Porites',
    species: 'porites',
    code: 'PPOR',
    commonNames: ['Finger coral', 'Jeweled finger coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  {
    id: 'past',
    organismKind: 'coral',
    genus: 'Porites',
    species: 'astreoides',
    code: 'PAST',
    commonNames: ['Mustard hill coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'pdiv',
    organismKind: 'coral',
    genus: 'Porites',
    species: 'divaricata',
    code: 'PDIV',
    commonNames: ['Thin finger coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  {
    id: 'pfur',
    organismKind: 'coral',
    genus: 'Porites',
    species: 'furcata',
    code: 'PFUR',
    commonNames: ['Branched finger coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  // Dichocoenia
  {
    id: 'dsto',
    organismKind: 'coral',
    genus: 'Dichocoenia',
    species: 'stokesii',
    code: 'DSTO',
    commonNames: ['Elliptical star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Meandrina
  {
    id: 'mmea',
    organismKind: 'coral',
    genus: 'Meandrina',
    species: 'meandrites',
    code: 'MMEA',
    commonNames: ['Maze coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Agaricia species
  {
    id: 'aaga',
    organismKind: 'coral',
    genus: 'Agaricia',
    species: 'agaricites',
    code: 'AAGA',
    commonNames: ['Lettuce coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'plating' },
  },
  {
    id: 'alam',
    organismKind: 'coral',
    genus: 'Agaricia',
    species: 'lamarcki',
    code: 'ALAM',
    commonNames: ["Lamarck's sheet coral"],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'plating' },
  },
  {
    id: 'aten',
    organismKind: 'coral',
    genus: 'Agaricia',
    species: 'tenuifolia',
    code: 'ATEN',
    commonNames: ['Thin leaf lettuce coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'plating' },
  },
  // Eusmilia
  {
    id: 'efas',
    organismKind: 'coral',
    genus: 'Eusmilia',
    species: 'fastigiata',
    code: 'EFAS',
    commonNames: ['Smooth flower coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  // Mycetophyllia species
  {
    id: 'myla',
    organismKind: 'coral',
    genus: 'Mycetophyllia',
    species: 'lamarckiana',
    code: 'MYLA',
    commonNames: ['Ridged cactus coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'plating' },
  },
  {
    id: 'myfe',
    organismKind: 'coral',
    genus: 'Mycetophyllia',
    species: 'ferox',
    code: 'MYFE',
    commonNames: ['Rough cactus coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'plating' },
  },
  // Madracis species
  {
    id: 'maur',
    organismKind: 'coral',
    genus: 'Madracis',
    species: 'auretenra',
    code: 'MAUR',
    commonNames: ['Yellow pencil coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'branching' },
  },
  {
    id: 'mdec',
    organismKind: 'coral',
    genus: 'Madracis',
    species: 'decactis',
    code: 'MDEC',
    commonNames: ['Ten-ray star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Solenastrea species
  {
    id: 'sbou',
    organismKind: 'coral',
    genus: 'Solenastrea',
    species: 'bournoni',
    code: 'SBOU',
    commonNames: ['Smooth star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  {
    id: 'shy',
    organismKind: 'coral',
    genus: 'Solenastrea',
    species: 'hyades',
    code: 'SHYA',
    commonNames: ['Knobby star coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Favia
  {
    id: 'ffra',
    organismKind: 'coral',
    genus: 'Favia',
    species: 'fragum',
    code: 'FFRA',
    commonNames: ['Golfball coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Isophyllia
  {
    id: 'isin',
    organismKind: 'coral',
    genus: 'Isophyllia',
    species: 'sinuosa',
    code: 'ISIN',
    commonNames: ['Sinuous cactus coral'],
    propagationModes: ['asexualFragmentation', 'sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'massive' },
  },
  // Scolymia
  {
    id: 'scub',
    organismKind: 'coral',
    genus: 'Scolymia',
    species: 'cubensis',
    code: 'SCUB',
    commonNames: ['Artichoke coral'],
    propagationModes: ['sexualSpawning'],
    metadata: { nativeRange: 'Caribbean', growthForm: 'solitary' },
  },
];

const coralMorphologyOverrides: Record<string, CoralMorphologyLiteral> = {
};

const coralMorphologyDefaults: Record<string, CoralMorphologyLiteral> = {
  acropora: 'branching',
  agaricia: 'foliose',
  colpophyllia: 'massive',
  dendrogyra: 'columnar',
  dichocoenia: 'massive',
  diploria: 'massive',
  eusmilia: 'branching',
  favia: 'massive',
  isophyllia: 'massive',
  madracis: 'branching',
  meandrina: 'massive',
  montastraea: 'massive',
  mycetophyllia: 'foliose',
  orbicella: 'massive',
  porites: 'digitate',
  pseudodiploria: 'massive',
  scolymia: 'massive',
  siderastrea: 'massive',
  solenastrea: 'massive',
};

const eslListedSpeciesIds = new Set<string>([
  'acer',
  'apal',
  'dcyl',
  'myfe',
  'oann',
  'ofav',
  'ofra',
]);

function resolveCoralMorphology(
  genus: string,
  species: string,
): CoralMorphologyLiteral | undefined {
  const normalizedGenus = genus.trim().toLowerCase();
  const normalizedSpecies = species.trim().toLowerCase();
  if (!normalizedGenus || !normalizedSpecies) {
    return undefined;
  }
  const speciesKey = `${normalizedGenus} ${normalizedSpecies}`;
  return coralMorphologyOverrides[speciesKey] ?? coralMorphologyDefaults[normalizedGenus];
}

const provenanceSeeds: ProvenanceSeed[] = [
  {
    id: 'kelp_broodstock_cb_2024',
    organismKind: 'kelp',
    provenanceKind: 'broodstock',
    displayName: 'Casco Bay Broodstock 2024',
    speciesId: 'sala',
    aliasLabels: ['CB-BS-24'],
    metadata: {
      partnerOrg: 'Gulf of Maine Kelp Co-op',
      collectionDate: '2024-03-15',
      notes: 'Broodstock collected before spring sporulation window.',
    },
  },
  {
    id: 'GENET-AP-001',
    organismKind: 'coral',
    provenanceKind: 'genet',
    displayName: 'Founder Genet AP-001',
    speciesId: 'apal',
    metadata: {
      provenanceId: 'GENET-AP-001',
      collectionSite: 'Lower Keys Ex-situ Nursery',
      permitId: 'FKNMS-2025-OP-112',
    },
  },
  {
    id: 'GENET-AC-014',
    organismKind: 'coral',
    provenanceKind: 'genet',
    displayName: 'Cervicornis Cohort Parent 014',
    speciesId: 'acer',
    metadata: {
      provenanceId: 'GENET-AC-014',
      collectionSite: 'Upper Keys Hatchery',
      permitId: 'FKNMS-2025-OP-112',
    },
  },
  {
    id: 'oyster_hatchery_batr_2024',
    organismKind: 'oyster',
    provenanceKind: 'hatcheryLot',
    displayName: 'Bay Atlantic Triploid Lot 2024-A',
    speciesId: 'crvi',
    aliasLabels: ['BATR-24A'],
    metadata: {
      hatchery: 'Bay Atlantic',
      triploid: true,
      spawnDate: '2024-05-01',
    },
  },
  {
    id: 'seagrass_donor_irma_reef',
    organismKind: 'seagrass',
    provenanceKind: 'donorMeadow',
    displayName: 'Irma Reef Donor Meadow',
    speciesId: 'thte',
    aliasLabels: ['IR-Donor'],
    metadata: {
      site: 'Irma Reef, Marathon Key',
      permit: 'FL-DEP-2023-441',
      notes: 'Used for 2024 plot inoculations.',
    },
  },
  {
    id: 'seagrass_nursery_fb_2025',
    organismKind: 'seagrass',
    provenanceKind: 'cohort',
    displayName: 'Florida Bay Nursery 2025',
    speciesId: 'thte',
    metadata: {
      nursery: 'Florida Bay Plot 12',
      permitId: 'FL-DEP-FB-2025-01',
    },
  },
  {
    id: 'crab_broodstock_chesapeake_2025',
    organismKind: 'crab',
    provenanceKind: 'broodstock',
    displayName: 'Chesapeake Broodstock 2025',
    speciesId: 'casa',
    metadata: {
      hatchery: 'Chesapeake Hatchery A',
      season: 'Spring 2025',
    },
  },
  {
    id: 'finfish_feather_hatchery_2025',
    organismKind: 'finfish',
    provenanceKind: 'broodstock',
    displayName: 'Feather River Hatchery Lot 2025',
    speciesId: 'onmy',
    metadata: {
      hatchery: 'Feather River Hatchery',
      stockType: 'Feather River Reach 2',
    },
  },
  {
    id: 'urchin_cohort_monterey_2025',
    organismKind: 'echinoid',
    provenanceKind: 'cohort',
    displayName: 'Monterey Kelp Cohort 2025',
    speciesId: 'mefr',
    metadata: {
      site: 'Monterey Kelp Site B',
      permitId: 'CA-DFW-URCHIN-2025',
    },
  },
  {
    id: 'mangrove_propagule_keys_2025',
    organismKind: 'mangrove',
    provenanceKind: 'cohort',
    displayName: 'Keys Propagule Cohort 2025',
    speciesId: 'rhma',
    aliasLabels: ['KEYS-RHMA-25'],
    metadata: {
      collectionSite: 'Florida Keys Mangrove Nursery',
      notes: 'Propagules collected post-hurricane for stabilization plantings.',
    },
  },
  {
    id: 'sea_cucumber_broodstock_molucca_2025',
    organismKind: 'seaCucumber',
    provenanceKind: 'broodstock',
    displayName: 'Molucca Sea Cucumber Broodstock 2025',
    speciesId: 'hosc',
    metadata: {
      hatchery: 'Molucca Bay Hatchery',
      cohort: 'Sandfish 2025',
    },
  },
];

function ensureSeedCoverage() {
  const missingSpecies = ORGANISM_KIND_VALUES.filter((kind) =>
    !speciesSeeds.some((seed) => seed.organismKind === kind),
  );
  if (missingSpecies.length > 0) {
    throw new Error(
      `Species seeds missing organism kinds: ${missingSpecies.join(', ')}`,
    );
  }

  const missingProvenances = ORGANISM_KIND_VALUES.filter((kind) =>
    !provenanceSeeds.some((seed) => seed.organismKind === kind),
  );
  if (missingProvenances.length > 0) {
    throw new Error(
      `Provenance seeds missing organism kinds: ${missingProvenances.join(', ')}`,
    );
  }
}

async function seedSpecies(db: Firestore, dryRun: boolean) {
  if (dryRun) {
    console.log('🔎 [Dry Run] Species payloads:');
    speciesSeeds.forEach((seed) => console.log(seed));
    return;
  }

  console.log(`🌿 Seeding ${speciesSeeds.length} taxonomy_species documents...`);
  for (const seed of speciesSeeds) {
    const tags = new Set<string>(seed.tags ?? []);
    if (eslListedSpeciesIds.has(seed.id)) {
      tags.add('ESL listed');
    }

    await db.collection('taxonomy_species').doc(seed.id).set(
      {
        organismKind: seed.organismKind,
        genus: seed.genus,
        species: seed.species,
        code: seed.code,
        commonNames: seed.commonNames ?? [],
        aliases: seed.aliases ?? [],
        ...(seed.organismKind === 'coral' && {
          morphology:
            seed.morphology ?? resolveCoralMorphology(seed.genus, seed.species),
        }),
        ...(tags.size > 0 && { tags: Array.from(tags) }),
        classification: seed.classification ?? {},
        propagationModes: seed.propagationModes ?? [],
        ...(seed.imageUrl && { imageUrl: seed.imageUrl }),
        ...(seed.thumbnailUrl && { thumbnailUrl: seed.thumbnailUrl }),
        metadata: seed.metadata ?? {},
      },
      { merge: true },
    );
    console.log(`  ✅ ${seed.id} (${seed.organismKind})`);
  }
}

async function seedProvenances(db: Firestore, dryRun: boolean) {
  if (dryRun) {
    console.log('🔎 [Dry Run] Provenance payloads:');
    provenanceSeeds.forEach((seed) => console.log(seed));
    return;
  }

  console.log(
    `🌊 Seeding ${provenanceSeeds.length} taxonomy_provenances documents...`,
  );
  for (const seed of provenanceSeeds) {
    await db.collection('taxonomy_provenances').doc(seed.id).set(
      {
        organismKind: seed.organismKind,
        provenanceKind: seed.provenanceKind,
        displayName: seed.displayName,
        speciesId: seed.speciesId,
        parentProvenanceId: seed.parentProvenanceId ?? null,
        siteId: seed.siteId ?? null,
        aliasLabels: seed.aliasLabels ?? [],
        metadata: seed.metadata ?? {},
      },
      { merge: true },
    );
    console.log(`  ✅ ${seed.id} (${seed.provenanceKind})`);
  }
}

function initializeFirestore(): Firestore {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
  let app;
  if (serviceAccountPath) {
    const absolute = path.resolve(serviceAccountPath);
    const credentials = JSON.parse(fs.readFileSync(absolute, 'utf8'));
    app = initializeApp({ credential: cert(credentials) });
  } else {
    app = initializeApp({ credential: applicationDefault() });
  }
  return getFirestore(app);
}

async function main() {
  ensureSeedCoverage();
  const dryRun = process.argv.includes('--dry-run');
  const db = initializeFirestore();

  if (dryRun) {
    console.log('⚠️  Dry run enabled. No changes will be written.');
  }

  await seedSpecies(db, dryRun);
  await seedProvenances(db, dryRun);

  if (dryRun) {
    console.log('✅ Dry run complete.');
  } else {
    console.log('✅ Taxonomy seeding complete.');
  }
}

main().catch((error) => {
  console.error('❌ Failed to seed taxonomy data:', error);
  process.exit(1);
});
