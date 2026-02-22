// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site_activity_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Widget for managing organization activities in the admin panel.
/// Allows adding/removing activities and saves changes to Firestore.
///
/// Activities are filtered based on [supportedKinds] - only activities
/// related to enabled organism types are shown. Non-coral organism activities
/// (kelp, seagrass, mangrove, etc.) are hidden by default unless those
/// organism types are explicitly enabled for the organization.
class OrganizationActivitiesWidget extends StatefulWidget {
  const OrganizationActivitiesWidget({
    required this.organization,
    required this.repository,
    required this.userId,
    this.supportedKinds = const [],
    super.key,
  });

  final Organization organization;
  final OrganizationRepository repository;
  final String userId;

  /// List of organism kinds enabled for this organization.
  /// If empty, only coral-related activities are shown by default.
  final List<OrganismKind> supportedKinds;

  @override
  State<OrganizationActivitiesWidget> createState() =>
      _OrganizationActivitiesWidgetState();
}

class _OrganizationActivitiesWidgetState
    extends State<OrganizationActivitiesWidget> {
  late Set<String> _selectedActivityIds;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _selectedActivityIds = Set<String>.from(widget.organization.activities);
  }

  Future<void> _saveActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await widget.repository.updateActivities(
        organizationId: widget.organization.id,
        activityIds: _selectedActivityIds.toList(),
        updatedById: widget.userId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Activities updated successfully';
        });

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update organization activities',
        e,
        stackTrace,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to update activities: ${e.toString()}';
        });
      }
    }
  }

  void _toggleActivity(String activityId) {
    setState(() {
      if (_selectedActivityIds.contains(activityId)) {
        _selectedActivityIds.remove(activityId);
      } else {
        _selectedActivityIds.add(activityId);
      }
    });
  }

  /// Check if an activity's organism kind is supported
  bool _isSupportedActivity(SiteActivityType activity) {
    final activityKind = activity.siteType.organismKind;

    // If no kinds specified, default to coral only
    if (widget.supportedKinds.isEmpty) {
      return activityKind == OrganismKind.coral;
    }

    return widget.supportedKinds.contains(activityKind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter activities based on supported organism kinds
    final allActivities = SiteActivityType.builtins
        .where(_isSupportedActivity)
        .toList();

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organization Activities',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the activities your organization performs',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),

            // Activity checkboxes
            ...allActivities.map((activity) {
              final isSelected = _selectedActivityIds.contains(activity.id);
              return CheckboxListTile(
                title: Text(activity.name),
                value: isSelected,
                onChanged: _isLoading
                    ? null
                    : (_) => _toggleActivity(activity.id),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            }),

            const SizedBox(height: 24),

            // Status messages
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),

            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _successMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

            // Save button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveActivities,
                  child: const Text('Save Activities'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
