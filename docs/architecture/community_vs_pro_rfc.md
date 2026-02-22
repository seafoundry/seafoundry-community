# RFC: Community • Pro • Scale — Tier Strategy, Architecture & Rollout
**Author:** Seafoundry Product & Platform (compiled by GPT-5 Pro)  
**Date:** 2026-01-09 (updates prior RFC)  
**Status:** Draft → Review → Accept  
**Audience:** Product, Engineering, RevOps, Support, Partnerships  
**Tags:** tiers, OSS, monetization, entitlements, repo-architecture, migration

> This document **updates** the earlier “Community vs Pro” RFC to a **three‑tier** model and folds Scale into the strategy and execution plan. It preserves the original intent and decisions while adding **Scale** scope, OSS Community specifics, and **a‑la‑carte‑ready** gating.

---

## 1) Summary

We formalize three offerings:

- **Community** — **web‑only**, **open‑source**, **free**. Coral‑only. Tracks **genetics, inventory, outplanting** with minimum viable **six‑field export** (Date + five axes: **Taxonomy/Species**, **Provenance/Genotype**, **Location/Geometry (centerpoint)**, **Life Stage**, **Quantity/Unit**). Contributes (mandatory) to a **public holdings & activity map**; supports **external transfers** (record + send/receive). **Permitting fields are excluded/not required** at this tier so OSS adopters can run without permit governance.

- **Pro** — Adds **mobile** + **offline/asynch** + notifications, **advanced husbandry** (mortality reasons, structured observations, triage, health history/summary, tank/tree health events), **monitoring** with **KML geometry**, **event imagery**, **BMP association**, **bleaching/disease assessments**, **inventory multi‑views**, **acclimation**, **harvest warnings**, **selective data sharing**, **dropdown‑filterable reports**, and **permit management** (create/maintain permit fields for harvest, transfers, nursery facilities, outplanting, and monitoring workflows).

- **Scale** — Adds **role‑based training gates for actions** (e.g., interns can’t outplant until trained), **recurring tasks**, **approvals**, **auto‑assign**, **time tracking**, **advanced calendar/Gantt**, and **deliverables integrations** where practitioners can create grants, associate specific corals/permits, plan against quantities/inventory, and generate reports tied to those commitments, plus **planning & fleet optimization**, **satellite & weather overlays**, and **AI‑assisted imagery** workflows.

**Commercial intent:** low-friction adoption via Community → upgrade path to Pro for field-ready UX and to **Scale** only when operational complexity demands it. Architecture supports future **a-la-carte** add-ons without refactoring, and the Visual Engagement roadmap (`docs/VisualEngagement.md`) supplies the hero surfaces, public read models, experiences, and growth hooks that map into each tier.

---

## 2) Non‑Goals

- Build billing UI/processor now.  
- Re‑write existing mobile clients for Community (mobile is Pro+).  
- Backport comprehensive health/mortality features into Community.  
- Deliver a heavy feature‑flag service; a **lightweight entitlements + lints** approach is sufficient.

---

## 3) Tiers & Category Boundaries

We align features into the following **categories/themes** (parentheticals are subtitles from the planning sheet):

1. **General Use**  
2. **Inventory Tracking** *(including Holdings, Production & Harvest)*  
3. **Husbandry & Nursery Maintenance** *(Including Coral Health and Task management)*  
4. **Genetics Management** *(Including Provenance and Sexual Propagation)*  
5. **Collaboration Features** *(Including Transfers)*  
6. **Restoration Tracking** *(Including Outplanting and Monitoring)*  
7. **Insights & Reporting** *(Including Analytics and Advanced Report Generation)*  
8. **Workforce Management** *(including Chat, Roles, Training and Individual Task Logging)*  
9. **Operations Optimization** *(Including Fleet Management and Deliverables Integration)*

### 3.1 Community (OSS, web‑only, coral‑only)
- **Must include:** authentication, org membership, intuitive nav; register/add nurseries & corals; internal moves; **basic frag events** (keep provenance chain); **outplant site (centerpoint)** & **outplant event**; **read‑only outplant map**; **external transfers** (record + send/receive); **six‑field CSV exports**; **public holdings & activity map** (mandatory sharing).  
- **Explicitly excludes:** any health status/mortality coding; monitoring workflows; KML; imagery attachments; messaging; mobile/offline; analytics beyond simple summaries.
- **Structure hierarchy:** Movement + GraphBloc flows remain `org → nursery → structure → coral` so the web-only OSS build keeps the current bloc/navigation wiring without requiring a move refactor.

