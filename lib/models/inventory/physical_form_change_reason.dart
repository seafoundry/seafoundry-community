enum PhysicalFormChangeReason {
  growth('Growth / maturation'),
  densityManagement('Density management'),
  substrateChange('Substrate change'),
  other('Other');

  const PhysicalFormChangeReason(this.label);

  final String label;
}
