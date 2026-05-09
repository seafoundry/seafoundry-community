// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Shared selector for provenance + life stage inputs. Automatically restricts
/// life stage options based on the chosen provenance type metadata.
class ProvenanceLifeStageSelector extends StatefulWidget {
  const ProvenanceLifeStageSelector({
    super.key,
    required this.allowedProvenanceTypes,
    required this.initialSelection,
    required this.onChanged,
    this.provenanceLabel = 'Provenance Type',
    this.lifeStageLabel = 'Life Stage',
    this.helperText,
    this.lifeStageHelperText,
    this.fieldKeyPrefix,
    this.enabled = true,
  });

  final List<ProvenanceType> allowedProvenanceTypes;
  final ProvenanceLifeStageSelection initialSelection;
  final ValueChanged<ProvenanceLifeStageSelection> onChanged;
  final String provenanceLabel;
  final String lifeStageLabel;
  final String? helperText;
  final String? lifeStageHelperText;
  final String? fieldKeyPrefix;
  final bool enabled;

  @override
  State<ProvenanceLifeStageSelector> createState() =>
      _ProvenanceLifeStageSelectorState();
}

class _ProvenanceLifeStageSelectorState
    extends State<ProvenanceLifeStageSelector> {
  late ProvenanceType _provenanceType;
  late LifeStage _lifeStage;

  @override
  void initState() {
    super.initState();
    _provenanceType = widget.initialSelection.provenanceType;
    _lifeStage = widget.initialSelection.lifeStage;

    // Ensure initial values are in allowed lists
    _normalizeSelection();
  }

  void _normalizeSelection() {
    var nextProvenance = _provenanceType;
    var nextLifeStage = _lifeStage;
    var changed = false;

    final allowedTypes = widget.allowedProvenanceTypes;
    if (allowedTypes.isNotEmpty && !allowedTypes.contains(nextProvenance)) {
      nextProvenance = allowedTypes.first;
      nextLifeStage = nextProvenance.defaultLifeStage;
      changed = true;
    }

    final allowedStages =
        (nextProvenance.allowedLifeStages.isNotEmpty
                ? nextProvenance.allowedLifeStages
                : LifeStage.values)
            .toList();
    if (allowedStages.isNotEmpty && !allowedStages.contains(nextLifeStage)) {
      nextLifeStage = allowedStages.first;
      changed = true;
    }

    if (changed) {
      _provenanceType = nextProvenance;
      _lifeStage = nextLifeStage;
      // Notify parent of the normalized values
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyChanged();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProvenanceLifeStageSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    var nextProvenance = _provenanceType;
    var nextLifeStage = _lifeStage;
    var shouldNotify = false;
    var shouldUpdate = false;

    final selectionChanged =
        oldWidget.initialSelection.provenanceType !=
            widget.initialSelection.provenanceType ||
        oldWidget.initialSelection.lifeStage !=
            widget.initialSelection.lifeStage;
    if (selectionChanged) {
      nextProvenance = widget.initialSelection.provenanceType;
      nextLifeStage = widget.initialSelection.lifeStage;
      shouldUpdate = true;
    }

    final allowedTypes = widget.allowedProvenanceTypes;
    if (allowedTypes.isNotEmpty && !allowedTypes.contains(nextProvenance)) {
      nextProvenance = allowedTypes.first;
      nextLifeStage = nextProvenance.defaultLifeStage;
      shouldUpdate = true;
      shouldNotify = true;
    }

    final allowedStages =
        (nextProvenance.allowedLifeStages.isNotEmpty
                ? nextProvenance.allowedLifeStages
                : LifeStage.values)
            .toList();
    if (allowedStages.isNotEmpty && !allowedStages.contains(nextLifeStage)) {
      nextLifeStage = allowedStages.first;
      shouldUpdate = true;
      shouldNotify = true;
    }

    if (shouldUpdate &&
        (nextProvenance != _provenanceType || nextLifeStage != _lifeStage)) {
      setState(() {
        _provenanceType = nextProvenance;
        _lifeStage = nextLifeStage;
      });
      if (shouldNotify) {
        _notifyChanged();
      }
    }
  }

  List<LifeStage> get _allowedLifeStages {
    final allowed = _provenanceType.allowedLifeStages;
    return allowed.isNotEmpty ? allowed : LifeStage.values;
  }

  void _notifyChanged() {
    widget.onChanged(
      ProvenanceLifeStageSelection(
        provenanceType: _provenanceType,
        lifeStage: _lifeStage,
      ),
    );
  }

  String _dropdownKey(String suffix) =>
      '${widget.fieldKeyPrefix ?? 'provenance-life-stage'}-$suffix';

  @override
  Widget build(BuildContext context) {
    final allowedTypes = widget.allowedProvenanceTypes.isNotEmpty
        ? widget.allowedProvenanceTypes
        : <ProvenanceType>[_provenanceType];
    final provenanceItems = allowedTypes
        .map(
          (type) => DropdownMenuItem<ProvenanceType>(
            value: type,
            child: Text(type.displayName),
          ),
        )
        .toList();

    final lifeStageItems = _allowedLifeStages
        .map(
          (stage) => DropdownMenuItem<LifeStage>(
            value: stage,
            child: Text(stage.displayName),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ProvenanceType>(
          key: ValueKey(_dropdownKey('provenance')),
          initialValue: _provenanceType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.provenanceLabel,
            helperText:
                widget.helperText ??
                'Describes how this record originated (compliance).',
            enabled: widget.enabled,
          ),
          items: provenanceItems,
          onChanged:
              widget.enabled
                  ? (value) {
                    if (value == null) return;
                    final allowedStages = value.allowedLifeStages.isNotEmpty
                        ? value.allowedLifeStages
                        : LifeStage.values;
                    setState(() {
                      _provenanceType = value;
                      if (!allowedStages.contains(_lifeStage)) {
                        _lifeStage = value.defaultLifeStage;
                      }
                      _notifyChanged();
                    });
                  }
                  : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LifeStage>(
          key: ValueKey(_dropdownKey('life-stage')),
          initialValue: _lifeStage,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.lifeStageLabel,
            helperText:
                widget.lifeStageHelperText ?? 'Select the current life stage.',
            enabled: widget.enabled,
          ),
          items: lifeStageItems,
          onChanged:
              widget.enabled
                  ? (value) {
                    if (value == null) return;
                    setState(() {
                      _lifeStage = value;
                      _notifyChanged();
                    });
                  }
                  : null,
        ),
      ],
    );
  }
}
