// @tier: community
// ignore_for_file: missing_override_of_must_be_overridden

import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

class SiteType extends BuiltinRecordType {
  const SiteType({
    required super.id,
    required super.name,
    required this.description,
    required this.groupTypes,
    required this.environment,
  });

  final String description;
  final List<GroupType> groupTypes;

  /// The site environment (ex-situ for land-based, in-situ for ocean-based)
  final SiteEnvironment environment;

  static final Map<String, SiteType> builtins = {
    nurseryExSitu.id: nurseryExSitu,
    'nes': nurseryExSitu,
    nurseryInSitu.id: nurseryInSitu,
    'nis': nurseryInSitu,
    outplanting.id: outplanting,
    'op': outplanting,
    geneBank.id: geneBank,
    'gb': geneBank,
    fieldCollection.id: fieldCollection,
    kelpFarm.id: kelpFarm,
    reefAquaculture.id: reefAquaculture,
    seagrassPlot.id: seagrassPlot,
    mangroveOutplant.id: mangroveOutplant,
    growOutPond.id: growOutPond,
    racewaySite.id: racewaySite,
    releaseSite.id: releaseSite,
    baselineSite.id: baselineSite,
    'bl': baselineSite,
    referenceSite.id: referenceSite,
    'ref': referenceSite,
    externalHolding.id: externalHolding,
    'eh': externalHolding,
  };

