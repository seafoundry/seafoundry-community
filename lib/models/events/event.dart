// @tier: community
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

import 'event_permit_metadata.dart';
import 'outplant_geometry.dart';

export 'event_permit_metadata.dart';
export 'outplant_geometry.dart';

class EventBaseParams {
  const EventBaseParams({
    this.permitMetadata,
    this.geometry,
    this.clearGeometry = false,
  });

  final EventPermitMetadata? permitMetadata;
  final OutplantGeometry? geometry;
  final bool clearGeometry;

  EventBaseParams copyWith({
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    bool? clearGeometry,
  }) {
    return EventBaseParams(
      permitMetadata: permitMetadata ?? this.permitMetadata,
      geometry: clearGeometry == true ? null : (geometry ?? this.geometry),
      clearGeometry: clearGeometry ?? this.clearGeometry,
    );
  }
}

class Event extends InventoryRecord {
  Event({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    required this.eventTypeId,
    required this.recordId,
    required this.recordModelType,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    OutplantGeometry? geometry,
    EventBaseParams base = const EventBaseParams(),
  }) : permitMetadata = base.permitMetadata ?? permitMetadata,
       geometry = base.clearGeometry ? null : (base.geometry ?? geometry);

  Event.fromJson(super.json)
    : eventTypeId = json['eventTypeId'],
      recordId = json['recordId'],
      recordModelType = json['recordModelType'] != null ? ModelType.fromSlug(json['recordModelType'] as String) : ModelType.unknown,
      permitMetadata = EventPermitMetadata.fromJson(
        json['permitMetadata'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['permitMetadata'])
            : null,
      ),
      geometry = OutplantGeometry.maybeFromJson(json['geometry']),
      super.fromJson();

