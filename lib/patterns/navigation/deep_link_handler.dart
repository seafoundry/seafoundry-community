import 'package:collection/collection.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Centralized deep link parsing and building utilities.
///
/// The handler supports both custom scheme links (`seafoundry://…`) and universal
/// links (`https://seafoundry.app/…`). When parsing a link the handler will try
/// to resolve it to the current organization's graph hierarchy and return the
/// matching [GraphNode]. When building a link from a node you can generate
/// either a custom scheme or universal link URI.
///
/// Supported inbound formats:
/// - `seafoundry://reefco/outplant-zone-a` (host represents the org domain)
/// - `seafoundry://site/site123` (type + identifier)
/// - `https://seafoundry.app/reefco/outplant-zone-a`
/// - `https://seafoundry.app/site/site123?org=reefco`
/// - `/reefco/outplant-zone-a` (bare path)
///
/// For type-based links (`site/{id}`, `group/{id}`, `coral/{id}`) the handler
/// resolves the identifier against the respective repository. Identifiers may
/// be either the record's Firestore document ID or its slug.
class DeepLinkHandler {
  DeepLinkHandler._();

  static const String _defaultCustomScheme = 'seafoundry';
  static const String _universalScheme = 'https';
  static const List<String> _defaultUniversalHosts = <String>[
    'seafoundry.app',
    'www.seafoundry.app',
    'app.seafoundry.dev',
    'app.seafoundry.com',
    'staging.seafoundry.app',
    'beta.seafoundry.app',
    'seafoundryapp.web.app',
    'seafoundryapp.firebaseapp.com',
    'provenance.seafoundry.com',
    'localhost',
  ];

  /// Attempts to resolve a raw deep link string into a [GraphNode].
  static Future<GraphNode?> parseDeepLink(
    String url, {
    required GraphRepository graphRepository,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return _loadRoot(graphRepository);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      LoggingService.instance.warning(
        'DeepLinkHandler: Unable to parse deep link "$url"',
      );
      return null;
    }

    return parseUri(uri, graphRepository: graphRepository);
  }

  /// Attempts to resolve a [Uri] into a [GraphNode].
  static Future<GraphNode?> parseUri(
    Uri uri, {
    required GraphRepository graphRepository,
  }) async {
    // Skip demo mode trigger URLs - these are handled by SimpleRouter
    if (_isDemoModeTrigger(uri)) {
      LoggingService.instance.trace(
        'DeepLinkHandler: Skipping demo mode trigger URL "${uri.fragment}"',
      );
      return _loadRoot(graphRepository);
    }

    final organizationDomain = graphRepository.organization.domain;
    final segments = _extractSegments(uri);

    if (segments.isEmpty) {
      // Fallback to `path` query parameter (e.g. seafoundry://?path=org/site)
      final pathParameter = uri.queryParameters['path'];
      if (pathParameter != null && pathParameter.isNotEmpty) {
        return _loadNodeForPath(
          graphRepository,
          _ensureDomainPrefix(graphRepository, pathParameter),
        );
      }
      return _loadRoot(graphRepository);
    }

    // Direct organization path links (first segment equals org domain).
    if (_isOrganizationSegment(segments.first, organizationDomain)) {
      // If the only segment is the org domain itself, return root directly
      if (segments.length == 1) {
        return _loadRoot(graphRepository);
      }
      return _loadNodeForPath(graphRepository, segments.join('/'));
    }

    // If link supplies organization via query parameter, try with that prefix.
    final orgOverride =
        uri.queryParameters['org'] ??
        uri.queryParameters['organization'] ??
        uri.queryParameters['organizationId'] ??
        uri.queryParameters['domain'];
    if (orgOverride != null &&
        orgOverride.isNotEmpty &&
        _isOrganizationSegment(orgOverride, organizationDomain)) {
      final composed = <String>[orgOverride, ...segments].join('/');
      final node = await _loadNodeForPath(graphRepository, composed);
      if (node != null) {
        return node;
      }
    }

    // Handle type-based patterns (site/{id}, group/{id}, etc.).
    final resolved = await _resolveTypeBasedLink(
      segments: segments,
      uri: uri,
      graphRepository: graphRepository,
    );
    if (resolved != null) {
      return resolved;
    }

    LoggingService.instance.warning(
      'DeepLinkHandler: Unsupported deep link format "$uri"',
    );
    return null;
  }

