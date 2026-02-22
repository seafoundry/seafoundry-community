// @tier: community
import 'package:flutter/material.dart';

import '../../models/inventory/organism_record.dart';
import '../../models/inventory/size_spec.dart';
import '../../models/population_measurement.dart';
import '../../models/provenance_life_stage_selection.dart';
import '../../models/types/life_stage.dart';
import '../../models/types/organism_kind.dart';
import '../../models/types/provenance_type.dart';
import '../../services/life_stage_transition_service.dart';
import '../../services/size_mappings_service.dart';
import '../../services/validation/organism_constraints_service.dart';
import '../dialogs/components/provenance_life_stage_selector.dart';
import 'life_stage_progression.dart';
import 'physical_form_selector.dart';

/// Bundles provenance, life-stage, and physical form selectors into a single form.
class FiveAxisEditor extends StatefulWidget {
  const FiveAxisEditor({
    super.key,
    required this.organismKind,
    required this.initialSelection,
    required this.initialPhysicalFormId,
    required this.initialSizeSpec,
    required this.measurement,
    required this.onChanged,
    this.constraintsService = const OrganismConstraintsService(),
    this.sizeMappings,
    this.transitionService,
    this.fieldKeyPrefix,
    this.allowedProvenanceTypes,
    this.sizeClassOptions,
  });

  final OrganismKind organismKind;
  final ProvenanceLifeStageSelection initialSelection;
  final String? initialPhysicalFormId;
  final SizeSpec initialSizeSpec;
  final PopulationMeasurement measurement;
  final ValueChanged<FiveAxisSelection> onChanged;
  final OrganismConstraintsService constraintsService;
  final SizeMappingsService? sizeMappings;
  final LifeStageTransitionService? transitionService;
  final String? fieldKeyPrefix;
  final List<ProvenanceType>? allowedProvenanceTypes;
  final List<String>? sizeClassOptions;

  @override
  State<FiveAxisEditor> createState() => _FiveAxisEditorState();
}

class _FiveAxisEditorState extends State<FiveAxisEditor> {
  late ProvenanceLifeStageSelection _selection = widget.initialSelection;
  PhysicalFormSelection? _physicalFormSelection;
  bool _showTimeline = false;

  @override
  void initState() {
    super.initState();
    _physicalFormSelection = widget.initialPhysicalFormId == null
        ? null
        : PhysicalFormSelection(
            physicalFormId: widget.initialPhysicalFormId!,
            sizeSpec: widget.initialSizeSpec,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void didUpdateWidget(covariant FiveAxisEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    var shouldNotify = false;
    if (oldWidget.initialSelection != widget.initialSelection) {
      _selection = widget.initialSelection;
      shouldNotify = true;
    }
    if (oldWidget.initialPhysicalFormId != widget.initialPhysicalFormId ||
        oldWidget.initialSizeSpec != widget.initialSizeSpec) {
      _physicalFormSelection = widget.initialPhysicalFormId == null
          ? null
          : PhysicalFormSelection(
              physicalFormId: widget.initialPhysicalFormId!,
              sizeSpec: widget.initialSizeSpec,
            );
      shouldNotify = true;
    }
    if (shouldNotify) {
      _scheduleNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _buildRecord();
    // Per 5-axis canonical model (page 6): default to THREE provenance types
    // (founder, cohort, sexual recruit) unless the caller overrides.
    final allowedTypes =
        widget.allowedProvenanceTypes ??
        const [
          ProvenanceType.wild, // founder
          ProvenanceType.sexualCohort, // cohort
          ProvenanceType.graduatedIndividual, // sexual recruit
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProvenanceLifeStageSelector(
          fieldKeyPrefix: widget.fieldKeyPrefix,
          allowedProvenanceTypes: allowedTypes,
          initialSelection: _selection,
          onChanged: (selection) {
            setState(() => _selection = selection);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _showTimeline = !_showTimeline),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.timeline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showTimeline
                        ? 'Hide life-stage context'
                        : 'Show life-stage context',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(_showTimeline ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_showTimeline)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LifeStageProgressionWidget(
              record: record,
              transitionService:
                  widget.transitionService ?? LifeStageTransitionService(),
            ),
          ),
        const SizedBox(height: 12),
        PhysicalFormSelectorWidget(
          organismKind: widget.organismKind,
          lifeStage: _selection.lifeStage,
          initialPhysicalFormId: _physicalFormSelection?.physicalFormId,
          initialSizeSpec: _physicalFormSelection?.sizeSpec ?? const SizeSpec(),
          constraintsService: widget.constraintsService,
          sizeMappings: widget.sizeMappings ?? SizeMappingsService.empty(),
          sizeClassOptions: widget.sizeClassOptions,
          onChanged: (selection) {
            setState(() => _physicalFormSelection = selection);
            _notify();
          },
        ),
      ],
    );
  }

  OrganismRecord _buildRecord() {
    final organismRecord = OrganismRecord.partial(
      organismKind: widget.organismKind,
      lifeStage: LifeStageSpec(stage: _selection.lifeStage),
      measurement: widget.measurement,
      provenanceType: _selection.provenanceType,
      sizeSpec: _physicalFormSelection?.sizeSpec ?? widget.initialSizeSpec,
    );
    return organismRecord;
  }

  void _notify() {
    if (_physicalFormSelection == null ||
        _physicalFormSelection?.physicalFormId == null ||
        _physicalFormSelection?.sizeSpec == null) {
      return;
    }
    widget.onChanged(
      FiveAxisSelection(
        provenanceSelection: _selection,
        physicalFormSelection: _physicalFormSelection!,
      ),
    );
  }

  void _scheduleNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notify();
    });
  }
}

class FiveAxisSelection {
  const FiveAxisSelection({
    required this.provenanceSelection,
    required this.physicalFormSelection,
  });

  final ProvenanceLifeStageSelection provenanceSelection;
  final PhysicalFormSelection physicalFormSelection;
}
