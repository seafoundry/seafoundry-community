---
title: Fix OutplantBatchDialog RenderBox Error
status: complete
priority: high
assignee: antigravity
tags: [bugfix, ui, layout, flutter]
---

# Fix OutplantBatchDialog RenderBox Error

## Context
The `OutplantBatchDialog` was crashing with a "Cannot hit test a render box with no size" error. This was traced to the `ListView` displaying organism selections. The dynamic height calculation for the `ConstrainedBox` (`length * 80`) combined with default `ListView` behavior likely caused a layout instability or invalid size (e.g. 0 height in a context where >0 is expected, or infinite loop) during hit testing.

## Root Cause
- **Unstable Layout Constraints**: attempting to manually calculate `maxHeight` based on item count is fragile.
- **RenderBox Size Missing**: The `RenderConstrainedBox` wrapping the list failed to determine its size, typically due to an exception during `performLayout` of its child (`ListView`).

## Resolution
- **Standardized Constraints**: Replaced manual height math with a fixed `BoxConstraints(maxHeight: 300)`.
- **ShrinkWrap**: Enabled `shrinkWrap: true` on `ListView` to ensure it only occupies necessary space within the `ConstrainedBox`.
- **Layout Safety**: This ensures the render object always provides a deterministic size (0 to 300) to its parent, preventing the "size MISSING" error.

## User Question: "Is size related to the organism Record?"
- **Clarification**: The "size" in the crash log ("render box with no size") refers to the **pixel dimensions** (width/height) of the UI widget (RenderBox), NOT a data field (like `sizeSpec` or `sizeClass`) on the `OrganismRecord`.
- **Verification**: Reviewed `OrganismRecord` and `SizeSpec` models. While they contain "size" data, they are not directly involved in the widget's layout logic in a way that would cause this specific crash.

## Status
- [x] Identify crashing widget (Organism List).
- [x] Refactor `_buildOrganismSelection` to use robust `ConstrainedBox` + `shrinkWrap` pattern.
- [x] Verify static analysis passes.
