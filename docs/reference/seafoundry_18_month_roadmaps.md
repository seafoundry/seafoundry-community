# SeaFoundry 18-Month Roadmaps

## 1) Technical Roadmap (Engineering-Facing)

**Time Span:** Nov 2025 → Apr 2027 (18 months)  
**Tracks:** A) Community Web, B) Pro & Mobile, C) Multi-Organism  
**Monthly Demos:** Last week of each month (🟣)

---

### A. Milestone Calendar

| Month | Community Web (A) | Pro & Mobile (B) | Multi-Organism (C) | Cross-Repo |
|--------|--------------------|------------------|---------------------|-------------|
| **Nov '25 (M1)** 🟣 | C0: scaffolding refactor, CSV v2 spec, site-type FAB rules | P0: feature gates, packaging | — | CRC (Babelfish) + Legacy prep |
| **Dec '25 (M2)** 🟣 | C1: read-only maps (center/bounds), outplant/monitor exports | P1: Offline surfacing, P2: CSV Wizard MVP | — | Migration beta rehearsal |
| **Jan '26 (M3)** | **GA (Community Web)**, self-host docs | P3: map tools preview, Mobile Alpha planning | C0: discovery (oyster/kelp/seagrass) | CRC ingest + legacy import |
| **Feb '26 (M4)** 🟣 | GA polish | **Mobile Alpha (conference)**, Wizard apply, adapter v1 | C1: data abstractions (OrganismKind, LifeStage) | Pilot enablement |
| **Mar '26 (M5)** 🟣 | CSV validator QoL | P3: KML edit tools | C2: service/dialog strategies | — |
| **Apr '26 (M6)** 🟣 | Monitoring map panel | P4: In-situ grid ops, gene-bank rollups | C3: UI maps/sheets (oyster/kelp/seagrass) | — |
| **May '26 (M7)** 🟣 | Reporting bundle v1 | P1+P2 hardening | C3 cont: seagrass polygons | — |
| **Jun '26 (M8)** 🟣 | Accessibility, performance | **Pro Prod readiness (billing off)** | C4: QA/pilots | — |
| **Jul '26 (M9)** 🟣 | — | **Pro Production (billing on)** | C4 cont: pilot fixes | — |
| **Aug '26 (M10)** 🟣 | — | Pro analytics dashboards v1 | C5: mangroves discovery | — |
| **Sep '26 (M11)** 🟣 | — | Role/training enforcement | C5: mangroves data contracts | — |
| **Oct '26 (M12)** 🟣 | — | Advanced map filters | C6: mangroves UI/spreadsheets | — |
| **Nov '26 (M13)** 🟣 | — | Partner adapters 2–3 | C6 cont: mangrove pilots | — |
| **Dec '26 (M14)** 🟣 | — | Pro reliability SLOs | C7: fin-fish discovery | — |
| **Jan '27 (M15)** 🟣 | — | — | C7: fin-fish data/contracts | — |
| **Feb '27 (M16)** 🟣 | — | — | C8: fin-fish UI & pilots | — |
| **Mar '27 (M17)** 🟣 | — | — | C9: cross-organism reports | — |
| **Apr '27 (M18)** 🟣 | — | — | C10: multi-organism GA | — |

---

### B. Technical Detail by Track

#### **Track A – Community Web (standardization-first)**

**M1: Foundations**  
- Introduce `OrganismKind`, `LifeStage`, `MeasurementUnit`, `PopulationMeasurement`  
- Extend CSV spec to v2 (`docs/csv_templates/SeaFoundry_Universal_CSV_v2_spec.json`)  
- Site-type FAB/action enforcement (Monitoring/Treatment only)  
- CRC (Babelfish) & legacy migration scripts  

**Anchors:**
```bash
rg -n "enum (CoralType|GenetType)" lib/models
rg -n "UniversalCsv|parseCsv" lib/services/csv
rg -n "FloatingActionButton|PopupMenu" lib/widgets
```

