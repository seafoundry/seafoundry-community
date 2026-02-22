// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/inputs/lineage_id_selector.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

import '../../components/dialog_scroll_view.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 3a: Provenance - For NEW genet mode only
class ProvenanceStep extends StatelessWidget {
  const ProvenanceStep({super.key, required this.state});

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Provenance Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ProvenanceTypeSelector(
            selected: state.provenanceType,
            onChanged: cubit.provenanceTypeChanged,
          ),
          const SizedBox(height: 24),
          if (state.provenanceType == ProvenanceType.wild) ...[
            _FounderCollectionMetadataSection(state: state),
            const SizedBox(height: 24),
          ],
          if (state.provenanceType == ProvenanceType.sexualCohort) ...[
            Text(
              'Parent Gametes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Select parent gamete genets for sexual cohort',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            LineageIdSelector(
              label: 'Sire Gamete ID',
              value: state.sireProvenanceId,
              species: state.species,
              localFilter: _isGameteGenet,
              itemLabelBuilder: _gameteLabel,
              onChanged: (value) => cubit.sireProvenanceIdChanged(value ?? ''),
            ),
            const SizedBox(height: 12),
            LineageIdSelector(
              label: 'Dam Gamete ID',
              value: state.damProvenanceId,
              species: state.species,
              localFilter: _isGameteGenet,
              itemLabelBuilder: _gameteLabel,
              onChanged: (value) => cubit.damProvenanceIdChanged(value ?? ''),
            ),
          ],
          if (state.provenanceType == ProvenanceType.graduatedIndividual) ...[
            Text(
              'Source Cohort',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LineageIdSelector(
              label: 'Source Cohort ID',
              value: state.sourceCohortId,
              species: state.species,
              allowedProvenanceTypeIds: const ['provenance_type_sexual_cohort'],
              onChanged: (value) => cubit.sourceCohortIdChanged(value ?? ''),
            ),
          ],
          if (state.provenanceType == ProvenanceType.transfer) ...[
            Text(
              'Transfer / Import',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _TransferOrganizationSelector(state: state),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Partner email (optional)',
                hintText: 'contact@example.org',
                border: OutlineInputBorder(),
              ),
              initialValue: state.transferEmail ?? '',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: cubit.transferEmailChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// Florida-specific region options for wild/founder collection
const _flRegionOptions = [
  'SE FL',
  'Upper Keys',
  'Middle Keys',
  'Lower Keys',
  'Marquesas',
  'Dry Tortugas',
];

/// Florida-specific founder type options
const _flFounderTypeOptions = ['COO', 'Rescue', 'Wild'];

/// Florida-specific habitat collection type options
const _flHabitatCollectionTypeOptions = [
  'Marginal',
  'Nearshore',
  'Mid-Channel',
  'Offshore',
];

class _FounderCollectionMetadataSection extends StatelessWidget {
  const _FounderCollectionMetadataSection({required this.state});

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Collection Metadata (optional)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Add details about where and how this founder was collected.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Florida-specific dropdowns
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'FL Region (optional)',
            border: OutlineInputBorder(),
          ),
          initialValue: state.flRegion,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select region...'),
            ),
            ..._flRegionOptions.map(
              (region) => DropdownMenuItem(value: region, child: Text(region)),
            ),
          ],
          onChanged: cubit.flRegionChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'FL Founder Type (optional)',
            border: OutlineInputBorder(),
          ),
          initialValue: state.flFounderType,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select founder type...'),
            ),
            ..._flFounderTypeOptions.map(
              (type) => DropdownMenuItem(value: type, child: Text(type)),
            ),
          ],
          onChanged: cubit.flFounderTypeChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'FL Habitat Collection Type (optional)',
            border: OutlineInputBorder(),
          ),
          initialValue: state.flHabitatCollectionType,
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select habitat type...'),
            ),
            ..._flHabitatCollectionTypeOptions.map(
              (type) => DropdownMenuItem(value: type, child: Text(type)),
            ),
          ],
          onChanged: cubit.flHabitatCollectionTypeChanged,
        ),
        const SizedBox(height: 12),

        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Collection Method (optional)',
            hintText: 'e.g., rescue, hand collection',
            border: OutlineInputBorder(),
          ),
          initialValue: state.wildCollectionMethod ?? '',
          onChanged: cubit.wildCollectionMethodChanged,
        ),
        const SizedBox(height: 12),
        _CollectionDatePickerField(
          value: state.collectionDate,
          onChanged: cubit.collectionDateChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Reef of Origin (optional)',
            hintText: 'e.g., Pickles Reef',
            border: OutlineInputBorder(),
          ),
          initialValue: state.collectionReefOrigin ?? '',
          onChanged: cubit.collectionReefOriginChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Habitat Type (optional)',
            hintText: 'e.g., reef crest',
            border: OutlineInputBorder(),
          ),
          initialValue: state.collectionHabitatType ?? '',
          onChanged: cubit.collectionHabitatTypeChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Depth (m) (optional)',
            hintText: 'e.g., 3.2',
            border: OutlineInputBorder(),
          ),
          initialValue: state.collectionDepth ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: cubit.collectionDepthChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Collecting Institution (optional)',
            hintText: 'e.g., NOAA',
            border: OutlineInputBorder(),
          ),
          initialValue: state.collectionInstitution ?? '',
          onChanged: cubit.collectionInstitutionChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Latitude (optional)',
                  hintText: '±DD.ddddd',
                  border: OutlineInputBorder(),
                ),
                initialValue: state.collectionLatitude ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: cubit.collectionLatitudeChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Longitude (optional)',
                  hintText: '±DDD.ddddd',
                  border: OutlineInputBorder(),
                ),
                initialValue: state.collectionLongitude ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: cubit.collectionLongitudeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CollectionDatePickerField extends StatelessWidget {
  const _CollectionDatePickerField({
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final displayText = value != null
        ? dateFormat.format(value!)
        : 'Select collection date';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Collection Date (optional)',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.event),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          displayText,
          style: value == null
              ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).hintColor,
                )
              : null,
        ),
      ),
    );
  }
}

