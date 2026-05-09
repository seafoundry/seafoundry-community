import 'package:flutter/material.dart';

enum SpreadsheetColumnType { text, number, dropdown, date, boolean }

class SpreadsheetColumn {
  const SpreadsheetColumn({
    required this.key,
    required this.title,
    this.width = 160,
    this.minWidth,
    this.alignment = Alignment.centerLeft,
    this.type = SpreadsheetColumnType.text,
    this.enableSorting = false,
    this.enableEditing = false,
    this.booleanLabels,
    this.dropdownOptions,
    this.dropdownOptionsProvider,
    this.formatter,
    this.validator,
    this.validationMessage,
    this.onTap,
  });

  final String key;
  final String title;
  final double width;
  final double? minWidth;
  final Alignment alignment;
  final SpreadsheetColumnType type;
  final bool enableSorting;
  final bool enableEditing;
  final List<String>? dropdownOptions;
  final List<String> Function(Map<String, dynamic>)? dropdownOptionsProvider;
  final String Function(dynamic)? formatter;
  final bool Function(dynamic)? validator;
  final String? validationMessage;
  final void Function(int rowIndex, Map<String, dynamic> rowData)? onTap;
  final Map<bool, String>? booleanLabels;
}

class SpreadsheetRow {
  const SpreadsheetRow({required this.cells, this.raw, this.key});

  final Map<String, SpreadsheetCell> cells;
  final Map<String, dynamic>? raw;
  final Key? key;
}

class SpreadsheetCell {
  const SpreadsheetCell({required this.child, this.placeholder = false, this.onTap});

  final Widget child;
  final bool placeholder;
  final GestureTapCallback? onTap;

  factory SpreadsheetCell.text(
    String value, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
    GestureTapCallback? onTap,
    bool placeholder = false,
  }) => SpreadsheetCell(
    child: Text(value, style: style, textAlign: textAlign),
    onTap: onTap,
    placeholder: placeholder,
  );
}
