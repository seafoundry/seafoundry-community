import 'package:seafoundry_app/models/types/model_type.dart';

List<String> _splitLocationSegments(
  String urlPath, {
  String? organizationDomain,
}) {
  final segments = urlPath
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return <String>[];
  }

  if (organizationDomain != null &&
      organizationDomain.isNotEmpty &&
      segments.first == organizationDomain) {
    segments.removeAt(0);
  }

  return segments;
}

String formatLocationPathFromPath({
  required String urlPath,
  String? organizationDomain,
}) {
  final segments = _splitLocationSegments(
    urlPath,
    organizationDomain: organizationDomain,
  );
  return segments.join('/');
}

String formatLocationPathFromRecord({
  required String urlPath,
  String? organizationDomain,
}) {
  final segments = _splitLocationSegments(
    urlPath,
    organizationDomain: organizationDomain,
  );
  if (segments.isNotEmpty) {
    segments.removeLast();
  }
  return segments.join('/');
}

String formatLocationPathFromEvent({
  required String urlPath,
  ModelType? recordModelType,
  String? organizationDomain,
}) {
  final segments = _splitLocationSegments(
    urlPath,
    organizationDomain: organizationDomain,
  );
  if (segments.isNotEmpty) {
    // Remove event slug
    segments.removeLast();
  }

  if (recordModelType == ModelType.organismRecord && segments.isNotEmpty) {
    // Remove organism slug to show location (site/structure/...)
    segments.removeLast();
  }

  return segments.join('/');
}
