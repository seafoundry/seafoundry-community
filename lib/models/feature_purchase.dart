// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of purchase for a feature
enum PurchaseType {
  subscription,
  oneTime;

  static PurchaseType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'subscription':
        return PurchaseType.subscription;
      case 'one_time':
      case 'onetime':
        return PurchaseType.oneTime;
      default:
        return PurchaseType.subscription;
    }
  }

  String toJson() {
    switch (this) {
      case PurchaseType.subscription:
        return 'subscription';
      case PurchaseType.oneTime:
        return 'one_time';
    }
  }
}

/// Status of a feature purchase
enum PurchaseStatus {
  active,
  canceled,
  expired,
  pastDue;

  static PurchaseStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return PurchaseStatus.active;
      case 'canceled':
      case 'cancelled':
        return PurchaseStatus.canceled;
      case 'expired':
        return PurchaseStatus.expired;
      case 'past_due':
      case 'pastdue':
        return PurchaseStatus.pastDue;
      default:
        return PurchaseStatus.active;
    }
  }

  String toJson() {
    switch (this) {
      case PurchaseStatus.active:
        return 'active';
      case PurchaseStatus.canceled:
        return 'canceled';
      case PurchaseStatus.expired:
        return 'expired';
      case PurchaseStatus.pastDue:
        return 'past_due';
    }
  }
}

/// Represents a purchased feature for an organization
///
/// Stored in Firestore at: organizations/{orgId}/purchases/{purchaseId}
class FeaturePurchase {
  /// Unique identifier for this purchase
  final String id;

  /// Organization that owns this purchase
  final String organizationId;

  /// The feature key that was purchased (e.g., 'ai_copilot', 'offline_sync')
  final String featureKey;

  /// Whether this is a subscription or one-time purchase
  final PurchaseType purchaseType;

  /// Stripe customer ID for the organization
  final String stripeCustomerId;

  /// Stripe subscription ID (for subscriptions only)
  final String? stripeSubscriptionId;

  /// Stripe payment intent ID (for one-time purchases)
  final String? stripePaymentIntentId;

  /// Stripe price ID used for this purchase
  final String stripePriceId;

  /// Current status of the purchase
  final PurchaseStatus status;

  /// When the purchase was made
  final DateTime purchasedAt;

  /// When the subscription expires (null for perpetual one-time purchases)
  final DateTime? expiresAt;

  /// When the subscription was canceled (if applicable)
  final DateTime? canceledAt;

  /// User ID of the admin who made the purchase
  final String purchasedByUserId;

  /// When this record was created
  final DateTime createdAt;

  /// When this record was last updated
  final DateTime updatedAt;

  /// Whether this was created via migration from legacy tier system
  final bool isMigrated;

  /// Original tier if migrated (for reference)
  final String? originalTier;

  const FeaturePurchase({
    required this.id,
    required this.organizationId,
    required this.featureKey,
    required this.purchaseType,
    required this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.stripePaymentIntentId,
    required this.stripePriceId,
    required this.status,
    required this.purchasedAt,
    this.expiresAt,
    this.canceledAt,
    required this.purchasedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.isMigrated = false,
    this.originalTier,
  });

  /// Whether this purchase is currently valid and grants feature access
  bool get isValid {
    if (status != PurchaseStatus.active) return false;
    if (expiresAt == null) return true; // Perpetual one-time purchase
    return expiresAt!.isAfter(DateTime.now());
  }

  /// Whether this is a subscription purchase
  bool get isSubscription => purchaseType == PurchaseType.subscription;

  /// Whether this is a one-time purchase
  bool get isOneTime => purchaseType == PurchaseType.oneTime;

  /// Whether the subscription has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  /// Days until expiration (null if no expiration)
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (expiresAt!.isBefore(now)) return 0;
    return expiresAt!.difference(now).inDays;
  }

  /// Create from Firestore document
  factory FeaturePurchase.fromJson(Map<String, dynamic> json, {String? id}) {
    return FeaturePurchase(
      id: id ?? json['id'] as String,
      organizationId: json['organizationId'] as String,
      featureKey: json['featureKey'] as String,
      purchaseType: PurchaseType.fromString(json['purchaseType'] as String),
      stripeCustomerId: json['stripeCustomerId'] as String,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
      stripePriceId: json['stripePriceId'] as String,
      status: PurchaseStatus.fromString(json['status'] as String),
      purchasedAt: _parseDateTime(json['purchasedAt']),
      expiresAt: json['expiresAt'] != null
          ? _parseDateTime(json['expiresAt'])
          : null,
      canceledAt: json['canceledAt'] != null
          ? _parseDateTime(json['canceledAt'])
          : null,
      purchasedByUserId: json['purchasedByUserId'] as String,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      isMigrated: json['_migrated'] as bool? ?? false,
      originalTier: json['_originalTier'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'featureKey': featureKey,
      'purchaseType': purchaseType.toJson(),
      'stripeCustomerId': stripeCustomerId,
      if (stripeSubscriptionId != null)
        'stripeSubscriptionId': stripeSubscriptionId,
      if (stripePaymentIntentId != null)
        'stripePaymentIntentId': stripePaymentIntentId,
      'stripePriceId': stripePriceId,
      'status': status.toJson(),
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (canceledAt != null) 'canceledAt': Timestamp.fromDate(canceledAt!),
      'purchasedByUserId': purchasedByUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (isMigrated) '_migrated': isMigrated,
      if (originalTier != null) '_originalTier': originalTier,
    };
  }

  /// Create a copy with updated fields
  FeaturePurchase copyWith({
    String? id,
    String? organizationId,
    String? featureKey,
    PurchaseType? purchaseType,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    String? stripePaymentIntentId,
    String? stripePriceId,
    PurchaseStatus? status,
    DateTime? purchasedAt,
    DateTime? expiresAt,
    DateTime? canceledAt,
    String? purchasedByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMigrated,
    String? originalTier,
  }) {
    return FeaturePurchase(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      featureKey: featureKey ?? this.featureKey,
      purchaseType: purchaseType ?? this.purchaseType,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
      status: status ?? this.status,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      canceledAt: canceledAt ?? this.canceledAt,
      purchasedByUserId: purchasedByUserId ?? this.purchasedByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMigrated: isMigrated ?? this.isMigrated,
      originalTier: originalTier ?? this.originalTier,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'FeaturePurchase(id: $id, featureKey: $featureKey, '
        'status: $status, isValid: $isValid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeaturePurchase && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
