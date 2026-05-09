
/// Mode for batch transfer: multiple genets to one org, or one genet to multiple orgs.
enum BatchTransferMode {
  multiGenetToOneOrg('multiGenetToOneOrg'),
  oneGenetToMultiOrg('oneGenetToMultiOrg');

  const BatchTransferMode(this.id);
  final String id;
}

/// Step in the batch transfer wizard flow.
enum BatchTransferStep {
  selectFixed('selectFixed'),
  addItems('addItems'),
  review('review'),
  submitting('submitting'),
  complete('complete');

  const BatchTransferStep(this.id);
  final String id;
}

/// Status of an individual batch transfer item.
enum BatchItemStatus {
  pending('pending'),
  submitting('submitting'),
  success('success'),
  failure('failure');

  const BatchItemStatus(this.id);
  final String id;
}
