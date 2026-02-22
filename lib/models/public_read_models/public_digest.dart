// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Weekly digest for an org's public feed.
class PublicDigest extends Record {
  const PublicDigest({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.metadata,
    required this.weekOf,
    this.highlightAssetIds = const <String>[],
    this.summary,
    this.metrics,
    this.published = false,
    this.publishedAt,
  });

  PublicDigest.fromJson(super.json)
      : weekOf = json['weekOf'] ?? Missing.string,
        highlightAssetIds = _stringList(json['highlightAssetIds']),
        summary = json['summary'] is String ? json['summary'] as String : null,
        metrics = VisualKpiSnapshot.maybeFromJson(json['metrics']),
        published = json['published'] == true,
        publishedAt = json['publishedAt'] is String
            ? json['publishedAt'] as String
            : null,
        super.fromJson();

  final String weekOf; // ISO8601 date (e.g., Monday of week)
  final List<String> highlightAssetIds;
  final String? summary;
  final VisualKpiSnapshot? metrics;
  final bool published;
  final String? publishedAt;

  @override
  ModelType get modelType => ModelType.publicDigest;

  @override
  Map<String, dynamic> toJson() => {
        'weekOf': weekOf,
        if (highlightAssetIds.isNotEmpty) 'highlightAssetIds': highlightAssetIds,
        if (summary != null && summary!.isNotEmpty) 'summary': summary,
        if (metrics != null) 'metrics': metrics!.toJson(),
        'published': published,
        if (publishedAt != null && publishedAt!.isNotEmpty)
          'publishedAt': publishedAt,
        ...super.toJson(),
      };

  @override
  PublicDigest copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    Map<String, dynamic>? metadata,
    String? weekOf,
    List<String>? highlightAssetIds,
    String? summary,
    VisualKpiSnapshot? metrics,
    bool? published,
    String? publishedAt,
  }) =>
      PublicDigest(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        createdById: createdById ?? this.createdById,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedById: updatedById ?? this.updatedById,
        organizationId: organizationId ?? this.organizationId,
        metadata: metadata ?? this.metadata,
        weekOf: weekOf ?? this.weekOf,
        highlightAssetIds: highlightAssetIds ?? this.highlightAssetIds,
        summary: summary ?? this.summary,
        metrics: metrics ?? this.metrics,
        published: published ?? this.published,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  @override
  List<Object?> get props => super.props + [
        weekOf,
        highlightAssetIds.join('|'),
        summary,
        metrics?.propsFingerprint,
        published,
        publishedAt,
      ];

  static List<String> _stringList(dynamic v) =>
      v is List ? v.whereType<String>().toList(growable: false) : const <String>[];
}

/// Minimal KPI snapshot for visual engagement.
class VisualKpiSnapshot {
  const VisualKpiSnapshot({
    this.exposures = 0,
    this.taps = 0,
    this.shares = 0,
    this.followClicks = 0,
    this.qrScans = 0,
  });

  factory VisualKpiSnapshot.fromJson(Map<String, dynamic> json) =>
      VisualKpiSnapshot(
        exposures: _int(json['exposures']),
        taps: _int(json['taps']),
        shares: _int(json['shares']),
        followClicks: _int(json['followClicks']),
        qrScans: _int(json['qrScans']),
      );

  static VisualKpiSnapshot? maybeFromJson(dynamic v) {
    if (v is Map) {
      return VisualKpiSnapshot.fromJson(Map<String, dynamic>.from(v));
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'exposures': exposures,
        'taps': taps,
        'shares': shares,
        'followClicks': followClicks,
        'qrScans': qrScans,
      };

  final int exposures;
  final int taps;
  final int shares;
  final int followClicks;
  final int qrScans;

  String get propsFingerprint =>
      [exposures, taps, shares, followClicks, qrScans].join('-');

  static int _int(dynamic v) => v is num ? v.toInt() : 0;
}

