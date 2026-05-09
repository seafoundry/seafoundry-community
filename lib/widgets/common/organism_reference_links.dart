import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/models/records/record.dart';

typedef OrganismLinkTapHandler =
    void Function(BuildContext context, String value);

OrganismLinkTapHandler? _recordLinkHandler;
OrganismLinkTapHandler? _genetLinkHandler;

void registerOrganismLinkHandlers({
  OrganismLinkTapHandler? recordLinkHandler,
  OrganismLinkTapHandler? genetLinkHandler,
}) {
  _recordLinkHandler = recordLinkHandler;
  _genetLinkHandler = genetLinkHandler;
}

void openRecordLink(BuildContext context, String urlPath) {
  final trimmed = urlPath.trim();
  if (trimmed.isEmpty || trimmed == Missing.string) return;
  final handler = _recordLinkHandler;
  if (handler != null) {
    handler(context, trimmed);
    return;
  }
  final navigationCubit = _maybeNavigationCubit(context);
  navigationCubit?.navigateToPath(trimmed);
}

class GenetIdLink extends StatelessWidget {
  const GenetIdLink({
    super.key,
    required this.localGenetId,
    this.genetRecordId,
    this.style,
    this.showUnderline = true,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.onTap,
  });

  final String localGenetId;
  final String? genetRecordId;
  final TextStyle? style;
  final bool showUnderline;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final OrganismLinkTapHandler? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = localGenetId.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final resolvedId = (genetRecordId != null && genetRecordId!.trim().isNotEmpty)
        ? genetRecordId!.trim()
        : trimmed;
    VoidCallback? onTapCallback;
    if (resolvedId.isNotEmpty) {
      final handler = onTap ?? _genetLinkHandler;
      if (handler != null) {
        onTapCallback = () => handler(context, resolvedId);
      }
    }
    return _linkText(
      context,
      label: trimmed,
      onTap: onTapCallback,
      style: style,
      showUnderline: showUnderline,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

class RecordNameLink extends StatelessWidget {
  const RecordNameLink({
    super.key,
    required this.tagId,
    this.urlPath,
    this.style,
    this.showUnderline = true,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.onTap,
  });

  final String tagId;
  final String? urlPath;
  final TextStyle? style;
  final bool showUnderline;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final OrganismLinkTapHandler? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = tagId.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final path = urlPath?.trim() ?? '';
    VoidCallback? onTapCallback;
    if (path.isNotEmpty) {
      final navigationCubit = _maybeNavigationCubit(context);
      if (onTap != null) {
        onTapCallback = () => onTap!(context, path);
      } else if (navigationCubit != null) {
        onTapCallback = () => navigationCubit.navigateToPath(path);
      } else if (_recordLinkHandler != null) {
        onTapCallback = () => _recordLinkHandler!(context, path);
      }
    }
    return _linkText(
      context,
      label: trimmed,
      onTap: onTapCallback,
      style: style,
      showUnderline: showUnderline,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

class OrganismReferenceLinks extends StatelessWidget {
  const OrganismReferenceLinks({
    super.key,
    required this.tagId,
    required this.localGenetId,
    this.urlPath,
    this.genetRecordId,
    this.separator = ' * ',
    this.style,
    this.recordNameStyle,
    this.localIdStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.showUnderline = true,
    this.disableNavigation = false,
    this.onRecordTap,
    this.onGenetTap,
  });

  final String? tagId;
  final String? localGenetId;
  final String? urlPath;
  final String? genetRecordId;
  final String separator;
  final TextStyle? style;
  final TextStyle? recordNameStyle;
  final TextStyle? localIdStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool showUnderline;

  /// When true, disables all navigation links and displays as plain text.
  /// Useful in selection dialogs to prevent accidental navigation.
  final bool disableNavigation;
  final OrganismLinkTapHandler? onRecordTap;
  final OrganismLinkTapHandler? onGenetTap;

  @override
  Widget build(BuildContext context) {
    final recordValue = tagId?.trim() ?? '';
    final localValue = localGenetId?.trim() ?? '';
    if (recordValue.isEmpty && localValue.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;
    final resolvedLocalStyle =
        localIdStyle ??
        baseStyle?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final resolvedRecordStyle =
        recordNameStyle ?? baseStyle?.copyWith(fontWeight: FontWeight.w600);

    final hasLocal = localValue.isNotEmpty;
    final hasRecord = recordValue.isNotEmpty;

    // When navigation is disabled, render plain text without links
    if (disableNavigation) {
      return _buildPlainText(
        recordValue: recordValue,
        localValue: localValue,
        hasRecord: hasRecord,
        hasLocal: hasLocal,
        baseStyle: baseStyle,
        resolvedRecordStyle: resolvedRecordStyle,
        resolvedLocalStyle: resolvedLocalStyle,
      );
    }

    if (!hasLocal) {
      return RecordNameLink(
        tagId: recordValue,
        urlPath: urlPath,
        style: resolvedRecordStyle,
        showUnderline: showUnderline,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        onTap: onRecordTap,
      );
    }

    if (!hasRecord) {
      return GenetIdLink(
        localGenetId: localValue,
        genetRecordId: genetRecordId,
        style: resolvedLocalStyle,
        showUnderline: showUnderline,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        onTap: onGenetTap,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: RecordNameLink(
            tagId: recordValue,
            urlPath: urlPath,
            style: resolvedRecordStyle,
            showUnderline: showUnderline,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            onTap: onRecordTap,
          ),
        ),
        Text(
          separator,
          style: baseStyle,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
        Flexible(
          fit: FlexFit.loose,
          child: GenetIdLink(
            localGenetId: localValue,
            genetRecordId: genetRecordId,
            style: resolvedLocalStyle,
            showUnderline: showUnderline,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            onTap: onGenetTap,
          ),
        ),
      ],
    );
  }

  Widget _buildPlainText({
    required String recordValue,
    required String localValue,
    required bool hasRecord,
    required bool hasLocal,
    required TextStyle? baseStyle,
    required TextStyle? resolvedRecordStyle,
    required TextStyle? resolvedLocalStyle,
  }) {
    if (!hasLocal) {
      return Text(
        recordValue,
        style: resolvedRecordStyle,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    if (!hasRecord) {
      return Text(
        localValue,
        style: resolvedLocalStyle,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            recordValue,
            style: resolvedRecordStyle,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          ),
        ),
        Text(
          separator,
          style: baseStyle,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            localValue,
            style: resolvedLocalStyle,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          ),
        ),
      ],
    );
  }
}

Widget _linkText(
  BuildContext context, {
  required String label,
  required VoidCallback? onTap,
  TextStyle? style,
  bool showUnderline = true,
  int? maxLines,
  TextOverflow? overflow,
  TextAlign? textAlign,
}) {
  final theme = Theme.of(context);
  final baseStyle = style ?? theme.textTheme.bodyMedium;
  final linkStyle = onTap == null
      ? baseStyle
      : baseStyle?.copyWith(
          color: theme.colorScheme.primary,
          decoration: showUnderline ? TextDecoration.underline : null,
          decorationColor: theme.colorScheme.primary,
        );
  final text = Text(
    label,
    style: linkStyle,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
  );
  if (onTap == null) return text;

  return GestureDetector(
    onTap: onTap,
    child: MouseRegion(cursor: SystemMouseCursors.click, child: text),
  );
}

NavigationCubit? _maybeNavigationCubit(BuildContext context) {
  try {
    return context.read<NavigationCubit>();
  } on ProviderNotFoundException {
    return null;
  }
}

String formatOrganismReferenceLabel({
  required String? localGenetId,
  required String? tagId,
  String separator = ' * ',
  String fallback = '',
}) {
  final localValue = localGenetId?.trim() ?? '';
  final recordValue = tagId?.trim() ?? '';
  final hasLocal = localValue.isNotEmpty;
  final hasRecord = recordValue.isNotEmpty;

  if (hasLocal && hasRecord) {
    return '$recordValue$separator$localValue';
  }
  if (hasRecord) return recordValue;
  if (hasLocal) return localValue;
  return fallback;
}

class RecordDisplayInfo {
  const RecordDisplayInfo({
    required this.tagId,
    this.localGenetId,
    this.isHidden = false,
  });

  final String tagId;
  final String? localGenetId;
  final bool isHidden;
}

const String kHiddenIdentifierLabel = 'Identifier hidden';

RecordDisplayInfo resolveRecordDisplayInfo({
  required bool showUuid,
  required bool showIdentifier,
  required String recordId,
  required String? tagId,
  required String? localGenetId,
  String hiddenLabel = kHiddenIdentifierLabel,
}) {
  if (!showIdentifier) {
    final resolvedLocalId = localGenetId?.trim();
    return RecordDisplayInfo(
      tagId: (resolvedLocalId != null && resolvedLocalId.isNotEmpty)
          ? resolvedLocalId
          : hiddenLabel,
      isHidden: true,
    );
  }

  final resolvedName = showUuid ? recordId.trim() : (tagId?.trim() ?? '');
  final fallbackName = resolvedName.isNotEmpty ? resolvedName : recordId.trim();
  final resolvedLocalId = localGenetId?.trim();

  return RecordDisplayInfo(
    tagId: fallbackName,
    localGenetId: (resolvedLocalId == null || resolvedLocalId.isEmpty)
        ? null
        : resolvedLocalId,
  );
}
