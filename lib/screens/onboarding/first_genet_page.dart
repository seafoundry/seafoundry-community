import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/life_stage_constraint_service.dart';
import 'package:seafoundry_app/widgets/common/pid_status_chip.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_field.dart';
import 'package:seafoundry_app/widgets/forms/onboarding_species_selector.dart';

/// Onboarding page for creating the user's first genet and organism record
/// using the five-axis data model (taxonomy, provenance, location, life stage, measurement).
class FirstGenetPage extends StatelessWidget {
  const FirstGenetPage({
    super.key,
    required this.localIdController,
    required this.recordNameController,
    required this.quantityController,
    required this.selectedSpecies,
    required this.organismKind,
    required this.selectedLifeStage,
    required this.initialQuantity,
    required this.selectedProvenanceType,
    required this.onSpeciesChanged,
    required this.onLifeStageChanged,
    required this.onQuantityChanged,
    required this.onProvenanceTypeChanged,
    required this.onNext,
    required this.provenanceSearch,
    required this.onClonalIdChanged,
    required this.onAccessionNumberChanged,
    required this.onAliasIdChanged,
    required this.onProvenanceIdChanged,
    required this.onProvenanceSuggestionSelected,
    required this.onSetActiveProvenanceField,
    required this.onClearProvenanceSelection,
    required this.isSubmitting,
    this.onRecordNameChanged,
    this.onLocalIdChanged,
    this.onAutoLocalIdChanged,
    this.isLocalIdManuallyEdited = false,
    this.errorMessage,
    this.collectionMethod,
    this.collectionDate,
    this.cohortName,
    this.cohortDate,
    this.onCollectionMethodChanged,
    this.onCollectionDateChanged,
    this.onCohortNameChanged,
    this.onCohortDateChanged,
    this.onBack,
    this.onSkip,
    this.onSuggestLocalId,
    this.clonalId,
    this.accessionNumber,
    this.aliasId,
    this.provenanceId,
  });

  final TextEditingController localIdController;
  final TextEditingController recordNameController;
  final TextEditingController quantityController;
  final Species? selectedSpecies;
  final OrganismKind organismKind;
  final LifeStage? selectedLifeStage;
  final int initialQuantity;
  final ProvenanceType selectedProvenanceType;
  final String? clonalId;
  final String? accessionNumber;
  final String? aliasId;
  final String? provenanceId;
  final ProvenanceSearchState provenanceSearch;
  final String? errorMessage;
  final bool isSubmitting;
  final bool isLocalIdManuallyEdited;

  // Provenance metadata
  final String? collectionMethod;
  final DateTime? collectionDate;
  final String? cohortName;
  final DateTime? cohortDate;

  // Callbacks
  final ValueChanged<String>? onRecordNameChanged;
  final ValueChanged<String>? onLocalIdChanged;
  final ValueChanged<String>? onAutoLocalIdChanged;
  final ValueChanged<Species?> onSpeciesChanged;
  final ValueChanged<LifeStage?> onLifeStageChanged;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<ProvenanceType> onProvenanceTypeChanged;
  final ValueChanged<String?>? onCollectionMethodChanged;
  final ValueChanged<DateTime?>? onCollectionDateChanged;
  final ValueChanged<String?>? onCohortNameChanged;
  final ValueChanged<DateTime?>? onCohortDateChanged;
  final ValueChanged<String> onClonalIdChanged;
  final ValueChanged<String> onAccessionNumberChanged;
  final ValueChanged<String> onAliasIdChanged;
  final ValueChanged<String> onProvenanceIdChanged;
  final void Function(ProvenanceSuggestion, ProvenanceMatchField)
  onProvenanceSuggestionSelected;
  final void Function(ProvenanceMatchField) onSetActiveProvenanceField;
  final VoidCallback onClearProvenanceSelection;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final Future<String?> Function(Species species)? onSuggestLocalId;

  /// The provenance types available for onboarding (simplified set)
  static const _onboardingProvenanceTypes = [
    ProvenanceType.wild,
    ProvenanceType.transfer,
    ProvenanceType.unknown,
  ];

