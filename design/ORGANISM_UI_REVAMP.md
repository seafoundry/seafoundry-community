# Organism UI Revamp Proposal

## Problem Statement
The current UI for editing organism records is fragmented and inconsistent:
- **Inconsistent "Edit" Actions**: The "Edit" button in spreadsheets often opens an "Edit Name" dialog instead of a full property editor.
- **Confusing Monolithic Editor**: `OrganismRecordEditDialog` combines Life Stage, Physical Form, Size, and Quantity into one complex form, which is overwhelming and error-prone.
- **Fragmented Workflows**: Specialized dialogs like `SizeChangeDialog` and `LifeStageProgressionDialog` exist but are not consistently accessible.
- **Lack of "Quick Actions"**: Users expect a consistent "3-dot" or "Quick Action" menu to access common tasks (Move, Update Size, Archive) from any context (Grid, List, Graph).

## Proposed Solution
Implement a unified **Organism Quick Action Sheet** that acts as the primary entry point for all organism management tasks. This replaces the ambiguous "Edit" button logic with a clear menu of intent-based actions.

### 1. New Component: `OrganismQuickActionSheet`
A bottom sheet (mobile-friendly, works on desktop) that provides:
- **Header**: Organism Summary (Name, ID, Species, Current Status).
- **Actions Grid**:
  - **Edit Name / ID**: Opens `_OrganismEditNameDialog`.
  - **Update Size**: Opens `SizeChangeDialog` (Growth/Shrinkage).
  - **Progress Life Stage**: Opens `LifeStageProgressionDialog` (Development).
  - **Adjust Quantity**: Opens NEW `QuantityChangeDialog` (Gain/Loss/Mortality).
  - **Edit Properties**: Opens the full `OrganismRecordEditDialog` (for advanced/bulk edits if needed, or deprecate/hide it).
  - **Move**: Opens `MoveNodeDialog`.
  - **History**: Opens `EventHistoryScreen`.
  - **Archive**: Opens `_OrganismRemovalDialog` (or equivalent).

### 2. New Component: `QuantityChangeDialog`
A focused dialog specifically for adjusting quantity (Census/Audit/Mortality).
- Wraps `QuantityChangeEditor`.
- Handles Gain (Reproduction, Transfer In) and Loss (Mortality, Outplant, Transfer Out).
- Requires Reason and optionally Comment.
- Updates the record and logs the event consistently.

### 3. Integration Updates
- **`InventoryEditingCoordinator`**: Update `edit()` to launch `OrganismQuickActionSheet` by default for Organisms, instead of just entering "Edit Name" mode.
- **Spreadsheets**: The "Edit" icon will now open the Quick Action Sheet, giving users immediate access to all relevant workflows.
- **Graph Node Info**: The "3-dot" menu can either show the Quick Action Sheet or align its menu items to match the Sheet's options (Quick Action Sheet is preferred for consistency).

## Benefits
- **Intent-Based**: Users choose *what* they want to do (e.g., "Update Size") rather than "Edit Record" and figuring out which field to change.
- **Context-Aware**: The sheet can filter actions based on user permissions or organism state (e.g., disable "Outplant" if not ready).
- **Consistent**: The same menu appears whether you click "Edit" in a list or the "3-dot" menu in a card.
- **Scalable**: Easy to add new actions (e.g., "Add Photo", "Log Health Issue") to the grid without cluttering specific dialogs.
