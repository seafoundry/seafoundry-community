// @tier: community

import 'package:seafoundry_app/models/inventory/holding_attributes.dart';

/// Builder for constructing HoldingAttributes from CSV row data.
class HoldingAttributesBuilder {
  HoldingAttributesBuilder._();

  /// Builds HoldingAttributes from CSV row data.
  ///
  /// Extracts all holding attribute fields from the row using camelCase keys.
  static HoldingAttributes build(Map<String, String> row) {
    String? read(String key) {
      final value = row[key];
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return HoldingAttributes(
      speciesId: read('speciesId'),
      speciesCode: read('speciesCode'),
      speciesScientific: read('speciesScientific'),
      permitType: read('permitType'),
      permitId: read('permitId'),
      issuingAuthority: read('issuingAuthority'),
      validFrom: read('validFrom'),
      validTo: read('validTo'),
      habitatType: read('habitatType'),
      siteJurisdiction: read('siteJurisdiction'),
      protectedAreaFlag: read('protectedAreaFlag'),
      siteName: read('siteName'),
      enclosureId: read('enclosureId'),
      dropperId: read('dropperId'),
      geometryFormat: read('geometryFormat'),
      geometryWkt: read('geometryWkt'),
      geometryGeojson: read('geometryGeojson'),
    );
  }
}