### 3.2 Pro (mobile & advanced workflows)
- Adds **mortality reasons & structured observations**, **triage**, **health histories**, **tank/tree health events**; **monitoring** with **KML**, **imagery**, **BMP tags**, **bleaching/disease assessments**; **inventory multi‑view** (planar/table/kanban); **acclimation** & **harvest warnings**; **selective sharing**; **dropdown‑filterable reports**; **basic tasks & calendar**; **notifications**; **mobile offline** capture.
- **Structure hierarchy customization:** unlocks `org → nursery → superstructure group → structure → substructure group → coral` paths with configurable grouping metadata so facilities can represent racks, trees, or bespoke zones beyond the Community baseline.

### 3.3 Scale (operational integrations & optimization)
- Adds **role‑based training gates** on FAB actions; **recurring tasks**, **approvals**, **auto‑assign**, **time tracking**, **advanced visuals** (calendar/Gantt); **deliverable & permit integrations** (filters + columns/templates); **planning overlays**, **KML workflow tooling**, **satellite & weather** data; **fleet & schedule optimization**; **AI imagery assist**.

---

## 4) Architecture Decisions

### 4.1 Web stack
- **Community:** **Flutter Web** (max code reuse).  
- **Pro/Scale:** Flutter mobile + web as today.

### 4.2 Data & Auth
- **Default:** Firebase (Auth + Firestore). Community ships OSS docs for self‑hosting.  
- **Pro/Scale add‑on:** Supabase **sync** and SQL‑driven analytics views (read‑heavy joins; reports).

### 4.3 Repository Layout (tier‑safe & a‑la‑carte ready)
```
/packages
  /core_shared                # models, DTOs, taxonomy, CSV adapters
  /feature_access             # entitlements, compile/runtime gates, upgrade CTA
  /features
    /genetics_core            # Community‑safe
    /inventory_core           # Community‑safe
    /outplant_core            # Community‑safe (centerpoint only)
    /collab_public_map        # Community mandatory public map (read/write to aggregate)
    /health_pro               # Pro
    /monitoring_pro           # Pro (KML, imagery, BMP, assessments)
    /tasks_pro                # Pro (basic tasks + calendar)
    /workforce_scale          # Scale (recurring, approvals, auto‑assign, time)
    /ops_scale                # Scale (fleet, weather, AI imagery, optimizations)
    /deliverables_scale       # Scale (permit/grant templates, extra columns/filters)
/app_web_community            # Flutter Web entry; imports only *_core + collab_public_map
/app_mobile_pro               # Mobile/Web entry; Pro + Scale features via entitlements
/config
  tiers.yaml                  # declarative mapping: features → community|pro|scale|shared
  entitlements.schema.json    # JWT claim schema (tier + a‑la‑carte features[])
/docs
  architecture/community_vs_pro_rfc.md     # (this doc supersedes prior)
  architecture/community_vs_pro_task_list.md
  oss/README_COMMUNITY.md
```

- **Directionality enforced**: `app_web_community` cannot import any `*_pro` or `*_scale`. Analyzer + CI enforces.  
- **A‑la‑carte support**: entitlements carry a `features[]` list; bundles (Pro/Scale) are just predefined sets.

### 4.4 Entitlements & Paywall
- **FeatureAccessService** (Dart):
  - Compile‑time `TIER=community|pro|scale` + runtime license token (JWT) claims `{{ tier, features:[], orgId, exp }}`.
  - API: `isFeatureEnabled(FeatureKey)`, `requireFeatureOrCta(context, key)`.
  - **Preferred gating**: use feature keys defined in `config/tier_features.yaml` via `FeatureAccessService`
    (or `TierGate`/`FeatureGate` with `featureKey`) instead of ad‑hoc tier checks in widgets.
    Current UI-facing keys include `monitoring_workspace`, `comments`,
    `visual_identity_hero`, `visual_engagement_phase_d`, and
    `visual_engagement_phase_e_f`.
  - First gate: **mortality reasons** in `lib/widgets/common/quantity_change_editor.dart` → Community shows read‑only chips + **Upgrade to Pro** CTA; Pro edits as today.
