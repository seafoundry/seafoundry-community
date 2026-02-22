// @tier: community
import 'package:flutter/material.dart';

/// Banner showing custody information in dialogs/screens.
///
/// Displays an informational banner when viewing or editing organisms
/// that are managed on behalf of another organization. Optionally
/// provides a decline custody action.
class CustodyInfoBanner extends StatelessWidget {
  const CustodyInfoBanner({
    super.key,
    required this.ownerOrganizationName,
    this.showDeclineOption = false,
    this.onDecline,
  });

  final String ownerOrganizationName;
  final bool showDeclineOption;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You will manage these organisms on behalf of '
                  '$ownerOrganizationName',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (showDeclineOption && onDecline != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDecline,
                child: Text(
                  'Decline custody',
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner for edit dialogs when current user is a custodian.
///
/// Explains that identity fields are locked and only location/quantity
/// can be edited while managing organisms on behalf of another organization.
class CustodyEditRestrictionBanner extends StatelessWidget {
  const CustodyEditRestrictionBanner({
    super.key,
    required this.ownerOrganizationId,
  });

  final String ownerOrganizationId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custody Mode',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This organism is owned by $ownerOrganizationId. '
                  'You can update location and quantity, but identity '
                  'fields are managed by the owner.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