  static const SiteType nurseryExSitu = SiteType(
    id: 'site_type_nursery_ex_situ',
    name: 'Ex-Situ Nursery',
    description: 'Land-based facility for rearing organisms in controlled conditions (tanks, raceways).',
    environment: SiteEnvironment.exSitu,
    groupTypes: [
      GroupType.lifeSupportSystem,
      GroupType.tank,
      GroupType.raceway,
      GroupType.tray,
      GroupType.group,
    ],
  );
  static const SiteType nurseryInSitu = SiteType(
    id: 'site_type_nursery_in_situ',
    name: 'In-Situ Nursery',
    description: 'Ocean-based nursery using trees, tables, or other structures.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.tree,
      GroupType.treeBranch,
      GroupType.dome,
      GroupType.reebarTable,
      GroupType.cradle,
      GroupType.aframe,
      GroupType.group,
    ],
  );
  static const SiteType outplanting = SiteType(
    id: 'site_type_outplanting',
    name: 'Outplanting Site',
    description: 'Natural reef or restoration area where organisms are permanently planted.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.zone,
      GroupType.grid,
      GroupType.gridCell,
      GroupType.tag,
      GroupType.group,
    ],
  );
  static const SiteType geneBank = SiteType(
    id: 'site_type_gene_bank',
    name: 'Gene Bank',
    description: 'Specialized facility for preserving genetic diversity.',
    environment: SiteEnvironment.exSitu,
    groupTypes: [
      GroupType.lifeSupportSystem,
      GroupType.tank,
      GroupType.raceway,
      GroupType.tray,
      GroupType.group,
    ],
  );
  static const SiteType fieldCollection = SiteType(
    id: 'fc',
    name: 'In-Situ Field Collection',
    description: 'Wild site for collecting broodstock or genetic material.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.zone,
      GroupType.grid,
      GroupType.gridCell,
      GroupType.tag,
      GroupType.group,
    ],
  );
  static const SiteType kelpFarm = SiteType(
    id: 'site_type_kelp_farm',
    name: 'Kelp Farm',
    description: 'Open ocean farm for cultivating kelp on longlines.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.longline,
      GroupType.dropperLine,
      GroupType.raft,
      GroupType.group,
    ],
  );
  static const SiteType reefAquaculture = SiteType(
    id: 'site_type_reef_aquaculture',
    name: 'Reef Aquaculture',
    description: 'Farming site for oysters or shellfish using racks, bags, or cages.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.reefPatch,
      GroupType.bag,
      GroupType.rack,
      GroupType.cage,
      GroupType.group,
    ],
  );
  static const SiteType seagrassPlot = SiteType(
    id: 'site_type_seagrass_plot',
    name: 'Seagrass Plot',
    description: 'Designated area for seagrass restoration and monitoring.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.plotTransect,
      GroupType.quadrat,
      GroupType.grid,
      GroupType.tag,
      GroupType.group,
    ],
  );
  static const SiteType mangroveOutplant = SiteType(
    id: 'site_type_mangrove_outplant',
    name: 'Mangrove Outplant',
    description: 'Coastal area for planting and monitoring mangrove forests.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.plotTransect,
      GroupType.beltTransect,
      GroupType.tag,
      GroupType.group,
    ],
  );
  static const SiteType growOutPond = SiteType(
    id: 'site_type_grow_out_pond',
    name: 'Grow-out Pond',
    description: 'Pond or enclosed area for growing organisms to market size.',
    environment: SiteEnvironment.exSitu,
    groupTypes: [
      GroupType.pond,
      GroupType.pen,
      GroupType.linePen,
      GroupType.group,
    ],
  );
  static const SiteType racewaySite = SiteType(
    id: 'site_type_raceway',
    name: 'Raceway Site',
    description: 'Flow-through system for intensive fish culture.',
    environment: SiteEnvironment.exSitu,
    groupTypes: [
      GroupType.raceway,
      GroupType.tank,
      GroupType.pen,
      GroupType.group,
    ],
  );
  static const SiteType releaseSite = SiteType(
    id: 'site_type_release',
    name: 'Release Site',
    description: 'Location for releasing organisms into the wild.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [GroupType.boatDrop, GroupType.tag, GroupType.group],
  );

  /// Monitoring-only site: baseline for comparison with restoration sites.
  /// Cannot receive organisms from transfers - used for scientific comparison.
  static const SiteType baselineSite = SiteType(
    id: 'site_type_baseline',
    name: 'Baseline Site',
    description: 'Non-intervention site monitored as a baseline for comparison with restoration sites.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.zone,
      GroupType.grid,
      GroupType.gridCell,
      GroupType.tag,
      GroupType.group,
    ],
  );

  /// Monitoring-only site: healthy reef reference for comparison.
  /// Cannot receive organisms from transfers - used for scientific comparison.
  static const SiteType referenceSite = SiteType(
    id: 'site_type_reference',
    name: 'Reference Site',
    description: 'Healthy reef site used as a reference for scientific comparison.',
    environment: SiteEnvironment.inSitu,
    groupTypes: [
      GroupType.zone,
      GroupType.grid,
      GroupType.gridCell,
      GroupType.tag,
      GroupType.group,
    ],
  );

  /// External holding site: represents organisms held at another organization.
  /// Used for retained ownership transfers where organisms are hosted externally.
  static const SiteType externalHolding = SiteType(
    id: 'site_type_external_holding',
    name: 'External Holding',
    description: 'Virtual site representing organisms held at an external organization.',
    environment: SiteEnvironment.exSitu,
    groupTypes: [
      GroupType.group,
    ],
  );

  /// Get SiteType by ID, returns null if not found.
  ///
  /// Use this when the site type is optional or when you need to handle
  /// missing/invalid IDs gracefully.
  static SiteType? maybeFromId(String? id) {
    if (id == null) return null;
    final direct = builtins[id];
    if (direct != null) {
      return direct;
    }
    try {
      return builtins.values.firstWhere((type) => type.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get SiteType by ID, returns [nurseryExSitu] as default if not found.
  ///
  /// Use this when a fallback is acceptable. For nullable semantics,
  /// use [maybeFromId] instead.
  static SiteType fromId(String? id) {
    return maybeFromId(id) ?? nurseryExSitu;
  }

  /// Whether this is a monitoring-only site type (baseline or reference).
  /// Monitoring-only sites cannot receive organisms from transfers - they are
  /// used for scientific comparison with restoration sites.
  bool get isMonitoringOnly =>
      this == baselineSite || this == referenceSite;

  /// Whether this is an external holding site type.
  /// External holding sites represent organisms held at another organization.
  bool get isExternalHolding => this == externalHolding;

  /// Whether this is an ex-situ (land-based) site type
  bool get isExSitu => environment == SiteEnvironment.exSitu;

  /// Whether this is an in-situ (ocean-based) site type
  bool get isInSitu => environment == SiteEnvironment.inSitu;

  /// Get the primary organism kind for this site type.
  ///
  /// Note: [externalHolding] sites are virtual and can hold any organism kind,
  /// so they return coral as the default.
  OrganismKind get organismKind {
    if (this == nurseryExSitu || this == nurseryInSitu || this == geneBank ||
        this == outplanting || this == fieldCollection ||
        this == baselineSite || this == referenceSite ||
        this == externalHolding) {
      return OrganismKind.coral;
    } else if (this == kelpFarm) {
      return OrganismKind.kelp;
    } else if (this == seagrassPlot) {
      return OrganismKind.seagrass;
    } else if (this == mangroveOutplant) {
      return OrganismKind.mangrove;
    } else if (this == reefAquaculture) {
      return OrganismKind.oyster;
    } else if (this == growOutPond) {
      return OrganismKind.echinoid; // Could be multiple, but we'll use echinoid as default
    } else if (this == racewaySite || this == releaseSite) {
      return OrganismKind.finfish;
    } else {
      return OrganismKind.coral; // Default to coral
    }
  }
}