**M2–M3: Read-only Maps & Reporting**  
- Render site maps (`lib/widgets/map/*`)  
- Outplant/Monitoring exports  
- Self-host docs (Docker, static hosting)

**M4–M7: Monitoring map panel, Reporting bundle, QoL**  
- Embed Monitoring panel  
- Create `lib/services/reporting/*`  
- Accessibility & performance passes

---

#### **Track B – Pro & Mobile**

**M1: Packaging & Gates**  
- Add `feature_gate.dart`, build flavors (`APP_TIER=community|pro`)  
- Split packages (`community_core`, `pro_addons`)

**M2–M4: Offline & Wizard**  
- Offline queue (`lib/services/offline_queue.dart`)  
- CSV Wizard (`lib/screens/import/wizard/*`)  
- Curated adapter (`lib/services/csv/adapters/tracks_v1_adapter.dart`)

**M5–M9: Maps & In-situ Grid**  
- Draw/upload KML (`lib/widgets/map/editor/*`)  
- Grid operations (`lib/widgets/in_situ/grid_renderer.dart`)  
- Gene-bank summaries (`lib/widgets/cards/gene_bank_summary_card.dart`)

---

#### **Track C – Multi-Organism**

**M3–M4: Discovery + Data Abstractions**  
- Define neutral data types  
  - `lib/models/types/organism_kind.dart` (enum: coral, oyster, seagrass, kelp, mangrove, urchin, crab, finfish)
  - `lib/models/types/life_stage.dart` (gamete, embryo, larva, juvenile, adult, broodstock)
  - `lib/models/types/measurement_unit.dart` (count, g, kg, ml, L)
  - `lib/models/population_measurement.dart` (value + unit wrapper)
- Batch holdings for early stages  
  - `lib/models/holdings/gamete_batch.dart`
  - `lib/models/holdings/larval_batch.dart`
  - `lib/models/batch_holding.dart` (base class)
- Extend CSV spec with organism columns
  - Add all canonical fields from foundational requirements:
    ```
    organismKind, provenanceId, cohortId, lifeStage, measurementUnit,
    permitId, issuingAuthority, validFrom, validTo, carbonPool.*,
    volunteerHours, trainingHours, credentialId
    ```
- Align schema backlog with `docs/architecture/taxonomy/README.md` (lifecycle canon, permit/MRV/CSR fields)

**M5–M7: Services, Dialogs, UI**  
- Service layer abstractions:
  - `lib/services/observation_field_registry.dart` (dynamic field configuration)
  - `lib/services/strategies/propagation_workflow_strategy.dart`
  - `lib/services/life_stage_adapter_service.dart`
  - `lib/services/site_baseline_service.dart`
- Repository updates:
  - Add `CohortRepository` (`lib/repositories/cohort_repository.dart`)
  - Add `ReproductiveEventRepository` (`lib/repositories/reproductive_event_repository.dart`)
  - Update `EventRepository` to support `PopulationMeasurement`
- Dialog enhancements:
  - Update `UnifiedObservationDialog` with organism presets
  - Add "Update site baseline" toggle to monitoring dialogs
  - Include permit fields in `OutplantBatchDialog`
- Organism-specific toggles in spreadsheets/maps:
  - Add organism dropdown to all spreadsheet headers
  - Dynamic column switching based on organism selection
  - Map overlays with organism-specific icons

**M8–M10: Pilots (Oysters, Kelp, Seagrass)**  
- Group types (cage/rack/bag/reefPatch)  
- Line geometry for kelp  
- Polygon plots for seagrass

**M11–M18: Mangroves → Fin-fish → Multi-Organism GA**  
- Mangroves hydrology & UI (M10–M13)  
- Fin-fish lineage & water-quality (M14–M17)  
- Cross-organism reports (M18)

---

### C. Testing & QA

- Add multi-organism fixtures under `/test/fixtures/`:
  - `oyster_nursery_data.json`
  - `kelp_longline_data.json`
  - `seagrass_plot_data.json`
  - `multi_species_site_data.json`
