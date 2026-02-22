// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/ui.dart';

import 'components/transfer_fields.dart';

class TransferDetailsSection extends StatelessWidget {
  const TransferDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: TransferTargetPicker(),
        ),
        UI.spacingVerticalSm,
        const TransferCollectorField(),
        UI.spacingVerticalSm,
        const TransferInstitutionField(),
        UI.spacingVerticalSm,
        const TransferEmailField(),
        UI.spacingVerticalSm,
        const TransferDateField(),
        UI.spacingVerticalSm,
        const TransferNotesField(),
      ],
    );
  }
}
