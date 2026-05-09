// @tier: community

/// Identifies each spreadsheet type for column preference persistence.
enum SpreadsheetId {
  genetics('genetics'),
  inventoryEvents('inventoryEvents'),
  holdings('holdings'),
  observations('observations'),
  outplantEvents('outplantEvents');

  const SpreadsheetId(this.id);
  final String id;
}
