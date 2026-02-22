// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/ui.dart';

class FounderDetailsSection extends StatelessWidget {
  const FounderDetailsSection({super.key, required this.state});

  final GenetCreationInProgress state;

  @override
  Widget build(BuildContext context) {
    final formState = state.formState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProvenanceTextField(
          label: 'Reef/Origin',
          initialValue: formState.provOrigin.value,
          tooltip:
              'Specific reef or natural origin where this genet was collected.',
          onChanged: (v) =>
              context.read<GenetCreationBloc>().onProvOriginChanged(v),
        ),
        UI.spacingVerticalSm,
        _ProvenanceTextField(
          label: 'Location',
          initialValue: formState.provLocation.value,
          tooltip: 'Location description used in provenance reports.',
          onChanged: (v) =>
              context.read<GenetCreationBloc>().onProvLocationChanged(v),
        ),
        UI.spacingVerticalSm,
        _ProvenanceTextField(
          label: 'Depth (m)',
          initialValue: formState.provDepth.value,
          tooltip: 'Collection depth in meters (use decimals for precision).',
          onChanged: (v) =>
              context.read<GenetCreationBloc>().onProvDepthChanged(v),
        ),
        UI.spacingVerticalSm,
        _ProvenanceTextField(
          label: 'Habitat Type',
          initialValue: formState.provHabitatType.value,
          tooltip: 'Habitat classification of the collection site.',
          onChanged: (v) =>
              context.read<GenetCreationBloc>().onProvHabitatTypeChanged(v),
        ),
        UI.spacingVerticalSm,
        Row(
          children: const [
            Expanded(child: _ProvenanceLatField()),
            SizedBox(width: 8),
            Expanded(child: _ProvenanceLngField()),
          ],
        ),
      ],
    );
  }
}

class _ProvenanceTextField extends StatelessWidget {
  const _ProvenanceTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.tooltip,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: tooltip != null ? InfoTooltipIcon(message: tooltip!) : null,
      ),
      initialValue: initialValue,
      onChanged: onChanged,
    );
  }
}

class _ProvenanceLatField extends StatelessWidget {
  const _ProvenanceLatField();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }
    final formState = state.formState;
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Latitude (±DD.ddddd)',
        border: OutlineInputBorder(),
        suffixIcon: InfoTooltipIcon(
          message: 'Latitude in decimal degrees with at least five decimals.',
        ),
      ),
      initialValue: formState.provLatitude.value,
      onChanged: (v) => bloc.onProvLatitudeChanged(v),
    );
  }
}

class _ProvenanceLngField extends StatelessWidget {
  const _ProvenanceLngField();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }
    final formState = state.formState;
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Longitude (±DDD.ddddd)',
        border: OutlineInputBorder(),
        suffixIcon: InfoTooltipIcon(
          message: 'Longitude in decimal degrees with at least five decimals.',
        ),
      ),
      initialValue: formState.provLongitude.value,
      onChanged: (v) => bloc.onProvLongitudeChanged(v),
    );
  }
}
