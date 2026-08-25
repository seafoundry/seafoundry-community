import 'dart:convert';

import 'package:seafoundry_community/services/csv/downloaders/csv_download_interface.dart';
import 'package:universal_html/html.dart' as html;

CsvDownloadAdapter createCsvDownloadAdapter() =>
    const _WebCsvDownloadAdapter();

class _WebCsvDownloadAdapter extends CsvDownloadAdapter {
  const _WebCsvDownloadAdapter();

  @override
  bool get isSupported => true;

  @override
  Future<void> save({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
