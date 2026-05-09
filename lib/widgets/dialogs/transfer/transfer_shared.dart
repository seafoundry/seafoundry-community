// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/base_search_dialog.dart';

/// Returns the display label for a [Genet]: trimmed localId if present,
/// otherwise trimmed name.
String genetDisplayLabel(Genet genet) {
  final localId = genet.localId?.trim();
  if (localId != null && localId.isNotEmpty) return localId;
  return genet.name.trim();
}

class OrganizationSearchDialog extends BaseSearchDialog<Organization> {
  final OrganizationRepository repository;

  /// Organization ID to exclude from search results (typically the current org).
  final String? excludeOrganizationId;

  const OrganizationSearchDialog({
    super.key,
    required this.repository,
    this.excludeOrganizationId,
  });

  @override
  State<BaseSearchDialog<Organization>> createState() =>
      _OrganizationSearchDialogState();
}

class _OrganizationSearchDialogState
    extends BaseSearchDialogState<Organization> {
  @override
  int get maxRecentItems => 20;

  @override
  String get title => 'Select Organization';

  @override
  Widget? get titleIcon => const Icon(Icons.business, color: Colors.blue);

  @override
  String get searchHint => 'Search organizations...';

  OrganizationSearchDialog get _widget =>
      widget as OrganizationSearchDialog;

  @override
  Future<List<Organization>> performSearch(String query) async {
    try {
      final result = await _widget.repository.searchOrganizations(
        query: query,
        limit: 25,
      );
      // Filter out the excluded organization (e.g., user's own organization)
      final excludeId = _widget.excludeOrganizationId;
      if (excludeId != null) {
        return result.items.where((org) => org.id != excludeId).toList();
      }
      return result.items;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to search organizations',
        e,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Future<List<Organization>> loadRecentItems() async {
    try {
      final result = await _widget.repository.searchOrganizations(
        query: '',
        limit: maxRecentItems,
      );
      final excludeId = _widget.excludeOrganizationId;
      if (excludeId != null) {
        return result.items.where((org) => org.id != excludeId).toList();
      }
      return result.items;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load recent organizations',
        e,
        stackTrace,
      );
      return [];
    }
  }

  @override
  Widget buildSearchResult(BuildContext context, Organization item) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.business)),
      title: Text(item.name),
      subtitle: Text('${item.domain} • ${item.id}'),
    );
  }

  @override
  String getItemId(Organization item) => item.id;

  @override
  String getItemDisplayName(Organization item) => item.name;
}

