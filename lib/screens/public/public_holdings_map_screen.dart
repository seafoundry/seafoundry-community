// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seafoundry_app/cubits/public_holdings_map/public_holdings_map_cubit.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point_samples.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/services/provenance_crosswalk_service.dart';
import 'package:seafoundry_app/services/public/public_preview_access_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicHoldingsMapScreen extends StatefulWidget {
  const PublicHoldingsMapScreen({
    super.key,
    required this.orgId,
    this.previewMode = false,
    this.enableSampleImpactData = false,
    this.readModelsService,
    this.initialShowFilters = false,
    this.showBranding = true,
    this.showCrosswalkSearch = true,
    this.hideSignIn = false,
  });

  final String orgId;
  final bool previewMode;
  final bool enableSampleImpactData;
  final PublicReadModelsService? readModelsService;
  final bool initialShowFilters;
  final bool showBranding;
  final bool showCrosswalkSearch;

  /// When true, hides the Sign In button. Use for embedded views where user is
  /// already authenticated (e.g., community holdings map).
  final bool hideSignIn;

  @override
  State<PublicHoldingsMapScreen> createState() =>
      _PublicHoldingsMapScreenState();
}

class _PublicHoldingsMapScreenState extends State<PublicHoldingsMapScreen> {
  late final PublicReadModelsService _service;
  late final HistoricalDataService _historicalService;
  late final ProvenanceCrosswalkService _crosswalkService;
  late final PublicHoldingsMapCubit _cubit;
  Stream<List<PublicImpactPoint>> _stream = const Stream.empty();
  final Completer<GoogleMapController> _controller = Completer();
  PreviewAccessDecision _previewAccess = const PreviewAccessDecision.pending();
  String? _upgradeUrl;
  bool _isAtLeastPro = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUpgradeUrl();
    _evaluatePreviewAccess();
    // Preload marker icons for web platform support
    preloadClusterMarkerIcons();

