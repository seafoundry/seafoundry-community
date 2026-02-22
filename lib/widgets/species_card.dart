// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/species.dart';

import 'cards.dart';
import 'ui.dart';
import 'ui_text.dart';

class SpeciesCard extends StatelessWidget {
  final Species species;
  final void Function(Species species)? onTap;
  final bool showArrow;

  const SpeciesCard({super.key, required this.species, this.onTap, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return AppCards.basic(
      onTap: onTap != null ? () => onTap!(species) : null,
      child: Row(
        children: [
          UI.roundedIcon(Icons.local_florist),
          UI.spacingHorizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(species.code, style: UIText.h5Style.copyWith(fontWeight: FontWeight.bold)),
                    UI.spacingHorizontalSm,
                    UIText.bodySmall(species.name),
                  ],
                ),
              ],
            ),
          ),
          if (showArrow && onTap != null) UI.iconSmall(Icons.chevron_right, color: UI.textSecondaryColor),
        ],
      ),
    );
  }
}
