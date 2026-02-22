// @tier: community
import 'package:seafoundry_app/models/types/record_type.dart';
import 'package:seafoundry_app/models/types/site_type.dart';

class SiteActivityType extends BuiltinRecordType {
  static final List<SiteActivityType> builtins = SiteType.builtins.values
      .toSet() // Remove duplicates (same SiteType with different alias keys)
      .map((siteType) => SiteActivityType(siteType: siteType))
      .toList();

  SiteActivityType({required this.siteType}) : super(id: siteType.id, name: siteType.name);
  final SiteType siteType;

  @override
  String get name {
    switch (siteType) {
      case SiteType.nurseryExSitu:
        return 'Ex-Situ Production';
      case SiteType.nurseryInSitu:
        return 'In-Situ Production';
      case SiteType.geneBank:
        return 'Gene Banking';
      case SiteType.outplanting:
        return 'Outplanting';
      case SiteType.fieldCollection:
        return 'Field Collection';
      case SiteType.kelpFarm:
        return 'Kelp Farm';
      case SiteType.reefAquaculture:
        return 'Reef Aquaculture';
      case SiteType.seagrassPlot:
        return 'Seagrass Plot';
      case SiteType.mangroveOutplant:
        return 'Mangrove Outplant';
      case SiteType.growOutPond:
        return 'Grow-out Pond';
      case SiteType.racewaySite:
        return 'Raceway Site';
      case SiteType.releaseSite:
        return 'Release Site';
      case SiteType.baselineSite:
        return 'Baseline Monitoring';
      case SiteType.referenceSite:
        return 'Reference Monitoring';
      default:
        // Fallback to site type name for any future additions
        return siteType.name;
    }
  }
}