  Event.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
    super.metadata,
    String? eventTypeId,
    String? recordId,
    ModelType? recordModelType,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
    EventBaseParams base = const EventBaseParams(),
  }) : eventTypeId = eventTypeId ?? json?['eventTypeId'] ?? Missing.string,
       recordId = recordId ?? json?['recordId'] ?? Missing.string,
       recordModelType =
           recordModelType ??
           ModelType.values.byName(
             json?['recordModelType'] ?? ModelType.unknown.name,
           ),
       permitMetadata =
           base.permitMetadata ??
           permitMetadata ??
           EventPermitMetadata.fromJson(
             json?['permitMetadata'] is Map<String, dynamic>
                 ? Map<String, dynamic>.from(json?['permitMetadata'])
                 : null,
           ),
       geometry = base.clearGeometry
           ? null
           : base.geometry ??
                 geometry ??
                 OutplantGeometry.maybeFromJson(json?['geometry']),
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      'eventTypeId': eventTypeId,
      'recordId': recordId,
      'recordModelType': recordModelType.name,
      if (!permitMetadata.isEmpty) 'permitMetadata': permitMetadata.toJson(),
      if (geometry != null) 'geometry': geometry!.toJson(),
      ...super.toJson(),
    };
  }

  @override
  Event copyWith({
    String? eventTypeId,
    String? recordId,
    ModelType? recordModelType,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? id,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    final resolvedBase = resolveBaseParams(
      permitMetadata: permitMetadata,
      geometry: geometry,
    );
    return Event(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      base: resolvedBase,
    );
  }

  @protected
  EventBaseParams resolveBaseParams({
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    final resolvedPermit = permitMetadata ?? this.permitMetadata;
    final resolvedGeometry = geometry ?? this.geometry;
    return EventBaseParams(
      permitMetadata: resolvedPermit,
      geometry: resolvedGeometry,
    );
  }

  @override
  ModelType get modelType => ModelType.event;

  EventType get eventType =>
      EventType.builtins[eventTypeId] ?? EventType.unknown;

  final String eventTypeId;
  final String recordId;
  final ModelType recordModelType;

  final EventPermitMetadata permitMetadata;
  final OutplantGeometry? geometry;

  @override
  List<Object?> get props =>
      super.props + [eventTypeId, recordId, recordModelType, permitMetadata, geometry];

  @override
  String toString() {
    return 'Event(${eventType.name}, $createdAt)';
  }
}

class OutplantEvent extends Event {
  OutplantEvent({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    required super.recordModelType,
    required this.name,
    required this.siteId,
    required this.allocations,
    this.comment,
    this.percentCover,
    this.percentBleaching,
    this.percentDisease,
    this.healthStatus,
    this.deliverableId,
    this.attachmentMethodId,
    super.geometry,
    super.permitMetadata,
    super.base,
  }) : super(eventTypeId: 'outplant_event');

  OutplantEvent.fromJson(super.json)
    : name = json['name'] ?? json['eventName'] ?? json['slug'],
      siteId = json['siteId'] ?? json['recordId'] ?? '',
      allocations = List.unmodifiable(_parseAllocations(json)),
      comment = json['comment'],
      percentCover = safeDouble(json['percentCover']),
      percentBleaching = safeDouble(json['percentBleaching']),
      percentDisease = safeDouble(json['percentDisease']),
      healthStatus = json['healthStatus'],
      deliverableId = json['deliverableId'] as String?,
      attachmentMethodId = json['attachmentMethodId'] as String?,
      super.fromJson();

  OutplantEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,
    String? eventTypeId,
    String? name,
    String? siteId,
    List<OutplantAllocation>? allocations,
    String? comment,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    String? healthStatus,
    String? deliverableId,
    String? attachmentMethodId,
    OutplantGeometry? geometry,
    EventPermitMetadata? permitMetadata,
    super.base,
  }) : name =
           name ??
           json?['name'] ??
           json?['eventName'] ??
           json?['slug'] ??
           'Outplant',
       siteId = siteId ?? json?['siteId'] ?? json?['recordId'] ?? 'unknown',
       allocations = List.unmodifiable(
         allocations ?? _parseAllocations(json ?? {}),
       ),
       comment = comment ?? json?['comment'],
       percentCover =
           percentCover ?? safeDouble(json?['percentCover']),
       percentBleaching =
           percentBleaching ?? safeDouble(json?['percentBleaching']),
       percentDisease =
           percentDisease ?? safeDouble(json?['percentDisease']),
       healthStatus = healthStatus ?? json?['healthStatus'],
       deliverableId = deliverableId ?? json?['deliverableId'] as String?,
       attachmentMethodId = attachmentMethodId ?? json?['attachmentMethodId'] as String?,
       super.partial(eventTypeId: eventTypeId ?? 'outplant_event');

  final String name;
  final String siteId;
  final List<OutplantAllocation> allocations;
  final String? comment;
  final double? percentCover;
  final double? percentBleaching;
  final double? percentDisease;
  final String? healthStatus;

  /// Optional link to a Deliverable for permit tracking
  final String? deliverableId;

  /// Attachment method used for this outplant (builtin or custom ID)
  final String? attachmentMethodId;

  int get totalQuantity =>
      allocations.fold<int>(0, (sum, a) => sum + a.quantity);


  /// Whether any allocations target a specific plot/patch (have a groupId)
  bool get hasPlotAllocations => allocations.any((a) => a.groupId != null);

  /// The set of distinct plot/patch groupIds used in allocations
  Set<String> get uniqueGroupIds =>
      allocations.map((a) => a.groupId).whereType<String>().toSet();

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'siteId': siteId,
      'allocations': allocations.map((a) => a.toJson()).toList(),
      'comment': comment,
      if (percentCover != null) 'percentCover': percentCover,
      if (percentBleaching != null) 'percentBleaching': percentBleaching,
      if (percentDisease != null) 'percentDisease': percentDisease,
      if (healthStatus != null) 'healthStatus': healthStatus,
      if (deliverableId != null) 'deliverableId': deliverableId,
      if (attachmentMethodId != null) 'attachmentMethodId': attachmentMethodId,
      'totalQuantity': totalQuantity,
      ...super.toJson(),
    };
  }

  @override
  bool validate() {
    return super.validate() &&
        siteId.isNotEmpty &&
        name.trim().isNotEmpty &&
        allocations.isNotEmpty &&
        totalQuantity > 0;
  }

  @override
  OutplantEvent copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? eventTypeId,
    String? recordId,
    String? urlPath,
    String? internalPath,
    String? slug,
    ModelType? recordModelType,
    String? name,
    String? siteId,
    List<OutplantAllocation>? allocations,
    String? comment,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    String? healthStatus,
    String? deliverableId,
    String? attachmentMethodId,
    bool clearDeliverableId = false,
    bool clearAttachmentMethodId = false,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
  }) {
    return OutplantEvent(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      recordId: recordId ?? this.recordId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ).copyWith(clearGeometry: clearGeometry),

      recordModelType: recordModelType ?? this.recordModelType,
      name: name ?? this.name,
      siteId: siteId ?? this.siteId,
      allocations: List.unmodifiable(allocations ?? this.allocations),
      comment: comment ?? this.comment,
      percentCover: percentCover ?? this.percentCover,
      percentBleaching: percentBleaching ?? this.percentBleaching,
      percentDisease: percentDisease ?? this.percentDisease,
      healthStatus: healthStatus ?? this.healthStatus,
      deliverableId: clearDeliverableId ? null : (deliverableId ?? this.deliverableId),
      attachmentMethodId: clearAttachmentMethodId ? null : (attachmentMethodId ?? this.attachmentMethodId),
      geometry: clearGeometry ? null : (geometry ?? this.geometry),
    );
  }


  @override
  List<Object?> get props => [
        ...super.props,
        name,
        siteId,
        allocations,
        comment,
        percentCover,
        percentBleaching,
        percentDisease,
        healthStatus,
        deliverableId,
        attachmentMethodId,
      ];

  static List<OutplantAllocation> _parseAllocations(Map<String, dynamic> json) {
    final rawAllocations = json['allocations'];
    if (rawAllocations is List) {
      return rawAllocations
          .whereType<Map<String, dynamic>>()
          .map(OutplantAllocation.fromJson)
          .toList();
    }

    // Backwards compatibility: single quantity snapshot
    final quantity = _parseQuantity(json['quantity']);
    final snapshot = json['snapshot'];
    if (snapshot is Map<String, dynamic>) {
      final organismId = snapshot['id'] ?? json['recordId'] ?? '';
      return [
        OutplantAllocation(
          organismId: organismId,
          tagId: snapshot['tagId'] ?? 'Record',
          speciesId: snapshot['speciesId'] ?? '',
          genetId: snapshot['genetId'],
          outplantTagId: json['outplantTagId'],
          tagName: json['tagName'],
          tagPath: json['tagPath'],
          quantity: quantity,
          sourcePath: snapshot['urlPath'] ?? '',
          snapshot: snapshot,
        ),
      ];
    }

    if (quantity > 0) {
      return [
        OutplantAllocation(
          organismId: json['recordId'] ?? '',
          tagId: 'Record',
          speciesId: '',
          genetId: null,
          outplantTagId: json['outplantTagId'],
          tagName: json['tagName'],
          tagPath: json['tagPath'],
          quantity: quantity,
          sourcePath: json['urlPath'] ?? '',
          snapshot: snapshot is Map<String, dynamic> ? snapshot : null,
        ),
      ];
    }

    return const <OutplantAllocation>[];
  }

  static int _parseQuantity(Object? raw) {
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }
}

