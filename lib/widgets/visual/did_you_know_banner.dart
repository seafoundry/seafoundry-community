// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/tip_service.dart';
import 'package:seafoundry_app/services/user_prefs_service.dart';

/// A compact banner that surfaces rotating "Did you know?" tips.
///
/// It listens to TipService for approved tips filtered by optional
/// species, node type, and role. If no tips are available, it renders
/// nothing to keep surfaces clean.
///
/// Supports tips from external sources (Wikipedia, GBIF) with source
/// attribution displayed alongside the content.
class DidYouKnowBanner extends StatefulWidget {
  const DidYouKnowBanner({
    super.key,
    this.speciesId,
    this.speciesName,
    this.nodeType,
    this.role,
    this.dismissKey,
    this.interval = const Duration(seconds: 12),
    this.ttl = const Duration(days: 7),
  });

  final String? speciesId;
  final String? speciesName;
  final String? nodeType;
  final String? role;
  final String? dismissKey;
  final Duration interval;
  final Duration ttl;

  @override
  State<DidYouKnowBanner> createState() => _DidYouKnowBannerState();
}

class _DidYouKnowBannerState extends State<DidYouKnowBanner> {
  StreamSubscription<List<Tip>>? _sub;
  List<Tip> _tips = const [];
  int _index = 0;
  Timer? _timer;
  bool _dismissed = false;
  bool _initialized = false;
  bool _featureEnabled = true;

  @override
  void initState() {
    super.initState();
    _featureEnabled = _isFeatureEnabled();
    if (!_featureEnabled) {
      _initialized = true;
      return;
    }
    // Check persisted dismissals
    _checkPersistedDismissal();
    TipService? tipService;
    try {
      tipService = context.read<TipService>();
    } on ProviderNotFoundException {
      tipService = null;
    }
    if (tipService == null) {
      return;
    }
    _sub = tipService
        .streamTips(
          speciesId: widget.speciesId,
          speciesName: widget.speciesName,
          nodeType: widget.nodeType,
          role: widget.role,
        )
        .listen((tips) {
      if (!mounted) return;
      setState(() {
        _tips = tips;
        if (_index >= _tips.length) _index = 0;
      });
    });
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      if (_tips.isEmpty) return;
      setState(() => _index = (_index + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_featureEnabled) {
      return const SizedBox.shrink();
    }
    if (!_initialized) {
      // Avoid flashing before we know dismiss state
      return const SizedBox.shrink();
    }
    if (_dismissed || _tips.isEmpty) return const SizedBox.shrink();

    final tip = _tips[_index];
    final theme = Theme.of(context);
    final bg = theme.colorScheme.secondaryContainer;
    final fg = theme.colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: _buildLeading(tip, theme, fg),
          title: Text(
            'Did you know? ${tip.text}',
            style: theme.textTheme.bodyMedium?.copyWith(color: fg),
          ),
          subtitle: _buildSourceAttribution(tip, theme, fg),
          trailing: IconButton(
            tooltip: 'Dismiss',
            icon: Icon(Icons.close, color: fg),
            onPressed: () async {
              if (widget.dismissKey != null) {
                await UserPrefsService.instance
                    .dismiss(widget.dismissKey!, widget.ttl);
              }
              if (mounted) setState(() => _dismissed = true);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Tip tip, ThemeData theme, Color fg) {
    if (tip.imageUrl != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(tip.imageUrl!),
        backgroundColor: theme.colorScheme.surface,
      );
    }

    // Use different icons based on source
    IconData icon;
    switch (tip.source) {
      case TipSource.wikipedia:
        icon = Icons.menu_book;
      case TipSource.gbif:
        icon = Icons.account_tree;
      default:
        icon = Icons.lightbulb;
    }

    return Icon(icon, color: fg);
  }

  Widget? _buildSourceAttribution(Tip tip, ThemeData theme, Color fg) {
    final sourceName = tip.source.displayName;
    if (sourceName.isEmpty) return null;

    // Only show attribution for external sources
    if (tip.source == TipSource.internal || tip.source == TipSource.firestore) {
      return null;
    }

    return Text(
      'Source: $sourceName',
      style: theme.textTheme.bodySmall?.copyWith(
        color: fg.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Future<void> _checkPersistedDismissal() async {
    if (widget.dismissKey == null) {
      setState(() => _initialized = true);
      return;
    }
    final dismissed = await UserPrefsService.instance
        .isDismissed(widget.dismissKey!);
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _initialized = true;
    });
  }

  bool _isFeatureEnabled() {
    try {
      final access = context.read<FeatureAccessService>();
      return access.supportsVisualEngagementPhaseD;
    } catch (_) {
      return false;
    }
  }
}