  /// Builds a deep link string for the provided [GraphNode].
  ///
  /// When [asUniversalLink] is true the resulting link will use HTTPS with the
  /// provided or default host (`https://seafoundry.app/...`). Otherwise a
  /// custom-scheme link (`seafoundry://...`) is produced.
  static String buildDeepLink(
    GraphNode node, {
    bool asUniversalLink = false,
    String? scheme,
    String? hostOverride,
  }) => buildUri(
    node,
    asUniversalLink: asUniversalLink,
    scheme: scheme,
    hostOverride: hostOverride,
  ).toString();

  /// Builds a [Uri] for the provided [GraphNode].
  static Uri buildUri(
    GraphNode node, {
    bool asUniversalLink = false,
    String? scheme,
    String? hostOverride,
  }) {
    final segments = node.urlPath
        .split('/')
        .where((segment) {
          return segment.trim().isNotEmpty;
        })
        .toList(growable: false);

    if (segments.isEmpty) {
      return Uri(
        scheme: asUniversalLink
            ? _universalScheme
            : (scheme ?? _defaultCustomScheme),
        host: hostOverride,
      );
    }

    if (asUniversalLink) {
      return Uri(
        scheme: _universalScheme,
        host: hostOverride ?? _defaultUniversalHosts.first,
        pathSegments: segments,
      );
    }

    final host = hostOverride ?? segments.first;
    final pathSegments = segments.length > 1
        ? segments.sublist(1)
        : const <String>[];
    return Uri(
      scheme: scheme ?? _defaultCustomScheme,
      host: host,
      pathSegments: pathSegments,
    );
  }

  static List<String> _extractSegments(Uri uri) {
    if (uri.fragment.isNotEmpty) {
      return uri.fragment
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
    }

    final segments = <String>[];

    if (uri.host.isNotEmpty &&
        !_defaultUniversalHosts.contains(uri.host.toLowerCase())) {
      segments.add(uri.host);
    }

    segments.addAll(uri.pathSegments.where((segment) => segment.isNotEmpty));

    if (segments.isEmpty && uri.scheme.isEmpty && uri.host.isEmpty) {
      final raw = uri.toString();
      if (raw.contains('/')) {
        segments.addAll(raw.split('/').where((segment) => segment.isNotEmpty));
      } else if (raw.isNotEmpty) {
        segments.add(raw);
      }
    }

    return segments;
  }

  static bool _isOrganizationSegment(
    String segment,
    String organizationDomain,
  ) {
    return segment.toLowerCase() == organizationDomain.toLowerCase();
  }

  static Future<GraphNode?> _resolveTypeBasedLink({
    required List<String> segments,
    required Uri uri,
    required GraphRepository graphRepository,
  }) async {
    if (segments.isEmpty) {
      return _loadRoot(graphRepository);
    }

    final primary = segments.first.toLowerCase();
    switch (primary) {
      case 'home':
      case 'dashboard':
        return _loadRoot(graphRepository);
      case 'organization':
        return _resolveOrganizationLink(segments, graphRepository);
      case 'site':
        return _resolveInventoryLink(
          repository: graphRepository.siteRepository,
          identifier: _valueFromSegmentsOrQuery(segments, 1, uri, <String>[
            'siteId',
            'id',
            'site',
            'slug',
          ]),
          graphRepository: graphRepository,
        );
      case 'group':
        return _resolveInventoryLink(
          repository: graphRepository.groupRepository,
          identifier: _valueFromSegmentsOrQuery(segments, 1, uri, <String>[
            'groupId',
            'id',
            'group',
            'slug',
          ]),
          graphRepository: graphRepository,
        );
      case 'coral':
        return _resolveInventoryLink(
          repository: graphRepository.organismRecordRepository,
          identifier: _valueFromSegmentsOrQuery(segments, 1, uri, <String>[
            'coralId',
            'id',
            'coral',
            'slug',
          ]),
          graphRepository: graphRepository,
        );
      case 'record':
        return _resolveRecordLink(segments, graphRepository);
      case 'invite':
        return _resolveInviteLink(
          segments: segments,
          uri: uri,
          graphRepository: graphRepository,
        );
      default:
        final fallbackPath = _ensureDomainPrefix(
          graphRepository,
          segments.join('/'),
        );
        return _loadNodeForPath(graphRepository, fallbackPath);
    }
  }

