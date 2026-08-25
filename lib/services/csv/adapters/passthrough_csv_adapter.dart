import 'package:seafoundry_community/services/csv/adapters/csv_translation_adapter.dart';

/// Default adapter that simply clones the provided rows. Registered last so
/// more specific adapters can opt-in via metadata.
class PassthroughCsvAdapter extends CsvTranslationAdapter {
  const PassthroughCsvAdapter() : super(id: 'passthrough');

  @override
  bool supports(CsvTranslationContext context) => true;
}