class OutplantAllocation {
  const OutplantAllocation({
    required this.organismId,
    required this.tagId,
    required this.speciesId,
    this.genetId,
    this.outplantTagId,
    this.tagName,
    this.tagPath,
    this.groupId,
    this.groupName,
    this.groupPath,
    required this.quantity,
    required this.sourcePath,
    this.snapshot,
  });

  final String organismId;
  final String tagId;
  final String speciesId;
  final String? genetId;
  final String? outplantTagId;
  final String? tagName;
  final String? tagPath;

  /// Target plot/patch group ID (null = site-level outplant)
  final String? groupId;

  /// Human-readable name for the target plot/patch
  final String? groupName;

  /// URL path for navigation to the target plot/patch
  final String? groupPath;

  final int quantity;
  final String sourcePath;
  final Map<String, dynamic>? snapshot;

  Map<String, dynamic> toJson() {
    return {
      'organismId': organismId,
      'tagId': tagId,
      'speciesId': speciesId,
      if (genetId != null) 'genetId': genetId,
      if (outplantTagId != null) 'outplantTagId': outplantTagId,
      if (tagName != null) 'tagName': tagName,
      if (tagPath != null) 'tagPath': tagPath,
      if (groupId != null) 'groupId': groupId,
      if (groupName != null) 'groupName': groupName,
      if (groupPath != null) 'groupPath': groupPath,
      'quantity': quantity,
      'sourcePath': sourcePath,
      if (snapshot != null) 'snapshot': snapshot,
    };
  }

  factory OutplantAllocation.fromJson(Map<String, dynamic> json) {
    final organismId = json['organismId'] ?? '';
    final tagId = json['tagId'] ?? 'Record';

    return OutplantAllocation(
      organismId: organismId,
      tagId: tagId,
      speciesId: json['speciesId'] ?? '',
      genetId: json['genetId'],
      outplantTagId: json['outplantTagId'],
      tagName: json['tagName'],
      tagPath: json['tagPath'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      groupPath: json['groupPath'],
      quantity: OutplantEvent._parseQuantity(json['quantity']),
      sourcePath: json['sourcePath'] ?? '',
      snapshot: json['snapshot'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['snapshot'] as Map)
          : null,
    );
  }
}
