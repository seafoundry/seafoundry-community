import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/types/population_gain_reason.dart';
import 'package:seafoundry_community/widgets/common/visual_selector.dart';

/// Selector widget for PopulationGainReason
///
/// Displays a visual grid of gain reason options for organism inventory intake.
class PopulationGainReasonSelector extends StatelessWidget {
  const PopulationGainReasonSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PopulationGainReason? selected;
  final ValueChanged<PopulationGainReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return VisualSelector<PopulationGainReason>(
      options: [
        VisualOption(
          value: PopulationGainReason.fragmentation,
          icon: Icons.content_cut,
          label: 'Fragmentation',
          description: 'Created from parent fragment',
          color: Colors.green,
        ),
        VisualOption(
          value: PopulationGainReason.recruitment,
          icon: Icons.child_care,
          label: 'Recruitment',
          description: 'Natural settlement or spawning',
          color: Colors.blue,
        ),
        VisualOption(
          value: PopulationGainReason.rescue,
          icon: Icons.healing,
          label: 'Rescue / Collection',
          description: 'Field rescue or collection',
          color: Colors.orange,
        ),
        VisualOption(
          value: PopulationGainReason.transferIn,
          icon: Icons.move_to_inbox,
          label: 'Transfer In',
          description: 'Received from another source',
          color: Colors.purple,
        ),
        VisualOption(
          value: PopulationGainReason.other,
          icon: Icons.help_outline,
          label: 'Other',
          description: 'Other reason',
          color: Colors.grey,
        ),
      ],
      selected: selected,
      onChanged: onChanged,
      columns: 2,
    );
  }
}