- Tests to maintain:  
```
# Adapter Tests
test/adapters/coral_life_stage_adapter_test.dart
test/adapters/genet_lineage_adapter_test.dart
test/adapters/organism_field_registry_test.dart

# Migration Tests
test/migrations/coral_to_organism_migration_test.dart

# Integration Tests  
test/integration/multi_organism_workflow_test.dart
test/integration/mixed_species_nursery_test.dart
test/integration/batch_holding_lifecycle_test.dart

# Regression Tests
test/regression/coral_only_deployment_test.dart
test/regression/offline_queue_compatibility_test.dart
test/regression/csv_backwards_compatibility_test.dart
```

---

## 2) Business Roadmap (Stakeholder-Facing)

**Goal:** Explain product milestones, pilots, and outcomes to partners and funders.

### A. Releases & Demos

| Phase | Date | Description |
|--------|------|-------------|
| **Community Alpha** | Nov 22–Dec 1, 2025 | Site-specific screens, CSV checks, first site maps |
| **Community Beta** | Dec 12–20, 2025 | Outplant/Monitoring pages with maps/exports |
| **Conference GA (Community Web)** | Jan 1, 2026 | Web app ready; CRC integration; legacy migration |
| **Pro Mobile Alpha** | Feb 2026 (conference) | Offline, guided importer, map tools (preview) |
| **Pro Production** | Jul 2026 | Full release, billing on, advanced maps, roles |
| **Multi-Organism Pilots** | Jun–Oct 2026 | Oysters, Kelp, Seagrass pilots |
| **Multi-Organism GA** | Apr 2027 | Add Mangroves & Fin-fish, cross-organism reports |

### B. Features by Tier

**Community (Web, Free/Freemium)**  
- Plan sites (nursery/outplant) with appropriate actions  
- Track genetics, inventory, outplanting, and monitoring  
- Import/export with a unified CSV format  
- Read-only site maps  
- Self-host or use hosted version

**Pro (Paid)**  
- Offline work and sync  
- Guided CSV importer with curated adapters  
- Map tools for drawing/uploading placements  
- In-situ grid & gene-bank rollups  
- Mobile access for field operations

### C. Pilot Programs & Partnerships

- **Florida Keys coral standardization:** Q4 ’25–Q1 ’26  
- **Mobile Alpha (conference):** Feb ’26  
- **Oyster/Kelp/Seagrass pilots:** Q2–Q4 ’26  
- **Mangrove/Fin-fish pilots:** Q1–Q2 ’27  

### D. Success Metrics

| KPI | Target |
|------|---------|
| Adoption | ≥ 10 orgs using CSV imports with <5% error |
| Coverage | 80% of outplant sites mapped |
| Field Reliability (Pro) | 95% sync success within 24h |
| Pilot Output | ≥ 3 pilot programs reporting monthly |
| Multi-Organism Reach | 5 orgs using new species modules by Q4 ’26 |

### E. Communications Plan

- **Monthly stakeholder demos** (last week each month)  
- **Pre-conference updates** (Beta + GA)  
- **Conference collateral** (Community + Mobile demo)  
- **Post-conference pilot recruitment**  

### F. Packaging

- **Community:** free, web-based, self-host or hosted  
- **Pro:** paid; mobile/offline/maps/importer/grid/analytics  
- **Enterprise:** private hosting, analytics, SSO/SLA  

---

**Repo files for reference:** `README.md`, `WORK_LOG.md`, `TODO.md`, `docs/csv_templates/`, `docs/architecture/taxonomy/README.md`, `lib/widgets/map/`, `lib/services/csv/`, `lib/models/types/`.

**GitHub labels:** `track:A-community`, `track:B-pro-mobile`, `track:C-multi-org`, `phase:M1`–`M18`, `area:csv`, `area:maps`, `area:dialogs`, `area:offline`, `area:adapters`, `area:reporting`.

---

> ✅ **Implementation next step:** Add this file to `docs/roadmap/18M_ROADMAP.md` and create GitHub milestones and issue templates matching the phase codes above.
