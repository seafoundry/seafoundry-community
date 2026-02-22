# CSV Template Notes

## Organism-Specific Field Conventions

**Coral** fields reflect NCRMP/CREMP/AGRRA conventions for size, bleaching, disease, and outplant tracking; our "genet" fields match genetic ID/SNP practices.

**Oyster** rows follow TNC/NOAA Universal Metrics (density #/m², shell height mm, reef area m², reef height cm) and standard water‑quality variables.

**Seagrass** rows mimic Seagrass‑Watch practice (Braun‑Blanquet cover classes, shoot density, Secchi depth).

**Kelp** captures longline geometry via WKT LINESTRING and now includes the holding-specific fields required by Pod E (`lineIdentifier`, `lineLengthMeters`, `dropperId`, and `depthMeters`) so seeded-line batches align with StructureCapacityService rules.

**Oyster** rows now expose spat bag metadata (`bagIdentifier`, `depthMeters`) alongside reef metrics so CSV imports can create `OysterBagHolding` records directly.

**Finfish** covers broodstock/spawn → fry inventory → release with health certificates and permits, and the refreshed template adds `averageWeightGrams` for stocked pen cohorts.

**Crab** holdings include `averageCarapaceWidthMm` and pond identifiers so grow-out batches respect structure capacity.

**Seagrass** rows moved from Braun‑Blanquet metrics to the module-centric fields used by `SeagrassModuleHolding` (`coveragePercent`, `canopyHeightCm`, `moduleAreaSquareMeters`).

**Mangrove** now ships its own template focused on transect plots with `averageHeightCm` and `survivalPercent`, aligned with EMR/blue‑carbon guidance.

**Urchin** uses size‑frequency and a light water‑quality panel (useful for hatchery/grow‑out as well).

> Every template now starts with inline `#` comment lines that call out the organism-specific fields (measurement units, identifiers, physical form values, etc.) so partners see the requirements in-context while editing CSVs. Seagrass and mangrove templates also gained explicit `lifeStage` columns to keep v2 rows aligned with the taxonomy enums.

> See `docs/csv/csv_v2_migration.md` for the full description of organism-specific fields plus links back to each template.
