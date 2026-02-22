// @tier: community
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

bool looksLikeEmail(String value) => value.contains('@');

String humanizeEmail(String email) {
  final localPart = email.split('@').first;
  if (localPart.isEmpty) return email;
  final tokens = localPart
      .split(RegExp(r'[._-]+'))
      .where((token) => token.trim().isNotEmpty)
      .map(_capitalizeToken)
      .toList();
  if (tokens.isEmpty) return localPart;
  return tokens.join(' ');
}

String _capitalizeToken(String token) {
  if (token.isEmpty) return token;
  if (token.length == 1) return token.toUpperCase();
  return token[0].toUpperCase() + token.substring(1).toLowerCase();
}

String? _metadataDisplayName(Map<String, dynamic>? metadata) {
  if (metadata == null) return null;
  const keys = ['displayName', 'fullName', 'name'];
  for (final key in keys) {
    final raw = metadata[key];
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty && !looksLikeEmail(trimmed)) {
        return trimmed;
      }
    }
  }

  final firstName = metadata['firstName'] ??
      metadata['first_name'] ??
      metadata['firstname'];
  final lastName = metadata['lastName'] ??
      metadata['last_name'] ??
      metadata['lastname'];

  if (firstName is String || lastName is String) {
    final first = (firstName as String?)?.trim() ?? '';
    final last = (lastName as String?)?.trim() ?? '';
    final combined = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (combined.isNotEmpty && !looksLikeEmail(combined)) {
      return combined;
    }
  }

  return null;
}

String formatUserDisplayName(User? user, String fallbackId) {
  if (user != null) {
    final metadataName = _metadataDisplayName(user.metadata);
    if (metadataName != null) return metadataName;

    final name = user.name.trim();
    if (name.isNotEmpty && !looksLikeEmail(name)) {
      return name;
    }

    final email = user.email.trim();
    if (email.isNotEmpty) {
      return humanizeEmail(email);
    }

    if (name.isNotEmpty) {
      return humanizeEmail(name);
    }
  }

  return looksLikeEmail(fallbackId) ? humanizeEmail(fallbackId) : fallbackId;
}

Future<User?> _fetchUserFromQuery(
  RecordRepository recordRepository,
  String field,
  String value,
) async {
  try {
    final collection = FirestoreCollectionResolver.instance.collection(
      recordRepository.db,
      ModelType.user.collectionPath,
    );
    final snapshot = await collection
        .where(field, isEqualTo: value)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return RecordFactory.recordFromJson<User>(snapshot.docs.first.data());
  } catch (error, stackTrace) {
    LoggingService.instance.error(
      'Failed to query user by $field',
      error,
      stackTrace,
    );
    return null;
  }
}

Future<User?> fetchUserByIdOrFallback({
  required RecordRepository recordRepository,
  required String userId,
}) async {
  try {
    final direct = await recordRepository.getRecord<User>(
      ModelType.user,
      userId,
    );
    if (direct != null) {
      return direct;
    }
  } catch (error, stackTrace) {
    LoggingService.instance.warning(
      'Failed to resolve user $userId by id',
      {'error': error.toString(), 'stackTrace': stackTrace.toString()},
    );
  }

  if (looksLikeEmail(userId)) {
    final normalized = userId.toLowerCase().trim();
    final byEmail = await _fetchUserFromQuery(
      recordRepository,
      'email',
      normalized,
    );
    if (byEmail != null) {
      return byEmail;
    }
  }

  return _fetchUserFromQuery(recordRepository, 'uid', userId);
}

Future<String> resolveUserDisplayName({
  required RecordRepository recordRepository,
  required String userId,
  Map<String, String>? cache,
}) async {
  if (userId.isEmpty) return '';
  final cached = cache != null ? cache[userId] : null;
  if (cached != null) return cached;

  final user = await fetchUserByIdOrFallback(
    recordRepository: recordRepository,
    userId: userId,
  );
  final displayName = formatUserDisplayName(user, userId);
  if (cache != null) {
    cache[userId] = displayName;
  }
  return displayName;
}