- **Server enforcement** for hosted Pro/Scale: deny Pro‑only endpoints when tier=community.
- **Tiered Services**:
  - `TieredSnapshotService`: Community gets basic snapshots; Pro/Scale get pre-computed intervals and historical queries
  - `TieredSyncManager`: Community gets immediate sync only; Pro/Scale get async operations and scheduled tasks
  - `TieredRepositoryWrapper`: Filters Pro/Scale fields from records based on entitlements

### 4.5 Data Portability & Migration
- **Shared schema**; Pro/Scale fields **optional**. Community ignores them safely.  
- **Upgrade/downgrade scripts** preserve Pro/Scale metadata and add missing Community columns.  
- **CSV adapters**: Community exports six fields; Pro/Scale export a superset with schema version tags.

### 4.6 CI/CD
- Workflows: `community_web.yaml` (web tests/build) and `pro_full.yaml` (mobile/web + lints).  
- Branch protections: `community` requires web pipeline; `pro` requires both.  
- Lint: analyzer reads `tiers.yaml` and fails forbidden imports; snapshot tests verify hidden widgets in Community.

---

## 5) Productized Workflows by Tier (highlights)

### Community
- Genetics translation; register/add nursery & coral; internal moves; **basic frag events**; **external transfers** (record + send/receive); **outplant sites (centerpoint)** & **outplant events**; **read-only outplant map**; **mandatory public holdings/activity map**; **six-field CSV export**.
- Visual Engagement foundation (Pods VE-A/B/C): organizations create public brand profiles with hero imagery + logos that flow into `public_read_models/*` and double as their markers on the Community holdings/outplant map, alongside hero/tip playlists and the shared theming provider described in `docs/VisualEngagement.md`.
- **Permitting:** Not exposed/required; Community data capture focuses on geometry + inventory only so OSS deployments avoid permit governance overhead.

### Pro
- **Husbandry/Health:** mortality reasons, structured observations, triage, health history, tank/tree health.  
- **Restoration:** monitoring events, BMP tags, **KML**, event imagery, bleaching/disease assessments; planning map modes.  
- **Inventory:** multi-view; acclimation; harvest warnings.  
- **Collab:** selective sharing; notifications.  
- **Reporting:** dropdown filters & customizable output.  
- **Workforce:** basic tasks & calendar; offline mobile logging.
- Visual Engagement personalization (Pods VE-D/E): advanced onboarding (“introduce yourself”, hero curation), profile media galleries, Did-You-Know strips scoped by species/role, and action gating/training modules that hook into FeatureAccess + TrainingService.
- **Permitting:** Practitioners create and maintain permit fields across harvest, transfer, nursery, outplanting, and monitoring activities with validation hooks + reporting surfaces.

### Scale
- **Workforce:** training gates; recurring tasks; approvals; auto-assign; time tracking; advanced visuals.  
- **Restoration:** advanced overlays; KML tooling; **satellite & weather** layers; **AI imagery** assist.  
- **Reports/Integrations:** deliverables & permit templates; extra filters/columns; dashboards.
- Visual Engagement growth levers (Pods VE-E/F): kiosk/QR experiences with visitor tracking, experiences/trips marketplace (`experiences/{xpId}`), sponsorship/ad slot placements, follow/digest Cloud Functions, KPI instrumentation, and security-rule hardening for public read models.
- **Deliverables + permit integrations:** Create/manage grants, associate specific corals/permits, plan against inventory targets, and generate reporting packs tied to those deliverables.

---

## 6) Rollout Plan (P0 → P7)

- **P0 – Alignment & Branching**: rename branches (`community`→`pro`), cut new `community`; update CI defaults; publish change notes.  
- **P1 – Tier Manifest & Lints**: add `config/tiers.yaml`; analyzer + CI checks; render matrix doc.  
- **P2 – FeatureAccess & First Gate**: implement service; gate mortality reasons; add tests.  
- **P3 – Upgrade UX & Server Enforcement**: shared Upgrade CTA; extend gates (husbandry tiles, monitoring, mobile/offline entry); license validation in backend.  
- **P4 – Data Compatibility & Migrations**: audit schemas; upgrade/downgrade scripts; CSV adapters (Community six‑field vs Pro/Scale superset).  
- **P5 – CI/CD & OSS Docs**: split pipelines; branch protections; publish OSS Community guide; partner beta.  
- **P6 – Scale: Workforce & Ops**: role‑gated FAB actions, recurring/approvals/auto‑assign/time tracking, advanced calendar/Gantt; deliverables templates + filters/columns.  
- **P7 – Scale: Integrations & AI**: planning overlays, KML workflows, satellite & weather APIs, fleet optimization; AI imagery pilot with reviewer QA.

