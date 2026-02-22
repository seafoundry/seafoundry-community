// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/permit_repository.dart';
import 'package:seafoundry_app/utils/date_utils.dart';
import 'package:seafoundry_app/widgets/common/loading_overlay.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'components/dialog_scroll_view.dart';
import '../notifications/toast_overlay.dart';

class PermitEditDialog extends StatefulWidget {
  final Permit? permit;

  const PermitEditDialog({super.key, this.permit});

  static Future<void> show(BuildContext context, {Permit? permit}) async {
    // Read required providers from parent context before showDialog
    // (showDialog creates a new overlay context that doesn't inherit providers)
    final permitRepo = context.read<PermitRepository>();
    final org = context.read<Organization>();
    final user = context.read<User>();
    final siteRepo = context.maybeRead<SiteRepository>();

    await showDialog(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      builder: (dialogContext) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<PermitRepository>.value(value: permitRepo),
          if (siteRepo != null)
            RepositoryProvider<SiteRepository>.value(value: siteRepo),
        ],
        child: MultiProvider(
          providers: [
            Provider<Organization>.value(value: org),
            Provider<User>.value(value: user),
          ],
          child: PermitEditDialog(permit: permit),
        ),
      ),
    );
  }

  @override
  State<PermitEditDialog> createState() => _PermitEditDialogState();
}

