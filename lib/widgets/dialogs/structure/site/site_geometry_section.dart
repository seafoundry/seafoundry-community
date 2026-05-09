// @tier: community
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/services/outplant_geometry_builder.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Widget for entering and parsing site geometry coordinates.
///
/// Supports manual coordinate entry (lat,lng pairs) and file uploads
/// (CSV, GeoJSON formats). Coordinates are parsed and validated
/// before being stored in the site creation bloc.
class SiteGeometrySection extends StatefulWidget {
  const SiteGeometrySection({super.key, required this.formState});

  final SiteFormState formState;

  @override
  State<SiteGeometrySection> createState() => _SiteGeometrySectionState();
}

class _SiteGeometrySectionState extends State<SiteGeometrySection> {
  final OutplantGeometryBuilder _builder = const OutplantGeometryBuilder();
  late final TextEditingController _controller;
  bool _isParsing = false;
  bool _isProgrammaticUpdate = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.formState.geometryManual?.value ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant SiteGeometrySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedText = widget.formState.geometryManual?.value ?? '';
    if (_controller.text != updatedText) {
      _setControllerText(updatedText, notify: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setControllerText(String text, {bool notify = true}) {
    _isProgrammaticUpdate = true;
    _controller
      ..text = text
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    _isProgrammaticUpdate = false;
    if (notify) {
      final bloc = context.read<SiteCreationBloc>();
      bloc.add(SiteGeometryManualChanged(text));
    }
  }

  void _handleChanged(String value) {
    if (_isProgrammaticUpdate) return;
    final bloc = context.read<SiteCreationBloc>();
    bloc.add(SiteGeometryManualChanged(value));
    bloc.add(const SiteGeometryCleared());
  }

  Future<void> _parseManual() async {
    final bloc = context.read<SiteCreationBloc>();
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      bloc.add(
        const SiteGeometryParseResult(
          geometry: null,
          statusMessage: null,
          validationMessage:
              'Enter at least one coordinate pair (lat,lng) before parsing.',
        ),
      );
      return;
    }

    setState(() => _isParsing = true);
    try {
      final coordinates = _parseManualCoordinates(raw);
      final input = OutplantGeometryInput(
        type: coordinates.length == 1
            ? OutplantGeometryType.point
            : OutplantGeometryType.polygon,
        coordinates: coordinates,
        source: OutplantGeometrySource.manual,
      );
      final geometry = _builder.build(input: input);
      final normalized = _formatCoordinates(geometry);
      _setControllerText(normalized);
      bloc.add(
        SiteGeometryParseResult(
          geometry: geometry,
          statusMessage: 'Loaded ${geometry.coordinates.length} coordinate(s).',
        ),
      );
    } on FormatException catch (error) {
      bloc.add(
        SiteGeometryParseResult(
          geometry: null,
          validationMessage: error.message,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  Future<void> _pickGeometryFile() async {
    final bloc = context.read<SiteCreationBloc>();
    setState(() => _isParsing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['csv', 'geojson', 'json'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        throw const FormatException('Unable to read file bytes.');
      }

      final content = String.fromCharCodes(file.bytes!);
      final coordinates = _parseManualCoordinates(content);
      final input = OutplantGeometryInput(
        type: coordinates.length == 1
            ? OutplantGeometryType.point
            : OutplantGeometryType.polygon,
        coordinates: coordinates,
        source: OutplantGeometrySource.csv,
      );
      final geometry = _builder.build(input: input);
      final normalized = _formatCoordinates(geometry);
      _setControllerText(normalized);
      bloc.add(
        SiteGeometryParseResult(
          geometry: geometry,
          statusMessage:
              'Loaded ${geometry.coordinates.length} coordinate(s) from ${file.name}.',
        ),
      );
    } on FormatException catch (error) {
      bloc.add(
        SiteGeometryParseResult(
          geometry: null,
          validationMessage: error.message,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  void _addCoordinateRow() {
    final text = _controller.text.trimRight();
    final updated = text.isEmpty ? '' : '$text\n';
    _setControllerText('${updated}0.000000,0.000000', notify: false);
    _handleChanged(_controller.text);
  }

  /// Parses manually entered coordinate text (one lat,lng pair per line).
  static List<GeoCoordinate> _parseManualCoordinates(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('No coordinate pairs found.');
    }
    final coordinates = <GeoCoordinate>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,\s]+'));
      if (parts.length < 2) {
        throw FormatException('Invalid coordinate pair: "$line"');
      }
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) {
        throw FormatException('Non-numeric coordinate: "$line"');
      }
      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return coordinates;
  }

  String _formatCoordinates(OutplantGeometry geometry) {
    return geometry.coordinates
        .map(
          (coord) =>
              '${coord.latitude.toStringAsFixed(6)},${coord.longitude.toStringAsFixed(6)}',
        )
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final statusMessage = widget.formState.geometryStatusMessage;
    final validationMessage = widget.formState.geometryValidationMessage;
    final geometry = widget.formState.geometry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIText.bodyMedium('Site Geometry'),
        UI.spacingVerticalSm,
        Text(
          'Paste latitude/longitude pairs (one per line) or upload a CSV '
          'or GeoJSON file. Provide at least one coordinate pair.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        UI.spacingVerticalSm,
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 8,
          onChanged: _handleChanged,
          decoration: InputDecoration(
            hintText: '25.761681,-80.191788',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          keyboardType: TextInputType.multiline,
        ),
        UI.spacingVerticalSm,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isParsing ? null : _parseManual,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Parse Coordinates'),
            ),
            OutlinedButton.icon(
              onPressed: _isParsing ? null : _pickGeometryFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload CSV/GeoJSON'),
            ),
            TextButton.icon(
              onPressed: _isParsing ? null : _addCoordinateRow,
              icon: const Icon(Icons.add),
              label: const Text('Add Row'),
            ),
          ],
        ),
        if (_isParsing) ...[
          UI.spacingVerticalSm,
          const LinearProgressIndicator(),
        ],
        if (statusMessage != null && statusMessage.isNotEmpty) ...[
          UI.spacingVerticalSm,
          Text(
            statusMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
        if (validationMessage != null && validationMessage.isNotEmpty) ...[
          UI.spacingVerticalSm,
          Text(
            validationMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (geometry != null) ...[
          UI.spacingVerticalSm,
          Text(
            'Ready to save ${geometry.coordinates.length} coordinate(s).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
