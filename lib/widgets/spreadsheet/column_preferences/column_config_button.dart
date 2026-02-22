// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/spreadsheet_column_preferences/spreadsheet_column_preferences_cubit.dart';
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/column_config_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/spreadsheet_id.dart';

/// Toolbar button that opens the column configuration dialog.
class ColumnConfigButton extends StatelessWidget {
  const ColumnConfigButton({
    super.key,
    required this.spreadsheetId,
    required this.allColumns,
  });

  final SpreadsheetId spreadsheetId;
  final List<ColumnConfigItem> allColumns;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.view_column_outlined),
      tooltip: 'Configure columns',
      onPressed: () {
        final cubit = context.read<SpreadsheetColumnPreferencesCubit>();
        showDialog<void>(
          context: context,
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: ColumnConfigDialog(
              spreadsheetId: spreadsheetId,
              allColumns: allColumns,
            ),
          ),
        );
      },
    );
  }
}
