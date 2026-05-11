/// Human-friendly alphanumeric sorting helpers.
int compareHumanReadable(String a, String b) {
  final left = a.trim().toLowerCase();
  final right = b.trim().toLowerCase();
  if (left == right) return 0;

  final aParts = _splitAlphaNumeric(left);
  final bParts = _splitAlphaNumeric(right);
  final maxLen = aParts.length < bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < maxLen; i += 1) {
    final aPart = aParts[i];
    final bPart = bParts[i];
    final aIsNumber = int.tryParse(aPart) != null;
    final bIsNumber = int.tryParse(bPart) != null;

    if (aIsNumber && bIsNumber) {
      final aNum = int.parse(aPart);
      final bNum = int.parse(bPart);
      if (aNum != bNum) return aNum.compareTo(bNum);
    } else if (aIsNumber != bIsNumber) {
      return aIsNumber ? -1 : 1;
    } else {
      final cmp = aPart.compareTo(bPart);
      if (cmp != 0) return cmp;
    }
  }

  return aParts.length.compareTo(bParts.length);
}

List<String> _splitAlphaNumeric(String input) {
  final parts = <String>[];
  final buffer = StringBuffer();
  bool? isDigit;

  for (final codeUnit in input.codeUnits) {
    final char = String.fromCharCode(codeUnit);
    final digit = codeUnit >= 48 && codeUnit <= 57;
    if (isDigit == null) {
      isDigit = digit;
      buffer.write(char);
      continue;
    }

    if (digit == isDigit) {
      buffer.write(char);
    } else {
      parts.add(buffer.toString());
      buffer.clear();
      buffer.write(char);
      isDigit = digit;
    }
  }

  if (buffer.isNotEmpty) {
    parts.add(buffer.toString());
  }

  return parts.isEmpty ? [input] : parts;
}