  static Future<GraphNode?> _resolveOrganizationLink(
    List<String> segments,
    GraphRepository graphRepository,
  ) async {
    if (segments.length < 2) {
      return _loadRoot(graphRepository);
    }

    final identifier = segments[1];
    final organization = graphRepository.organization;
    if (identifier == organization.id || identifier == organization.domain) {
      return _loadRoot(graphRepository);
    }

    LoggingService.instance.warning(
      'DeepLinkHandler: organization identifier "$identifier" does not match current organization.',
    );
    return null;
  }

  static Future<GraphNode?> _resolveInventoryLink<T extends InventoryRecord>({
    required InventoryRecordRepository<T> repository,
    required String? identifier,
    required GraphRepository graphRepository,
  }) async {
    if (identifier == null || identifier.isEmpty) {
      LoggingService.instance.warning(
        'DeepLinkHandler: Missing identifier for ${repository.modelType.displayName} deep link.',
      );
      return null;
    }

    final record = await _findInventoryRecord(repository, identifier);
    if (record == null) {
      LoggingService.instance.warning(
        'DeepLinkHandler: No ${repository.modelType.displayName} found for "$identifier".',
      );
      return null;
    }

    return _loadNodeForPath(graphRepository, record.urlPath);
  }

  static Future<GraphNode?> _resolveRecordLink(
    List<String> segments,
    GraphRepository graphRepository,
  ) async {
    if (segments.length < 3) {
      LoggingService.instance.warning(
        'DeepLinkHandler: Record deep link requires type and identifier.',
      );
      return null;
    }

    final typeSegment = segments[1].toLowerCase();
    final identifier = segments[2];
    final modelType = _modelTypeFromSegment(typeSegment);
    if (modelType == null) {
      LoggingService.instance.warning(
        'DeepLinkHandler: Unsupported record type "$typeSegment".',
      );
      return null;
    }

    switch (modelType) {
      case ModelType.organization:
        return _resolveOrganizationLink(<String>[
          'organization',
          identifier,
        ], graphRepository);
      case ModelType.site:
        return _resolveInventoryLink(
          repository: graphRepository.siteRepository,
          identifier: identifier,
          graphRepository: graphRepository,
        );
      case ModelType.group:
        return _resolveInventoryLink(
          repository: graphRepository.groupRepository,
          identifier: identifier,
          graphRepository: graphRepository,
        );
      case ModelType.organismRecord:
        return _resolveInventoryLink(
          repository: graphRepository.organismRecordRepository,
          identifier: identifier,
          graphRepository: graphRepository,
        );
      default:
        LoggingService.instance.warning(
          'DeepLinkHandler: Record type $modelType does not correspond to a navigable graph node.',
        );
        return null;
    }
  }

  /// Handle invite deep links (/invite/{invitationId} or /invite/{token})
  static Future<GraphNode?> _resolveInviteLink({
    required List<String> segments,
    required Uri uri,
    required GraphRepository graphRepository,
  }) async {
    // Extract invitation ID/token from segments or query params
    final invitationId = _valueFromSegmentsOrQuery(segments, 1, uri, <String>[
      'invitationId',
      'id',
      'invitation',
      'token',
    ]);

    if (invitationId == null || invitationId.isEmpty) {
      LoggingService.instance.warning('DeepLinkHandler: Missing invitation ID in invite link');
      return null;
    }

    // Log the invite link detection - the actual invitation handling
    // will be done by OnboardingCubit when it checks for pending invitations
    LoggingService.instance.info('DeepLinkHandler: Processing invite link for $invitationId');

    // Store the invitation ID in a way that OnboardingCubit can access
    // For now, return root node - navigation will be handled after auth
    return _loadRoot(graphRepository);
  }

