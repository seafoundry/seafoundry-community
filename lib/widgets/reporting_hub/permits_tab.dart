// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/reporting_hub/reporting_hub.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/repositories/permit_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/permit_edit_dialog.dart';

/// Permits management tab for the Reporting Hub
///
/// Displays all permits for the organization with ability to:
/// - View permit details (name, number, issuing authority)
/// - Create new permits
/// - Edit existing permits
/// - See expiration warnings
class PermitsTab extends StatelessWidget {
  const PermitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final repo = context.read<PermitRepository>();
        final org = context.read<Organization>();
        return PermitsTabCubit(
          repository: repo,
          organizationId: org.id,
        )..watchPermits();
      },
      child: const _PermitsTabContent(),
    );
  }
}

class _PermitsTabContent extends StatelessWidget {
  const _PermitsTabContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'permits-add-fab',
        onPressed: () => PermitEditDialog.show(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<PermitsTabCubit, PermitsTabState>(
        builder: (context, state) {
          if (state.errorMessage != null) {
            return Center(child: Text('Error: ${state.errorMessage}'));
          }
          if (state.loading && state.permits.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final permits = state.permits;
          if (permits.isEmpty) {
            return const _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: permits.length,
            itemBuilder: (context, index) {
              final permit = permits[index];
              return _PermitCard(permit: permit);
            },
          );
        },
      ),
    );
  }
}

class _PermitCard extends StatelessWidget {
  final Permit permit;

  const _PermitCard({required this.permit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description, size: 32),
        title: Text(permit.name),
        subtitle: Text('${permit.permitNumber} • ${permit.issuingAuthority}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (permit.isExpiringSoon)
              const Tooltip(
                message: 'Expiring Soon',
                child: Icon(Icons.warning_amber, color: Colors.orange),
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => PermitEditDialog.show(context, permit: permit),
            ),
          ],
        ),
        onTap: () => PermitEditDialog.show(context, permit: permit),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No permits found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add permits to track regulatory compliance',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
