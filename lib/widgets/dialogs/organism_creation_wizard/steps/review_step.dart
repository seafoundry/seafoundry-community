// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/utils/record_name_derived.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 6: Review - Summary card showing all selections + validation warnings
class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.state,
  });

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final validationIssues = state.validationIssues;
    final organismKindLabel =
        state.organismKind?.metadata.displayName ?? 'Not set';
    final lifeStageLabel = state.lifeStage?.displayName ?? 'Not set';
    final provenanceTypeLabel = state.provenanceType?.displayName ?? 'Not set';
    final physicalFormLabel = _physicalFormLabel(state);
    final quantityLabel =
        '${_formatMeasurementValue(state.measurement.value)} ${state.measurement.unit.label}';

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (validationIssues.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Validation Issues',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...validationIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  issue,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Review Your Organism',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewRow(
                    'Organism Kind',
                    organismKindLabel,
                  ),
                  _buildReviewRow(
                    'Species',
                    state.species?.name ?? 'Not set',
                  ),
                  _buildReviewRow(
                    'Life Stage',
                    lifeStageLabel,
                  ),
                  _buildReviewRow(
                    'Local ID',
                    state.effectiveLocalId ?? 'Missing',
                  ),
                  _buildReviewRow(
                    'Record Name',
                    state.recordName?.trim().isNotEmpty == true
                        ? state.recordName!.trim()
                        : (RecordNameDerived.fromLocalId(
                              state.effectiveLocalId,
                            ) ??
                            'Unknown'),
                  ),
                  _buildReviewRow(
                    'Mode',
                    state.isNewGenet ? 'New Genet' : 'Existing Inventory',
                  ),
                  if (state.isNewGenet) ...[
                    _buildReviewRow(
                      'Provenance Type',
                      provenanceTypeLabel,
                    ),
                    if (state.provenanceType ==
                        ProvenanceType.sexualCohort) ...[
                      _buildReviewRow(
                        'Sire Gamete',
                        state.sireProvenanceId ?? 'Not set',
                      ),
                      _buildReviewRow(
                        'Dam Gamete',
                        state.damProvenanceId ?? 'Not set',
                      ),
                    ],
                    if (state.provenanceType ==
                        ProvenanceType.graduatedIndividual)
                      _buildReviewRow(
                        'Source Cohort',
                        state.sourceCohortId ?? 'Not set',
                      ),
                    if (state.provenanceType == ProvenanceType.transfer) ...[
                      _buildReviewRow(
                        'Source Organization',
                        state.transferOrgId ?? 'Not set',
                      ),
                      if (state.transferEmail != null &&
                          state.transferEmail!.trim().isNotEmpty)
                        _buildReviewRow(
                          'Partner Email',
                          state.transferEmail!.trim(),
                        ),
                    ],
                  ] else
                    _buildReviewRow(
                      'Gain Reason',
                      state.gainReason?.name ?? 'Not set',
                    ),
                  _buildReviewRow(
                    'Physical Form',
                    physicalFormLabel,
                  ),
                  _buildReviewRow(
                    'Quantity',
                    quantityLabel,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 8),
                Text('Ready to Create'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _physicalFormLabel(OrganismCreationState state) {
    final explicitLabel = state.physicalFormLabel?.trim();
    if (explicitLabel != null && explicitLabel.isNotEmpty) {
      return explicitLabel;
    }

    final formId = state.physicalForm?.formId;
    if (formId == null || formId.trim().isEmpty) return 'Not set';

    for (final form in state.availablePhysicalForms) {
      if (form.id == formId) {
        return form.displayName;
      }
    }

    return formatSnakeCaseToTitleCase(formId);
  }

  String _formatMeasurementValue(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
