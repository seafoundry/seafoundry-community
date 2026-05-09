/// Predefined reasons users can provide when advancing an organism to the next
/// life stage. Keeping the list centralized makes it easier to map to enums or
/// analytics later without hunting through multiple dialogs.
enum LifeStageTransitionReason {
  graduation('Graduation'),
  environmentalTrigger('Environmental trigger'),
  manualAdjustment('Manual adjustment'),
  other('Other');

  const LifeStageTransitionReason(this.label);

  final String label;
}
