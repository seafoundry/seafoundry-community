// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/provenance_crosswalk_service.dart';

/// Search delegate for finding genets via the provenance crosswalk service.
class CrosswalkSearchDelegate
    extends SearchDelegate<CommunityProvenanceRecord?> {
  CrosswalkSearchDelegate(this.service);

  final ProvenanceCrosswalkService service;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestionsOrResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsOrResults(context);
  }

  Widget _buildSuggestionsOrResults(BuildContext context) {
    if (query.length < 2) {
      return const Center(
        child: Text('Enter at least 2 characters to search genets'),
      );
    }

    return FutureBuilder<List<CommunityProvenanceRecord>>(
      future: service.searchByAliasPrefix(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(child: Text('No genets found'));
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final record = results[index];
            final aliasesList = record.aliases;
            final aliases = aliasesList.map((a) => a.id).join(', ');

            return ListTile(
              title: Text(record.provenanceId),
              subtitle: Text('${record.species} - Aliases: $aliases'),
              onTap: () => close(context, record),
            );
          },
        );
      },
    );
  }
}
