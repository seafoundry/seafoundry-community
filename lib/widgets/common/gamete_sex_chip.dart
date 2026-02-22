// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Visual configuration for gamete sex display.
class GameteSexVisual {
  final IconData icon;
  final Color color;
  final String label;

  const GameteSexVisual._({
    required this.icon,
    required this.color,
    required this.label,
  });

  static const egg = GameteSexVisual._(
    icon: Icons.egg_outlined,
    color: Color(0xFFFF9800), // Orange
    label: 'Eggs',
  );

  static const sperm = GameteSexVisual._(
    icon: Icons.water_drop_outlined,
    color: Color(0xFF00BCD4), // Cyan
    label: 'Sperm',
  );

  static GameteSexVisual? fromRole(ProvenanceGameteRole? role) {
    if (role == null) return null;
    return role == ProvenanceGameteRole.egg ? egg : sperm;
  }
}

/// Displays gamete sex (eggs/sperm) as a compact chip with icon.
///
/// Use this widget to show gamete type on organism cards when the
/// organism has [LifeStage.gamete].
///
/// Features:
/// - Shows appropriate icon: egg icon for eggs, water drop for sperm
/// - Color-coded: orange/amber for eggs, cyan/blue for sperm
/// - Compact display suitable for card layouts
class GameteSexChip extends StatelessWidget {
  const GameteSexChip({
    super.key,
    required this.role,
    this.compact = false,
    this.showLabel = true,
  });

  /// The gamete role to display.
  final ProvenanceGameteRole role;

  /// Whether to use compact styling (smaller padding/font).
  final bool compact;

  /// Whether to show the label text (e.g., "Eggs" or "Sperm").
  /// If false, only shows the icon.
  final bool showLabel;

  /// Creates a chip from an OrganismRecord, returning null if not a gamete.
  static GameteSexChip? fromOrganism(
    OrganismRecord organism, {
    bool compact = false,
    bool showLabel = true,
  }) {
    if (organism.lifeStage.stage != LifeStage.gamete) return null;

    final role = resolveGameteRole(organism);
    if (role == null) return null;

    return GameteSexChip(
      role: role,
      compact: compact,
      showLabel: showLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = GameteSexVisual.fromRole(role)!;

    final horizontalPadding = compact ? 4.0 : 6.0;
    final verticalPadding = compact ? 1.0 : 2.0;
    final fontSize = compact ? 9.0 : 10.0;
    final iconSize = compact ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: visual.color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visual.icon,
            size: iconSize,
            color: visual.color,
          ),
          if (showLabel) ...[
            SizedBox(width: compact ? 2 : 3),
            Text(
              visual.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: visual.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Resolves gamete role from an OrganismRecord.
///
/// Checks multiple sources in priority order:
/// 1. provenanceAttributes.gameteRole (canonical location)
/// 2. metadata['gameteRole'] or metadata['gameteSex']
///
/// Returns null if the organism is not a gamete or role is not set.
ProvenanceGameteRole? resolveGameteRole(OrganismRecord organism) {
  // First check the canonical location
  final roleFromAttrs = organism.provenanceAttributes.gameteRole;
  if (roleFromAttrs != null) return roleFromAttrs;

  // Fall back to metadata
  return _resolveGameteRoleFromMetadata(organism.metadata);
}

ProvenanceGameteRole? _resolveGameteRoleFromMetadata(
  Map<String, dynamic>? metadata,
) {
  if (metadata == null || metadata.isEmpty) return null;

  String? read(List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  final rawRole = read([
    'gameteRole',
    'gamete_role',
    'gameteSex',
    'gamete_sex',
  ]);

  final parsedRole = ProvenanceGameteRoleX.tryParse(rawRole);
  if (parsedRole != null) {
    return parsedRole;
  }

  // Handle string variations
  if (rawRole != null) {
    final normalized = rawRole.toLowerCase();
    if (normalized == 'egg' || normalized == 'eggs') {
      return ProvenanceGameteRole.egg;
    }
    if (normalized == 'sperm' || normalized == 'sire') {
      return ProvenanceGameteRole.sperm;
    }
  }

  // Check boolean flags
  final eggFlag = metadata['egg'] == true || metadata['isEgg'] == true;
  if (eggFlag) return ProvenanceGameteRole.egg;
  final sireFlag = metadata['sire'] == true || metadata['isSire'] == true;
  if (sireFlag) return ProvenanceGameteRole.sperm;

  return null;
}
