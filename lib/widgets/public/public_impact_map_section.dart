// @tier: community
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point_samples.dart';

class PublicImpactMapSection extends StatefulWidget {
  const PublicImpactMapSection({
    super.key,
    required this.orgId,
    required this.stream,
    this.previewMode = false,
    this.enableSampleData = false,
  });

  final String orgId;
  final Stream<List<PublicImpactPoint>> stream;
  final bool previewMode;
  final bool enableSampleData;

  @override
  State<PublicImpactMapSection> createState() => _PublicImpactMapSectionState();
}

class _PublicImpactMapSectionState extends State<PublicImpactMapSection> {
  bool _showHoldings = true;
  bool _showOutplants = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Holdings'),
              selected: _showHoldings,
              onSelected: (value) => setState(() => _showHoldings = value),
            ),
            FilterChip(
              label: const Text('Outplants'),
              selected: _showOutplants,
              onSelected: (value) => setState(() => _showOutplants = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<PublicImpactPoint>>(
            stream: widget.stream,
            builder: (context, snapshot) {
              final raw = snapshot.data ?? const <PublicImpactPoint>[];
              final resolved = _resolvedPoints(raw);
              final filtered = _filteredPoints(resolved);
              if (!_showHoldings && !_showOutplants) {
                return _emptyState(
                  'Enable at least one layer to view the map.',
                );
              }
              // Always show the map base, even when loading or empty
              // This provides a better visual experience than placeholders
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  filtered.isEmpty;
              final emptyMessage = resolved.isNotEmpty
                  ? 'No impact points match the selected layers.'
                  : 'No public impact data published yet.';
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CustomPaint(
                            painter: _ImpactMapPainter(
                              points: filtered,
                              showHoldings: _showHoldings,
                              showOutplants: _showOutplants,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        if (isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (filtered.isEmpty)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                emptyMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImpactLegend(points: filtered),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<PublicImpactPoint> _resolvedPoints(List<PublicImpactPoint> raw) {
    if (raw.isNotEmpty) return raw;
    if (widget.enableSampleData || widget.previewMode) {
      return sampleImpactPoints;
    }
    return raw;
  }

  List<PublicImpactPoint> _filteredPoints(List<PublicImpactPoint> points) {
    return points
        .where((point) {
          if (point.pointType == PublicImpactPointType.holding) {
            return _showHoldings;
          }
          return _showOutplants;
        })
        .toList(growable: false);
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ImpactMapPainter extends CustomPainter {
  _ImpactMapPainter({
    required this.points,
    required this.showHoldings,
    required this.showOutplants,
  });

  final List<PublicImpactPoint> points;
  final bool showHoldings;
  final bool showOutplants;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF021F3F), Color(0xFF093B63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), background);

    for (final point in points) {
      if (point.pointType == PublicImpactPointType.holding && !showHoldings) {
        continue;
      }
      if (point.pointType == PublicImpactPointType.outplant && !showOutplants) {
        continue;
      }
      final offset = _project(point.latitude, point.longitude, size);
      final color = point.pointType == PublicImpactPointType.holding
          ? const Color(0xFF00E5B2)
          : const Color(0xFFFFB74D);
      final magnitude = math.max(2.0, math.log(point.magnitude + 1) * 4);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(offset, magnitude.toDouble(), paint);
      canvas.drawCircle(
        offset,
        magnitude.toDouble() / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactMapPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.showHoldings != showHoldings ||
        oldDelegate.showOutplants != showOutplants;
  }

  Offset _project(double lat, double lng, Size size) {
    final x = (lng + 180) / 360 * size.width;
    final y = size.height - ((lat + 90) / 180 * size.height);
    return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
  }
}

class _ImpactLegend extends StatelessWidget {
  const _ImpactLegend({required this.points});

  final List<PublicImpactPoint> points;

  @override
  Widget build(BuildContext context) {
    final holdings = points
        .where((p) => p.pointType == PublicImpactPointType.holding)
        .fold<int>(0, (sum, point) => sum + point.magnitude);
    final outplants = points
        .where((p) => p.pointType == PublicImpactPointType.outplant)
        .fold<int>(0, (sum, point) => sum + point.magnitude);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendChip(
          color: const Color(0xFF00E5B2),
          label: 'Holdings',
          value: holdings,
        ),
        const SizedBox(width: 12),
        _LegendChip(
          color: const Color(0xFFFFB74D),
          label: 'Outplants',
          value: outplants,
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $value',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
