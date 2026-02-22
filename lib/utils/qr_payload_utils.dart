// @tier: community
import 'dart:convert';

/// Helpers for QR payload sizing constraints.
class QrPayloadUtils {
  const QrPayloadUtils._();

  /// Max payload bytes for QR version 40-L in byte mode.
  static const int maxPayloadBytesV40L = 2953;

  /// Returns true when the payload exceeds QR capacity for version 40-L.
  static bool isPayloadTooLong(String payload) {
    return utf8.encode(payload).length > maxPayloadBytesV40L;
  }
}
