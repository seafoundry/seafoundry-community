// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';

/// Table for displaying PID/genotype breakdown counts.
class ImpactPointBreakdownTable extends StatelessWidget {
  const ImpactPointBreakdownTable({
    super.key,
    required this.breakdown,
    required this.totalColonies,
    required this.idLabel,
    this.idTextStyle,
  });

  final Map<String, int> breakdown;
  final int totalColonies;
  final String idLabel;
  final TextStyle? idTextStyle;

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = entries.take(25).toList();
    final hidden = entries.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _BreakdownHeader(idLabel: idLabel),
              ...visible.map(
                (entry) => _BreakdownRow(
                  id: entry.key,
                  count: entry.value,
                  total: totalColonies,
                  idTextStyle: idTextStyle,
                ),
              ),
            ],
          ),
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '...and $hidden more IDs',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader({required this.idLabel});

  final String idLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: crcAccentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              idLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(
            width: 110,
            child: Text(
              'Count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.id,
    required this.count,
    required this.total,
    this.idTextStyle,
  });

  final String id;
  final int count;
  final int total;
  final TextStyle? idTextStyle;

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    final percentLabel = total > 0 ? '${percentage.toStringAsFixed(1)}%' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              id,
              style:
                  idTextStyle ??
                  const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '${formatNumber(count)} ($percentLabel)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
