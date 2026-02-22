// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/navigation/bottom_action_bar.dart';

/// Extracts primary actions from graph node for bottom action bar
///
/// Returns the three category-based buttons: Inventory, Observations, Husbandry.
class PrimaryActionExtractor {
  const PrimaryActionExtractor();

  /// Extract primary actions for bottom action bar
  /// 
  /// Returns three category-based buttons: Inventory, Observations, Husbandry.
  /// Each opens the respective category sheet with all available actions.
  List<BottomAction> extractPrimaryActions() {
    return [
      BottomAction(
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        tooltip: 'Inventory actions',
        onPressed: null,
      ),
      BottomAction(
        label: 'Husbandry',
        icon: Icons.assignment_outlined,
        tooltip: 'Observations & Husbandry',
        onPressed: null,
      ),
      BottomAction(
        label: 'Tasks & Chats',
        icon: Icons.checklist_outlined,
        tooltip: 'Tasks & Chats',
        onPressed: null,
      ),
    ];
  }

}

