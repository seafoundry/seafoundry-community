
/// Result of dual-path migration validation
class DualPathValidationResult {
  const DualPathValidationResult({
    required this.isEnabled,
    required this.message,
    this.coralCount,
    this.organismRecordCount,
    this.totalCoralQuantity,
    this.totalOrganismQuantity,
    this.orphanedCoralCount,
    this.discrepancies = const [],
  });

  final bool isEnabled;
  final String message;
  final int? coralCount;
  final int? organismRecordCount;
  final int? totalCoralQuantity;
  final int? totalOrganismQuantity;
  final int? orphanedCoralCount;
  final List<String> discrepancies;

  bool get hasDiscrepancies => discrepancies.isNotEmpty;

  @override
  String toString() {
    if (!isEnabled) {
      return 'Dual-Path Validation: Not Enabled';
    }

    final buffer = StringBuffer();
    buffer.writeln('Dual-Path Validation Result:');
    buffer.writeln('  Message: $message');
    if (coralCount != null) {
      buffer.writeln('  Coral Records: $coralCount');
    }
    if (organismRecordCount != null) {
      buffer.writeln('  OrganismRecord.coral Records: $organismRecordCount');
    }
    if (totalCoralQuantity != null) {
      buffer.writeln('  Total Coral Quantity: $totalCoralQuantity');
    }
    if (totalOrganismQuantity != null) {
      buffer.writeln('  Total Organism Quantity: $totalOrganismQuantity');
    }
    if (orphanedCoralCount != null && orphanedCoralCount! > 0) {
      buffer.writeln('  Orphaned Corals: $orphanedCoralCount');
    }
    if (discrepancies.isNotEmpty) {
      buffer.writeln('  Discrepancies:');
      for (final discrepancy in discrepancies) {
        buffer.writeln('    - $discrepancy');
      }
    }
    return buffer.toString();
  }
}