---

## 6.1) Data Architecture for Tiered Features

### Snapshot & Historical Queries
- **Community**: Basic before/after snapshots for audit trails only
- **Pro**: Pre-computed snapshots at standard intervals (7, 30, 90, 180 days) with historical reconstruction
- **Scale**: Custom aggregation pipelines, configurable intervals, and advanced analytics on historical data

### Async Storage & Operations
- **Community**: Synchronous operations only; offline queue for network resilience
- **Pro**: Basic async operations, scheduled tasks, offline-first mobile with background sync
- **Scale**: Advanced job scheduling, recurring tasks with approvals, batch operations with progress tracking

### Field-Level Security Model
- All tiers share the same Firestore collections
- Records use `TieredRecord` base class with optional `proFields` and `scaleFields`
- Repository wrappers filter fields based on current entitlements
- Ensures seamless upgrades/downgrades without data migration

## 7) Risks & Mitigations

- Branch rename breakage → one‑window maintenance + alias branch for a release.  
- Pro code leaking into Community → lints + CI + snapshot tests.  
- Data loss on tier switch → optional fields + reversible migrations + staging validation.  
- OSS forks removing upgrade messaging → resilient CTA handling; clarify brand usage in OSS README.

---

## 8) Open Questions

1) Telemetry for OSS Community (opt-in)?  
2) Community visibility of Pro-only metadata (read-only)?  
3) Legacy hosted “community” tenants after rename—migrate to Pro or to new Community?

---

## 10) Visual Engagement Pod Alignment

- **Pod VE-A – Media & Read Models (Community)**: document public collections (`docs/api/README.md`, new `docs/analytics/visual_engagement_metrics.md`), add media/brand models (`lib/models/media/*.dart`, `lib/models/brand/brand_config.dart`), extend `ImageService`, and build Cloud Functions (`functions/src/media_ingestion.ts`, `node_story_builder.ts`, `public_digest.ts`) that hydrate `public_read_models/*` with the six-field data guaranteed in Community while supplying hero imagery + logos for the holdings/outplant map.
- **Pod VE-B – Visual Identity & Theming (Community → Pro)**: ship `HeroBackground`, spreadsheet hero rails, and `OrgBrandTheme` provider, ensuring Community web and Pro experiences share the same playlist/tip surfaces before FeatureAccess gates kick in.
- **Pod VE-C – Public Surfaces & Map Presence (Community)**: wire public/profile routes, QR entry points to the holdings/outplant map, and anonymous overlays so Community builds can host stories where hero imagery + logos represent each organization without touching operational collections.
- **Pod VE-D – Personalization & Training (Pro/Scale bridge)**: extend onboarding with `/users/{id}/intro`, rotate profile media, and add `TrainingService` hooks inside `lib/widgets/graph_node/actions/*` to enforce module completion before sensitive actions—paired with FeatureAccess entitlements.
- **Pod VE-E – Growth, Kiosks & Revenue (Scale)**: implement kiosk/QR experiences with visitor tracking, sponsorship tiles, experience listings, follow/digest Functions, and marketing CTAs that align with Scale’s deliverables and operations packages.
- **Pod VE-F – Analytics, Docs & Rollout (All tiers)**: define KPI contracts, add structured logging, expand emulator/security tests, and publish launch playbooks so Visual Engagement features ship behind tier-aware gates.

Pods map directly onto the rollout plan (P0–P7): VE-A/B/C feed Community milestones (P0–P5), VE-D spans the Pro readiness work (P2–P4), and VE-E/F drive Scale/Growth deliverables (P6–P7).

---

## 11) Approvals (check boxes in PR)
- [ ] Product (Community)  
- [ ] Product (Pro)  
- [ ] Engineering Lead  
- [ ] Revenue Ops  
- [ ] Support/Success  
- [ ] Security/Legal
