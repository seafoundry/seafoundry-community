// @tier: community
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';

/// Builders for seeding dialog field configurations
class SeedingFieldBuilders {
  static SeedingFieldConfig org(String? value) => SeedingFieldConfig(
        key: 'org',
        flagName: 'org',
        label: 'Organization ID',
        placeholder: '<ORG_ID>',
        required: true,
        initialValue: value,
      );

  static SeedingFieldConfig user(String? value) => SeedingFieldConfig(
        key: 'user',
        flagName: 'user',
        label: 'Admin User ID',
        placeholder: '<ADMIN_USER_ID>',
        required: true,
        initialValue: value,
      );

  static SeedingFieldConfig user2() => const SeedingFieldConfig(
        key: 'user2',
        flagName: 'user2',
        label: 'Second User ID (optional)',
        helper: 'Include a collaborator for events such as transfers.',
        advanced: true,
      );

  static SeedingFieldConfig history({required bool initial}) =>
      SeedingFieldConfig(
        key: 'history',
        flagName: 'history',
        label: 'Generate event history (--history)',
        helper: 'Adds historical move events when enabled.',
        type: SeedingFieldType.bool,
        initialBool: initial,
        omitWhenFalse: true,
        flagOnly: true,
      );

  static List<SeedingFieldConfig> inventoryOverrides() => const [
        SeedingFieldConfig(
          key: 'ex_structures',
          flagName: 'ex_structures',
          label: 'Ex-situ structures range',
          helper: 'Format: min-max (e.g. 10-18)',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'ex_racks',
          flagName: 'ex_racks',
          label: 'Ex-situ racks per structure',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'ex_fragments',
          flagName: 'ex_fragments',
          label: 'Ex-situ fragments per rack',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'ex_genets',
          flagName: 'ex_genets',
          label: 'Ex-situ genets per rack',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'in_structures',
          flagName: 'in_structures',
          label: 'In-situ structures range',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'in_racks',
          flagName: 'in_racks',
          label: 'In-situ racks per structure',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'in_fragments',
          flagName: 'in_fragments',
          label: 'In-situ fragments per rack',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'gene_structures',
          flagName: 'gene_structures',
          label: 'Gene bank structures range',
          helper: 'Format: min-max',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'gene_individuals',
          flagName: 'gene_individuals',
          label: 'Gene bank individuals',
          helper: 'Single integer (e.g. 20)',
          advanced: true,
        ),
        SeedingFieldConfig(
          key: 'outplant_tags',
          flagName: 'outplant_tags',
          label: 'Outplant tag count',
          helper: 'Single integer (e.g. 6)',
          advanced: true,
        ),
      ];

  static List<SeedingFieldConfig> resetOverrides() {
    return [
      ...inventoryOverrides(),
      const SeedingFieldConfig(
        key: 'in_genets',
        flagName: 'in_genets',
        label: 'In-situ genets per rack',
        helper: 'Format: min-max',
        advanced: true,
      ),
    ];
  }

  static SeedingFieldConfig extraArgs() => const SeedingFieldConfig(
        key: 'additional_args',
        flagName: null,
        label: 'Additional CLI flags',
        helper:
            'Optional extra flags, space separated (e.g. --overwrite=true --limit=5).',
        placeholder: '--flag=value --another=10',
        type: SeedingFieldType.textarea,
        advanced: true,
      );

  static SeedingFieldConfig modularDelete() => const SeedingFieldConfig(
        key: 'delete',
        flagName: 'delete',
        label: 'Delete existing data',
        helper: 'Remove current sites, groups, and corals before seeding.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
        initialBool: true,
      );