  static ModelType? _modelTypeFromSegment(String segment) {
    final sanitized = segment.replaceAll(RegExp(r'[^a-z_]'), '');
    try {
      return ModelType.values.byName(sanitized);
    } catch (_) {
      return null;
    }
  }

  static String? _valueFromSegmentsOrQuery(
    List<String> segments,
    int index,
    Uri uri,
    List<String> queryKeys,
  ) {
    if (segments.length > index && segments[index].isNotEmpty) {
      return segments[index];
    }
    for (final key in queryKeys) {
      final value = uri.queryParameters[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static Future<T?> _findInventoryRecord<T extends InventoryRecord>(
    InventoryRecordRepository<T> repository,
    String identifier,
  ) async {
    final byId = await repository.getRecordForId(identifier);
    if (byId != null) {
      return byId;
    }

    final allRecords = await repository.getAll();
    return allRecords.firstWhereOrNull((record) {
      final slugMatches = record.slug.toLowerCase() == identifier.toLowerCase();
      final pathMatches =
          record.urlPath.split('/').last.toLowerCase() ==
          identifier.toLowerCase();
      return slugMatches || pathMatches;
    });
  }

  static Future<GraphNode?> _loadNodeForPath(
    GraphRepository graphRepository,
    String path,
  ) async {
    final normalized = _ensureDomainPrefix(graphRepository, path);
    final node = await graphRepository.getNodeForUrlPath(normalized);
    if (node == null) {
      LoggingService.instance.warning(
        'DeepLinkHandler: No graph node found for path "$normalized".',
      );
      return null;
    }
    await node.awaitLoaded();
    return node;
  }

  static Future<GraphNode> _loadRoot(GraphRepository graphRepository) async {
    final root = graphRepository.root;
    await root.awaitLoaded();
    return root;
  }

  static String _ensureDomainPrefix(
    GraphRepository graphRepository,
    String path,
  ) {
    final trimmed = path.trim().replaceFirst(RegExp('^/+'), '');
    if (trimmed.isEmpty) {
      return graphRepository.organization.domain;
    }
    final domain = graphRepository.organization.domain;
    if (trimmed.toLowerCase().startsWith(domain.toLowerCase())) {
      return trimmed;
    }
    return '$domain/$trimmed';
  }

  /// Check if URI is a demo mode trigger URL (e.g., #demo, #demo-community)
  /// These are handled by SimpleRouter and should not be processed as navigation links
  static bool _isDemoModeTrigger(Uri uri) {
    final fragment = uri.fragment.toLowerCase();
    if (fragment.isEmpty) return false;
    
    // Match demo mode trigger patterns
    return fragment == 'demo' ||
           fragment == 'demo-community' ||
           fragment.startsWith('demo-community');
  }
}

/// Extension for easy deep link support on [GraphNode] instances.
extension DeepLinkExtension on GraphNode {
  /// Returns a custom-scheme deep link (e.g. `seafoundry://org/site`).
  String get deepLink => DeepLinkHandler.buildDeepLink(this);

  /// Returns a universal HTTPS deep link (e.g. `https://seafoundry.app/org/site`).
  String get universalDeepLink =>
      DeepLinkHandler.buildDeepLink(this, asUniversalLink: true);

  /// Returns a [Uri] representing the deep link for this node.
  Uri get deepLinkUri => DeepLinkHandler.buildUri(this);

  /// Returns a universal [Uri] (`https://…`) representing this node.
  Uri get universalDeepLinkUri =>
      DeepLinkHandler.buildUri(this, asUniversalLink: true);
}
