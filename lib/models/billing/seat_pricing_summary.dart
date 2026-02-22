// @tier: community
import 'package:seafoundry_app/models/invitation.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/models/user.dart';

class SeatRoleSummary {
  const SeatRoleSummary({
    required this.role,
    required this.total,
    required this.included,
    required this.billable,
  });

  final UserRole role;
  final int total;
  final int included;
  final int billable;

  int get monthlyCostUsd => billable * role.monthlyPriceUsd;
}

class SeatPricingSummary {
  const SeatPricingSummary({
    required this.tier,
    required this.roles,
    required this.totalMembers,
    required this.totalInvitations,
    required this.totalMonthlyCostUsd,
    required this.adminLimit,
    required this.adminOverLimit,
    required this.practitionerLimit,
    required this.practitionerOverLimit,
  });

  static const int unlimitedSeats = -1;
  static const int communityAdminSeatLimit = 2;
  static const int proAdminSeatLimit = 2;
  static const int proPractitionerSeatLimit = 3;
  static const int communityIncludedAdminSeats = 2;
  static const int proIncludedAdminSeats = 2;
  static const int proIncludedPractitionerPlusSeats = 3;
  static const int scaleIncludedPractitionerPlusSeats = 7;

  final Tier tier;
  final List<SeatRoleSummary> roles;
  final int totalMembers;
  final int totalInvitations;
  final int totalMonthlyCostUsd;
  final int adminLimit;
  final bool adminOverLimit;
  final int practitionerLimit;
  final bool practitionerOverLimit;

  int get totalSeats => totalMembers + totalInvitations;

  SeatRoleSummary summaryFor(UserRole role) {
    return roles.firstWhere((summary) => summary.role == role);
  }

  static SeatPricingSummary fromRoster({
    required Tier tier,
    required List<User> members,
    required List<Invitation> invitations,
  }) {
    final pendingInvitations = invitations.where((invite) => invite.isPending);
    final roleCounts = {
      for (final role in UserRole.values) role: 0,
    };

    for (final member in members) {
      final role = _resolveUserRole(member);
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }

    for (final invite in pendingInvitations) {
      final role = _resolveInvitationRole(invite);
      roleCounts[role] = (roleCounts[role] ?? 0) + 1;
    }

    final summaries = <SeatRoleSummary>[];
    var totalMonthlyCost = 0;

    for (final role in UserRole.values) {
      final total = roleCounts[role] ?? 0;
      final included = _includedSeatsForRole(tier, role);
      final billable = total > included ? total - included : 0;
      final summary = SeatRoleSummary(
        role: role,
        total: total,
        included: included,
        billable: billable,
      );
      summaries.add(summary);
      totalMonthlyCost += summary.monthlyCostUsd;
    }

    final adminCount = roleCounts[UserRole.admin] ?? 0;
    final practitionerCount = roleCounts[UserRole.practitioner] ?? 0;
    final adminLimit = _limitForRole(tier, UserRole.admin);
    final practitionerLimit = _limitForRole(tier, UserRole.practitioner);

    return SeatPricingSummary(
      tier: tier,
      roles: summaries,
      totalMembers: members.length,
      totalInvitations: pendingInvitations.length,
      totalMonthlyCostUsd: totalMonthlyCost,
      adminLimit: adminLimit,
      adminOverLimit: adminLimit >= 0 && adminCount > adminLimit,
      practitionerLimit: practitionerLimit,
      practitionerOverLimit:
          practitionerLimit >= 0 && practitionerCount > practitionerLimit,
    );
  }

  static UserRole _resolveUserRole(User user) {
    return UserRole.fromId(user.role) ?? UserRole.practitioner;
  }

  static UserRole _resolveInvitationRole(Invitation invitation) {
    return UserRole.fromId(invitation.role) ?? UserRole.practitioner;
  }

  static int _includedSeatsForRole(Tier tier, UserRole role) {
    final proOrScale =
        tier == Tier.pro || tier == Tier.scale;
    if (role == UserRole.admin) {
      return proOrScale
          ? proIncludedAdminSeats
          : communityIncludedAdminSeats;
    }
    if (role == UserRole.practitionerPlus) {
      if (tier == Tier.scale) {
        return scaleIncludedPractitionerPlusSeats;
      }
      if (tier == Tier.pro) {
        return proIncludedPractitionerPlusSeats;
      }
    }
    return 0;
  }

  static int _limitForRole(Tier tier, UserRole role) {
    if (tier == Tier.scale) {
      return unlimitedSeats;
    }
    if (tier == Tier.pro) {
      if (role == UserRole.admin) {
        return proAdminSeatLimit;
      }
      if (role == UserRole.practitioner) {
        return proPractitionerSeatLimit;
      }
      return unlimitedSeats;
    }
    if (role == UserRole.admin) {
      return communityAdminSeatLimit;
    }
    return unlimitedSeats;
  }
}
