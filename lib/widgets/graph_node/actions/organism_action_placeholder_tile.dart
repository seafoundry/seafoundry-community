// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Shared builder for organism-aware placeholder tiles shown when an action
/// category lacks real workflows for the selected organism/scope.
class OrganismActionPlaceholderTile {
  static ListTile build({
    required OrganismKind organismKind,
    required String title,
    required String description,
    IconData icon = Icons.construction,
  }) {
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}