  static SeedingFieldConfig modularLandNursery() => const SeedingFieldConfig(
        key: 'seed_land',
        flagName: 'seed_land',
        label: 'Seed land-based nurseries',
        helper: 'Populate ex-situ nursery structures and corals.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig modularFieldNursery() => const SeedingFieldConfig(
        key: 'seed_field',
        flagName: 'seed_field',
        label: 'Seed field nurseries',
        helper: 'Populate in-situ nursery structures and corals.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig modularGeneBank() => const SeedingFieldConfig(
        key: 'seed_gene',
        flagName: 'seed_gene',
        label: 'Seed gene banks',
        helper: 'Populate gene bank tanks with individual samples.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig modularOutplantEvents() =>
      const SeedingFieldConfig(
        key: 'seed_outplant',
        flagName: 'seed_outplant',
        label: 'Seed outplant events',
        helper: 'Create outplant tags and events with allocations.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig modularMonitoringEvents() =>
      const SeedingFieldConfig(
        key: 'seed_monitoring',
        flagName: 'seed_monitoring',
        label: 'Seed monitoring events',
        helper: 'Add monitoring records with entries for seeded outplants.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig modularHistory() => const SeedingFieldConfig(
        key: 'seed_history',
        flagName: 'seed_history',
        label: 'Seed history (observations & moves)',
        helper: 'Generate historical activity, observations, and moves.',
        type: SeedingFieldType.bool,
        omitWhenFalse: true,
        flagOnly: false,
      );

  static SeedingFieldConfig _visibleTextField({
    required String key,
    required String flag,
    required String label,
    String? helper,
    String? placeholder,
    String initialValue = '',
    required String controllingKey,
  }) =>
      SeedingFieldConfig(
        key: key,
        flagName: flag,
        label: label,
        helper: helper,
        placeholder: placeholder,
        advanced: true,
        initialValue: initialValue,
        isVisible: (values) => values[controllingKey] ?? false,
      );

  static SeedingFieldConfig modularExStructures() => _visibleTextField(
        key: 'ex_structures',
        flag: 'ex_structures',
        label: 'Ex-situ structures range',
        helper: 'Format: min-max (e.g. 10-18)',
        initialValue: '10-15',
        controllingKey: 'seed_land',
      );

  static SeedingFieldConfig modularExRacks() => _visibleTextField(
        key: 'ex_racks',
        flag: 'ex_racks',
        label: 'Ex-situ racks per structure',
        helper: 'Format: min-max',
        initialValue: '8-14',
        controllingKey: 'seed_land',
      );

  static SeedingFieldConfig modularExFragments() => _visibleTextField(
        key: 'ex_fragments',
        flag: 'ex_fragments',
        label: 'Ex-situ fragments per rack',
        helper: 'Format: min-max',
        initialValue: '20-60',
        controllingKey: 'seed_land',
      );

  static SeedingFieldConfig modularExGenets() => _visibleTextField(
        key: 'ex_genets',
        flag: 'ex_genets',
        label: 'Ex-situ genets per rack',
        helper: 'Format: min-max',
        initialValue: '3-5',
        controllingKey: 'seed_land',
      );

  static SeedingFieldConfig modularInStructures() => _visibleTextField(
        key: 'in_structures',
        flag: 'in_structures',
        label: 'In-situ structures range',
        helper: 'Format: min-max',
        initialValue: '10-15',
        controllingKey: 'seed_field',
      );

  static SeedingFieldConfig modularInRacks() => _visibleTextField(
        key: 'in_racks',
        flag: 'in_racks',
        label: 'In-situ racks per structure',
        helper: 'Format: min-max',
        initialValue: '10-15',
        controllingKey: 'seed_field',
      );

  static SeedingFieldConfig modularInFragments() => _visibleTextField(
        key: 'in_fragments',
        flag: 'in_fragments',
        label: 'In-situ fragments per structure',
        helper: 'Format: min-max',
        initialValue: '20-60',
        controllingKey: 'seed_field',
      );

  static SeedingFieldConfig modularInGenets() => _visibleTextField(
        key: 'in_genets',
        flag: 'in_genets',
        label: 'In-situ genets per structure',
        helper: 'Format: min-max',
        initialValue: '3-5',
        controllingKey: 'seed_field',
      );

  static SeedingFieldConfig modularGeneStructures() => _visibleTextField(
        key: 'gene_structures',
        flag: 'gene_structures',
        label: 'Gene bank structures range',
        helper: 'Format: min-max',
        initialValue: '8-12',
        controllingKey: 'seed_gene',
      );

  static SeedingFieldConfig modularGeneIndividuals() => _visibleTextField(
        key: 'gene_individuals',
        flag: 'gene_individuals',
        label: 'Gene bank individuals',
        helper: 'Single integer (e.g. 20)',
        initialValue: '20',
        controllingKey: 'seed_gene',
      );

  static SeedingFieldConfig modularOutplantCount() => _visibleTextField(
        key: 'outplant_count',
        flag: 'outplant_count',
        label: 'Outplant events to create',
        helper: 'Number of outplant events',
        initialValue: '4',
        controllingKey: 'seed_outplant',
      );

  static SeedingFieldConfig modularOutplantAllocations() => _visibleTextField(
        key: 'outplant_allocations',
        flag: 'outplant_allocations',
        label: 'Allocations per outplant event',
        helper: 'Number of coral clusters per event',
        initialValue: '3',
        controllingKey: 'seed_outplant',
      );

  static SeedingFieldConfig modularMonitoringCount() => _visibleTextField(
        key: 'monitoring_count',
        flag: 'monitoring_count',
        label: 'Monitoring events to create',
        helper: 'Number of monitoring events with entries',
        initialValue: '3',
        controllingKey: 'seed_monitoring',
      );
}
