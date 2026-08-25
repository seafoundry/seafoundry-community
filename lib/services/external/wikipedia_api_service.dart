import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:seafoundry_community/services/logging_service.dart';

/// Data class representing a Wikipedia summary for a species.
class WikipediaSummary {
  const WikipediaSummary({
    required this.title,
    required this.extract,
    this.description,
    this.thumbnailUrl,
  });

  final String title;
  final String extract;
  final String? description;
  final String? thumbnailUrl;

  /// Creates a short fact-style text from the summary.
  String toFactText() {
    // Use description if short enough, otherwise extract first sentence
    if (description != null && description!.length <= 150) {
      return description!;
    }
    // Extract first sentence from the extract
    final firstSentence = extract.split('. ').first;
    if (firstSentence.length <= 200) {
      return firstSentence.endsWith('.') ? firstSentence : '$firstSentence.';
    }
    return '${firstSentence.substring(0, 197)}...';
  }
}

/// Service for fetching species information from Wikipedia's REST API.
///
/// Uses the Wikipedia Page Summary endpoint to get concise species descriptions.
/// https://en.wikipedia.org/api/rest_v1/page/summary/{title}
class WikipediaApiService {
  WikipediaApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://en.wikipedia.org/api/rest_v1/page/summary';
  static const _timeout = Duration(seconds: 10);

  /// User-Agent sent with Wikipedia API requests. Per the Wikimedia
  /// User-Agent policy, this should identify the client and provide a
  /// contact address. Forks should override via dart-define so the
  /// contact address routes to their own maintainer.
  static const _userAgent = String.fromEnvironment(
    'WIKIPEDIA_USER_AGENT',
    defaultValue: 'SeaFoundryCommunityApp/1.0 (https://github.com/seafoundry/seafoundry-community)',
  );

  /// Fetches a summary for the given species name.
  ///
  /// Tries the scientific name first, then falls back to common name if provided.
  /// Returns null if the species is not found or an error occurs.
  Future<WikipediaSummary?> getSummary(
    String speciesName, {
    String? commonName,
  }) async {
    // Try scientific name first (usually more specific)
    var summary = await _fetchSummary(speciesName);
    if (summary != null) return summary;

    // Try common name if provided
    if (commonName != null && commonName.isNotEmpty) {
      summary = await _fetchSummary(commonName);
      if (summary != null) return summary;
    }

    return null;
  }

  Future<WikipediaSummary?> _fetchSummary(String title) async {
    try {
      // URL-encode the title, replacing spaces with underscores
      final encodedTitle = Uri.encodeComponent(title.replaceAll(' ', '_'));
      final uri = Uri.parse('$_baseUrl/$encodedTitle');

      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          // Include a user-agent as required by Wikipedia API policy.
          // Configurable via WIKIPEDIA_USER_AGENT dart-define.
          'User-Agent': _userAgent,
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _parseSummary(data);
      }

      if (response.statusCode == 404) {
        // Page not found - not an error, just no data
        return null;
      }

      if (kDebugMode) {
        LoggingService.instance.warning('WikipediaApiService: HTTP ${response.statusCode} for "$title"');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.warning('WikipediaApiService: Error fetching "$title": $e');
      }
      return null;
    }
  }

  WikipediaSummary? _parseSummary(Map<String, dynamic> data) {
    final title = data['title'] as String?;
    final extract = data['extract'] as String?;

    if (title == null || extract == null || extract.isEmpty) {
      return null;
    }

    // Check if this is a disambiguation page
    final type = data['type'] as String?;
    if (type == 'disambiguation') {
      return null;
    }

    // Extract thumbnail URL if available
    String? thumbnailUrl;
    final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
    if (thumbnail != null) {
      thumbnailUrl = thumbnail['source'] as String?;
    }

    return WikipediaSummary(
      title: title,
      extract: extract,
      description: data['description'] as String?,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// Disposes of the HTTP client resources.
  void dispose() {
    _client.close();
  }
}
