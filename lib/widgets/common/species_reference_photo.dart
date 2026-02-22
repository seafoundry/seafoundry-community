// @tier: community
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/nodes/node_icon.dart';
import '../../models/models.dart';
import '../../services/species_info_service.dart';
import '../optimized/optimized_network_image.dart';

class SpeciesReferencePhoto extends StatefulWidget {
  const SpeciesReferencePhoto({
    super.key,
    required this.speciesId,
    required this.modelType,
    this.size = 72.0,
    this.borderRadius = 12.0,
  });

  final String? speciesId;
  final ModelType modelType;
  final double size;
  final double borderRadius;

  @override
  State<SpeciesReferencePhoto> createState() => _SpeciesReferencePhotoState();
}

class _SpeciesReferencePhotoState extends State<SpeciesReferencePhoto> {
  SpeciesInfoService? _service;
  SpeciesInfoService? _lastService;
  Future<SpeciesFact?>? _factFuture;
  Species? _resolvedSpecies;
  String? _lastSpeciesId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= _maybeReadService(context);
    _refreshFactIfNeeded();
  }

  @override
  void didUpdateWidget(SpeciesReferencePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speciesId != widget.speciesId) {
      _refreshFactIfNeeded(force: true);
    }
  }

  void _refreshFactIfNeeded({bool force = false}) {
    if (!force &&
        _lastSpeciesId == widget.speciesId &&
        _lastService == _service) {
      return;
    }

    _lastSpeciesId = widget.speciesId;
    _lastService = _service;
    final species = Species.fallback(widget.speciesId);
    _resolvedSpecies = species;

    if (_service == null || species.id == 'species_unknown') {
      _factFuture = null;
      return;
    }

    _factFuture = _service!.getFactForSpecies(species.name);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallback(context);
    final factFuture = _factFuture;
    if (factFuture == null) {
      return fallback;
    }

    return FutureBuilder<SpeciesFact?>(
      future: factFuture,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data?.imageUrl;
        if (imageUrl == null || imageUrl.isEmpty) {
          return fallback;
        }
        return _buildImage(context, imageUrl);
      },
    );
  }

  SpeciesInfoService? _maybeReadService(BuildContext context) {
    try {
      return context.read<SpeciesInfoService>();
    } catch (_) {
      return null;
    }
  }

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainerHighest;
    final onSurface = theme.colorScheme.onSurfaceVariant;

    return _buildFrame(
      child: Center(
        child: NodeIcon.large(
          modelType: widget.modelType,
          color: onSurface,
        ),
      ),
      backgroundColor: surface,
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.surface.withValues(alpha: 0.75);
    final devicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final cacheSize = (widget.size * devicePixelRatio).round();

    return _buildFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          OptimizedNetworkImage(
            imageUrl: imageUrl,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            semanticLabel:
                _resolvedSpecies?.name ?? 'Species reference photo',
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: overlayColor,
                shape: BoxShape.circle,
              ),
              child: NodeIcon.small(modelType: widget.modelType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrame({required Widget child, Color? backgroundColor}) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(
          color: backgroundColor ?? Colors.transparent,
          child: child,
        ),
      ),
    );
  }
}
