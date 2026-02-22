# Organism Creation Wizard

Multi-step wizard for creating organism records with guided validation.

## Architecture

### Main Components

- **`organism_creation_wizard.dart`**: Main wizard container and navigation logic
- **`organism_creation_wizard_exports.dart`**: Barrel file for easy importing
- **`steps/`**: Individual step widgets (to be implemented)

### Wizard Flow

The wizard presents different steps based on the creation mode:

#### New Genet Mode (isNewGenet = true)
1. Classification - Species, organism kind, life stage
2. Identity - Local ID, aliases (optional)
3. Provenance - Provenance type, parent gametes, source cohort
4. Biometrics - Physical form, size spec
5. Measurements - Count, volume, tissue area
6. Review - Final validation and submission

#### Existing Inventory Mode (isNewGenet = false)
1. Classification - Species, organism kind, life stage
2. Identity - Local ID, aliases (optional)
3. Gain Reason - Population gain reason
4. Biometrics - Physical form, size spec
5. Measurements - Count, volume, tissue area
6. Review - Final validation and submission

### Integration

The wizard wraps the existing `OrganismCreationCubit` and provides:
- Step-by-step navigation
- Visual progress indicator
- Per-step validation
- Dynamic step configuration based on mode

### Usage

```dart
final record = await OrganismCreationWizard.show(
  context,
  organizationId: orgId,
  createdById: userId,
  siteId: siteId,  // optional
  groupId: groupId,  // optional
);

if (record != null) {
  // Save record to repository
}
```

## Development Status

- [x] Wizard shell and navigation
- [ ] Classification step widget
- [ ] Identity step widget
- [ ] Provenance step widget
- [ ] Gain reason step widget
- [ ] Biometrics step widget
- [ ] Measurements step widget
- [ ] Review step widget

## Testing

Step widgets should be tested individually and as part of the full wizard flow.
Each step should validate its inputs before allowing navigation to the next step.

## Naming Conventions
- In-app variables, identifiers, map keys, and user-facing names use camelCase.
- File and directory names prefer snake_case when creating or renaming, but internal naming is the hard rule.
