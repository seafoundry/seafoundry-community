// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/historical_data_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_details_sheet.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/site_details_content.dart';

/// Bottom sheet showing detailed outplant information for a site.
///
/// Displays site statistics, species breakdown, genotype summary,
/// and outplant events grouped by date.
class SiteDetailsSheet extends StatefulWidget {
  const SiteDetailsSheet({
    super.key,
    required this.siteId,
    required this.clusterLabel,
    required this.historicalService,
    required this.datasetId,
  });

  final String siteId;
  final String clusterLabel;
  final HistoricalDataService historicalService;
  final String datasetId;

  @override
  State<SiteDetailsSheet> createState() => _SiteDetailsSheetState();
}

class _SiteDetailsSheetState extends State<SiteDetailsSheet> {
  SiteOutplantDetails? _details;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await widget.historicalService.fetchSiteOutplantDetails(
        datasetId: widget.datasetId,
        siteId: widget.siteId,
      );
      if (mounted) {
        setState(() {
          _details = details;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load site outplant details',
        {
          'siteId': widget.siteId,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      if (mounted) {
        setState(() {
          _error = 'Failed to load details: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoldingsMapDetailsSheet(
      title: _details?.reefName ?? widget.clusterLabel,
      subtitle: _details?.region,
      initialChildSize: 0.6,
      contentBuilder: _buildContent,
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading outplant data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_details == null) {
      return const SizedBox.shrink();
    }

    return SiteDetailsContent(
      details: _details!,
      scrollController: scrollController,
    );
  }
}
