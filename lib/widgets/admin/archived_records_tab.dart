// @tier: community
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubits/archived_records/archived_records_cubit.dart';
import '../../cubits/archived_records/archived_records_state.dart';
import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../services/firebase_service.dart';
import '../dialogs/components/safe_dialog.dart';
import '../ui.dart';

class ArchivedRecordsTab extends StatelessWidget {
  const ArchivedRecordsTab({
    super.key,
    required this.organization,
    required this.user,
  });

  final Organization organization;
  final User user;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirebaseService>().firestore;
    return BlocProvider(
      create: (_) => ArchivedRecordsCubit(
        organismRepository: ArchivedOrganismRecordRepository(
          organization: organization,
          user: user,
          firestore: firestore,
        ),
        genetRepository: ArchivedGenetRepository(
          organization: organization,
          user: user,
          firestore: firestore,
        ),
        missionRepository: ArchivedMissionRepository(
          organization: organization,
          user: user,
          firestore: firestore,
        ),
      ),
      child: const _ArchivedRecordsView(),
    );
  }
}

class _ArchivedRecordsView extends StatelessWidget {
  const _ArchivedRecordsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: UI.surfaceColor,
            elevation: 1,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Organisms'),
                Tab(text: 'Genets'),
                Tab(text: 'Missions'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrganisms(context),
                _buildGenets(context),
                _buildMissions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganisms(BuildContext context) {
    return BlocSelector<ArchivedRecordsCubit, ArchivedRecordsState,
        List<OrganismRecord>>(
      selector: (state) => state.organisms,
      builder: (context, records) {
        if (records.isEmpty) {
          return const Center(child: Text('No archived organisms.'));
        }
        return ListView.separated(
          padding: UI.screenPaddingAll,
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = records[index];
            final title = record.recordName.trim().isNotEmpty
                ? record.recordName
                : (record.localId ?? record.id);
            return ListTile(
              title: Text(title),
              subtitle: Text(_archiveSubtitle(record.metadata)),
              trailing: IconButton(
                tooltip: 'Restore',
                icon: const Icon(Icons.restore),
                onPressed: () => _confirmRestore(
                  context,
                  label: title,
                  onRestore: () =>
                      context.read<ArchivedRecordsCubit>().restoreOrganism(
                            record,
                          ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGenets(BuildContext context) {
    return BlocSelector<ArchivedRecordsCubit, ArchivedRecordsState, List<Genet>>(
      selector: (state) => state.genets,
      builder: (context, records) {
        if (records.isEmpty) {
          return const Center(child: Text('No archived genets.'));
        }
        return ListView.separated(
          padding: UI.screenPaddingAll,
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = records[index];
            return ListTile(
              title: Text(record.displayName),
              subtitle: Text(_archiveSubtitle(record.metadata)),
              trailing: IconButton(
                tooltip: 'Restore',
                icon: const Icon(Icons.restore),
                onPressed: () => _confirmRestore(
                  context,
                  label: record.displayName,
                  onRestore: () =>
                      context.read<ArchivedRecordsCubit>().restoreGenet(record),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMissions(BuildContext context) {
    return BlocSelector<ArchivedRecordsCubit, ArchivedRecordsState,
        List<Mission>>(
      selector: (state) => state.missions,
      builder: (context, records) {
        if (records.isEmpty) {
          return const Center(child: Text('No archived missions.'));
        }
        return ListView.separated(
          padding: UI.screenPaddingAll,
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = records[index];
            return ListTile(
              title: Text(record.name),
              subtitle: Text(_archiveSubtitle(record.metadata)),
              trailing: IconButton(
                tooltip: 'Restore',
                icon: const Icon(Icons.restore),
                onPressed: () => _confirmRestore(
                  context,
                  label: record.name,
                  onRestore: () =>
                      context.read<ArchivedRecordsCubit>().restoreMission(
                            record,
                          ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _archiveSubtitle(Map<String, dynamic>? metadata) {
    final reasonType = metadata?[kArchivedReasonTypeKey] as String?;
    final reasonLabel = reasonType == kArchiveReasonTypeMortality
        ? 'Mortality'
        : reasonType == kArchiveReasonTypeDeleted
            ? 'Deleted'
            : 'Archived';
    final archivedAt = _parseArchivedAt(metadata);
    final dateLabel = archivedAt == null
        ? 'Unknown date'
        : _formatDate(archivedAt.toLocal());
    return '$reasonLabel · $dateLabel';
  }

  DateTime? _parseArchivedAt(Map<String, dynamic>? metadata) {
    final raw = metadata?[kArchivedAtKey];
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _confirmRestore(
    BuildContext context, {
    required String label,
    required Future<void> Function() onRestore,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await context.showSafeDialog<bool>(
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore record?'),
        content: Text('Restore "$label" to active inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onRestore();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Restored "$label".')),
      );
    }
  }

}
