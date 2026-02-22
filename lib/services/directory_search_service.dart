// @tier: community
import 'package:cloud_functions/cloud_functions.dart';

class DirectoryUserResult {
  const DirectoryUserResult({
    required this.id,
    required this.name,
    required this.email,
    this.organizationId,
    this.organizationName,
  });

  final String id;
  final String name;
  final String email;
  final String? organizationId;
  final String? organizationName;

  factory DirectoryUserResult.fromJson(Map<String, dynamic> json) {
    return DirectoryUserResult(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['email'] as String? ?? 'Member',
      email: json['email'] as String? ?? '',
      organizationId: json['organizationId'] as String?,
      organizationName: json['organizationName'] as String?,
    );
  }
}

class DirectoryOrganizationResult {
  const DirectoryOrganizationResult({
    required this.id,
    required this.name,
    required this.domain,
    this.members = const [],
  });

  final String id;
  final String name;
  final String domain;
  final List<DirectoryUserResult> members;

  factory DirectoryOrganizationResult.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'] as List? ?? const [];
    final members = membersRaw
        .whereType<Map<String, dynamic>>()
        .map(DirectoryUserResult.fromJson)
        .toList();

    return DirectoryOrganizationResult(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['domain'] as String? ?? 'Organization',
      domain: json['domain'] as String? ?? '',
      members: members,
    );
  }
}

class DirectorySearchResult {
  const DirectorySearchResult({
    this.users = const [],
    this.organizations = const [],
  });

  final List<DirectoryUserResult> users;
  final List<DirectoryOrganizationResult> organizations;

  factory DirectorySearchResult.fromJson(Map<String, dynamic> json) {
    final usersRaw = json['users'] as List? ?? const [];
    final orgsRaw = json['organizations'] as List? ?? const [];

    return DirectorySearchResult(
      users: usersRaw
          .whereType<Map<String, dynamic>>()
          .map(DirectoryUserResult.fromJson)
          .toList(),
      organizations: orgsRaw
          .whereType<Map<String, dynamic>>()
          .map(DirectoryOrganizationResult.fromJson)
          .toList(),
    );
  }
}

class DirectorySearchService {
  DirectorySearchService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<DirectorySearchResult> search(String query, {int limit = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const DirectorySearchResult();
    }

    final callable = _functions.httpsCallable('searchDirectory');
    final result = await callable.call<Map<String, dynamic>>({
      'query': trimmed,
      'limit': limit,
    });

    return DirectorySearchResult.fromJson(
      Map<String, dynamic>.from(result.data),
    );
  }
}
