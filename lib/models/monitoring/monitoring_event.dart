// @tier: community
import 'package:flutter/widgets.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/monitoring/organism_monitoring_data.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

export 'organism_monitoring_data.dart';

/// Helper functions for working with monitoring events
/// Following main branch's architecture patterns
class MonitoringEvent {
  /// Convert a MonitoringEventRecord to a OrganismMonitoringData
  static OrganismMonitoringData toOrganismMonitoringData(
    MonitoringEventRecord event, {
    required String recordName,
    required String speciesName,
    String? siteName,
    String? groupName,
  }) {
    return OrganismMonitoringData(
      organismId: event.recordId,
      recordName: recordName,
      speciesId: event.recordModelType.name,
      speciesName: speciesName,
      genetId: '', // Would need to be populated from organism data
      siteId: event.siteId,
      siteName: siteName,
      groupId: null,
      groupName: groupName,
      oldHealthStatus: event.oldHealthStatusEnum ?? HealthStatus.healthy,
      newHealthStatus: event.newHealthStatusEnum,
      healthIssueTypeId: event.healthIssueTypeId,
      percentCover: event.percentCover,
      percentBleaching: event.percentBleaching,
      percentDisease: event.percentDisease,
      measurements: event.measurements,
      imageUrl: event.imageUrl,
      comment: event.comment,
      monitoringDate:
          event.monitoringDate ??
          DateTimeConverter.fromIso8601String(event.createdAt) ??
          DateTime.now(),
      createTask: event.createTask,
    );
  }

  /// Create a MonitoringEventRecord from a GraphNode and OrganismMonitoringData
  /// Uses GraphNodeCompat for compatibility with main's architecture
  static Future<MonitoringEventRecord?> createFromNode({
    required BuildContext context,
    required GraphNode node,
    required OrganismMonitoringData data,
    required String createdById,
    required String organizationId,
  }) async {
    try {
      // Wait for node to be loaded
      await node.awaitLoaded();

      // Get record ID and URL path using main's pattern
      final recordId = node.id;
      final urlPath = node.urlPath;
      final internalPath = node.internalPath;
      final modelType = node.modelType;

      final now = DateTimeConverter.nowAsIso8601String();
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final slug = 'monitoring-$id';

      return MonitoringEventRecord(
        id: id,
        createdById: createdById,
        createdAt: now,
        updatedAt: now,
        updatedById: createdById,
        organizationId: organizationId,
        recordId: recordId,
        recordModelType: modelType,
        urlPath: '$urlPath/$slug',
        internalPath: '$internalPath/$id',
        slug: slug,
        oldHealthStatus: data.oldHealthStatus.id,
        newHealthStatus: data.newHealthStatus?.id,
        healthIssueTypeId: data.healthIssueTypeId,
        percentCover: data.percentCover,
        percentBleaching: data.percentBleaching,
        percentDisease: data.percentDisease,
        measurements: data.measurements,
        siteId: data.siteId,
        monitoringDate: data.monitoringDate,
        organismIds: [data.organismId],
        comment: data.comment,
        imageUrl: data.imageUrl,
        createTask: data.createTask,
      );
    } catch (e) {
      return null;
    }
  }
}