class _TransferOrganizationSelector extends StatefulWidget {
  const _TransferOrganizationSelector({required this.state});

  final OrganismCreationState state;

  @override
  State<_TransferOrganizationSelector> createState() =>
      _TransferOrganizationSelectorState();
}

class _TransferOrganizationSelectorState
    extends State<_TransferOrganizationSelector>
    with SafeDialogMixin<_TransferOrganizationSelector> {
  final TextEditingController _orgQuery = TextEditingController();
  Timer? _timer;
  bool _searching = false;
  List<Organization> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search('');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orgQuery.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final repository = context.maybeRead<OrganizationRepository>();
    if (repository == null) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final response = await repository.searchOrganizations(
        query: query.trim(),
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _results = response.items;
        _searching = false;
      });
    } catch (e, stack) {
      LoggingService.instance.error('Organization search failed', e, stack);
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
      showDialogSnackBar('Failed to search organizations', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.maybeRead<OrganizationRepository>();
    if (repository == null) {
      return Text(
        'Organization search unavailable.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    final cubit = context.read<OrganismCreationCubit>();
    final selectedOrgId = widget.state.transferOrgId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _orgQuery,
          decoration: const InputDecoration(
            labelText: 'Search partner organization',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _timer?.cancel();
            if (v.trim().isEmpty) {
              _search('');
              return;
            }
            _timer = Timer(const Duration(milliseconds: 300), () => _search(v));
          },
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SizedBox(
          height: 120,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: DialogScrollView(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Unknown Organization'),
                    subtitle: const Text('unknown'),
                    trailing: selectedOrgId == 'unknown'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      cubit.transferOrgIdChanged('unknown');
                      _orgQuery.text = 'unknown';
                    },
                  ),
                  if (_results.isEmpty && !_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No organizations found. Try a different search term.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ..._results.map((org) {
                    final selected = selectedOrgId == org.id;
                    return ListTile(
                      title: Text(org.name),
                      subtitle: Text(org.domain),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        cubit.transferOrgIdChanged(org.id);
                        _orgQuery.text = org.name;
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool _isGameteGenet(Genet genet) {
  final meta = genet.metadata;
  final lifeStageId = meta['lifeStageId']?.toString() ?? '';
  final gameteSex = meta['gameteSex']?.toString() ?? '';
  return lifeStageId == 'life_stage_gamete' || gameteSex.isNotEmpty;
}

String _gameteLabel(Genet genet) {
  final meta = genet.metadata;
  final gameteSex = meta['gameteSex']?.toString().toLowerCase() ?? '';
  if (gameteSex == 'eggs') return '${genet.name} (Eggs)';
  if (gameteSex == 'sperm') return '${genet.name} (Sperm)';
  return genet.name;
}
