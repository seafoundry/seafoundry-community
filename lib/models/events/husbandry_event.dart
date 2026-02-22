// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/event_mixins.dart';

/// Abstract base class for all husbandry-related events
///
/// Husbandry events track maintenance and care activities performed
/// on sites, groups, or corals. These include water quality testing,
/// feeding, cleaning, treatments, environmental adjustments, and
/// structure maintenance.
abstract class HusbandryEvent extends Event with ImageEvent, CommentEvent {
  @override
  final String? imageUrl;

  @override
  final String? comment;

  HusbandryEvent({
    required super.id,
    required super.eventTypeId,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
    this.imageUrl,
    this.comment,
  });

  HusbandryEvent.fromJson(super.json)
    : imageUrl = json['imageUrl'],
      comment = json['comment'],
      super.fromJson();

  HusbandryEvent.partial({
    super.json,
    super.id,
    super.eventTypeId,
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

    super.base,
    String? imageUrl,
    String? comment,
  }) : imageUrl = imageUrl ?? json?['imageUrl'],
       comment = comment ?? json?['comment'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (comment != null) 'comment': comment,
    };
  }

  @override
  List<Object?> get props => [...super.props, imageUrl, comment];
}
