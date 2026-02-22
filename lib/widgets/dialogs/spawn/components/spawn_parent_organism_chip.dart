// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import '../../../spreadsheet/safe_provider_mixin.dart';

class SpawnParentOrganismChip extends StatelessWidget {
  const SpawnParentOrganismChip({
    super.key,
    required this.organismId,
    required this.onDeleted,
  });

  final String organismId;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final organismRepository = context.maybeRead<OrganismRecordRepository>();
    if (organismRepository == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 250),
        child: Chip(
          label: Text(
            organismId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: onDeleted,
        ),
      );
    }

    return FutureBuilder<String>(
      future: _resolveDisplayName(organismRepository, organismId),
      builder: (context, snapshot) {
        final label = snapshot.data ?? organismId;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Chip(
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: onDeleted,
          ),
        );
      },
    );
  }

  static Future<String> _resolveDisplayName(
    OrganismRecordRepository repository,
    String id,
  ) async {
    try {
      final organism = await repository.getRecordForId(id);
      if (organism == null) {
        return id;
      }
      final species = SpeciesRegistry.globalById(organism.speciesId);
      final code = species?.code ?? 'UNKNOWN';
      return '${organism.name.isNotEmpty ? organism.name : organism.id} ($code)';
    } catch (error) {
      LoggingService.instance.warning(
        'Failed to resolve organism display name: $error',
        {'organismId': id},
      );
      return id;
    }
  }
}
