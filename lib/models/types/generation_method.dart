// @tier: community

/// Method by which an organism record was generated from a source record.
///
/// Used to track lineage in event history when organisms are created
/// via split or propagation operations.
enum GenerationMethod {
  split('split', 'Split'),
  propagation('propagation', 'Propagation');

  const GenerationMethod(this.id, this.label);

  final String id;
  final String label;

  static GenerationMethod? fromId(String? id) {
    if (id == null) return null;
    return GenerationMethod.values.where((m) => m.id == id).firstOrNull;
  }

  /// Resolve generation method from the explicit `generationMethod`
  /// metadata key on an organism record.
  static GenerationMethod? infer(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    return fromId(metadata['generationMethod'] as String?);
  }

  /// Build standard generation tracking metadata entries.
  ///
  /// Used by both [OrganismSplitService] and [PropagationBloc] to ensure
  /// consistent metadata keys across generation methods.
  static Map<String, dynamic> buildMetadata({
    required GenerationMethod method,
    required String sourceOrganismId,
    required String sourceOrganismRecordName,
    String? sourceOrganismLocalId,
  }) =>
      {
        'generationMethod': method.id,
        'sourceOrganismId': sourceOrganismId,
        'sourceOrganismRecordName': sourceOrganismRecordName,
        if (sourceOrganismLocalId != null)
          'sourceOrganismLocalId': sourceOrganismLocalId,
      };
}