    if (widget.enableSampleImpactData && !widget.previewMode) {
      _cubit.loadCrcData();
    }
  }

  void _initializeServices() {
    _service = widget.readModelsService ?? PublicReadModelsService();
    _historicalService = HistoricalDataService();
    _crosswalkService = ProvenanceCrosswalkService(
      firestore: context.read<FirebaseService>().firestore,
    );
    _cubit = PublicHoldingsMapCubit(
      historicalDataService: _historicalService,
    );
    _previewAccess = widget.previewMode
        ? const PreviewAccessDecision.pending()
        : const PreviewAccessDecision.allowed();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewPending = widget.previewMode && _previewAccess.pending;
    final previewBlocked =
        widget.previewMode && !_previewAccess.pending && !_previewAccess.allowed;
    final previewEnabled = widget.previewMode && _previewAccess.allowed;

    if (previewPending) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (previewBlocked) {
      return PreviewDeniedView(reason: _previewAccess.reason);
    }

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        body: _buildBody(previewEnabled),
      ),
    );
  }

  Widget _buildBody(bool previewEnabled) {
    final showSignIn = !widget.hideSignIn;
    final showActionButtons = widget.showCrosswalkSearch || showSignIn;
    final showHeaderRow = widget.showBranding || showActionButtons;
    final showUpgradeCallout = previewEnabled && !_isAtLeastPro;

    return StreamBuilder<List<PublicImpactPoint>>(
      stream: _stream,
      builder: (context, snapshot) {
        return BlocBuilder<PublicHoldingsMapCubit, PublicHoldingsMapState>(
          builder: (context, cubitState) {
            if (widget.enableSampleImpactData && cubitState.isLoadingCrcData) {
              return HoldingsMapLoadingState(
                loadingStatus: cubitState.loadingStatus,
              );
            }

            final points = _buildPointsList(snapshot, cubitState, previewEnabled);

            if (snapshot.connectionState == ConnectionState.waiting &&
                points.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return HoldingsMapView(
              points: points,
              cubitState: cubitState,
              controller: _controller,
              showHeaderRow: showHeaderRow,
              showSignIn: showSignIn,
              showUpgradeCallout: showUpgradeCallout,
              showBranding: widget.showBranding,
              showCrosswalkSearch: widget.showCrosswalkSearch,
              enableSampleImpactData: widget.enableSampleImpactData,
              initialShowFilters: widget.initialShowFilters,
              onSiteDetailsTap: _showSiteDetails,
              onCrosswalkSearch: _showCrosswalkSearch,
              onHoldingsChanged: _cubit.setShowHoldings,
              onOutplantsChanged: _cubit.setShowOutplants,
              onCrcDataChanged: _cubit.setShowCrcData,
              onMapGesturesEnabled: _cubit.setMapGesturesEnabled,
              upgradeUrl: _upgradeUrl,
              onUpgrade: _openUpgradeUrl,
            );
          },
        );
      },
    );
  }

  List<PublicImpactPoint> _buildPointsList(
    AsyncSnapshot<List<PublicImpactPoint>> snapshot,
    PublicHoldingsMapState cubitState,
    bool previewEnabled,
  ) {
    List<PublicImpactPoint> points = [];

    if (widget.enableSampleImpactData && cubitState.showCrcData) {
      points = _cubit.getFilteredCrcPoints();
    }

    final firestorePoints = snapshot.data ?? const [];
    if (firestorePoints.isNotEmpty) {
      final existingIds = points.map((p) => p.id).toSet();
      final newPoints =
          firestorePoints.where((p) => !existingIds.contains(p.id)).toList();
      points = [...points, ...newPoints];
    }

    if (points.isEmpty && previewEnabled) {
      points = sampleImpactPoints;
    }

    return points;
  }

  Future<void> _showSiteDetails(ImpactCluster cluster) async {
    if (!mounted) return;
    _cubit.setMapGesturesEnabled(false);

    final isCrcData = _isCrcCluster(cluster.id);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (isCrcData) {
          final siteId = _resolveCrcSiteId(cluster.id);
          return SiteDetailsSheet(
            siteId: siteId,
            clusterLabel: cluster.label ?? 'Site',
            historicalService: _historicalService,
            datasetId: crcDatasetId,
          );
        }
        return ImpactPointDetailsSheet(cluster: cluster);
      },
    );

    if (!mounted) return;
    _cubit.setMapGesturesEnabled(true);
  }

  bool _isCrcCluster(String id) {
    return id.startsWith('crc-') ||
        id.startsWith('nursery-') ||
        id.startsWith('partner-');
  }

  String _resolveCrcSiteId(String rawId) {
    var normalized = rawId;
    if (normalized.startsWith('crc-')) {
      normalized = normalized.substring(4);
    }
    if (normalized.startsWith('crc_site_')) {
      normalized = normalized.substring('crc_site_'.length);
    }
    return normalized;
  }

  Future<void> _evaluatePreviewAccess() async {
    if (!widget.previewMode) {
      _stream = _service.streamImpactPoints(widget.orgId);
      return;
    }
    final decision = await PublicPreviewAccessService().evaluate(widget.orgId);
    if (!mounted) return;
    setState(() {
      _previewAccess = decision;
      if (decision.allowed) {
        _stream = _service.streamImpactPoints(widget.orgId);
        if (widget.enableSampleImpactData) {
          _cubit.loadCrcData();
        }
      }
    });
  }

  Future<void> _loadUpgradeUrl() async {
    final access = FeatureAccessService(defaultTier: Tier.community);
    await access.loadManifest();
    if (!mounted) return;
    setState(() {
      _upgradeUrl = access.upgradeUrl;
      _isAtLeastPro = access.isAtLeastPro;
    });
  }

  Future<void> _openUpgradeUrl() async {
    if (_upgradeUrl == null) return;
    final uri = Uri.tryParse(_upgradeUrl!);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showCrosswalkSearch() async {
    final result = await showSearch<CommunityProvenanceRecord?>(
      context: context,
      delegate: CrosswalkSearchDelegate(_crosswalkService),
    );

    if (result != null) {
      final genetId = result.aliases.isNotEmpty
          ? result.aliases.first.id
          : result.provenanceId;

      if (!_cubit.state.showCrcData) {
        _cubit.setShowCrcData(true);
      }

      _cubit.setGenet(genetId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filtering by genet: $genetId')),
      );
    }
  }
}
