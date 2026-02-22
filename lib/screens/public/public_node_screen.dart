// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/public_read_models/media_asset.dart';
import 'package:seafoundry_app/models/public_read_models/public_playlist.dart';
import 'package:seafoundry_app/navigation/public_route.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/screens/public/public_org_screen.dart';
import 'package:seafoundry_app/services/public/public_preview_access_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';

class PublicNodeScreen extends StatefulWidget {
  const PublicNodeScreen({
    super.key,
    required this.orgId,
    required this.nodeId,
    this.previewMode = false,
    this.readModelsService,
  });

  final String orgId;
  final String nodeId;
  final bool previewMode;
  final PublicReadModelsService? readModelsService;

  @override
  State<PublicNodeScreen> createState() => _PublicNodeScreenState();
}

class _PublicNodeScreenState extends State<PublicNodeScreen> {
  late final PublicReadModelsService _service;
  late Stream<BrandProfile?> _brandStream;
  late Stream<List<MediaAsset>> _mediaStream;
  late Future<PublicPlaylist?> _playlistFuture;
  PreviewAccessDecision _previewAccess = const PreviewAccessDecision.pending();

  @override
  void initState() {
    super.initState();
    _service = widget.readModelsService ?? PublicReadModelsService();
    _previewAccess = widget.previewMode
        ? const PreviewAccessDecision.pending()
        : const PreviewAccessDecision.allowed();
    _brandStream = _service.streamBrandProfile(
      widget.orgId,
      preview: _previewAccess.allowed,
    );
    _mediaStream = _service.streamPublicMedia(
      widget.orgId,
      preview: _previewAccess.allowed,
    );
    _playlistFuture = _service.fetchPlaylist(widget.orgId, widget.nodeId);
    _evaluatePreviewAccess();
  }

  @override
  Widget build(BuildContext context) {
    final previewPending = widget.previewMode && _previewAccess.pending;
    final previewBlocked =
        widget.previewMode &&
        !_previewAccess.pending &&
        !_previewAccess.allowed;
    if (previewPending) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (previewBlocked) {
      return _previewDenied();
    }

    final previewEnabled = widget.previewMode && _previewAccess.allowed;

    return StreamBuilder<BrandProfile?>(
      stream: _brandStream,
      builder: (context, snapshot) {
        final brand = snapshot.data;
        final theme = brand != null
            ? BrandTheme.fromProfile(brand)
            : const BrandTheme(accentColor: Color(0xFF00BCD4));
        return BrandThemeProvider(
          theme: theme,
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    brand?.brandName ?? 'Organization node',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Node: ${widget.nodeId}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: FutureBuilder<PublicPlaylist?>(
                    future: _playlistFuture,
                    builder: (context, playlistSnapshot) {
                      if (playlistSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final playlist = playlistSnapshot.data;
                      if (playlist == null) {
                        return _missingPlaylist();
                      }
                      if (!playlist.published && !previewEnabled) {
                        return _unpublishedPlaylist();
                      }
                      return _PlaylistView(
                        playlist: playlist,
                        mediaStream: _mediaStream,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicOrganizationScreen(
                            orgId: widget.orgId,
                            initialView: PublicOrgView.impactMap,
                            previewMode: previewEnabled,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('View impact map'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _evaluatePreviewAccess() async {
    if (!widget.previewMode) return;
    final decision = await PublicPreviewAccessService().evaluate(widget.orgId);
    if (!mounted) return;
    setState(() {
      _previewAccess = decision;
      _brandStream = _service.streamBrandProfile(
        widget.orgId,
        preview: decision.allowed,
      );
      _mediaStream = _service.streamPublicMedia(
        widget.orgId,
        preview: decision.allowed,
      );
    });
  }

  Widget _previewDenied() {
    final reason = _previewAccess.reason;
    final message = reason == PreviewAccessBlockReason.unauthenticated
        ? 'Sign in as an organization admin to preview unpublished playlists.'
        : 'Preview is limited to organization admins. Publish this playlist to share it publicly.';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.https_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Preview unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missingPlaylist() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'This node is not public yet. Ask the team to publish ${widget.nodeId}\'s highlights.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _unpublishedPlaylist() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Preview only — this node\'s playlist is awaiting publish.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _PlaylistView extends StatelessWidget {
  const _PlaylistView({required this.playlist, required this.mediaStream});

  final PublicPlaylist playlist;
  final Stream<List<MediaAsset>> mediaStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaAsset>>(
      stream: mediaStream,
      initialData: const [],
      builder: (context, snapshot) {
        final assets = snapshot.data ?? const [];
        final playlistAssets = _resolvePlaylistAssets(assets);
        if (playlistAssets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Playlist ready. Waiting for published media assets.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: playlistAssets.length,
          itemBuilder: (context, index) {
            final asset = playlistAssets[index];
            final caption = playlist.items
                .firstWhere(
                  (item) => item.assetId == asset.id,
                  orElse: () => const PlaylistItem(assetId: ''),
                )
                .caption;
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(asset.url, fit: BoxFit.cover),
                  ),
                  if ((asset.altText ?? caption)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        asset.altText ?? caption ?? '',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<MediaAsset> _resolvePlaylistAssets(List<MediaAsset> allAssets) {
    if (playlist.items.isEmpty) return const [];
    final assetMap = {for (final asset in allAssets) asset.id: asset};
    final sorted = [...playlist.items]
      ..sort((a, b) => a.order.compareTo(b.order));
    return sorted
        .map((item) => assetMap[item.assetId])
        .whereType<MediaAsset>()
        .toList(growable: false);
  }
}
