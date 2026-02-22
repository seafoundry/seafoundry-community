// @tier: community
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'file_bytes_loader_stub.dart'
    if (dart.library.io) 'file_bytes_loader_io.dart'
    as file_loader;

class CsvFilePickerException extends FormatException {
  const CsvFilePickerException(super.message);
}

class CsvFilePickerOptions {
  const CsvFilePickerOptions({
    this.allowedExtensions = const ['csv'],
    this.dialogTitle,
  });

  final List<String> allowedExtensions;
  final String? dialogTitle;
}

class PickedCsvFile {
  const PickedCsvFile({
    required this.name,
    required this.bytes,
    this.extension,
    this.path,
  });

  final String name;
  final Uint8List bytes;
  final String? extension;
  final String? path;
}

abstract class CsvFilePicker {
  Future<PickedCsvFile?> pickCsvFile({
    CsvFilePickerOptions options = const CsvFilePickerOptions(),
  });
}

class PlatformCsvFilePicker implements CsvFilePicker {
  const PlatformCsvFilePicker();

  @override
  Future<PickedCsvFile?> pickCsvFile({
    CsvFilePickerOptions options = const CsvFilePickerOptions(),
  }) async {
    final allowedExtensions = options.allowedExtensions.isNotEmpty
        ? options.allowedExtensions
        : const ['csv'];

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
      allowMultiple: false,
      dialogTitle: options.dialogTitle,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    Uint8List? bytes = file.bytes;
    String? path;
    if (!kIsWeb) {
      path = file.path;
      if (bytes == null && path != null && path.isNotEmpty) {
        bytes = await file_loader.loadFileBytes(path);
      }
    }

    if (bytes == null) {
      throw const CsvFilePickerException('Failed to read file data');
    }

    return PickedCsvFile(
      name: file.name,
      bytes: bytes,
      extension: file.extension?.toLowerCase(),
      path: path,
    );
  }
}
