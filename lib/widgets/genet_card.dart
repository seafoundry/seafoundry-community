// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

import 'cards.dart';
import 'ui.dart';
import 'ui_text.dart';

class GenetCard extends StatelessWidget {
  final Genet genet;
  final void Function(Genet genet)? onTap;
  final bool showArrow;

  const GenetCard({
    super.key,
    required this.genet,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final species = SpeciesRegistry.globalById(genet.speciesId);
    final selection = ProvenanceLifeStageSelection.fromGenet(genet);
    final provenanceLabel = selection.provenanceType.displayName;
    final clonalId = ClonalIdDisplayService.resolveForGenet(genet);
    return AppCards.basic(
      onTap: onTap != null ? () => onTap!(genet) : null,
      child: Row(
        children: [
          UI.roundedIcon(Icons.biotech),
          UI.spacingHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: UIText.h5(genet.name)),
                    UI.spacingHorizontalSm,
                    Text(provenanceLabel, style: UIText.bodySmallStyle),
                  ],
                ),
                UI.spacingVerticalXs,
                if (species != null)
                  UIText.bodySmall(species.name)
                else
                  UIText.bodySmall(genet.speciesId),
                UI.spacingVerticalXs,
                UIText.caption('Provenance ID: ${genet.provenanceId}'),
                if (clonalId != null) ...[
                  UI.spacingVerticalXs,
                  UIText.bodySmall('Clonal ID: $clonalId'),
                ],
              ],
            ),
          ),
          if (showArrow && onTap != null)
            UI.iconSmall(Icons.chevron_right, color: UI.textSecondaryColor),
        ],
      ),
    );
  }
}
