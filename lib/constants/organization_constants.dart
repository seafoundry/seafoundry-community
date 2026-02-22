// @tier: community
import 'package:seafoundry_app/services/tier.dart';

const int communityMemberLimit = 2;
const bool communityInvitationsEnabled = false;

bool isCommunityTier(Tier tier) {
  return tier.isCommunity;
}
