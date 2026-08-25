import 'package:cloud_firestore/cloud_firestore.dart';

extension StringFieldStartsWith on Query {
  Query whereStringField(String field, {required String startsWith}) {
    return where(field, isGreaterThanOrEqualTo: startsWith).where(field, isLessThan: getPrefixUpperBound(startsWith));
  }

  String getPrefixUpperBound(String prefix) {
    if (prefix.isEmpty) return prefix;
    final lastChar = prefix.codeUnitAt(prefix.length - 1);
    final nextChar = String.fromCharCode(lastChar + 1);
    return prefix.substring(0, prefix.length - 1) + nextChar;
  }
}

String generateId({required FirebaseFirestore firestore}) {
  return firestore.collection('temp').doc().id;
}
