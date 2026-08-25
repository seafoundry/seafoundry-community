import 'package:flutter/material.dart';
import 'package:seafoundry_community/widgets/spreadsheet/spreadsheet_models.dart';

class GeneticsColumnDefinition {
  GeneticsColumnDefinition({
    SpreadsheetColumn? column,
    String? key,
    String? title,
    double? width,
    double? minWidth,
    Alignment? alignment,
    SpreadsheetColumnType? type,
    bool? enableSorting,
    bool? enableEditing,
    List<String>? dropdownOptions,
    List<String> Function(Map<String, dynamic>)? dropdownOptionsProvider,
    String Function(dynamic)? formatter,
    bool Function(dynamic)? validator,
    String? validationMessage,
    Map<bool, String>? booleanLabels,
    required this.valueBuilder,
    this.onTap,
  }) : column =
           column ??
           SpreadsheetColumn(
             key: key ?? 'unknown',
             title: title ?? key ?? 'Unknown',
             width: width ?? 160,
             minWidth: minWidth,
             alignment: alignment ?? Alignment.centerLeft,
             type: type ?? SpreadsheetColumnType.text,
             enableSorting: enableSorting ?? false,
             enableEditing: enableEditing ?? false,
             dropdownOptions: dropdownOptions,
             dropdownOptionsProvider: dropdownOptionsProvider,
             formatter: formatter,
             validator: validator,
             validationMessage: validationMessage,
             booleanLabels: booleanLabels,
           );

  final SpreadsheetColumn column;
  final String Function(Map<String, dynamic>) valueBuilder;
  final void Function(
    BuildContext context,
    int rowIndex,
    Map<String, dynamic> row,
    SpreadsheetColumn column,
  )?
  onTap;

  String get key => column.key;
  String get title => column.title;
  double get width => column.width;
}

class GeneticsColumnBuilders {
  static List<SpreadsheetColumn> buildColumns(
    List<GeneticsColumnDefinition> columns,
  ) => columns.map((c) => c.column).toList(growable: false);

  static SpreadsheetRow buildRow(
    BuildContext context,
    Map<String, dynamic> row,
    List<GeneticsColumnDefinition> columns, {
    int rowIndex = 0,
    void Function(BuildContext context, Map<String, dynamic> row)? onEdit,
    Widget Function(BuildContext context, Map<String, dynamic> row)?
    rowActionsBuilder,
  }) {
    final isExample = row['__example'] == true;
    final textStyle = TextStyle(
      color: isExample ? Colors.grey.shade500 : null,
      fontStyle: isExample ? FontStyle.italic : null,
    );

    final cells = <String, SpreadsheetCell>{};

    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final value = column.valueBuilder(row);

      Widget child;
      if (column.key == 'row_actions') {
        final dynamic rawGenetId = row['genetRecordId'];
        final genetRecordId = rawGenetId?.toString();
        child = rowActionsBuilder != null
            ? rowActionsBuilder(context, row)
            : Tooltip(
              message: genetRecordId == null || genetRecordId.isEmpty
                  ? 'Edit unavailable for this row'
                  : 'Unlock to edit genet details',
              child: IconButton(
                icon: const Icon(Icons.lock_open),
                visualDensity: VisualDensity.compact,
                onPressed:
                    (!isExample &&
                        genetRecordId != null &&
                        genetRecordId.isNotEmpty &&
                        onEdit != null)
                    ? () => onEdit(context, row)
                    : null,
              ),
            );
      } else {
        final baseStyle = textStyle;
        // Style genet names as links if they have onTap handlers
        final linkStyle = column.onTap != null && column.key == 'genetName'
            ? TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              )
            : null;
        child = Text(
          value,
          style: linkStyle ?? baseStyle,
          overflow: TextOverflow.ellipsis,
        );
      }

      if (!isExample && column.onTap != null) {
        final wrappedChild = child;
        child = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => column.onTap!(
            context,
            rowIndex >= 0 ? rowIndex : i,
            row,
            column.column,
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: wrappedChild,
            ),
          ),
        );
      }

      cells[column.key] = SpreadsheetCell(child: child, placeholder: isExample);
    }

    return SpreadsheetRow(raw: row, cells: cells);
  }
}
