// @tier: community
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart' as y;
import 'package:crypto/crypto.dart' as crypto;
import 'package:seafoundry_app/models/feature_purchase.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/tier.dart';

/// Maximally permissive feature access service.
///
/// Philosophy: App-layer feature gating is informational, not security.
/// Real security happens in Firestore rules (org data separation) and
/// cloud functions. This service provides UX hints about tier features
/// but doesn't enforce hard blocks.
///
/// The tier system (Community/Pro/Scale) helps guide users but should
/// not prevent access to features in most cases - it's primarily for
/// UI/UX guidance, not security enforcement.
///
/// Sources of truth (in priority order):
/// 1. License overrides: organization.metadata.license (signed payload)
/// 2. Tier-based access: organization.metadata.tier + manifest config
/// 3. Compile-time default via --dart-define=SF_TIER (defaults to community)
///
/// For features not in the manifest, the service defaults to ALLOWING access
/// (maximally permissive).
class FeatureAccessService extends ChangeNotifier {
  FeatureAccessService({
    required Tier defaultTier,
    String? organizationTier,
    String? licenseSecret,
  })  : _tier = organizationTier != null
            ? Tier.fromString(organizationTier)
            : defaultTier,
        _licenseSecret = licenseSecret ??
            const String.fromEnvironment('SF_LICENSE_SECRET') {
    assert(
      kDebugMode || _licenseSecret.isNotEmpty,
      'SF_LICENSE_SECRET must be set in production builds.',
    );
  }

  Tier _tier;
  Map<String, dynamic> _manifest = const {};
  Map<String, bool> _licenseFeatureOverrides = const {};
  DateTime? _licenseExpiresAt;
  bool _licenseApplied = false;
  String? _upgradeUrlOverride;
  final String _licenseSecret;

  // Purchase tracking (kept for structure but not used for gating)
  Map<String, FeaturePurchase> _activePurchases = const {};

  /// Returns the effective tier for the current organization.
  Tier get tier => _tier;

  bool get isCommunity => tier == Tier.community;
  bool get isPro => tier == Tier.pro;
  bool get isScale => tier == Tier.scale;

  /// Returns true if the user has at least Pro tier (Pro or Scale).
  /// Use this for gating Pro features that should also be available to Scale users.
  bool get isAtLeastPro => tier.allows(Tier.pro);
  DateTime? get licenseExpiresAt => _licenseExpiresAt;
  bool get hasValidLicense {
    if (!_licenseApplied) return false;
    if (_licenseExpiresAt == null) return true;
    return _licenseExpiresAt!.isAfter(DateTime.now());
  }

  String get tierLabel {
    final meta = _manifest['tiers']?[tier.name];
    final label = (meta is Map) ? meta['label']?.toString() : null;
    return label ?? tier.name;
  }

  /// Optional marketing/upgrade deep link based on the current tier.
  String? get upgradeUrl {
    if (_upgradeUrlOverride?.isNotEmpty ?? false) {
      return _upgradeUrlOverride;
    }
    final tiers = _manifest['tiers'];
    if (tiers is Map) {
      final current = tiers[tier.name];
      if (current is Map && current['upgrade_url'] != null) {
        return current['upgrade_url'].toString();
      }
    }
    return null;
  }

  /// Returns the upgrade URL for a required tier, if configured.
  ///
  /// Supports both legacy (upgrade_url on the current tier) and
  /// target-tier (upgrade_url on the required tier) manifests.
  String? upgradeUrlForTier(Tier requiredTier) {
    if (requiredTier.rank <= tier.rank) return null;
    if (_upgradeUrlOverride?.isNotEmpty ?? false) {
      return _upgradeUrlOverride;
    }

    final sourceTier = _upgradeSourceTier(requiredTier);
    final sourceUrl =
        sourceTier == null ? null : _upgradeUrlFromManifest(sourceTier);
    if (sourceUrl != null) return sourceUrl;

    return _upgradeUrlFromManifest(requiredTier);
  }

  /// Get all active purchases (kept for structure, not used for gating)
  Map<String, FeaturePurchase> get activePurchases => _activePurchases;