  @override
  Widget build(BuildContext context) {
    final organismDisplayName = organismKind.metadata.displayName;
    final isValid =
        localIdController.text.trim().isNotEmpty &&
        selectedSpecies != null &&
        selectedLifeStage != null &&
        initialQuantity > 0 &&
        !provenanceSearch.hasConflict;
    final activeField = provenanceSearch.activeField;
    final pidLocked = (provenanceId ?? '').trim().isNotEmpty;
    final hasResolvedPid = provenanceSearch.resolvedProvenanceId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your First $organismDisplayName'),
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(Icons.eco, size: 64, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              'Create Your First Genet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A genet represents a unique genetic identity. Set up your first '
              '$organismDisplayName with its provenance, species, and initial inventory.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Provenance Type Selection (Axis 2 - first because it affects other fields)
            _buildSectionLabel(context, 'Provenance Type', Icons.account_tree),
            const SizedBox(height: 8),
            _buildProvenanceExplanation(context),
            const SizedBox(height: 16),
            _buildProvenanceTypeSelector(context),
            const SizedBox(height: 16),

            // Provenance-specific metadata fields
            _buildProvenanceMetadataFields(context),
            const SizedBox(height: 8),

            // Species Selection (Taxonomy - Axis 1) - BEFORE Local ID for name suggestion
            _buildSectionLabel(context, 'Taxonomy', Icons.category),
            const SizedBox(height: 8),
            Text(
              'Species',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OnboardingSpeciesSelector(
              value: selectedSpecies,
              onChanged: (species) async {
                // First update the species selection
                onSpeciesChanged(species);
                // Then suggest a local ID if callback is provided and species is selected
                if (species != null && onSuggestLocalId != null) {
                  final suggestedName = await onSuggestLocalId!(species);
                  if (suggestedName != null &&
                      (localIdController.text.isEmpty ||
                          !isLocalIdManuallyEdited)) {
                    localIdController.text = suggestedName;
                    onAutoLocalIdChanged?.call(suggestedName);
                  }
                }
              },
            ),
            const SizedBox(height: 24),

            // Local ID Input
            Text(
              'Local ID',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: localIdController,
              decoration: InputDecoration(
                hintText: selectedSpecies != null
                    ? 'e.g., ${_getSuggestedLocalIdExample()}'
                    : 'Select a species first',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.tag),
                helperText: _getLocalIdHelperText(),
                helperMaxLines: 2,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: onLocalIdChanged,
            ),
            const SizedBox(height: 16),

            // Record Name Input
            Text(
              'Record Name',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: recordNameController,
              decoration: const InputDecoration(
                hintText: 'e.g., Bright, Calm, Fragment-A',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
                helperText:
                    'Auto-generated and editable. A human-friendly name for this record.',
                helperMaxLines: 2,
              ),
              onChanged: onRecordNameChanged,
            ),
            const SizedBox(height: 12),
            _buildRecordNameExplanation(context),
            const SizedBox(height: 24),

            // Provenance Search (PID / Alias / Clonal ID / Accession Number)
            _buildSectionLabel(context, 'Provenance Search', Icons.fingerprint),
            const SizedBox(height: 8),
            // if (selectedSpecies == null) ...[
            //   Text(
            //     'Select a species first to enable provenance search',
            //     style: Theme.of(context).textTheme.bodySmall?.copyWith(
            //           color: Theme.of(context).colorScheme.onSurfaceVariant,
            //         ),
            //   ),
            //   const SizedBox(height: 8),
            // ],
            SizedBox(
              width: double.infinity,
              child: ExpansionTile(
                key: const PageStorageKey('onboarding_external_ids'),
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 12),
                title: Text(
                  'Select External Aliases & IDs',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                children: [
                  ProvenanceAutocompleteField(
                    label: 'Provenance ID (PID)',
                    hintText: 'e.g., PID-APAL-0007',
                    icon: Icons.fingerprint,
                    value: provenanceId ?? '',
                    suggestions: provenanceSearch.provenanceIdSuggestions,
                    isSearching: provenanceSearch.isSearchingProvenanceId,
                    displayValueBuilder: (suggestion) =>
                        suggestion.provenanceId,
                    showOtherAliases: false,
                    enabled:
                        !hasResolvedPid &&
                        (activeField == null ||
                            activeField == ProvenanceMatchField.provenanceId),
                    onTextChanged: onProvenanceIdChanged,
                    onSuggestionSelected: (suggestion) =>
                        onProvenanceSuggestionSelected(
                          suggestion,
                          ProvenanceMatchField.provenanceId,
                        ),
                    onEditingComplete: () {
                      if ((provenanceId ?? '').trim().isNotEmpty) {
                        onSetActiveProvenanceField(
                          ProvenanceMatchField.provenanceId,
                        );
                      }
                    },
                    onDisabledTap:
                        (hasResolvedPid ||
                            (activeField != null &&
                                activeField !=
                                    ProvenanceMatchField.provenanceId))
                        ? onClearProvenanceSelection
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ProvenanceAutocompleteField(
                    label: 'Alias',
                    hintText: 'e.g., APAL-001',
                    icon: Icons.label_outline,
                    value: aliasId ?? '',
                    suggestions: provenanceSearch.aliasSuggestions,
                    isSearching: provenanceSearch.isSearchingAlias,
                    displayValueBuilder: (suggestion) =>
                        ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                    showOtherAliases: false,
                    enabled:
                        !pidLocked &&
                        (activeField == null ||
                            activeField == ProvenanceMatchField.alias),
                    onTextChanged: onAliasIdChanged,
                    onSuggestionSelected: (suggestion) =>
                        onProvenanceSuggestionSelected(
                          suggestion,
                          ProvenanceMatchField.alias,
                        ),
                    onEditingComplete: () {
                      if ((aliasId ?? '').trim().isNotEmpty) {
                        onSetActiveProvenanceField(ProvenanceMatchField.alias);
                      }
                    },
                    onDisabledTap:
                        (pidLocked ||
                            (activeField != null &&
                                activeField != ProvenanceMatchField.alias))
                        ? onClearProvenanceSelection
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ProvenanceAutocompleteField(
                    label: 'Clonal ID',
                    hintText: 'e.g., HG-0001',
                    icon: Icons.content_copy,
                    value: clonalId ?? '',
                    suggestions: provenanceSearch.clonalIdSuggestions,
                    isSearching: provenanceSearch.isSearchingClonalId,
                    enabled:
                        !pidLocked &&
                        (activeField == null ||
                            activeField == ProvenanceMatchField.clonalId),
                    onTextChanged: onClonalIdChanged,
                    onSuggestionSelected: (suggestion) =>
                        onProvenanceSuggestionSelected(
                          suggestion,
                          ProvenanceMatchField.clonalId,
                        ),
                    onEditingComplete: () {
                      if ((clonalId ?? '').trim().isNotEmpty) {
                        onSetActiveProvenanceField(
                          ProvenanceMatchField.clonalId,
                        );
                      }
                    },
                    onDisabledTap:
                        (pidLocked ||
                            (activeField != null &&
                                activeField != ProvenanceMatchField.clonalId))
                        ? onClearProvenanceSelection
                        : null,
                  ),
                  const SizedBox(height: 16),
                  ProvenanceAutocompleteField(
                    label: 'Accession Number',
                    hintText: 'e.g., ACC-2024-001',
                    icon: Icons.confirmation_number,
                    value: accessionNumber ?? '',
                    suggestions: provenanceSearch.accessionSuggestions,
                    isSearching: provenanceSearch.isSearchingAccession,
                    displayValueBuilder: (suggestion) =>
                        ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                    showOtherAliases: false,
                    enabled:
                        !pidLocked &&
                        (activeField == null ||
                            activeField ==
                                ProvenanceMatchField.accessionNumber),
                    onTextChanged: onAccessionNumberChanged,
                    onSuggestionSelected: (suggestion) =>
                        onProvenanceSuggestionSelected(
                          suggestion,
                          ProvenanceMatchField.accessionNumber,
                        ),
                    onEditingComplete: () {
                      if ((accessionNumber ?? '').trim().isNotEmpty) {
                        onSetActiveProvenanceField(
                          ProvenanceMatchField.accessionNumber,
                        );
                      }
                    },
                    onDisabledTap:
                        (pidLocked ||
                            (activeField != null &&
                                activeField !=
                                    ProvenanceMatchField.accessionNumber))
                        ? onClearProvenanceSelection
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (provenanceSearch.resolvedProvenanceId != null)
              _buildCommunityMatchSummary(context, provenanceSearch),
            if (provenanceSearch.resolvedProvenanceId != null)
              const SizedBox(height: 12),
            PidStatusChip(searchState: provenanceSearch),
            const SizedBox(height: 24),

            // Life Stage Selection (Axis 4)
            _buildSectionLabel(context, 'Life Stage', Icons.timeline),
            const SizedBox(height: 8),
            Text(
              'Current Stage',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildLifeStageSelector(context),
            const SizedBox(height: 24),

            // Quantity Input (Measurement - Axis 5)
            _buildSectionLabel(context, 'Measurement', Icons.straighten),
            const SizedBox(height: 8),
            Text(
              'Initial Quantity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'e.g., 1, 5, 10',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
                helperText: _getQuantityHelperText(),
                helperMaxLines: 2,
              ),
              onChanged: (value) {
                final quantity = int.tryParse(value) ?? 1;
                onQuantityChanged(quantity);
              },
            ),
            const SizedBox(height: 32),

            // Info Box - What Gets Created
            _buildInfoBox(context),
            const SizedBox(height: 32),

            // Error Message
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                if (onSkip != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onSkip,
                      child: const Text('Skip for now'),
                    ),
                  ),
                if (onSkip != null) const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isSubmitting || !isValid ? null : onNext,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Genet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildProvenanceExplanation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'What is Provenance?',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Provenance tracks the genetic origin of your organisms. This is essential '
            'for restoration genetics, breeding programs, and compliance reporting.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.blue.shade800),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordNameExplanation(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Local ID identifies the genet (shared genetics). '
              'Record Name identifies the individual record and will be '
              'auto-generated as a human-friendly label you can edit later.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceTypeSelector(BuildContext context) {
    return Column(
      children: _onboardingProvenanceTypes.map((type) {
        final isSelected = selectedProvenanceType == type;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onProvenanceTypeChanged(type),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // ignore: deprecated_member_use, deprecated_member_use_from_same_package
                  Radio<ProvenanceType>(
                    value: type,
                    // ignore: deprecated_member_use, deprecated_member_use_from_same_package
                    groupValue: selectedProvenanceType,
                    // ignore: deprecated_member_use, deprecated_member_use_from_same_package
                    onChanged: (value) {
                      if (value != null) onProvenanceTypeChanged(value);
                    },
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _getProvenanceIcon(type),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.displayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProvenanceMetadataFields(BuildContext context) {
    switch (selectedProvenanceType) {
      case ProvenanceType.wild:
        return _buildWildFounderFields(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWildFounderFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collection Method (optional)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            hintText: 'How was this organism collected?',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          initialValue: collectionMethod,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'manual', child: Text('Manual collection')),
            DropdownMenuItem(
              value: 'rescue',
              child: Text('Rescue/opportunity'),
            ),
            DropdownMenuItem(value: 'donation', child: Text('Donation')),
            DropdownMenuItem(value: 'purchase', child: Text('Purchase')),
            DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
          ],
          onChanged: onCollectionMethodChanged,
        ),
        const SizedBox(height: 16),
        Text(
          'Collection Date (optional)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        _buildDatePicker(
          context,
          value: collectionDate,
          hintText: 'When was this organism collected?',
          onChanged: onCollectionDateChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // _buildCohortFields and _buildGraduatedFields removed in
  // coral-only simplification (cohort/graduated provenance types removed).

  Widget _buildDatePicker(
    BuildContext context, {
    required DateTime? value,
    required String hintText,
    required ValueChanged<DateTime?>? onChanged,
  }) {
    final dateFormat = DateFormat.yMMMd();
    return InkWell(
      onTap: onChanged == null
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                onChanged(picked);
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged?.call(null),
                )
              : null,
        ),
        child: Text(
          value != null ? dateFormat.format(value) : hintText,
          style: value == null
              ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).hintColor,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLifeStageSelector(BuildContext context) {
    // Use organism constraints to show the full lifecycle options.
    final stages = LifeStageConstraintService.instance.getValidLifeStages(
      organismKind,
    );

    return DropdownButtonFormField<LifeStage>(
      decoration: const InputDecoration(
        hintText: 'Select life stage',
        prefixIcon: Icon(Icons.timeline),
        border: OutlineInputBorder(),
      ),
      initialValue: stages.contains(selectedLifeStage)
          ? selectedLifeStage
          : null,
      isExpanded: true,
      items: stages
          .map(
            (stage) => DropdownMenuItem<LifeStage>(
              value: stage,
              child: Text(stage.displayName),
            ),
          )
          .toList(),
      onChanged: onLifeStageChanged,
    );
  }

  Widget _buildInfoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Text(
                'What this creates:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            context,
            Icons.account_tree,
            'Genet (${selectedProvenanceType.displayName})',
            _getGenetDescription(),
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            context,
            Icons.inventory_2,
            'Organism Record',
            'Inventory entry placed in your ${_getSiteDescription()}',
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
            context,
            Icons.event,
            'Creation Event',
            'Audit trail entry recording this addition',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.teal.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.teal.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getProvenanceIcon(ProvenanceType type) {
    switch (type) {
      case ProvenanceType.wild:
        return Icons.nature;
      case ProvenanceType.cohort:
        return Icons.groups;
      case ProvenanceType.graduatedIndividual:
        return Icons.star_outline;
      case ProvenanceType.transfer:
        return Icons.move_to_inbox;
      case ProvenanceType.unknown:
        return Icons.help_outline;
    }
  }

  String _getGenetDescription() {
    switch (selectedProvenanceType) {
      case ProvenanceType.wild:
        return 'Founder stock collected from the wild';
      case ProvenanceType.cohort:
        return 'Organisms from a nursery-reared cohort';
      case ProvenanceType.graduatedIndividual:
        return 'Individual promoted from a cohort';
      case ProvenanceType.transfer:
        return 'Organisms received from another facility';
      case ProvenanceType.unknown:
        return 'Provenance information not available';
    }
  }

  String _getLocalIdHelperText() {
    switch (selectedProvenanceType) {
      case ProvenanceType.wild:
        return 'A unique ID for this wild-collected founder';
      case ProvenanceType.cohort:
        return 'A unique ID for this nursery cohort';
      case ProvenanceType.graduatedIndividual:
        return 'A unique ID for this graduated individual';
      case ProvenanceType.transfer:
        return 'A unique ID for this transferred organism';
      case ProvenanceType.unknown:
        return 'A unique ID for this organism';
    }
  }

  String _getQuantityHelperText() {
    switch (selectedProvenanceType) {
      case ProvenanceType.wild:
        return 'Number of wild-collected individuals';
      case ProvenanceType.cohort:
        return 'Number of individuals in cohort';
      case ProvenanceType.graduatedIndividual:
        return 'Number of graduated individuals';
      case ProvenanceType.transfer:
        return 'Number of transferred individuals';
      case ProvenanceType.unknown:
        return 'Number of individuals';
    }
  }

  String _getExampleLocalId() {
    return 'CORAL-001, APAL-001';
  }

  /// Get a species-specific example for the local ID field
  String _getSuggestedLocalIdExample() {
    if (selectedSpecies == null) {
      return _getExampleLocalId();
    }
    // Use the species ID to generate an example like "Apal-1"
    final code = selectedSpecies!.id.toLowerCase();
    if (code.isEmpty) {
      return _getExampleLocalId();
    }
    final formattedCode = code.length == 1
        ? code.toUpperCase()
        : code[0].toUpperCase() + code.substring(1);
    return '$formattedCode-1';
  }

  String _getSiteDescription() {
    return 'nursery tank';
  }

  Widget _buildCommunityMatchSummary(
    BuildContext context,
    ProvenanceSearchState search,
  ) {
    if (search.resolvedProvenanceId == null) return const SizedBox.shrink();

    // Prefer the match that actually has aliases populated
    final match = search.clonalIdMatch?.otherAliases.isNotEmpty == true
        ? search.clonalIdMatch
        : search.accessionMatch;

    if (match == null) return const SizedBox.shrink();

    final allAliases = match.otherAliases;
    if (allAliases.isEmpty) {
      // Just show minimal confirmation if no other aliases
      return Card(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Linked to Community ID: ${match.provenanceId}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hub,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Community Genetics Match',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  match.provenanceId,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'RobotoMono',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final alias in allAliases)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      alias,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
