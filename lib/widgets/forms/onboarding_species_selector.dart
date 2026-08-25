import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/species.dart';
import 'package:seafoundry_community/services/species_registry.dart';

/// Species selector for onboarding that doesn't require CurrentUser state.
/// Uses SpeciesRegistry.globalAll() directly since the organization hasn't
/// finished loading yet during onboarding.
class OnboardingSpeciesSelector extends StatelessWidget {
  const OnboardingSpeciesSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Species',
    this.hintText,
    this.enabled = true,
  });

  final Species? value;
  final ValueChanged<Species?> onChanged;
  final String? labelText;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Get all species from global registry (doesn't need CurrentUser)
    final allSpecies = SpeciesRegistry.globalAll();

    if (allSpecies.isEmpty) {
      return DropdownButtonFormField<Species?>(
        decoration: InputDecoration(
          labelText: labelText,
          hintText: 'No species loaded - seed taxonomy first',
          prefixIcon: const Icon(Icons.science),
          border: const OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      );
    }

    return DropdownButtonFormField<Species?>(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText ?? 'Select species',
        prefixIcon: const Icon(Icons.science),
        border: const OutlineInputBorder(),
      ),
      initialValue: value,
      isExpanded: true,
      items: allSpecies
          .map(
            (species) => DropdownMenuItem<Species?>(
              value: species,
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      species.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(species.name, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