  /// Returns whether a named feature is enabled for the current organization.
  ///
  /// Maximally permissive approach:
  /// 1. License override takes precedence when valid
  /// 2. Check tier-based manifest
  /// 3. Unknown features default to ALLOWED (permissive)
  bool isFeatureEnabled(String featureKey) {
    // 1. License override takes precedence when valid and not expired
    if (_licenseFeatureOverrides.isNotEmpty) {
      final now = DateTime.now();
      if (_licenseExpiresAt == null || _licenseExpiresAt!.isAfter(now)) {
        final override = _licenseFeatureOverrides[featureKey];
        if (override != null) return override;
      }
    }

    // 2. Tier-based manifest lookup
    final tiers = _manifest['tiers'];
    if (tiers is Map) {
      final current = tiers[tier.name];
      if (current is Map) {
        final features = current['features'];
        if (features is Map && features.containsKey(featureKey)) {
          final value = features[featureKey];
          if (value is bool) return value;
        }
      }
    }

    // 3. Unknown features default to ALLOWED (maximally permissive)
    return true;
  }

  /// Get the purchase status for a feature (for UI display)
  ///
  /// Returns legacy tier-based status since we've simplified to tier-only access.
  FeaturePurchaseStatus getPurchaseStatus(String featureKey) {
    return FeaturePurchaseStatus.legacyTierBased;
  }

  /// Get the purchase for a specific feature (if any)
  FeaturePurchase? getPurchase(String featureKey) {
    return _activePurchases[featureKey];
  }

  /// Apply purchases (kept for structure, does not affect feature gating)
  ///
  /// This stores purchases for reference but doesn't use them for access control.
  void applyPurchases(List<FeaturePurchase> purchases) {
    _activePurchases = {
      for (final p in purchases.where((p) => p.status == PurchaseStatus.active))
        p.featureKey: p,
    };
    notifyListeners();
  }

  /// Clear all purchases
  void clearPurchases() {
    _activePurchases = const {};
    notifyListeners();
  }

  // Convenience helpers for common gating checks - tier-based only
  bool get supportsMortalityReasons => isFeatureEnabled('mortality_reasons');
  bool get supportsObservationActions =>
      isFeatureEnabled('observation_actions');
  bool get supportsHusbandryActions => isFeatureEnabled('husbandry_actions');
  bool get supportsMonitoringDialog => isFeatureEnabled('monitoring_dialog');
  bool get supportsMonitoringWorkspace =>
      isFeatureEnabled('monitoring_workspace');

  /// Limited monitoring workspace access for baseline/reference sites only.
  /// Community tier has this enabled while full monitoring_workspace is disabled.
  bool get supportsMonitoringWorkspaceLimited =>
      isFeatureEnabled('monitoring_workspace_limited');

  /// Whether the user has any monitoring workspace access (full or limited).
  bool get hasAnyMonitoringAccess =>
      supportsMonitoringWorkspace || supportsMonitoringWorkspaceLimited;

  bool get supportsAiCopilot => isFeatureEnabled('ai_copilot');
  bool get supportsOperationsHub => isFeatureEnabled('operations_hub');
  bool get supportsComments => isFeatureEnabled('comments');
  bool get supportsSiteChat => isFeatureEnabled('site_chat');
  bool get supportsVisualEngagementPhaseD =>
      isFeatureEnabled('visual_engagement_phase_d');
  bool get supportsVisualEngagementPhaseEF =>
      isFeatureEnabled('visual_engagement_phase_e_f');

  /// Replace with targeted refresh when org metadata changes.
  void updateTierFromOrganizationMetadata(Map<String, dynamic>? metadata) {
    final raw = metadata?['tier'] ?? metadata?['plan'];
    if (raw != null) {
      _tier = Tier.fromString(raw.toString());
    }
    _upgradeUrlOverride = _normalizeUpgradeUrl(
      metadata?['upgradeUrl'] ?? metadata?['upgrade_url'],
    );
  }

