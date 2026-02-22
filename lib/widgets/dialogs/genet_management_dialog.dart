// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';
import 'package:seafoundry_app/cubits/genet_alias/genet_alias_cubit.dart';
import 'package:seafoundry_app/cubits/genet_edit_name/genet_edit_name_cubit.dart';
import 'package:seafoundry_app/cubits/genet_removal/genet_removal_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_alias_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_edit_name_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_merge_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_removal_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/genet_split_dialog.dart';

/// Mode for genet management operations
enum GenetManagementMode { editName, remove, editAliases, split, merge }

/// Rich result describing management dialog outcomes.
class GenetManagementResult {
  const GenetManagementResult({
    this.record,
    this.primaryRecord,
    this.createdRecords = const [],
    this.archivedGenetIds = const [],
    this.reassignedCoralCount = 0,
  });

  final ProvenanceRecord? record;
  final ProvenanceRecord? primaryRecord;
  final List<ProvenanceRecord> createdRecords;
  final List<String> archivedGenetIds;
  final int reassignedCoralCount;

  bool get hasChanges =>
      record != null ||
      createdRecords.isNotEmpty ||
      archivedGenetIds.isNotEmpty ||
      reassignedCoralCount > 0;
}

/// Unified entry point for genet management dialogs.
class GenetManagementDialog {
  GenetManagementDialog._();

  static Future<GenetManagementResult?> show(
    BuildContext context, {
    required GenetManagementMode mode,
    required ProvenanceRecord record,
    VoidCallback? onUpdated,
  }) async {
    final provenanceRepository = context.read<ProvenanceRepository>();

    switch (mode) {
      case GenetManagementMode.editName:
        final genetRepository = context.read<GenetRepository>();
        return _showDialog(
          context,
          providers: [
            RepositoryProvider<ProvenanceRepository>.value(
              value: provenanceRepository,
            ),
            RepositoryProvider<GenetRepository>.value(
              value: genetRepository,
            ),
          ],
          child: BlocProvider(
            create: (_) => GenetEditNameCubit(
              initialName: record.displayName,
              genetRepository: genetRepository,
            ),
            child: GenetEditNameDialog(record: record, onUpdated: onUpdated),
          ),
        );

      case GenetManagementMode.remove:
        final organismRepository = context.read<OrganismRecordRepository>();
        return _showDialog(
          context,
          providers: [
            RepositoryProvider<ProvenanceRepository>.value(
              value: provenanceRepository,
            ),
            RepositoryProvider<OrganismRecordRepository>.value(
              value: organismRepository,
            ),
          ],
          child: BlocProvider(
            create: (_) => GenetRemovalCubit(),
            child: GenetRemovalDialog(record: record, onUpdated: onUpdated),
          ),
        );

      case GenetManagementMode.editAliases:
        final provenanceLookupService =
            context.maybeRead<ProvenanceLookupService>();
        return _showDialog(
          context,
          providers: [
            RepositoryProvider<ProvenanceRepository>.value(
              value: provenanceRepository,
            ),
          ],
          child: BlocProvider(
            create: (_) => GenetAliasCubit(
              record: record,
              provenanceRepository: provenanceRepository,
              provenanceLookupService: provenanceLookupService,
            ),
            child: GenetAliasDialog(record: record, onUpdated: onUpdated),
          ),
        );

      case GenetManagementMode.split:
        return _showDialog(
          context,
          providers: [
            RepositoryProvider<ProvenanceRepository>.value(
              value: provenanceRepository,
            ),
          ],
          child: GenetSplitDialog(record: record, onUpdated: onUpdated),
        );

      case GenetManagementMode.merge:
        final organismRepository = context.read<OrganismRecordRepository>();
        final genetRepository = context.read<GenetRepository>();
        return _showDialog(
          context,
          providers: [
            RepositoryProvider<ProvenanceRepository>.value(
              value: provenanceRepository,
            ),
            RepositoryProvider<OrganismRecordRepository>.value(
              value: organismRepository,
            ),
            RepositoryProvider<GenetRepository>.value(value: genetRepository),
          ],
          child: GenetMergeDialog(record: record, onUpdated: onUpdated),
        );
    }
  }

  static Future<GenetManagementResult?> _showDialog(
    BuildContext context, {
    required List<SingleChildWidget> providers,
    required Widget child,
  }) {
    return showDialog<GenetManagementResult>(
      context: context,
      useRootNavigator: false,
      builder: (_) => MultiRepositoryProvider(providers: providers, child: child),
    );
  }
}
