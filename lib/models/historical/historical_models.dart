// @tier: community

// Historical data models for CRC and other legacy datasets.
//
// These models represent historical outplanting events and related data
// that are imported from external sources like the CRC (Coral Restoration Consortium).
//
// Key collections:
// - `historical_outplant_events/{id}` - Full event details
// - `reef_aggregates/{id}` - Aggregated reef statistics
// - `public_impact_points` - Map markers (includes historicalOutplant type)

export 'historical_filter_options.dart';
export 'historical_genotype.dart';
export 'historical_outplant_event.dart';
export 'nomenclature_system.dart';
export 'provenance_id.dart';
export 'reef_aggregate.dart';
