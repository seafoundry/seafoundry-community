// @tier: community

/// Result of hydrating a move event.
class MoveEventResult {
  const MoveEventResult({
    this.siteId,
    this.siteName,
    this.structureId,
    this.structureName,
    required this.details,
    this.quantityDelta,
  });

  final String? siteId;
  final String? siteName;
  final String? structureId;
  final String? structureName;
  final String details;
  final String? quantityDelta;
}

/// Result of hydrating an inventory event.
class InventoryEventResult {
  const InventoryEventResult({
    this.recordName,
    this.recordUrlPath,
    this.genetId,
    this.recordDisplay,
    this.physicalForm,
    this.siteId,
    this.siteName,
    this.structureId,
    this.structureName,
    this.details,
    this.quantityDelta,
  });

  final String? recordName;
  final String? recordUrlPath;
  final String? genetId;
  final String? recordDisplay;
  final String? physicalForm;
  final String? siteId;
  final String? siteName;
  final String? structureId;
  final String? structureName;
  final String? details;
  final String? quantityDelta;
}

/// Result of hydrating other (non-move, non-inventory) event types.
class GeneralEventResult {
  const GeneralEventResult({
    this.details,
    this.quantityDelta,
    this.recordDisplay,
    this.recordName,
    this.recordUrlPath,
    this.genetId,
    this.siteId,
    this.siteName,
    this.structureId,
  });

  final String? details;
  final String? quantityDelta;
  final String? recordDisplay;
  final String? recordName;
  final String? recordUrlPath;
  final String? genetId;
  final String? siteId;
  final String? siteName;
  final String? structureId;
}

/// Result of applying resolved record fallbacks.
class ResolvedFallbackResult {
  const ResolvedFallbackResult({
    required this.recordDisplay,
    this.recordName,
    this.physicalForm,
    this.siteId,
    this.siteName,
    this.structureId,
    this.structureName,
  });

  final String recordDisplay;
  final String? recordName;
  final String? physicalForm;
  final String? siteId;
  final String? siteName;
  final String? structureId;
  final String? structureName;
}
