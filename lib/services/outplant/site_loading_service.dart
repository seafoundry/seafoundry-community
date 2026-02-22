// @tier: community
import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Site and group loading with timeout and fallback logic for outplant operations.
///
/// This service handles the complexity of loading sites and groups from Firestore
/// with graceful timeout handling and stream-based fallbacks when queries are slow.
///
/// Key behaviors:
/// - Primary: attempts fast query-based fetch with timeout
/// - Fallback: uses stream-based loading if query times out
/// - Stream optimization: reuses existing BehaviorSubject values when available
class SiteLoadingService {
  SiteLoadingService({
    required SiteRepository siteRepository,
    GraphRepository? graphRepository,
    LoggingService? logger,
  })  : _siteRepository = siteRepository,
        _graphRepository = graphRepository,
        _logger = logger ?? LoggingService.instance;

  final SiteRepository _siteRepository;
  final GraphRepository? _graphRepository;
  final LoggingService _logger;

  /// Load all sites with timeout fallback.
  ///
  /// Attempts to fetch sites via [SiteRepository.getAll] with a 5-second timeout.
  /// If the query times out or fails, falls back to stream-based loading.
  ///
  /// Returns a list of all sites, or empty list if loading fails completely.
  Future<List<Site>> loadSites() async {
    try {
      _logger.debug('SiteLoadingService: attempting getAll with 5s timeout');
      return await _siteRepository.getAll().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _logger.warning('SiteLoadingService: getAll timed out after 5s');
          throw TimeoutException(
            'SiteRepository.getAll timed out',
            const Duration(seconds: 5),
          );
        },
      );
    } on TimeoutException catch (error, stackTrace) {
      _logger.warning(
        'SiteLoadingService: SiteRepository.getAll timed out, falling back to stream',
        error,
      );
      return _loadSitesFromStreamFallback(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      _logger.warning(
        'SiteLoadingService: SiteRepository.getAll failed, falling back to stream',
        error,
      );
      return _loadSitesFromStreamFallback(error: error, stackTrace: stackTrace);
    }
  }

  /// Load only outplant-enabled sites.
  ///
  /// Filters the results of [loadSites] to only include sites with
  /// [SiteType.outplanting] type.
  Future<List<Site>> loadOutplantSites() async {
    try {
      _logger.debug('SiteLoadingService: fetching outplant sites');
      final sites = await loadSites();

      final outplantSites = sites
          .where((site) => site.siteTypeId == SiteType.outplanting.id)
          .toList(growable: false);

      _logger.debug(
        'SiteLoadingService: loaded ${outplantSites.length} outplant sites (${sites.length} total)',
      );

      return outplantSites;
    } catch (error, stackTrace) {
      _logger.error(
        'SiteLoadingService: failed to load outplant sites',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  /// Load groups (plots/patches) available at a specific site.
  ///
  /// Uses [GraphRepository.streamGroupsForSite] to fetch groups, with a short
  /// timeout to prevent blocking. Failures are logged but return empty list.
  ///
  /// Requires [GraphRepository] to be provided at construction time.
  /// Returns empty list if GraphRepository was not provided.
  Future<List<Group>> loadGroupsForSite(Site site) async {
    if (_graphRepository == null) {
      _logger.warning(
        'SiteLoadingService: cannot load groups - GraphRepository not provided',
      );
      return const [];
    }

    try {
      final groups = await _graphRepository
          .streamGroupsForSite(site)
          .first
          .timeout(const Duration(seconds: 3));

      _logger.debug(
        'SiteLoadingService: loaded ${groups.length} groups for site ${site.id}',
      );

      return groups;
    } catch (error, stackTrace) {
      _logger.error(
        'SiteLoadingService: failed to load groups for site ${site.id}',
        error,
        stackTrace,
      );
      return const [];
    }
  }

  /// Stream-based fallback for site loading.
  ///
  /// Optimized to check for existing BehaviorSubject values before waiting
  /// for stream emissions, reducing latency when data is already cached.
  ///
  /// Flow:
  /// 1. Check if stream is BehaviorSubject with existing value
  /// 2. Return cached value immediately if available
  /// 3. Otherwise wait for first emission with 3s timeout
  /// 4. Return empty list on timeout or error
  Future<List<Site>> _loadSitesFromStreamFallback({
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (error != null) {
      _logger.debug(
        'SiteLoadingService: attempting stream fallback after getAll failure',
      );
    }

    try {
      // Optimization: check if stream already has value (BehaviorSubject)
      if (_siteRepository.streamAll is BehaviorSubject<List<Site>>) {
        final behaviorSubject =
            _siteRepository.streamAll as BehaviorSubject<List<Site>>;
        if (behaviorSubject.hasValue) {
          final sites = behaviorSubject.value;
          _logger.debug(
            'SiteLoadingService: using existing stream value with ${sites.length} sites',
          );
          return sites;
        }
      }

      // Otherwise wait for first emission with short timeout
      _logger.debug(
        'SiteLoadingService: waiting for stream with 3s timeout',
      );
      final sites = await _siteRepository.streamAll.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _logger.warning(
            'SiteLoadingService: stream timed out, returning empty list',
          );
          return const <Site>[];
        },
      );
      _logger.debug(
        'SiteLoadingService: stream fallback returned ${sites.length} sites',
      );
      return sites;
    } catch (fallbackError, fallbackStackTrace) {
      _logger.error(
        'SiteLoadingService: failed to load sites from stream fallback',
        fallbackError,
        fallbackStackTrace,
      );
      return const <Site>[];
    }
  }
}
