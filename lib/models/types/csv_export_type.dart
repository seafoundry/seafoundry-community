// @tier: community
/// Types of CSV exports available in the application
enum CSVExportType {
  genetics('Genetics', 'genetics'),
  inventory('Inventory', 'inventory'),
  husbandryLogged('Husbandry Logged', 'husbandry_logged'),
  husbandryTasksCreated('Husbandry Tasks Created', 'husbandry_tasks'),
  observations('Observations', 'observations'),
  monitoring('Monitoring', 'monitoring'),
  outplanting('Outplanting', 'outplanting');

  final String displayName;
  final String fileName;

  const CSVExportType(this.displayName, this.fileName);
}
