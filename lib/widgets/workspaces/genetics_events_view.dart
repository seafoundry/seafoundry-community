// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/spreadsheet/genetics/genetics_events_table.dart';

class GeneticsEventsView extends StatelessWidget {
  const GeneticsEventsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: GeneticsEventsTable(),
    );
  }
}
