import 'package:seafoundry_app/services/csv/downloaders/csv_download_interface.dart';

CsvDownloadAdapter createCsvDownloadAdapter() =>
    const _UnsupportedCsvDownloadAdapter();

class _UnsupportedCsvDownloadAdapter extends CsvDownloadAdapter {
  const _UnsupportedCsvDownloadAdapter();

  @override
  bool get isSupported => false;

  @override
  Future<void> save({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    throw UnsupportedError('CSV downloads are not supported on this platform.');
  }
}