  /// Reads a license payload from organization metadata and applies feature overrides.
  /// Expected shape (flexible, best-effort):
  ///   license: {
  ///     tier: 'pro'|'scale' (optional),
  ///     features: { mortality_reasons: true, offline_sync: true, ... },
  ///     expiresAt: isoString|millisecondsSinceEpoch (optional),
  ///     signature: 'base64...' (optional)
  ///   }
  void applyLicenseFromMetadata(Map<String, dynamic>? metadata) {
    _licenseApplied = false;
    _licenseFeatureOverrides = const {};
    _licenseExpiresAt = null;
    final baseUpgradeUrl = _normalizeUpgradeUrl(
      metadata?['upgradeUrl'] ?? metadata?['upgrade_url'],
    );
    _upgradeUrlOverride = baseUpgradeUrl;

    final baseTierRaw = metadata?['tier'] ?? metadata?['plan'];
    if (baseTierRaw != null) {
      _tier = Tier.fromString(baseTierRaw.toString());
    }

    final license = metadata?['license'];
    if (license is! Map) return;

    final evaluation = _evaluateLicense(license);
    if (!evaluation.valid) {
      _licenseExpiresAt = evaluation.expiresAt;
      return;
    }

    _licenseApplied = true;
    _licenseFeatureOverrides = evaluation.features;
    _licenseExpiresAt = evaluation.expiresAt;
    if (evaluation.upgradeUrl != null) {
      _upgradeUrlOverride = evaluation.upgradeUrl;
    }
    if (evaluation.tier != null) {
      _tier = evaluation.tier!;
    }
  }

  /// Loads the manifest from bundled YAML. Safe to call multiple times.
  Future<void> loadManifest({
    String assetPath = 'config/tier_features.yaml',
  }) async {
    try {
      final yaml = await rootBundle.loadString(assetPath);
      final doc = y.loadYaml(yaml);
      _manifest = jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      // Keep an empty manifest and rely on permissive defaults
      LoggingService.instance.error(
        'Failed to load tier features manifest from $assetPath - using permissive defaults',
        e,
        stackTrace,
      );
      _manifest = const {};
    }
  }

  /// Load manifest from a raw YAML string. Useful for testing where
  /// [rootBundle] is not available.
  @visibleForTesting
  void loadManifestFromString(String yaml) {
    final doc = y.loadYaml(yaml);
    _manifest = jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
  }

  _LicenseEvaluation _evaluateLicense(Map<dynamic, dynamic> license) {
    final expiresAt = _tryParseDate(license['expiresAt']);
    final now = DateTime.now();
    if (expiresAt != null && !expiresAt.isAfter(now)) {
      return _LicenseEvaluation(
        valid: false,
        features: const {},
        expiresAt: expiresAt,
        reason: 'expired',
      );
    }

    final normalizedUpgradeUrl = _normalizeUpgradeUrl(
      license['upgradeUrl'] ?? license['upgrade_url'],
    );
    final features = _parseFeatureOverrides(license['features']);
    final tierOverrideRaw = license['tier'];
    final tierOverride = tierOverrideRaw != null
        ? Tier.fromString(tierOverrideRaw.toString())
        : null;
    bool upgradeUrlSigned = true;

    // In production, license secret must be set
    if (!kDebugMode && _licenseSecret.isEmpty) {
      throw StateError(
        'SF_LICENSE_SECRET must be set in production builds for license validation',
      );
    }

    // If secret is provided, validate signature
    if (_licenseSecret.isNotEmpty) {
      final providedSig = license['signature']?.toString();
      if (providedSig == null || providedSig.isEmpty) {
        return _LicenseEvaluation(
          valid: false,
          features: const {},
          expiresAt: expiresAt,
          reason: 'missing_signature',
        );
      }
      final expected = _computeLicenseSignature(license, _licenseSecret,
          includeUpgradeUrl: true);
      if (expected != providedSig) {
        // Legacy fallback (pre-upgradeUrl signing). Accept features/tier but drop upgradeUrl override.
        final legacyExpected = _computeLicenseSignature(
            license, _licenseSecret,
            includeUpgradeUrl: false);
        if (legacyExpected != providedSig) {
          return _LicenseEvaluation(
            valid: false,
            features: const {},
            expiresAt: expiresAt,
            reason: 'invalid_signature',
          );
        }
        upgradeUrlSigned = false;
      }
    } else if (kDebugMode) {
      // In debug mode without secret, allow unsigned licenses
      return _LicenseEvaluation(
        valid: true,
        features: features,
        tier: tierOverride,
        expiresAt: expiresAt,
        upgradeUrl: normalizedUpgradeUrl,
      );
    }

    return _LicenseEvaluation(
      valid: true,
      features: features,
      tier: tierOverride,
      expiresAt: expiresAt,
      upgradeUrl: upgradeUrlSigned ? normalizedUpgradeUrl : null,
    );
  }

