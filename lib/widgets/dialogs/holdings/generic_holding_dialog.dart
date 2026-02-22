// @tier: community
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/widgets/common/alias_editor.dart';
import 'package:seafoundry_app/widgets/common/five_axis_editor.dart';
import 'package:seafoundry_app/widgets/common/physical_form_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/five_axis_dialog_section.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';
import 'package:seafoundry_app/widgets/repositories/registry/registry.dart';
import '../components/dialog_scroll_view.dart';
import '../../notifications/toast_overlay.dart';

class GenericHoldingDialog extends StatefulWidget {
  const GenericHoldingDialog({
    super.key,
    required this.group,
    required this.config,
  });

  final Group group;
  final HoldingDialogConfig config;

  static Future<bool?> show(
    BuildContext context, {
    required Group group,
    required HoldingDialogConfig config,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => GenericHoldingDialog(group: group, config: config),
    );
  }

  @override
  State<GenericHoldingDialog> createState() => _GenericHoldingDialogState();
}

class _GenericHoldingDialogState extends State<GenericHoldingDialog>
    with SafeDialogMixin<GenericHoldingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _localIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _extraFieldController = TextEditingController();
  final _bagIdentifierController = TextEditingController();
  final _ownerController = TextEditingController();
  final _managingController = TextEditingController();
  DateTime? _dateValue;
  bool _isSaving = false;
  late ProvenanceLifeStageSelection _initialFiveAxisSelection;
  FiveAxisSelection? _fiveAxisSelection;
  List<GenetAliasEntry> _aliases = const <GenetAliasEntry>[];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.config.defaultName;
    final orgId = widget.group.organizationId;
    _ownerController.text = orgId;
    _managingController.text = orgId;
    _initialFiveAxisSelection = ProvenanceLifeStageSelection(
      provenanceType: widget.config.initialProvenanceType,
      lifeStage: widget.config.initialLifeStage,
    );
    _quantityController.addListener(_handleMeasurementChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _localIdController.dispose();
    _quantityController.dispose();
    _extraFieldController.dispose();
    _bagIdentifierController.dispose();
    _ownerController.dispose();
    _managingController.dispose();
    _quantityController.removeListener(_handleMeasurementChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.config.title),
      content: Form(
        key: _formKey,
        child: DialogScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _localIdController,
                decoration: const InputDecoration(
                  labelText: 'Local ID',
                  helperText:
                      'Required. Genet/lineage identifier for this holding.',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Local ID is required';
                  }
                  return null;
                },
              ),
              if (widget.config.organismKind == OrganismKind.oyster)
                TextFormField(
                  controller: _bagIdentifierController,
                  decoration: const InputDecoration(
                    labelText: 'Bag identifier',
                    helperText: 'Optional – e.g., Rack 3 / Position 4',
                  ),
                ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: widget.config.quantityLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a value greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              FiveAxisDialogSection(
                organismKind: widget.config.organismKind,
                fieldKeyPrefix: widget.config.fieldKeyPrefix,
                initialSelection: _fiveAxisSelection?.provenanceSelection ??
                    _initialFiveAxisSelection,
                initialPhysicalFormId:
                    _fiveAxisSelection?.physicalFormSelection.physicalFormId ??
                        widget.config.initialPhysicalFormId,
                initialSizeSpec:
                    _fiveAxisSelection?.physicalFormSelection.sizeSpec ??
                        const SizeSpec(),
                measurement: _currentMeasurement(),
                helpText: widget.config.fiveAxisHelpText,
                onChanged: (selection) =>
                    setState(() => _fiveAxisSelection = selection),
              ),
              if (widget.config.extraField != null)
                TextFormField(
                  controller: _extraFieldController,
                  decoration: InputDecoration(
                    labelText: widget.config.extraField!.label,
                    helperText: widget.config.extraField!.helperText,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateValue == null
                          ? widget.config.dateFieldLabel
                          : '${widget.config.dateFieldLabel}: ${_dateValue!.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Select date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AliasEditorList(
                aliases: _aliases,
                onAddAlias: _addAlias,
                onRemoveAlias: _removeAlias,
                onValueChanged: _updateAliasValue,
                onSourceChanged: _updateAliasSource,
                onLabelChanged: _updateAliasLabel,
                excludedSystems: kReservedAliasSystems,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  labelText: 'Owner organization id',
                  hintText: 'Defaults to your organization',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managingController,
                decoration: const InputDecoration(
                  labelText: 'Managing organization id',
                  hintText: 'Custodial org for day-to-day care',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => popDialog(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleSubmit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateValue ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dateValue = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final registry = context.read<RepositoryRegistry>();
      final repository = registry.getForKind<HoldingRepository>(widget.config.organismKind);
      final measurement = _currentMeasurement();
      final axisSelection = _resolvedFiveAxisSelection();
      final group = widget.group;
      final ownerOrgId = _ownerController.text.trim().isEmpty
          ? group.organizationId
          : _ownerController.text.trim();
      final managingOrgId = _managingController.text.trim().isEmpty
          ? ownerOrgId
          : _managingController.text.trim();
      final aliasEntries = _buildAliasPayload();
      final recordName = _nameController.text.trim();
      final localId = _localIdController.text.trim();

      final params = HoldingFactoryParams(
        recordName: recordName,
        localId: localId,
        organismKind: widget.config.organismKind,
        measurement: measurement,
        siteId: group.siteId,
        groupId: group.id,
        ownerOrganizationId: ownerOrgId,
        managingOrganizationId: managingOrgId,
        organismRecord: OrganismRecord.partial(
          organismKind: widget.config.organismKind,
          recordName: recordName,
          localId: localId,
          lifeStage: LifeStageSpec(
            stage: axisSelection.provenanceSelection.lifeStage,
          ),
          provenanceType: axisSelection.provenanceSelection.provenanceType,
          measurement: measurement,
          sizeSpec: axisSelection.physicalFormSelection.sizeSpec,
          ownerOrganizationId: ownerOrgId,
          managingOrganizationId: managingOrgId,
          aliases: aliasEntries,
        ),
        organismLifeStage: axisSelection.provenanceSelection.lifeStage,
        extraFieldValue: _extraFieldController.text.trim().isEmpty
            ? null
            : double.tryParse(_extraFieldController.text.trim()),
        dateValue: _dateValue,
        bagIdentifier: _bagIdentifierController.text.trim().isEmpty
            ? null
            : _bagIdentifierController.text.trim(),
      );

      final holding = widget.config.holdingFactory(params);
      await repository.createHolding(holding);

      if (mounted) {
        popDialog(true);
      }
    } on CapabilityConstraintError catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ToastOverlay.showSnackBar(context,
      SnackBar(content: Text(message)),
    );
    setState(() => _isSaving = false);
  }

  void _addAlias() {
    setState(() {
      _aliases = List<GenetAliasEntry>.from(_aliases)
        ..add(const GenetAliasEntry());
    });
  }

  void _removeAlias(int index) {
    if (index < 0 || index >= _aliases.length) return;
    setState(() {
      _aliases = List<GenetAliasEntry>.from(_aliases)..removeAt(index);
    });
  }

  void _updateAliasValue(int index, String value) {
    if (index < 0 || index >= _aliases.length) return;
    setState(() {
      _aliases = List<GenetAliasEntry>.from(_aliases)
        ..[index] = _aliases[index].copyWith(value: value);
    });
  }

  void _updateAliasSource(int index, String source) {
    if (index < 0 || index >= _aliases.length) return;
    setState(() {
      _aliases = List<GenetAliasEntry>.from(_aliases)
        ..[index] = _aliases[index].copyWith(sourceSystem: source);
    });
  }

  void _updateAliasLabel(int index, String label) {
    if (index < 0 || index >= _aliases.length) return;
    setState(() {
      _aliases = List<GenetAliasEntry>.from(_aliases)
        ..[index] = _aliases[index].copyWith(label: label);
    });
  }

  List<OrganismAlias> _buildAliasPayload() {
    if (_aliases.isEmpty) return const <OrganismAlias>[];
    return _aliases
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => entry.toOrganismAlias())
        .toList(growable: false);
  }

  PopulationMeasurement _currentMeasurement() {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    return PopulationMeasurement(value: qty, unit: MeasurementUnit.count);
  }

  FiveAxisSelection _resolvedFiveAxisSelection() {
    return _fiveAxisSelection ??
        FiveAxisSelection(
          provenanceSelection: _initialFiveAxisSelection,
          physicalFormSelection: PhysicalFormSelection(
            physicalFormId: widget.config.initialPhysicalFormId ?? '',
            sizeSpec: const SizeSpec(),
          ),
        );
  }

  void _handleMeasurementChanged() {
    setState(() {});
  }
}
