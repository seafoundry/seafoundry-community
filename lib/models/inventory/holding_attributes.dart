import 'package:equatable/equatable.dart';

/// Canonical metadata for holdings that need to survive CSV v2 round-trips.
/// These fields previously lived inside ad-hoc metadata maps; surfacing them
/// here keeps repositories/DTOs type-safe while preserving backward
/// compatibility for legacy documents.
class HoldingAttributes extends Equatable {
  const HoldingAttributes({
    this.speciesId,
    this.speciesCode,
    this.speciesScientific,
    this.habitatType,
    this.siteJurisdiction,
    this.protectedAreaFlag,
    this.siteName,
    this.enclosureId,
    this.dropperId,
    this.geometryFormat,
    this.geometryWkt,
    this.geometryGeojson,
  });

  final String? speciesId;
  final String? speciesCode;
  final String? speciesScientific;
  final String? habitatType;
  final String? siteJurisdiction;
  final String? protectedAreaFlag;
  final String? siteName;
  final String? enclosureId;
  final String? dropperId;
  final String? geometryFormat;
  final String? geometryWkt;
  final String? geometryGeojson;

  bool get isEmpty =>
      speciesId == null &&
      speciesCode == null &&
      speciesScientific == null &&
      habitatType == null &&
      siteJurisdiction == null &&
      protectedAreaFlag == null &&
      siteName == null &&
      enclosureId == null &&
      dropperId == null &&
      geometryFormat == null &&
      geometryWkt == null &&
      geometryGeojson == null;

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        data[key] = value;
      }
    }

    put('speciesId', speciesId);
    put('speciesCode', speciesCode);
    put('speciesScientific', speciesScientific);
    put('habitatType', habitatType);
    put('siteJurisdiction', siteJurisdiction);
    put('protectedAreaFlag', protectedAreaFlag);
    put('siteName', siteName);
    put('enclosureId', enclosureId);
    put('dropperId', dropperId);
    put('geometry_format', geometryFormat);
    put('geometry_wkt', geometryWkt);
    put('geometry_geojson', geometryGeojson);
    return data;
  }

  HoldingAttributes copyWith({
    String? speciesId,
    String? speciesCode,
    String? speciesScientific,
    String? habitatType,
    String? siteJurisdiction,
    String? protectedAreaFlag,
    String? siteName,
    String? enclosureId,
    String? dropperId,
    String? geometryFormat,
    String? geometryWkt,
    String? geometryGeojson,
  }) {
    return HoldingAttributes(
      speciesId: speciesId ?? this.speciesId,
      speciesCode: speciesCode ?? this.speciesCode,
      speciesScientific: speciesScientific ?? this.speciesScientific,
      habitatType: habitatType ?? this.habitatType,
      siteJurisdiction: siteJurisdiction ?? this.siteJurisdiction,
      protectedAreaFlag: protectedAreaFlag ?? this.protectedAreaFlag,
      siteName: siteName ?? this.siteName,
      enclosureId: enclosureId ?? this.enclosureId,
      dropperId: dropperId ?? this.dropperId,
      geometryFormat: geometryFormat ?? this.geometryFormat,
      geometryWkt: geometryWkt ?? this.geometryWkt,
      geometryGeojson: geometryGeojson ?? this.geometryGeojson,
    );
  }

  HoldingAttributes merge(HoldingAttributes fallback) {
    return HoldingAttributes(
      speciesId: speciesId ?? fallback.speciesId,
      speciesCode: speciesCode ?? fallback.speciesCode,
      speciesScientific: speciesScientific ?? fallback.speciesScientific,
      habitatType: habitatType ?? fallback.habitatType,
      siteJurisdiction: siteJurisdiction ?? fallback.siteJurisdiction,
      protectedAreaFlag: protectedAreaFlag ?? fallback.protectedAreaFlag,
      siteName: siteName ?? fallback.siteName,
      enclosureId: enclosureId ?? fallback.enclosureId,
      dropperId: dropperId ?? fallback.dropperId,
      geometryFormat: geometryFormat ?? fallback.geometryFormat,
      geometryWkt: geometryWkt ?? fallback.geometryWkt,
      geometryGeojson: geometryGeojson ?? fallback.geometryGeojson,
    );
  }

  factory HoldingAttributes.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HoldingAttributes();
    String? read(String key) {
      final value = json[key];
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    return HoldingAttributes(
      speciesId: read('speciesId'),
      speciesCode: read('speciesCode'),
      speciesScientific: read('speciesScientific'),
      habitatType: read('habitatType'),
      siteJurisdiction: read('siteJurisdiction'),
      protectedAreaFlag: read('protectedAreaFlag'),
      siteName: read('siteName'),
      enclosureId: read('enclosureId'),
      dropperId: read('dropperId'),
      geometryFormat: read('geometry_format'),
      geometryWkt: read('geometry_wkt'),
      geometryGeojson: read('geometry_geojson'),
    );
  }

  static HoldingAttributes fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return const HoldingAttributes();
    return HoldingAttributes.fromJson(metadata);
  }

  @override
  List<Object?> get props => [
    speciesId,
    speciesCode,
    speciesScientific,
    habitatType,
    siteJurisdiction,
    protectedAreaFlag,
    siteName,
    enclosureId,
    dropperId,
    geometryFormat,
    geometryWkt,
    geometryGeojson,
  ];
}