  Map<String, bool> _parseFeatureOverrides(dynamic value) {
    if (value is! Map) return const {};
    final overrides = <String, bool>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val is bool) {
        overrides[key] = val;
      }
    }
    return overrides;
  }

  static String? _normalizeUpgradeUrl(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !(uri.hasScheme && (uri.isScheme('http') || uri.isScheme('https')))) {
      return null;
    }
    return uri.toString();
  }

  String? _upgradeUrlFromManifest(Tier tier) {
    final tiers = _manifest['tiers'];
    if (tiers is Map) {
      final current = tiers[tier.name];
      if (current is Map) {
        return _normalizeUpgradeUrl(current['upgrade_url']);
      }
    }
    return null;
  }

  static Tier? _upgradeSourceTier(Tier targetTier) {
    switch (targetTier) {
      case Tier.community:
        return null;
      case Tier.pro:
        return Tier.community;
      case Tier.scale:
        return Tier.pro;
    }
  }

  // Tier parsing now uses Tier.fromString from tier.dart

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      } catch (e) {
        LoggingService.instance.warning(
          'Failed to parse date from milliseconds value: $value - $e',
        );
        return null;
      }
    }
    final s = value.toString();
    try {
      return DateTime.parse(s);
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to parse date from string value: $s - $e',
      );
      return null;
    }
  }

  static String _computeLicenseSignature(
    Map<dynamic, dynamic> license,
    String secret, {
    bool includeUpgradeUrl = true,
  }) {
    // Build a canonical string: tier|expiresAt(ms)|upgradeUrl|features(sorted key=value)
    final tier = (license['tier'] ?? '').toString();
    final expiresAt = _canonicalMillis(license['expiresAt']);
    final upgradeUrl = includeUpgradeUrl
        ? (_normalizeUpgradeUrl(
                license['upgradeUrl'] ?? license['upgrade_url']) ??
            '')
        : '';
    final features = <String>[];
    final feats = license['features'];
    if (feats is Map) {
      for (final entry in feats.entries) {
        final key = entry.key.toString();
        final val = entry.value is bool ? (entry.value as bool) : false;
        features.add('$key=${val ? 1 : 0}');
      }
    }
    features.sort();
    final payload = '$tier|$expiresAt|$upgradeUrl|${features.join(';')}';
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(payload));
    return base64Url.encode(digest.bytes);
  }

  static int _canonicalMillis(dynamic value) {
    final dt = _tryParseDate(value);
    if (dt == null) return 0;
    return dt.millisecondsSinceEpoch;
  }

  /// Compile-time default from --dart-define=SF_TIER (community by default)
  static Tier compileTimeDefault() {
    const raw = String.fromEnvironment('SF_TIER', defaultValue: 'community');
    return Tier.fromString(raw);
  }
}

/// Status of a feature purchase for UI display
enum FeaturePurchaseStatus {
  /// Feature is not purchased
  notPurchased,

  /// Feature is actively purchased and valid
  active,

  /// Feature purchase has expired
  expired,

  /// Using legacy tier-based access (not purchase-based)
  legacyTierBased,
}

class _LicenseEvaluation {
  const _LicenseEvaluation({
    required this.valid,
    required this.features,
    this.tier,
    this.expiresAt,
    this.upgradeUrl,
    this.reason,
  });

  final bool valid;
  final Map<String, bool> features;
  final Tier? tier;
  final DateTime? expiresAt;
  final String? upgradeUrl;
  final String? reason;
}
