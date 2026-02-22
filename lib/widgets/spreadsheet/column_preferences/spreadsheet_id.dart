// @tier: community

/// Identifies each spreadsheet type for column preference persistence.
enum SpreadsheetId {
  genetics('genetics'),
  inventoryEvents('inventoryEvents'),
  holdings('holdings'),
  monitoring('monitoring'),
  observations('observations'),
  husbandry('husbandry'),
  outplantEvents('outplantEvents');

  const SpreadsheetId(this.id);
  final String id;
}
