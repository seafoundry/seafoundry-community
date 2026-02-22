// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Environmental baseline metadata stored per site (and optionally per organism).
///
/// Each baseline is designed to be flexible so new metrics (temperature, salinity,
/// dissolved oxygen, nutrient concentrations, etc.) can be recorded without
/// migrating the schema. Structured MRV fields can later provide stronger typing
/// once the taxonomy registry enumerates required parameters per organism.
class SiteBaseline extends Equatable {
  SiteBaseline({
    required this.siteId,
    this.organismKind,
    required Map<String, dynamic> metrics,
    this.notes,
    this.updatedAt,
    this.updatedBy,
  }) : metrics = Map.unmodifiable(Map<String, dynamic>.from(metrics));

  /// Graph node ID for the site the baseline describes.
  final String siteId;

  /// Optional organism specialization. When null, the baseline applies to the site overall.
  final OrganismKind? organismKind;

  /// Free-form metric map (temperature, salinity, etc.). Values should remain JSON-serializable.
  final Map<String, dynamic> metrics;

  /// Optional operator notes captured alongside the metrics.
  final String? notes;

  /// Last updated timestamp for audit/reference.
  final DateTime? updatedAt;

  /// ID of the user or service that last updated the baseline.
  final String? updatedBy;

  SiteBaseline copyWith({
    Map<String, dynamic>? metrics,
    String? notes,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SiteBaseline(
      siteId: siteId,
      organismKind: organismKind,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory SiteBaseline.fromJson(Map<String, dynamic> json, String siteId) {
    return SiteBaseline(
      siteId: (json['siteId'] as String?) ?? siteId,
      organismKind: _parseOrganismKind(json['organismKind'] as String?),
      metrics: Map<String, dynamic>.from(json['metrics'] as Map? ?? const {}),
      notes: json['notes'] as String?,
      updatedAt: _parseTimestamp(json['updatedAt']),
      updatedBy: json['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      if (organismKind != null) 'organismKind': organismKind!.name,
      'metrics': Map<String, dynamic>.from(metrics),
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  static OrganismKind? _parseOrganismKind(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return OrganismKind.values.firstWhere((kind) => kind.name == value);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Builds a deterministic document ID for Firestore persistence.
  static String documentId(String siteId, {OrganismKind? organismKind}) {
    final baseId = siteId.trim();
    if (organismKind == null) return baseId;
    return '${baseId}__${organismKind.name}';
  }

  @override
  List<Object?> get props => [
    siteId,
    organismKind,
    metrics,
    notes,
    updatedAt,
    updatedBy,
  ];
}
