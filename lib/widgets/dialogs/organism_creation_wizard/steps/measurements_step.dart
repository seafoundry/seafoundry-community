import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/widgets/common/physical_form_selector.dart';
import 'package:seafoundry_app/widgets/common/size_change_editor.dart';
import 'organism_creation_step_scroll_view.dart';


/// Step 5: Measurements - Quantity field with validation
class MeasurementsStep extends StatefulWidget {
  const MeasurementsStep({
    super.key,
    required this.state,
  });

  final OrganismCreationState state;

  @override
  State<MeasurementsStep> createState() => _MeasurementsStepState();
}

class _MeasurementsStepState extends State<MeasurementsStep> {
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    final value = widget.state.measurement.value;
    _quantityController = TextEditingController(
      text: value == 0 ? '' : _formatValue(value),
    );
  }

  @override
  void didUpdateWidget(covariant MeasurementsStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.measurement.value != oldWidget.state.measurement.value) {
      final currentValue = double.tryParse(_quantityController.text) ?? 0;
      if ((widget.state.measurement.value - currentValue).abs() > 0.0001) {
        final newValue = widget.state.measurement.value;
        // Keep cursor position if possible, otherwise it jumps to end
        // Simplest strategy for external updates is to replace text
        _quantityController.text = newValue == 0 ? '' : _formatValue(newValue);
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    // Remove trailing .0 for cleaner display
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();
    final state = widget.state;

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Physical Form',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (state.availablePhysicalForms.isEmpty)
            Text(
              'No physical forms available for this organism type and life stage',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else ...[
            PhysicalFormSelector(
              forms: state.availablePhysicalForms,
              selectedFormId: state.physicalForm?.formId,
              onChanged: (formId) {
                if (formId != null) {
                  final form = state.availablePhysicalForms
                      .firstWhere((f) => f.id == formId);
                  final instance = PhysicalFormInstance(
                    formId: formId,
                    sizeBandId: form.defaultSizeBand?.id ?? '',
                  );
                  cubit.physicalFormChanged(instance);
                }
              },
            ),
            if (state.physicalForm != null) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final formConfig = state.availablePhysicalForms.firstWhere(
                    (f) => f.id == state.physicalForm!.formId,
                    orElse: () => state.availablePhysicalForms.first,
                  );
                  if (formConfig.sizeBands.isEmpty) return const SizedBox.shrink();

                  return SizeChangeEditor(
                    currentSize: state.sizeSpec,
                    showCurrentSize: false,
                    sizeBandConfigs: formConfig.sizeBands,
                    selectedSizeClass: state.physicalForm!.sizeBandId,
                    onSizeClassChanged: (bandId) {
                      if (bandId != null) {
                        cubit.physicalFormChanged(
                          PhysicalFormInstance(
                            formId: state.physicalForm!.formId,
                            sizeBandId: bandId,
                          ),
                        );
                      }
                    },
                    isBusy: state.isLoading,
                    placeholderLabel: 'Size Class',
                  );
                },
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text(
            'Quantity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity *',
              hintText: 'Enter quantity (count, volume, etc.)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.numbers),
              helperText: 'Number of organisms or units',
              suffixText: state.measurement.unit.label,
              errorText: state.measurement.value <= 0
                  ? 'Quantity must be greater than 0'
                  : null,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                cubit.measurementChanged(
                  PopulationMeasurement(
                    value: parsed,
                    unit: state.measurement.unit,
                  ),
                );
              } else if (value.isEmpty) {
                // Set to 0 to trigger validation error and block "Next"
                cubit.measurementChanged(
                  PopulationMeasurement(
                    value: 0,
                    unit: state.measurement.unit,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