class _PermitEditDialogState extends State<PermitEditDialog>
    with SafeDialogMixin<PermitEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _numberController;
  late TextEditingController _authorityController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactEmailController;
  late TextEditingController _agencyController;
  late TextEditingController _conditionsController;
  
  late DateTime _validFrom;
  late DateTime _validTo;
  late PermitType _type;
  Future<List<Site>>? _sitesFuture;
  Set<String> _selectedSiteIds = {};
  String? _siteLoadError;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final permit = widget.permit;
    _nameController = TextEditingController(text: permit?.name);
    _numberController = TextEditingController(text: permit?.permitNumber);
    _authorityController = TextEditingController(text: permit?.issuingAuthority);
    _contactNameController = TextEditingController(text: permit?.contactName);
    _contactEmailController = TextEditingController(text: permit?.contactEmail);
    _agencyController = TextEditingController(text: permit?.regulatoryAgency);
    _conditionsController = TextEditingController(text: permit?.permitConditions);
    
    _validFrom = permit?.validFrom ?? DateTime.now();
    _validTo = permit?.validTo ?? DateTime.now().add(const Duration(days: 365));
    _type = permit?.type ?? PermitType.other;
    _selectedSiteIds = permit?.siteIds.toSet() ?? {};
    _sitesFuture = _loadSites();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _authorityController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _agencyController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  Future<List<Site>> _loadSites() async {
    try {
      final repo = context.read<SiteRepository>();
      return await repo.getAll();
    } catch (e) {
      setState(() => _siteLoadError = 'Failed to load sites');
      return [];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Basic date validation
    if (_validTo.isBefore(_validFrom)) {
      ToastOverlay.showSnackBar(context,
        const SnackBar(content: Text('End date must be after start date'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repo = context.read<PermitRepository>();

      final name = _nameController.text.trim();
      final number = _numberController.text.trim();
      final authority = _authorityController.text.trim();
      final contactName = _contactNameController.text.trim();
      final contactEmail = _contactEmailController.text.trim();
      final agency = _agencyController.text.trim();
      final conditions = _conditionsController.text.trim();
      final siteIds = _selectedSiteIds.toList();

      final org = context.read<Organization>();
      final user = context.read<User>();

      if (widget.permit == null) {
        final permit = Permit.partial(
          organizationId: org.id,
          createdById: user.id,
          updatedById: user.id,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          name: name,
          permitNumber: number,
          issuingAuthority: authority,
          validFrom: _validFrom,
          validTo: _validTo,
          type: _type,
          contactName: contactName.isEmpty ? null : contactName,
          contactEmail: contactEmail.isEmpty ? null : contactEmail,
          siteIds: siteIds,
          regulatoryAgency: agency.isEmpty ? null : agency,
          permitConditions: conditions.isEmpty ? null : conditions,
        );
        await repo.createPermit(permit);
      } else {
        final updated = widget.permit!.copyWith(
          name: name,
          permitNumber: number,
          issuingAuthority: authority,
          validFrom: _validFrom,
          validTo: _validTo,
          type: _type,
          contactName: contactName.isEmpty ? null : contactName,
          contactEmail: contactEmail.isEmpty ? null : contactEmail,
          siteIds: siteIds,
          regulatoryAgency: agency.isEmpty ? null : agency,
          permitConditions: conditions.isEmpty ? null : conditions,
        );
        await repo.updatePermit(updated);
      }

      if (mounted) {
        popDialog();
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text(widget.permit == null ? 'Permit created' : 'Permit updated')),
        );
      }
    } catch (e) {
      LoggingService.instance.error('Error saving permit', e);
      if (mounted) {
        ToastOverlay.showSnackBar(context,
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSaving,
      child: AlertDialog(
        title: Text(widget.permit == null ? 'Add Permit' : 'Edit Permit'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: _formKey,
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Row(
                     children: [
                       Expanded(
                         child: TextFormField(
                           controller: _nameController,
                           decoration: const InputDecoration(labelText: 'Permit Name *'),
                           validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                         ),
                       ),
                       UI.spacingHorizontalMd,
                       Expanded(
                         child: TextFormField(
                           controller: _numberController,
                           decoration: const InputDecoration(labelText: 'Permit Number *'),
                           validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                         ),
                       ),
                     ],
                   ),
                  UI.spacingVerticalMd,
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PermitType>(
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: PermitType.values.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          )).toList(),
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                       UI.spacingHorizontalMd,
                       Expanded(
                         child: TextFormField(
                           controller: _authorityController,
                           decoration: const InputDecoration(labelText: 'Issuing Authority *'),
                           validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                         ),
                       ),
                    ],
                  ),
                  UI.spacingVerticalMd,
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactNameController,
                          decoration: const InputDecoration(labelText: 'Contact Name'),
                        ),
                      ),
                      UI.spacingHorizontalMd,
                      Expanded(
                        child: TextFormField(
                          controller: _contactEmailController,
                          decoration: const InputDecoration(labelText: 'Contact Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  UI.spacingVerticalMd,
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Valid From',
                          value: _validFrom,
                          onChanged: (d) => setState(() => _validFrom = d),
                        ),
                      ),
                      UI.spacingHorizontalMd,
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Valid To',
                          value: _validTo,
                          onChanged: (d) => setState(() => _validTo = d),
                        ),
                      ),
                    ],
                  ),
                  UI.spacingVerticalMd,
                  TextFormField(
                    controller: _agencyController,
                    decoration: const InputDecoration(labelText: 'Regulatory Agency (Optional)'),
                  ),
                  UI.spacingVerticalMd,
                  TextFormField(
                    controller: _conditionsController,
                    decoration: const InputDecoration(labelText: 'Conditions / Notes'),
                    maxLines: 3,
                  ),
                  UI.spacingVerticalMd,
                  _buildSiteSelector(),
                ],
              ),
            ),
          ),
        ),
        actions: [
           TextButton(
            onPressed: () => popDialog(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(DateTimeUtils.formatDate(value)),
      ),
    );
  }

  Widget _buildSiteSelector() {
    if (_sitesFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Site>>(
      future: _sitesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (_siteLoadError != null || snapshot.hasError) {
          return Text(
            _siteLoadError ?? 'Failed to load sites',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }

        final sites = snapshot.data ?? const <Site>[];
        final outplantSites = sites.where(_isOutplantSite).toList();
        final monitoringSites = sites.where(_isMonitoringSite).toList();

        if (outplantSites.isEmpty && monitoringSites.isEmpty) {
          return const Text('No outplanting or monitoring sites available.');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Associated Sites',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (outplantSites.isNotEmpty) ...[
              const Text('Outplanting Sites'),
              const SizedBox(height: 6),
              _buildSiteChips(outplantSites),
              const SizedBox(height: 12),
            ],
            if (monitoringSites.isNotEmpty) ...[
              const Text('Monitoring Sites'),
              const SizedBox(height: 6),
              _buildSiteChips(monitoringSites),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSiteChips(List<Site> sites) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sites.map((site) {
        final selected = _selectedSiteIds.contains(site.id);
        return FilterChip(
          label: Text(site.name),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedSiteIds.add(site.id);
              } else {
                _selectedSiteIds.remove(site.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  bool _isOutplantSite(Site site) {
    return site.siteTypeId == 'site_type_outplanting' ||
        site.siteTypeId == 'op';
  }

  bool _isMonitoringSite(Site site) {
    return site.siteTypeId == 'site_type_baseline' ||
        site.siteTypeId == 'site_type_reference' ||
        site.siteTypeId == 'bl' ||
        site.siteTypeId == 'ref';
  }
}
