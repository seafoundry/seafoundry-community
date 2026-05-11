#!/bin/bash
# Push stacked PR branches and create PRs once network is available
# Run this when the port is unblocked

set -e

create_pr() {
  local branch=$1 base=$2 title=$3 body=$4
  echo "Pushing ${branch}..."
  git push origin "${branch}"
  gh pr create --base "${base}" --head "${branch}" --title "${title}" --body "${body}"
}

# Update these branches/titles/bodies as the stack changes
create_pr "pr/1-infrastructure" "main" "fix(firestore): update security rules, indexes, and demo mode" "## Summary
- Updated Firestore security rules for improved access control
- Updated Firestore indexes for query optimization
- Enhanced demo mode service with better state management
- Updated seed scripts for community and pro demos
- Added demo user UID fix scripts

## Test plan
- [ ] Verify Firestore rules work correctly
- [ ] Test demo mode functionality
- [ ] Run seed scripts in emulator"

create_pr "pr/2-model-refactoring" "pr/1-infrastructure" "refactor: update models, monitoring, transfer, and validation" "## Summary
- Refactored monitoring system with improved form handling
- Enhanced transfer service and dialogs
- Deprecated morphology type in favor of physical form
- Updated holdings and inventory models
- Improved fragging bloc and spawning workflow

## Test plan
- [ ] Test monitoring forms
- [ ] Test transfer workflows
- [ ] Verify organism validation
- [ ] Test fragging operations"

create_pr "pr/3-events-navigation" "pr/2-model-refactoring" "refactor: improve event system and navigation" "## Summary
- Enhanced event propagation service
- Updated event models and repositories
- Improved deep linking and navigation handling
- Updated graph node system

## Test plan
- [ ] Test event propagation
- [ ] Test deep link navigation
- [ ] Verify graph node rendering"

create_pr "pr/4-member-services" "pr/3-events-navigation" "feat: improve member management and invitation system" "## Summary
- Enhanced member management dialog
- Added manage members cubit
- Updated invitation system
- Improved singleton lifecycle management
- Updated repositories providers

## Test plan
- [ ] Test member invitations
- [ ] Test member management UI
- [ ] Verify singleton lifecycle"

create_pr "pr/5-auth-functions" "pr/4-member-services" "fix: update authentication and cloud functions" "## Summary
- Updated auth bloc and user management
- Enhanced cloud functions and Sebastian AI
- Improved crash reporting with composite pattern
- Updated CSV import/export services
- Added field work kit and UI components

## Test plan
- [ ] Test authentication flow
- [ ] Test Sebastian AI chat
- [ ] Verify crash reporting
- [ ] Test CSV import/export"

create_pr "pr/6-comments-ui" "pr/5-auth-functions" "feat: add comments feature and UI improvements" "## Summary
- Added chat comments feature
- Added paginated event loader
- Updated CI/CD workflows and quality gates
- Added architecture analysis documentation

## Test plan
- [ ] Test comments functionality
- [ ] Test event loading pagination
- [ ] Verify CI workflows"

create_pr "pr/7-chat-system" "pr/6-comments-ui" "feat: add chat system" "## Summary
- Added chat models and repositories
- Added chat room cubits
- Added chat widgets
- Updated Firestore rules and indexes

## Test plan
- [ ] Test chat room creation
- [ ] Test message sending/receiving
- [ ] Test chat room list"

create_pr "pr/8-admin-sync" "pr/7-chat-system" "feat: add sync conflict resolution and taxonomy admin" "## Summary
- Added sync conflict resolution UI
- Added taxonomy admin tabs (environmental, husbandry, morphology, validation)
- Added audit log and sync conflicts tabs
- Added observation overrides admin
- Updated tier features and feature access service

## Test plan
- [ ] Test sync conflict resolution
- [ ] Test taxonomy admin panels
- [ ] Verify feature gating"

create_pr "pr/9-final-docs" "pr/8-admin-sync" "docs: consolidate references and cleanup" "## Summary
- Consolidated legacy plan/status markdown into WORK_LOG and TODO
- Added Community OSS reference and updated README links
- Tidied deep-link/doc references for chat/comments

## Test plan
- [ ] Smoke check README links
- [ ] Verify WORK_LOG/TODO entries reflect latest work"

echo "=== All PRs pushed and created ==="
echo "Note: These are stacked PRs. Merge in order: PR1 -> PR2 -> ... -> PR9"
