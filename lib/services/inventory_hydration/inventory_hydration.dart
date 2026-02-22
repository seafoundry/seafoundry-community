// @tier: community
// Barrel file for inventory event hydration services.
// This module provides services for transforming raw Event objects
// into hydrated InventoryEventRow instances suitable for spreadsheet display.

export 'batch_hydration_service.dart';
export 'general_event_hydrator.dart' show hydrateGeneralEvent;
export 'hydration_result.dart';
export 'hydration_utils.dart';
export 'inventory_event_hydration_service.dart';
export 'inventory_event_hydrator.dart' show hydrateInventoryEvent;
export 'move_event_hydrator.dart' show hydrateMoveEvent;
export 'resolved_record_fallback.dart' show applyResolvedRecordFallbacks;
