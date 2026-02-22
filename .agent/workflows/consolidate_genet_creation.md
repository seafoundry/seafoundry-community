Feature: Consolidate Genet Creation and Local ID Suggestion

Based on the implemented changes, here is the updated workflow for editing an organism's identity and creating new genets:

1.  **Implicit Genet Creation:**
    *   **Workflow:** When editing an organism record, if you enter a "Clonal ID" or "Accession Number" and *do not* select an existing Genet from the dropdown (or if the lookup finds no match), the system will now automatically create a new `Genet` record upon submission.
    *   **Logic:** The system utilizes `Genet.partial` to create a minimal record with the provided identifiers, the user's ID (`createdById`), and organization context. It links this new genet to the organism record invisibly to the user.
    *   **Benefit:** This removes the need for a separate "Create New Genet" popup or workflow, keeping the user in the context of the editing form.

2.  **Automated Local ID Suggestion:**
    *   **Trigger:** When a user enters a Clonal ID or selects a provenance suggestion that implies a new identity (and no existing Genet is explicitly selected), the system triggers `_triggerLocalIdSuggestion`.
    *   **Action:** This queries the `GenetRepository` for the next available Local ID for the species (e.g., "Acme-005" if "Acme-004" exists).
    *   **UI Update:** The suggested Local ID is auto-filled into the "Local ID" field (unless the user has already manually typed a custom name).
    *   **Benefit:** Reduces data entry errors and ensures sequential ID naming conventions are followed without manual lookup.

3.  **UI Consolidation:**
    *   **Removal:** The "Create new genet" button has been removed from the `LocalIdSelectionDialog`.
    *   **Integration:** All identity creation happens within the main `OrganismRecordEditDialog` or `LocalIdSelectionDialog`'s input fields directly.

4.  **Error Handling & Validation:**
    *   **Validation:** Standard constraints (like unique name checks) still apply.
    *   **Resilience:** If genet creation fails during submission, the user is notified, and changes are not saved to prevent data inconsistency.

**Technical Notes:**
*   `Genet.partial` factory now correctly handles `organizationId` and `createdById`.
*   `provenanceType` access logic updated to use `.name` from the `ProvenanceType` enum.
*   Dependencies (`collection`) added to support list operations (`firstWhereOrNull`).

**Verification Steps:**
1.  Open an existing organism record for editing.
2.  Clear the current Genet selection (if any).
3.  Enter a *new, unique* Clonal ID (e.g., "Test-Strain-X").
4.  Observe the "Local ID" field automatically populating with the next sequence (e.g., "Org-005").
5.  Click "Save".
6.  Verify that a new Genet record "Org-005" (with Clonal ID "Test-Strain-X") was created and linked to the organism.
