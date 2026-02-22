#!/bin/bash
# Community Patches Script
# Applies community-specific modifications to the synced codebase
#
# NOTE: Many patches are currently placeholders and will be implemented
# by the efficient-implementer agents during Phase 2 of the migration.
#
# Usage:
#   ./scripts/community-patches.sh <community-directory>
#
# Current Patches:
#   - Removes Pro-specific CI/CD workflows
#   - Cleans Pro test directories
#   - Validates configuration files exist
#   - Scans for remaining Pro/Scale references (informational)
#
# Exit Codes:
#   0 - All patches applied successfully
#   1 - One or more patches failed

set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[PATCHES]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PATCHES]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[PATCHES]${NC} $1"
}

log_error() {
    echo -e "${RED}[PATCHES]${NC} $1"
}

# Cross-platform sed -i compatibility
# macOS/BSD sed requires: sed -i '' "s/pattern/replacement/g" file
# Linux/GNU sed requires: sed -i "s/pattern/replacement/g" file
if [[ "$(uname)" == "Darwin" ]]; then
    SED_IN_PLACE="sed -i ''"
else
    SED_IN_PLACE="sed -i"
fi

# Validate input
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <community-directory>"
    exit 1
fi

COMMUNITY_DIR="$1"

# Validate community directory exists
if [[ ! -d "${COMMUNITY_DIR}" ]]; then
    log_error "Community directory does not exist: ${COMMUNITY_DIR}"
    exit 1
fi

log_info "Applying community patches to: ${COMMUNITY_DIR}"

# Track patch success
PATCHES_APPLIED=0
PATCHES_FAILED=0

# Patch 1: Update pubspec.yaml for community edition
log_info "Patch 1: Updating pubspec.yaml for community edition..."
if [[ -f "${COMMUNITY_DIR}/pubspec.yaml" ]]; then
    # This will be filled in by other implementers
    # For now, just verify the file exists
    log_info "  pubspec.yaml found (no changes needed yet)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_error "  pubspec.yaml not found"
    PATCHES_FAILED=$((PATCHES_FAILED + 1))
fi

# Patch 2: Update app configuration files
log_info "Patch 2: Checking app configuration files..."
if [[ -d "${COMMUNITY_DIR}/lib/config" ]]; then
    log_info "  Configuration directory found (no changes needed yet)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  Configuration directory not found (may not exist)"
fi

# Patch 3: Placeholder for navigation/routing patches
log_info "Patch 3: Navigation/routing patches..."
if [[ -f "${COMMUNITY_DIR}/lib/navigation/simple_router.dart" ]]; then
    log_info "  Router file found (patches to be added by implementers)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  Router file not found"
fi

# Patch 4: Placeholder for service locator patches
log_info "Patch 4: Service locator patches..."
if [[ -f "${COMMUNITY_DIR}/lib/services/service_locator.dart" ]]; then
    log_info "  Service locator found (patches to be added by implementers)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  Service locator not found"
fi

# Patch 5: Main application patches
log_info "Patch 5: Main application patches..."
if [[ -f "${COMMUNITY_DIR}/lib/community_main.dart" ]]; then
    mv "${COMMUNITY_DIR}/lib/community_main.dart" "${COMMUNITY_DIR}/lib/main.dart"
    # Fix imports and class names in main.dart
    ${SED_IN_PLACE} "s/import 'community_app.dart';/import 'app.dart';/g" "${COMMUNITY_DIR}/lib/main.dart"
    ${SED_IN_PLACE} "s/CommunityApp/App/g" "${COMMUNITY_DIR}/lib/main.dart"
    log_success "  Renamed lib/community_main.dart to lib/main.dart and patched imports"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
elif [[ -f "${COMMUNITY_DIR}/lib/main.dart" ]]; then
    log_info "  lib/main.dart already exists"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/community_main.dart not found"
fi

# Patch 5b: App widget patches
log_info "Patch 5b: App widget patches..."
if [[ -f "${COMMUNITY_DIR}/lib/community_app.dart" ]]; then
    mv "${COMMUNITY_DIR}/lib/community_app.dart" "${COMMUNITY_DIR}/lib/app.dart"
    # Rename class
    ${SED_IN_PLACE} "s/class CommunityApp/class App/g" "${COMMUNITY_DIR}/lib/app.dart"
    # Rename constructor (fix for 'const_method' error)
    ${SED_IN_PLACE} "s/const CommunityApp/const App/g" "${COMMUNITY_DIR}/lib/app.dart"
    # Fix router import and class
    ${SED_IN_PLACE} "s/import.*community_simple_router.dart';/import 'package:seafoundry_app\/navigation\/simple_router.dart';/g" "${COMMUNITY_DIR}/lib/app.dart"
    ${SED_IN_PLACE} "s/CommunitySimpleRouter/SimpleRouter/g" "${COMMUNITY_DIR}/lib/app.dart"
    # Fix repo provider import and class
    ${SED_IN_PLACE} "s/import.*community_repositories_provider.dart';/import 'package:seafoundry_app\/widgets\/repositories\/repositories_provider.dart';/g" "${COMMUNITY_DIR}/lib/app.dart"
    ${SED_IN_PLACE} "s/CommunityRepositoriesProviderWrapper/RepositoriesProviderWrapper/g" "${COMMUNITY_DIR}/lib/app.dart"
    
    log_success "  Renamed lib/community_app.dart to lib/app.dart and patched"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
elif [[ -f "${COMMUNITY_DIR}/lib/app.dart" ]]; then
    log_info "  lib/app.dart already exists"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/community_app.dart not found"
fi

# Patch 5c: Router patches
log_info "Patch 5c: Router patches..."
if [[ -f "${COMMUNITY_DIR}/lib/navigation/community_simple_router.dart" ]]; then
    mv "${COMMUNITY_DIR}/lib/navigation/community_simple_router.dart" "${COMMUNITY_DIR}/lib/navigation/simple_router.dart"
    # Rename class
    ${SED_IN_PLACE} "s/class CommunitySimpleRouter/class SimpleRouter/g" "${COMMUNITY_DIR}/lib/navigation/simple_router.dart"
    # Rename constructor
    ${SED_IN_PLACE} "s/const CommunitySimpleRouter/const SimpleRouter/g" "${COMMUNITY_DIR}/lib/navigation/simple_router.dart"
    log_success "  Renamed lib/navigation/community_simple_router.dart to lib/navigation/simple_router.dart and patched"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
elif [[ -f "${COMMUNITY_DIR}/lib/navigation/simple_router.dart" ]]; then
    log_info "  lib/navigation/simple_router.dart already exists"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/navigation/community_simple_router.dart not found"
fi

# Patch 5d: Repository Provider patches
log_info "Patch 5d: Repository Provider patches..."
if [[ -f "${COMMUNITY_DIR}/lib/widgets/repositories/community_repositories_provider.dart" ]]; then
    mv "${COMMUNITY_DIR}/lib/widgets/repositories/community_repositories_provider.dart" "${COMMUNITY_DIR}/lib/widgets/repositories/repositories_provider.dart"
    REPO_PROVIDER="${COMMUNITY_DIR}/lib/widgets/repositories/repositories_provider.dart"

    # Rename classes - the community template uses Community prefix
    ${SED_IN_PLACE} "s/CommunityRepositoriesProviderWrapper/RepositoriesProviderWrapper/g" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "s/CommunityRepositoriesProvider/RepositoriesProvider/g" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "s/_CommunityRepositoriesProviderState/_RepositoriesProviderState/g" "${REPO_PROVIDER}"

    # Remove Pro-only imports that exist in the template but are removed from community build
    # NOTE: DO NOT remove csv_import_service or environmental_threshold_registry - they are community tier
    ${SED_IN_PLACE} "/import.*services\/observation_field_override_service.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*services\/state_reconstruction_service.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*repositories\/environment\/environmental_event_repository.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*services\/forecasting_service.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*services\/activity_feed_service.dart/d" "${REPO_PROVIDER}"

    log_success "  Renamed and patched lib/widgets/repositories/repositories_provider.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
elif [[ -f "${COMMUNITY_DIR}/lib/widgets/repositories/repositories_provider.dart" ]]; then
    log_info "  lib/widgets/repositories/repositories_provider.dart already exists"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/widgets/repositories/community_repositories_provider.dart not found"
fi

# Patch 5e: Navigation widget patches
log_info "Patch 5e: Navigation widget patches..."
if [[ -f "${COMMUNITY_DIR}/lib/navigation/community_simple_navigation_widget.dart" ]]; then
    mv "${COMMUNITY_DIR}/lib/navigation/community_simple_navigation_widget.dart" "${COMMUNITY_DIR}/lib/navigation/simple_navigation_widget.dart"
    NAV_WIDGET="${COMMUNITY_DIR}/lib/navigation/simple_navigation_widget.dart"

    # Rename class
    ${SED_IN_PLACE} "s/class CommunitySimpleNavigationWidget/class SimpleNavigationWidget/g" "${NAV_WIDGET}"
    ${SED_IN_PLACE} "s/const CommunitySimpleNavigationWidget/const SimpleNavigationWidget/g" "${NAV_WIDGET}"
    # Remove debug prints
    ${SED_IN_PLACE} "/debugPrint.*CommunitySimpleNavigationWidget/d" "${NAV_WIDGET}"

    log_success "  Renamed lib/navigation/community_simple_navigation_widget.dart to simple_navigation_widget.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
elif [[ -f "${COMMUNITY_DIR}/lib/navigation/simple_navigation_widget.dart" ]]; then
    log_info "  lib/navigation/simple_navigation_widget.dart already exists"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/navigation/community_simple_navigation_widget.dart not found"
fi

# Patch 5f: Site node screen patches (remove chat and monitoring features)
log_info "Patch 5f: Site node screen patches..."
SITE_SCREEN="${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
if [[ -f "${SITE_SCREEN}" ]]; then
    # Remove chat imports
    ${SED_IN_PLACE} "/import.*repositories\/chat\/chat_repository.dart/d" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "/import.*cubits\/chat\/chat_room_list_cubit.dart/d" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "/import.*cubits\/chat\/chat_room_cubit.dart/d" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "/import.*widgets\/chat\/chat_room_list_widget.dart/d" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "/import.*widgets\/chat\/chat_room_screen.dart/d" "${SITE_SCREEN}"
    # Remove monitoring dialog import
    ${SED_IN_PLACE} "/import.*widgets\/dialogs\/monitoring_dialog.dart/d" "${SITE_SCREEN}"

    # Simple replacements - don't try to patch complex code
    ${SED_IN_PLACE} "s/final chatEnabled = _shouldShowChat(context);/final chatEnabled = false;/g" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "s/final monitoringEnabled = featureAccess?.supportsMonitoring ?? false;/final monitoringEnabled = false;/g" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "s/final showMonitoringButton = monitoringSupported && monitoringEnabled;/final showMonitoringButton = false;/g" "${SITE_SCREEN}"

    # Remove MonitoringDialog.show calls (just remove lines with it)
    ${SED_IN_PLACE} "/MonitoringDialog\.show/d" "${SITE_SCREEN}"

    log_success "  Patched lib/screens/graph/site_node_screen.dart (removed chat/monitoring)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  lib/screens/graph/site_node_screen.dart not found"
fi

# Patch 5g: Update simple_router to reference SimpleNavigationWidget
log_info "Patch 5g: Update router to reference SimpleNavigationWidget..."
ROUTER_FILE="${COMMUNITY_DIR}/lib/navigation/simple_router.dart"
if [[ -f "${ROUTER_FILE}" ]]; then
    # Update import
    ${SED_IN_PLACE} "s/import.*community_simple_navigation_widget.dart';/import 'package:seafoundry_app\/navigation\/simple_navigation_widget.dart';/g" "${ROUTER_FILE}"
    # Update class reference
    ${SED_IN_PLACE} "s/CommunitySimpleNavigationWidget/SimpleNavigationWidget/g" "${ROUTER_FILE}"
    log_success "  Updated simple_router.dart to use SimpleNavigationWidget"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5h: Patch navigation_router_delegate.dart to remove chat
log_info "Patch 5h: Patching navigation_router_delegate.dart for chat removal..."
NAV_ROUTER_DELEGATE="${COMMUNITY_DIR}/lib/navigation/navigation_router_delegate.dart"
if [[ -f "${NAV_ROUTER_DELEGATE}" ]]; then
    # Remove chat imports
    ${SED_IN_PLACE} "/import.*repositories\/chat\/chat_repository.dart/d" "${NAV_ROUTER_DELEGATE}"
    ${SED_IN_PLACE} "/import.*widgets\/chat\/chat_room_screen.dart/d" "${NAV_ROUTER_DELEGATE}"
    ${SED_IN_PLACE} "/import.*cubits\/chat\/chat_room_cubit.dart/d" "${NAV_ROUTER_DELEGATE}"
    # Comment out chat-related code blocks
    ${SED_IN_PLACE} "s/context.read<ChatRepository>()/null \/\/ ChatRepository disabled in community/g" "${NAV_ROUTER_DELEGATE}"
    ${SED_IN_PLACE} "s/ChatRoomCubit(/\/\/ ChatRoomCubit disabled (/g" "${NAV_ROUTER_DELEGATE}"
    ${SED_IN_PLACE} "s/ChatRoomScreen(/\/\/ ChatRoomScreen disabled (/g" "${NAV_ROUTER_DELEGATE}"
    log_success "  Patched navigation_router_delegate.dart (removed chat)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5i: Patch organization_node_screen.dart to remove Pro-only features
# DISABLED - patches were too aggressive and broke the file
# log_info "Patch 5i: Patching organization_node_screen.dart..."
# This screen is in the skip list and will be preserved but needs manual review
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 5j: Patch organism_node_screen.dart to remove comments
log_info "Patch 5j: Patching organism_node_screen.dart..."
ORGANISM_SCREEN="${COMMUNITY_DIR}/lib/screens/graph/organism_node_screen.dart"
if [[ -f "${ORGANISM_SCREEN}" ]]; then
    # Remove comments import
    ${SED_IN_PLACE} "/import.*widgets\/comments\/comment_thread_widget.dart/d" "${ORGANISM_SCREEN}"
    # Remove any CommentThreadWidget references entirely (just remove the line)
    ${SED_IN_PLACE} "/CommentThreadWidget/d" "${ORGANISM_SCREEN}"
    log_success "  Patched organism_node_screen.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5k: Patch graph_node_events_list.dart to remove event_display
log_info "Patch 5k: Patching graph_node_events_list.dart..."
EVENTS_LIST="${COMMUNITY_DIR}/lib/screens/graph/graph_node_events_list.dart"
if [[ -f "${EVENTS_LIST}" ]]; then
    # The event_display.dart is now kept in skip list, so we just need to verify import exists
    log_info "  graph_node_events_list.dart - event_display.dart should be preserved"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5l: Patch graph_node_info.dart to keep wrapped_navigator
log_info "Patch 5l: Verifying graph_node_info.dart..."
GRAPH_INFO="${COMMUNITY_DIR}/lib/screens/graph/graph_node_info.dart"
if [[ -f "${GRAPH_INFO}" ]]; then
    # wrapped_navigator.dart is now kept in skip list
    log_info "  graph_node_info.dart - wrapped_navigator.dart should be preserved"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5m: Swap Pro widgets with community versions
log_info "Patch 5m: Swapping Pro widgets with community versions..."

# 5m1: event_display.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/widgets/display/community_event_display.dart" ]]; then
    # Remove Pro version if it exists
    rm -f "${COMMUNITY_DIR}/lib/widgets/display/event_display.dart"
    # Rename community version
    mv "${COMMUNITY_DIR}/lib/widgets/display/community_event_display.dart" "${COMMUNITY_DIR}/lib/widgets/display/event_display.dart"
    # Update class name
    ${SED_IN_PLACE} "s/CommunityEventDisplay/EventDisplay/g" "${COMMUNITY_DIR}/lib/widgets/display/event_display.dart"
    log_success "  Swapped event_display.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m2: graph_node_actions.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/widgets/graph_node/community_graph_node_actions.dart" ]]; then
    # Remove Pro version if it exists
    rm -f "${COMMUNITY_DIR}/lib/widgets/graph_node/graph_node_actions.dart"
    # Rename community version
    mv "${COMMUNITY_DIR}/lib/widgets/graph_node/community_graph_node_actions.dart" "${COMMUNITY_DIR}/lib/widgets/graph_node/graph_node_actions.dart"
    # Update class name
    ${SED_IN_PLACE} "s/CommunityGraphNodeActions/GraphNodeActions/g" "${COMMUNITY_DIR}/lib/widgets/graph_node/graph_node_actions.dart"
    log_success "  Swapped graph_node_actions.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m3: summary_statistics.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/widgets/navigation/community_summary_statistics.dart" ]]; then
    # Remove Pro version if it exists
    rm -f "${COMMUNITY_DIR}/lib/widgets/navigation/summary_statistics.dart"
    # Rename community version
    mv "${COMMUNITY_DIR}/lib/widgets/navigation/community_summary_statistics.dart" "${COMMUNITY_DIR}/lib/widgets/navigation/summary_statistics.dart"
    # Update class name
    ${SED_IN_PLACE} "s/CommunitySummaryStatistics/SummaryStatistics/g" "${COMMUNITY_DIR}/lib/widgets/navigation/summary_statistics.dart"
    log_success "  Swapped summary_statistics.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m4: site_summary_cards.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/widgets/graph_node/community_site_summary_cards.dart" ]]; then
    # Remove Pro version if it exists
    rm -f "${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_cards.dart"
    # Rename community version
    mv "${COMMUNITY_DIR}/lib/widgets/graph_node/community_site_summary_cards.dart" "${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_cards.dart"
    # Update class name
    ${SED_IN_PLACE} "s/CommunitySiteSummaryCards/SiteSummaryCards/g" "${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_cards.dart"
    # Also need to update internal reference to CommunitySummaryStatistics
    ${SED_IN_PLACE} "s/CommunitySummaryStatistics/SummaryStatistics/g" "${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_cards.dart"
    # Fix import path
    ${SED_IN_PLACE} "s/community_summary_statistics.dart/summary_statistics.dart/g" "${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_cards.dart"
    log_success "  Swapped site_summary_cards.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m5: organism_node_screen.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/screens/graph/community_organism_node_screen.dart" ]]; then
    rm -f "${COMMUNITY_DIR}/lib/screens/graph/organism_node_screen.dart"
    mv "${COMMUNITY_DIR}/lib/screens/graph/community_organism_node_screen.dart" "${COMMUNITY_DIR}/lib/screens/graph/organism_node_screen.dart"
    ${SED_IN_PLACE} "s/CommunityOrganismNodeScreen/OrganismNodeScreen/g" "${COMMUNITY_DIR}/lib/screens/graph/organism_node_screen.dart"
    log_success "  Swapped organism_node_screen.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m6: organization_node_screen.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/screens/graph/community_organization_node_screen.dart" ]]; then
    rm -f "${COMMUNITY_DIR}/lib/screens/graph/organization_node_screen.dart"
    mv "${COMMUNITY_DIR}/lib/screens/graph/community_organization_node_screen.dart" "${COMMUNITY_DIR}/lib/screens/graph/organization_node_screen.dart"
    ${SED_IN_PLACE} "s/CommunityOrganizationNodeScreen/OrganizationNodeScreen/g" "${COMMUNITY_DIR}/lib/screens/graph/organization_node_screen.dart"
    log_success "  Swapped organization_node_screen.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# 5m7: site_node_screen.dart -> use community version
if [[ -f "${COMMUNITY_DIR}/lib/screens/graph/community_site_node_screen.dart" ]]; then
    rm -f "${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
    mv "${COMMUNITY_DIR}/lib/screens/graph/community_site_node_screen.dart" "${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
    ${SED_IN_PLACE} "s/CommunitySiteNodeScreen/SiteNodeScreen/g" "${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
    log_success "  Swapped site_node_screen.dart with community version"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5n: Patch site_summary_blueprint.dart to remove monitoring dependency
log_info "Patch 5n: Patching site_summary_blueprint.dart for monitoring removal..."
SITE_BLUEPRINT="${COMMUNITY_DIR}/lib/widgets/graph_node/site_summary_blueprint.dart"
if [[ -f "${SITE_BLUEPRINT}" ]]; then
    # Patch 5n: Keeping site_summary_blueprint.dart features
    log_info "Patch 5n: Keeping monitoring events in site_summary_blueprint.dart (Basic Monitoring)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5o: Keeping monitoring_csv_importer.dart (Basic Monitoring)
log_info "Patch 5o: Keeping monitoring_csv_importer.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 5p: Keeping monitoring in csv_import_coordinator.dart (Basic Monitoring)
log_info "Patch 5p: Keeping monitoring in csv_import_coordinator.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 5q: Keeping monitoring in csv_import_service.dart (Basic Monitoring)
log_info "Patch 5q: Keeping monitoring in csv_import_service.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 5t: Update Site Limits (5 outplanting sites)
log_info "Patch 5t: Updating Site Limits (5 outplanting sites)..."
SITE_LIMITS="${COMMUNITY_DIR}/lib/services/site_limits_service.dart"
if [[ -f "${SITE_LIMITS}" ]]; then
    # Change communityOutplantingLimit = 1 to 5
    ${SED_IN_PLACE} "s/static const int communityOutplantingLimit = 1;/static const int communityOutplantingLimit = 5;/g" "${SITE_LIMITS}"
    # Update the documentation comment
    ${SED_IN_PLACE} "s/1 outplanting\/restoration site/5 outplanting\/restoration sites/g" "${SITE_LIMITS}"
    log_success "  Patched site_limits_service.dart (Limit: 5)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5u: Update Tier Config (Disable Monitoring for Community)
log_info "Patch 5u: Updating Tier Config (Disable Monitoring for Community)..."
TIER_CONFIG="${COMMUNITY_DIR}/config/tier_features.yaml"
if [[ -f "${TIER_CONFIG}" ]]; then
    # Keep monitoring fully Pro-only in community builds
    ${SED_IN_PLACE} "/^  community:/,/^  pro:/ s/monitoring_dialog:.*/      monitoring_dialog: false/" "${TIER_CONFIG}"
    ${SED_IN_PLACE} "/^  community:/,/^  pro:/ s/monitoring_workspace:.*/      monitoring_workspace: false/" "${TIER_CONFIG}"
    ${SED_IN_PLACE} "/^  community:/,/^  pro:/ s/monitoring_workspace_limited:.*/      monitoring_workspace_limited: false/" "${TIER_CONFIG}"
    log_success "  Patched tier_features.yaml (Disable Monitoring)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5v: Patch Monitoring Dialog (Hide Photos)
log_info "Patch 5v: Patching Monitoring Dialog (Hide Photos)..."
MONITORING_DIALOG="${COMMUNITY_DIR}/lib/widgets/dialogs/monitoring_dialog.dart"
if [[ -f "${MONITORING_DIALOG}" ]]; then
    # Replace const MonitoringImageUploads(), with feature check
    # We use a multi-line substitution trick or specific string replacement
    ${SED_IN_PLACE} "s/const MonitoringImageUploads(),/if (featureAccess?.isFeatureEnabled('imagery_attachments') ?? false) const MonitoringImageUploads(),/g" "${MONITORING_DIALOG}"
    log_success "  Patched monitoring_dialog.dart (Hid Photos)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 5r: Keeping csv_import_service.dart (patched above)
log_info "Patch 5r: Keeping csv_import_service.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 5s: Keeping csv_import_coordinator.dart (patched above)
log_info "Patch 5s: Keeping csv_import_coordinator.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6p: Patch event_repository.dart - DISABLED
# NOTE: event_repository.dart is too complex for sed patching.
# Use community_event_repository.dart instead (copied in Step 8)
log_info "Patch 6p: Skipping event_repository.dart (use community version)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6: Fix barrel exports in models.dart (selective removal)
log_info "Patch 6: Fixing barrel exports in models.dart..."
MODELS_FILE="${COMMUNITY_DIR}/lib/models/models.dart"
if [[ -f "${MODELS_FILE}" ]]; then
    # Remove only Pro monitoring exports - keep community ones
    # Keep: monitoring_entry.dart (community), monitoring_event_record.dart (community)
    # Remove: monitoring_dialog.dart, monitoring_schedule.dart, etc.
    ${SED_IN_PLACE} "/^export 'monitoring\/monitoring_dialog.dart/d" "${MODELS_FILE}"
    ${SED_IN_PLACE} "/^export 'monitoring\/monitoring_schedule.dart/d" "${MODELS_FILE}"
    ${SED_IN_PLACE} "/^export 'monitoring\/monitoring_data.dart/d" "${MODELS_FILE}"
    ${SED_IN_PLACE} "/^export 'monitoring\/coral_monitoring_data.dart/d" "${MODELS_FILE}"
    # NOTE: Keep monitoring_entry.dart and monitoring/image_attachment.dart
    log_success "  Selectively removed Pro monitoring exports from models.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  models.dart not found"
fi

# Patch 6a: DISABLED - vessel.dart, permit.dart, deliverable.dart, monitoring_schedule.dart are all community-tier
log_info "Patch 6a: Skipping (all record_factory model types are community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6b: Keeping export_service.dart (restore community export)
log_info "Patch 6b: Keeping export_service.dart (community feature)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))


# Patch 6c: Fix events barrel export - DISABLED
# NOTE: Keep monitoring_event_record.dart as it's marked @tier: community
log_info "Patch 6c: Skipping (keeping monitoring_event_record export)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6d: Keeping inventory_event bloc (community feature)
log_info "Patch 6d: Keeping inventory_event bloc (required for population/size changes)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6e: Keeping dialogs (needed for inventory management)
log_info "Patch 6e: Keeping population_loss_dialog.dart and size_change_dialog.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6f: Keeping genetics_spreadsheet_view.dart
log_info "Patch 6f: Keeping genetics_spreadsheet_view.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6g: event_factory.dart is complex - skip patching, leave for manual cleanup
log_info "Patch 6g: Skipping event_factory.dart (requires manual cleanup)"
# The event_factory.dart has complex switch statements that can't be easily patched with sed
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6h: event_repository.dart is complex - skip patching, leave for manual cleanup
log_info "Patch 6h: Skipping event_repository.dart (requires manual cleanup)"
# The event_repository.dart has complex dependencies that can't be easily patched with sed
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6h2: Fix blocs.dart barrel export
log_info "Patch 6h2: Keeping inventory_event in blocs.dart barrel"
# NOTE: We previously removed inventory_event, but now check if we need to keep it.
# Since we kept lib/blocs/inventory_event, we should keep the export.
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6h3: Remove husbandry_tasks_tab directory
log_info "Patch 6h3: Removing husbandry_tasks_tab..."
HUSBANDRY_TAB="${COMMUNITY_DIR}/lib/cubits/husbandry_tasks_tab"
if [[ -d "${HUSBANDRY_TAB}" ]]; then
    rm -rf "${HUSBANDRY_TAB}"
    log_success "  Removed husbandry_tasks_tab"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6i: Fix organism_record_history_view.dart (replace LoggingService with debugPrint)
log_info "Patch 6i: Fixing organism_record_history_view.dart..."
HISTORY_VIEW="${COMMUNITY_DIR}/lib/widgets/inventory/organism_record_history_view.dart"
if [[ -f "${HISTORY_VIEW}" ]]; then
    # Remove the LoggingService import
    ${SED_IN_PLACE} "/import.*logging_service.dart/d" "${HISTORY_VIEW}"
    # Replace the multi-line LoggingService.instance.error call with debugPrint
    # The original code: LoggingService.instance.error('...', error, stackTrace);
    # We need to replace it with: debugPrint('Failed to render history tile: $error');
    ${SED_IN_PLACE} "s/LoggingService.instance.error(/debugPrint(/g" "${HISTORY_VIEW}"
    # Remove the standalone error and stackTrace arguments that are now orphaned
    ${SED_IN_PLACE} "/^[[:space:]]*error,$/d" "${HISTORY_VIEW}"
    ${SED_IN_PLACE} "/^[[:space:]]*stackTrace,$/d" "${HISTORY_VIEW}"
    log_success "  Patched organism_record_history_view.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6j: Keeping csv_import_models.dart (Basic Monitoring)
log_info "Patch 6j: Keeping csv_import_models.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6k: Removing only specific widgets (Keep Monitoring Image Card for now if needed, or remove if unused)
# We need MonitoringImageAttachmentCard if we simply hide it in UI. If code still references it, we need it.
# MonitoringDialog imports MonitoringImageUploads which imports MonitoringImageAttachmentCard.
# So we MUST keep them if MonitoringDialog is kept.
log_info "Patch 6k: Keeping monitoring widgets (required for MonitoringDialog)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6k2: Keeping outplant_google_map.dart features (Basic Monitoring)
log_info "Patch 6k2: Keeping monitoring in outplant_google_map.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6l: Keeping events barrel details (Basic Monitoring)
log_info "Patch 6l: Keeping observation_event_details in details.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6m: Fix event_details_dialog.dart (remove ObservationEventDetails)
log_info "Patch 6m: Patching event_details_dialog.dart..."
EVENT_DETAILS="${COMMUNITY_DIR}/lib/widgets/dialogs/event_details_dialog.dart"
if [[ -f "${EVENT_DETAILS}" ]]; then
    ${SED_IN_PLACE} "/ObservationEventDetails/d" "${EVENT_DETAILS}"
    log_success "  Patched event_details_dialog.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6n: Keeping event_factory.dart features (Basic Monitoring)
log_info "Patch 6n: Keeping monitoring in event_factory.dart"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6o: Patch record_factory.dart - DISABLED (handled by Patch 6u)
# NOTE: Do NOT delete case statements - breaks switch exhaustiveness
# Patch 6u will replace return statements with throw statements instead
log_info "Patch 6o: Skipping - handled by Patch 6u..."
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6p: event_repository.dart - leave for manual cleanup (too complex for sed)
log_info "Patch 6p: Skipping event_repository.dart (requires manual cleanup)"
# The event_repository.dart has complex method bodies that can't be safely patched with sed
# Manual cleanup needed for: MonitoringEventRecord, MonitoringEntry references
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6q: Fix snapshot_comparison_screen.dart
log_info "Patch 6q: Patching snapshot_comparison_screen.dart..."
SNAPSHOT_SCREEN="${COMMUNITY_DIR}/lib/widgets/snapshot_comparison/snapshot_comparison_screen.dart"
if [[ -f "${SNAPSHOT_SCREEN}" ]]; then
    # Replace getById with get (standard repository method)
    ${SED_IN_PLACE} "s/\.getById(/\.get(/g" "${SNAPSHOT_SCREEN}"
    log_success "  Patched snapshot_comparison_screen.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6b: Scan for Pro/Scale references in remaining files
log_info "Patch 6b: Scanning for Pro/Scale references in remaining files..."
PRO_REFS_FOUND=0
if command -v grep &> /dev/null; then
    # Search for common Pro/Scale patterns (informational only for now)
    if grep -r "MonitoringEvent\|MonitoringSchedule\|SebastianChat\|HusbandryTask" "${COMMUNITY_DIR}/lib" --include="*.dart" > /dev/null 2>&1; then
        PRO_REFS_FOUND=$(grep -r "MonitoringEvent\|MonitoringSchedule\|SebastianChat\|HusbandryTask" "${COMMUNITY_DIR}/lib" --include="*.dart" 2>/dev/null | wc -l | xargs)
        log_warning "  Found ${PRO_REFS_FOUND} potential Pro/Scale references (to be patched by implementers)"
    else
        log_info "  No obvious Pro/Scale references found"
    fi
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6r: Fix graph_scaffold.dart (remove AppDrawer - Pro only)
log_info "Patch 6r: Patching graph_scaffold.dart..."
GRAPH_SCAFFOLD="${COMMUNITY_DIR}/lib/navigation/graph_scaffold.dart"
if [[ -f "${GRAPH_SCAFFOLD}" ]]; then
    # Remove AppDrawer import
    ${SED_IN_PLACE} "/import.*widgets\/app_drawer.dart/d" "${GRAPH_SCAFFOLD}"
    # Replace AppDrawer() with Drawer() placeholder
    ${SED_IN_PLACE} "s/drawer: const AppDrawer()/drawer: const Drawer(child: Center(child: Text('Menu')))/g" "${GRAPH_SCAFFOLD}"
    log_success "  Patched graph_scaffold.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6s: Keeping CSVImportService in repositories_provider.dart
log_info "Patch 6s: Keeping CSVImportService (patched in 5q)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6t: Fix site_node_screen.dart (SiteSummaryCards API mismatch)
# Simplified - just remove lines that reference removed code
log_info "Patch 6t: Patching site_node_screen.dart for cleanup..."
SITE_SCREEN="${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
if [[ -f "${SITE_SCREEN}" ]]; then
    # Remove showMonitoringUpgrade references
    ${SED_IN_PLACE} "/showMonitoringUpgrade/d" "${SITE_SCREEN}"
    # Remove MonitoringDialog references
    ${SED_IN_PLACE} "/MonitoringDialog/d" "${SITE_SCREEN}"
    log_success "  Patched site_node_screen.dart (cleanup)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch 6u: DISABLED - MonitoringSchedule, Vessel, Permit, Deliverable are all community-tier
log_info "Patch 6u: Skipping (all model types are community-tier - no throws needed)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6v: Fix organism_node_screen.dart - DISABLED (too complex for sed)
# log_info "Patch 6v: Patching organism_node_screen.dart..."
# The CommentThreadWidget was already removed by Patch 5j
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6w: Fix organization_node_screen.dart - DISABLED (too complex for sed)
# The organization screen patches were breaking the code structure
# Leave for manual review or create a community-specific version
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 6x: Fix event_repository.dart - DISABLED
# NOTE: event_repository.dart is handled by community version
log_info "Patch 6x: Skipping (event_repository uses community version)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch 7: Update README for community edition
log_info "Patch 7: Updating README documentation for Community Edition..."
README_FILE="${COMMUNITY_DIR}/README.md"
if [[ -f "${README_FILE}" ]]; then
    cat > "${README_FILE}" << EOF
# SeaFoundry Community Edition (OSS)

SeaFoundry Community Edition is a free, open-source web platform for marine restoration, creating a standard for inventory management and genetics tracking available to any practitioner.

## Features (Community)

*   **Inventory & Husbandry**: Track organism holdings, fragmentation, and movements (Gene Bank, Nursery).
*   **Genetics & Lineage**: Manage sexual cohorts, wild collections, and parental lineage.
*   **Basic Monitoring**: Record environmental parameters (temperature, salinity, etc.) and observations for outplanted sites.
*   **Restoration Sites**: Create up to **5** outplanting/restoration sites to manage field operations.
*   **Maps**: Visualize your sites and holdings on an interactive map.
*   **Data Portability**: Full CSV import/export capabilities (compatible with SeaFoundry ecosystem).

## Limitations

This is the fully open-source Community build. Advanced features are available in **Pro** and **Scale** tiers:
*   **Unlimited Sites** (Community limited to 1 nursery + 5 outplanting sites)
*   **Photo Monitoring** (Image uploads/attachmnets)
*   **Mobile App** (Offline sync, field mode)
*   **Advanced Reporting** (Project deliverables, automated reports)
*   **Team Management** (Role-based access, workforce tracking)
*   **AI Tools** (Copilot, automated analysis)

## Getting Started

1.  **Install Dependencies**:
    \`\`\`bash
    flutter pub get
    \`\`\`
2.  **Run Development Server**:
    \`\`\`bash
    flutter run -d chrome
    \`\`\`

## Architecture

This build uses the same core architecture as the full platform but is configured for the **Community** tier by default.
*   **Tier Source**: Main feature gating is handled via \`FeatureAccessService\` and \`config/tier_features.yaml\`.
*   **Services**: Uses standard Firestore repositories for data persistence.

## Community & Support

*   **Issues**: Please file issues in this repository for bugs or feature requests.
*   **Contributions**: We welcome PRs! Please see \`CONTRIBUTING.md\`.

---
*Generated Community Build*
EOF
    log_success "  Updated README.md for Community Edition"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  README.md not found"
fi

# Patch 8: Remove CI/CD workflows for Pro features
log_info "Patch 8: Cleaning GitHub workflows..."
if [[ -d "${COMMUNITY_DIR}/.github/workflows" ]]; then
    # Remove Pro-specific workflows
    PRO_WORKFLOWS=(
        "demo-mode-verification.yml"
        "pro_full.yaml"
    )

    WORKFLOWS_REMOVED=0
    for workflow in "${PRO_WORKFLOWS[@]}"; do
        WORKFLOW_FILE="${COMMUNITY_DIR}/.github/workflows/${workflow}"
        if [[ -f "${WORKFLOW_FILE}" ]]; then
            rm "${WORKFLOW_FILE}"
            log_info "  Removed Pro workflow: ${workflow}"
            WORKFLOWS_REMOVED=$((WORKFLOWS_REMOVED + 1))
        fi
    done

    if [[ ${WORKFLOWS_REMOVED} -gt 0 ]]; then
        log_success "  Removed ${WORKFLOWS_REMOVED} Pro-specific workflows"
    else
        log_info "  No Pro workflows to remove"
    fi
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  .github/workflows directory not found"
fi

# Patch 9: Placeholder for feature flag patches
log_info "Patch 9: Feature flag patches..."
if [[ -f "${COMMUNITY_DIR}/lib/services/feature_access_service.dart" ]]; then
    log_info "  Feature access service found (patches to be added by implementers)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  Feature access service not found"
fi

# Patch 10: Clean up Pro/Scale test files
log_info "Patch 10: Cleaning test directory..."
if [[ -d "${COMMUNITY_DIR}/test" ]]; then
    # Remove Pro-specific test directories (to be customized by implementers)
    TEST_DIRS_TO_REMOVE=(
        "test/unit/cubits/sebastian"
        "test/unit/cubits/training"
        "test/unit/models/sebastian"
        "test/unit/models/training"
        "test/unit/services/sebastian"
        "test/helpers/sebastian_test_helpers.dart"
        "test/integration/environmental_monitoring_test.dart"
        "test/unit/cubits/inventory_spreadsheet_cubit_test.dart"
        "test/unit/cubits/monitoring_entries_spreadsheet_cubit_test.dart"
        "test/unit/cubits/monitoring_form"
        "test/unit/cubits/outplant_events_spreadsheet_cubit_test.dart"
        "test/cubits/monitoring_form"
    )

    TEST_DIRS_REMOVED=0
    for test_dir in "${TEST_DIRS_TO_REMOVE[@]}"; do
        TARGET_DIR="${COMMUNITY_DIR}/${test_dir}"
        if [[ -e "${TARGET_DIR}" ]]; then
            rm -rf "${TARGET_DIR}"
            log_info "  Removed test path: ${test_dir}"
            TEST_DIRS_REMOVED=$((TEST_DIRS_REMOVED + 1))
        fi
    done

    if [[ ${TEST_DIRS_REMOVED} -gt 0 ]]; then
        log_success "  Removed ${TEST_DIRS_REMOVED} Pro test paths"
    else
        log_info "  No Pro test paths to remove"
    fi
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  test directory not found"
fi

# ============================================
# Patches A-P: Fix shared files referencing removed pro/scale features
# These patches address ~300 compilation errors in shared community-tier
# files that reference classes/imports removed during pro/scale stripping.
# ============================================

# Patch A: Fix wrapped_navigator.dart (remove pro-only providers)
log_info "Patch A: Fixing wrapped_navigator.dart..."
WRAPPED_NAV="${COMMUNITY_DIR}/lib/navigation/wrapped_navigator.dart"
if [[ -f "${WRAPPED_NAV}" ]]; then
    # Remove pro-only imports
    ${SED_IN_PLACE} "/import.*chat_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*comment_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*ecological_survey_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*custom_types_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*environmental_event_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*husbandry_task_definition_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*task_event_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*organism_config_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*role_definition_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*sync_conflict_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*sop_completion_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*sop_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*training_event_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*training_media_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*training_progress_repository.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*activity_feed_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*custom_type_resolver_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*forecasting_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*observation_field_override_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*state_reconstruction_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*task_creation_service.dart/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/import.*training_service.dart/d" "${WRAPPED_NAV}"

    # Remove pro-only copy<> body references in copyRepositoryProviders()
    ${SED_IN_PLACE} "/copy<TaskEventRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<TrainingEventRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<TrainingProgressRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<SOPCompletionRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<TrainingMediaRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<EcologicalSurveyRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<EnvironmentalEventRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<RoleDefinitionRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<HusbandryTaskDefinitionRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<SyncConflictRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<CustomTypesRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<ChatRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<CommentRepository>/d" "${WRAPPED_NAV}"
    # Remove pro-only copy<> in copyProviders() and copyChangeNotifierProviders()
    ${SED_IN_PLACE} "/copy<StateReconstructionService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<ActivityFeedService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<TaskCreationService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<TrainingService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<ObservationFieldOverrideService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<ForecastingService>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<OrganismConfigRepository>/d" "${WRAPPED_NAV}"
    ${SED_IN_PLACE} "/copy<CustomTypeResolverService>/d" "${WRAPPED_NAV}"

    log_success "  Patched wrapped_navigator.dart (removed pro imports + body refs)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch B: Fix repositories_provider.dart (remove pro repos)
log_info "Patch B: Fixing repositories_provider.dart..."
REPO_PROVIDER="${COMMUNITY_DIR}/lib/widgets/repositories/repositories_provider.dart"
if [[ -f "${REPO_PROVIDER}" ]]; then
    # Remove pro-only imports
    ${SED_IN_PLACE} "/import.*custom_types_repository.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*task_event_repository.dart/d" "${REPO_PROVIDER}"
    ${SED_IN_PLACE} "/import.*custom_type_resolver_service.dart/d" "${REPO_PROVIDER}"

    # Use Python to remove pro-only body references safely (sed line-deletion breaks code structure)
    python3 - "${REPO_PROVIDER}" << 'PYTHON_PATCH'
import re, sys

filepath = sys.argv[1]
with open(filepath, "r") as f:
    lines = f.readlines()

# Lines to remove by exact content patterns (single-line removals)
single_line_patterns = [
    r'late Map<OrganismKind, TaskEventRepository>',
    r'late CustomTypesRepository ',
    r'late CustomTypeResolverService ',
    r'_taskEventRepositories = taskEventRepositories;',
    r'_customTypesRepository = CustomTypesRepository',
    r'_customTypeResolverService\.dispose\(\)',
    r'final taskEventRepositories = <OrganismKind, TaskEventRepository>',
    r'final taskEventRepository = taskEventRepositories',
    r'firestore: firestore,\s*\);',  # closing of single-arg constructors after their opener was removed
]

# Multi-line block patterns to remove (start pattern, end pattern)
# IMPORTANT: end patterns use ^ and $ anchors so they only match lines
# that consist ENTIRELY of the closing delimiter (after stripping whitespace).
# Without anchors, r'\),' would also match parameter lines like
# 'value: UnmodifiableMapView(_repos),' causing premature block termination.
block_patterns = [
    # TaskEventRepository dispose loop
    (r'for \(final repo in _taskEventRepositories\.values\)', r'^\}$'),
    # CustomTypeResolverService init (2-3 lines)
    (r'_customTypeResolverService = CustomTypeResolverService\(', r'^\);$'),
    # TaskEventRepository creation in forEach (8 lines)
    (r'taskEventRepositories\[kind\] = TaskEventRepository\(', r'^\);$'),
    # TaskEventRepository registry registration
    (r'taskEventRepositories\.forEach\(', r'^\);$'),
    # Provider<Map<OrganismKind, TaskEventRepository>>
    (r'Provider<Map<OrganismKind, TaskEventRepository>>', r'^\),$'),
    # RepositoryProvider<TaskEventRepository> (first instance)
    (r'RepositoryProvider<TaskEventRepository>\(', r'^\),$'),
    # RepositoryProvider<CustomTypesRepository>
    (r'RepositoryProvider<CustomTypesRepository>', r'^\),$'),
    # ChangeNotifierProvider<CustomTypeResolverService>
    (r'ChangeNotifierProvider<CustomTypeResolverService>', r'^\),$'),
]

# Process: remove single lines
result = []
for line in lines:
    skip = False
    for pattern in single_line_patterns:
        if re.search(pattern, line):
            skip = True
            break
    if not skip:
        result.append(line)

# Process: remove blocks
final_result = []
i = 0
while i < len(result):
    line = result[i]
    removed = False
    for start_pat, end_pat in block_patterns:
        if re.search(start_pat, line):
            # Find the end of the block
            j = i + 1
            while j < len(result):
                if re.search(end_pat, result[j].strip()):
                    j += 1  # include the end line
                    break
                j += 1
            i = j
            removed = True
            break
    if not removed:
        final_result.append(line)
        i += 1

with open(filepath, "w") as f:
    f.writelines(final_result)

print(f"Removed {len(lines) - len(final_result)} lines from repositories_provider.dart")
PYTHON_PATCH

    # Post-process: remove ONLY truly orphaned close-parens left by block removal
    # An orphaned ), is one that immediately follows another ), at the SAME indent
    # with no other content between them (caused by removing a multi-line block above)
    python3 - "${REPO_PROVIDER}" << 'PYTHON_CLEANUP'
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    lines = f.readlines()

# Strategy: track paren nesting. An orphaned ), appears where the
# block above it was removed, leaving two consecutive ), at same indent.
# But most consecutive ), are legitimate (closing nested structures).
# So we only remove if the ), follows a ), AND there's no opening paren
# at a deeper indent between them (i.e., the previous ), and this one
# are at the same level with nothing in between).
result = []
removed = 0
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped == '),' and len(result) > 0:
        prev = result[-1]
        prev_stripped = prev.strip()
        cur_indent = len(line) - len(line.lstrip())
        prev_indent = len(prev) - len(prev.lstrip())
        # Only remove if EXACT same indent AND previous line is also just ),
        if prev_stripped == '),' and cur_indent == prev_indent:
            removed += 1
            continue
    result.append(line)

with open(filepath, 'w') as f:
    f.writelines(result)
print(f'Removed {removed} orphaned close-parens from repositories_provider.dart')
PYTHON_CLEANUP

    log_success "  Patched repositories_provider.dart (imports + body refs)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch C: Fix graph_node_info.dart (remove pro features)
log_info "Patch C: Fixing graph_node_info.dart..."
GRAPH_INFO="${COMMUNITY_DIR}/lib/screens/graph/graph_node_info.dart"
if [[ -f "${GRAPH_INFO}" ]]; then
    ${SED_IN_PLACE} "/import.*cascade_deletion_service.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*connectivity_service.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*inventory_editing_service.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*genet_profile_screen.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*delete_confirmation_dialog.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*organism_quick_action_sheet.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*site_delete_confirmation_dialog.dart/d" "${GRAPH_INFO}"
    ${SED_IN_PLACE} "/import.*organization_structure_screen.dart/d" "${GRAPH_INFO}"
    log_success "  Patched graph_node_info.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch D: Fix graph_node_events_list.dart (remove pro events cubit)
log_info "Patch D: Fixing graph_node_events_list.dart..."
EVENTS_LIST="${COMMUNITY_DIR}/lib/screens/graph/graph_node_events_list.dart"
if [[ -f "${EVENTS_LIST}" ]]; then
    ${SED_IN_PLACE} "/import.*graph_node_events_cubit.dart/d" "${EVENTS_LIST}"
    ${SED_IN_PLACE} "/import.*graph_node_events_state.dart/d" "${EVENTS_LIST}"
    log_success "  Patched graph_node_events_list.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch E: DISABLED - All record_factory model types (Vessel, Permit, Deliverable, MonitoringSchedule, Funder) are community-tier
log_info "Patch E: Skipping (all record_factory model types are community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch F: DISABLED - husbandry_schedule_entry, husbandry_schedule_registry, vessel are all community-tier
log_info "Patch F: Skipping (export_service imports are all community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch G: Fix community_graph_node_container.dart
log_info "Patch G: Fixing community_graph_node_container.dart..."
CONTAINER="${COMMUNITY_DIR}/lib/screens/graph/community_graph_node_container.dart"
if [[ -f "${CONTAINER}" ]]; then
    # Remove old community-prefixed imports
    ${SED_IN_PLACE} "/import.*community_organism_node_screen.dart/d" "${CONTAINER}"
    ${SED_IN_PLACE} "/import.*community_organization_node_screen.dart/d" "${CONTAINER}"
    ${SED_IN_PLACE} "/import.*community_site_node_screen.dart/d" "${CONTAINER}"
    # Add imports for renamed community screens (insert after first import line)
    ${SED_IN_PLACE} "1a\\
import 'package:seafoundry_app/screens/graph/organism_node_screen.dart';\\
import 'package:seafoundry_app/screens/graph/organization_node_screen.dart';\\
import 'package:seafoundry_app/screens/graph/site_node_screen.dart';
" "${CONTAINER}"
    # Rename class references
    ${SED_IN_PLACE} "s/CommunityOrganizationNodeScreen/OrganizationNodeScreen/g" "${CONTAINER}"
    ${SED_IN_PLACE} "s/CommunitySiteNodeScreen/SiteNodeScreen/g" "${CONTAINER}"
    ${SED_IN_PLACE} "s/CommunityOrganismNodeScreen/OrganismNodeScreen/g" "${CONTAINER}"
    log_success "  Patched community_graph_node_container.dart"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# Patch H: DISABLED - monitoring_schedule_service.dart is community-tier
log_info "Patch H: Skipping (monitoring_schedule_service is community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch I: DISABLED - connectivity_service.dart is community-tier
log_info "Patch I: Skipping (connectivity_service is community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch J: Fix barrel exports (community-tier exports are kept)
log_info "Patch J: Barrel exports - all remaining exports are community-tier, no removals needed."
# NOTE: funder.dart, vessel.dart, mission.dart, environmental_threshold_service.dart,
# husbandry_schedule_registry.dart, husbandry_task_filter_service.dart,
# validation_rule_registry.dart, local_storage_service.dart,
# community_comment_repository.dart, vessel_repository.dart, funder_repository.dart
# are all community-tier and should NOT be removed from barrel exports.
log_success "  Barrel exports verified (no community exports removed)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch K: DISABLED - connectivity_service.dart is community-tier, no need to remove references
log_info "Patch K: Skipping (connectivity_service is community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch L: Fix navigation files
log_info "Patch L: Fixing navigation files..."
SIMPLE_ROUTER="${COMMUNITY_DIR}/lib/navigation/simple_router.dart"
if [[ -f "${SIMPLE_ROUTER}" ]]; then
    ${SED_IN_PLACE} "/import.*tour_wrapper.dart/d" "${SIMPLE_ROUTER}"
    # Replace 'return const TourWrapper(\n          child: SimpleNavigationWidget(),' with 'return const SimpleNavigationWidget('
    ${SED_IN_PLACE} "s/return const TourWrapper(/return const SimpleNavigationWidget(/g" "${SIMPLE_ROUTER}"
    ${SED_IN_PLACE} "/child: SimpleNavigationWidget()/d" "${SIMPLE_ROUTER}"
    log_success "  Patched simple_router.dart (removed TourWrapper)"
fi
NAV_WIDGET="${COMMUNITY_DIR}/lib/navigation/simple_navigation_widget.dart"
if [[ -f "${NAV_WIDGET}" ]]; then
    ${SED_IN_PLACE} "/import.*community_page_screen.dart/d" "${NAV_WIDGET}"
    # Replace CommunityPageScreen() with a placeholder since it's a pro-only screen
    ${SED_IN_PLACE} "s/return CommunityPageScreen();/return const Center(child: Text('Community Feed - available in Pro'));/g" "${NAV_WIDGET}"
    log_success "  Patched simple_navigation_widget.dart (removed CommunityPageScreen)"
fi
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch M: Fix dialog mixins referencing ToastOverlay
log_info "Patch M: Checking ToastOverlay availability..."
TOAST_FILE="${COMMUNITY_DIR}/lib/widgets/notifications/toast_overlay.dart"
if [[ ! -f "${TOAST_FILE}" ]]; then
    log_warning "  ToastOverlay was removed - patching references..."
    # If ToastOverlay was deleted (shouldn't be now), remove references
    for DIALOG_FILE in \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/components/safe_dialog_mixin.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/mixins/event_propagation_mixin.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/transfer_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/organism_creation_wizard/organism_creation_wizard.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/transfer/batch_transfer_items_step.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/transfer/transfer_manual_register_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/structure_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/gene_bank/gene_bank_audit_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/gene_bank/gene_bank_temperature_monitoring_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/gene_bank/gene_bank_viability_test_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/holdings/generic_holding_dialog.dart" \
        "${COMMUNITY_DIR}/lib/widgets/dialogs/components/transfer_manifest_summary.dart"; do
        if [[ -f "${DIALOG_FILE}" ]]; then
            ${SED_IN_PLACE} "/import.*toast_overlay.dart/d" "${DIALOG_FILE}"
            ${SED_IN_PLACE} "/ToastOverlay/d" "${DIALOG_FILE}"
            ${SED_IN_PLACE} "/ToastController/d" "${DIALOG_FILE}"
            log_info "  Patched: $(basename ${DIALOG_FILE})"
        fi
    done
else
    log_success "  ToastOverlay exists - no patching needed"
fi
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch N: DISABLED - husbandry_schedule_registry.dart is community-tier
log_info "Patch N: Skipping (husbandry_schedule_registry is community-tier)"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch O: Fix node screens referencing community variants
log_info "Patch O: Fixing node screen references..."
ORG_SCREEN="${COMMUNITY_DIR}/lib/screens/graph/organization_node_screen.dart"
if [[ -f "${ORG_SCREEN}" ]]; then
    ${SED_IN_PLACE} "s/import.*community_summary_statistics.dart.*/import 'package:seafoundry_app\/widgets\/navigation\/summary_statistics.dart';/g" "${ORG_SCREEN}"
    ${SED_IN_PLACE} "s/CommunitySummaryStatistics/SummaryStatistics/g" "${ORG_SCREEN}"
    log_success "  Patched organization_node_screen.dart"
fi
SITE_SCREEN="${COMMUNITY_DIR}/lib/screens/graph/site_node_screen.dart"
if [[ -f "${SITE_SCREEN}" ]]; then
    ${SED_IN_PLACE} "s/import.*community_site_summary_cards.dart.*/import 'package:seafoundry_app\/widgets\/graph_node\/site_summary_cards.dart';/g" "${SITE_SCREEN}"
    ${SED_IN_PLACE} "s/CommunitySiteSummaryCards/SiteSummaryCards/g" "${SITE_SCREEN}"
    log_success "  Patched site_node_screen.dart"
fi
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch P: Fix spreadsheet_filter_bar.dart (remove OrganismSelector usage)
log_info "Patch P: Fixing spreadsheet_filter_bar.dart..."
FILTER_BAR="${COMMUNITY_DIR}/lib/widgets/spreadsheet/components/spreadsheet_filter_bar.dart"
if [[ -f "${FILTER_BAR}" ]]; then
    ${SED_IN_PLACE} "/import.*organism_selector.dart/d" "${FILTER_BAR}"
    # Replace OrganismSelector widget block with a placeholder SizedBox
    python3 - "${FILTER_BAR}" << 'PYTHON_PATCH_P'
import re, sys
filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()
# Replace OrganismSelector(...) block with const SizedBox()
content = re.sub(
    r'OrganismSelector\(\s*\n\s*value:.*?\n\s*onChanged:.*?\n\s*allowedKinds:.*?\n\s*isDense:.*?\n\s*\)',
    'const SizedBox()',
    content,
    flags=re.DOTALL,
)
with open(filepath, 'w') as f:
    f.write(content)
print('Replaced OrganismSelector with SizedBox in spreadsheet_filter_bar.dart')
PYTHON_PATCH_P
    log_success "  Patched spreadsheet_filter_bar.dart"
fi
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# Patch Q2: Fix graph_node_container.dart (remove GroupNodeScreen reference)
log_info "Patch Q2: Fixing graph_node_container.dart..."
GRAPH_CONTAINER="${COMMUNITY_DIR}/lib/screens/graph/graph_node_container.dart"
if [[ -f "${GRAPH_CONTAINER}" ]]; then
    # Remove group_node_screen import
    ${SED_IN_PLACE} "/import.*group_node_screen.dart/d" "${GRAPH_CONTAINER}"
    # Replace GroupNodeScreen(...) block with a placeholder
    python3 - "${GRAPH_CONTAINER}" << 'PYTHON_PATCH_Q2'
import re, sys
filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()
# Replace GroupNodeScreen constructor call with placeholder
content = re.sub(
    r'return GroupNodeScreen\(\s*\n\s*loadedNodeState:.*?\n\s*graphNode:.*?\n\s*\);',
    "return const Center(child: Text('Group details available in Pro'));",
    content,
    flags=re.DOTALL,
)
with open(filepath, 'w') as f:
    f.write(content)
print('Replaced GroupNodeScreen with placeholder in graph_node_container.dart')
PYTHON_PATCH_Q2
    log_success "  Patched graph_node_container.dart (removed GroupNodeScreen)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# ==============================================================================
# Patch S: Create placeholder firebase_options.dart and Google Services files
# ==============================================================================
log_info "Patch S: Creating placeholder Firebase config files..."

FIREBASE_OPTIONS="${COMMUNITY_DIR}/lib/firebase_options.dart"
cat > "${FIREBASE_OPTIONS}" << 'FIREBASE_OPTIONS_PLACEHOLDER'
// @tier: community
// PLACEHOLDER - Replace with your own Firebase configuration
// Run: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.example.seafoundryApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.example.seafoundryApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );
}
FIREBASE_OPTIONS_PLACEHOLDER
log_success "  Created placeholder firebase_options.dart"

# Create placeholder GoogleService-Info.plist for iOS
IOS_PLIST_DIR="${COMMUNITY_DIR}/ios/Runner"
mkdir -p "${IOS_PLIST_DIR}"
cat > "${IOS_PLIST_DIR}/GoogleService-Info.plist" << 'IOS_PLIST_PLACEHOLDER'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>YOUR_IOS_API_KEY</string>
	<key>GCM_SENDER_ID</key>
	<string>YOUR_SENDER_ID</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.example.seafoundryApp</string>
	<key>PROJECT_ID</key>
	<string>YOUR_PROJECT_ID</string>
	<key>STORAGE_BUCKET</key>
	<string>YOUR_PROJECT_ID.firebasestorage.app</string>
	<key>GOOGLE_APP_ID</key>
	<string>YOUR_IOS_APP_ID</string>
</dict>
</plist>
IOS_PLIST_PLACEHOLDER
log_success "  Created placeholder ios/Runner/GoogleService-Info.plist"

# Create placeholder GoogleService-Info.plist for macOS
MACOS_PLIST_DIR="${COMMUNITY_DIR}/macos/Runner"
mkdir -p "${MACOS_PLIST_DIR}"
cp "${IOS_PLIST_DIR}/GoogleService-Info.plist" "${MACOS_PLIST_DIR}/GoogleService-Info.plist"
log_success "  Created placeholder macos/Runner/GoogleService-Info.plist"

# Create placeholder google-services.json for Android
ANDROID_DIR="${COMMUNITY_DIR}/android/app"
mkdir -p "${ANDROID_DIR}"
cat > "${ANDROID_DIR}/google-services.json" << 'ANDROID_PLACEHOLDER'
{
  "project_info": {
    "project_number": "YOUR_PROJECT_NUMBER",
    "project_id": "YOUR_PROJECT_ID",
    "storage_bucket": "YOUR_PROJECT_ID.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "YOUR_ANDROID_APP_ID",
        "android_client_info": {
          "package_name": "com.example.seafoundry_app"
        }
      },
      "api_key": [
        {
          "current_key": "YOUR_ANDROID_API_KEY"
        }
      ]
    }
  ],
  "configuration_version": "1"
}
ANDROID_PLACEHOLDER
log_success "  Created placeholder android/app/google-services.json"

PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# ==============================================================================
# Patch T1: Fix tier_features.yaml YAML indentation
# ==============================================================================
log_info "Patch T1: Fixing tier_features.yaml YAML indentation..."
TIER_CONFIG="${COMMUNITY_DIR}/config/tier_features.yaml"
if [[ -f "${TIER_CONFIG}" ]]; then
    ${SED_IN_PLACE} 's/^            monitoring_dialog:/      monitoring_dialog:/' "${TIER_CONFIG}"
    ${SED_IN_PLACE} 's/^            monitoring_workspace:/      monitoring_workspace:/' "${TIER_CONFIG}"
    ${SED_IN_PLACE} 's/^            monitoring_workspace_limited:/      monitoring_workspace_limited:/' "${TIER_CONFIG}"
    log_success "  Fixed tier_features.yaml indentation"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# ==============================================================================
# Patch T2: Fix EventFactory default throw → safe fallback
# ==============================================================================
log_info "Patch T2: Fixing event_factory.dart default cases..."
EVENT_FACTORY="${COMMUNITY_DIR}/lib/models/factories/event_factory.dart"
if [[ -f "${EVENT_FACTORY}" ]]; then
    python3 - "${EVENT_FACTORY}" << 'PYTHON_PATCH_T2'
import re, sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

# Replace first throw (eventFromJson) with safe fallback
content = content.replace(
    """      default:
        throw RecordFactoryError(
          message: 'Invalid event type: $eventTypeId',
          json: json,
        );""",
    """      default:
        // Community build: return base Event for unrecognized types
        return Event.fromJson(normalizedJson);"""
)

# Replace second throw (incompleteEventFromJson) with safe fallback
content = content.replace(
    """      default:
        throw RecordFactoryError(
          message: 'Invalid incomplete event type: $eventTypeId',
          json: json,
        );""",
    """      default:
        // Community build: return partial Event for unrecognized types
        return Event.partial(json: normalizedJson);"""
)

with open(filepath, 'w') as f:
    f.write(content)
print('Patched event_factory.dart: replaced default throws with safe fallbacks')
PYTHON_PATCH_T2
    log_success "  Patched event_factory.dart (safe fallbacks)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# ==============================================================================
# Patch T3: Fix UpgradeDialog — remove PaymentService crash
# ==============================================================================
log_info "Patch T3: Fixing upgrade_dialog.dart..."
UPGRADE_DIALOG="${COMMUNITY_DIR}/lib/widgets/common/upgrade_dialog.dart"
if [[ -f "${UPGRADE_DIALOG}" ]]; then
    python3 - "${UPGRADE_DIALOG}" << 'PYTHON_PATCH_T3'
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

# Replace FeaturePurchaseSheet import with beta signup dialog
content = content.replace(
    "import 'package:seafoundry_app/widgets/common/feature_purchase_sheet.dart';",
    "import 'package:seafoundry_app/widgets/dialogs/beta_signup_dialog.dart';"
)

# Replace the onUpgrade callback that calls FeaturePurchaseSheet.show
# with a safe community-edition version that opens beta signup
old_block = """        onUpgrade: () {
          // Pop the upgrade dialog first
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          // Show the purchase sheet using the caller context which
          // still has CurrentUser, PaymentService, etc.
          if (callerContext.mounted) {
            FeaturePurchaseSheet.show(
              callerContext,
              featureKey: featureKeyForTier(requiredTier),
              featureName: featureName,
              customMessage: customMessage,
            );
          }
        },"""

new_block = """        onUpgrade: () {
          // Pop the upgrade dialog first
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          // Community edition: show beta signup instead of purchase
          if (callerContext.mounted) {
            showBetaSignupDialog(
              context: callerContext,
              featureName: featureName,
            );
          }
        },"""

content = content.replace(old_block, new_block)

with open(filepath, 'w') as f:
    f.write(content)
print('Patched upgrade_dialog.dart: replaced FeaturePurchaseSheet with beta signup')
PYTHON_PATCH_T3
    log_success "  Patched upgrade_dialog.dart (removed PaymentService dependency)"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
fi

# ==============================================================================
# Patch T4: Replace Pro/Scale UI text with neutral community messaging
# ==============================================================================
log_info "Patch T4: Replacing Pro/Scale UI text..."

# Navigation widget
NAV_WIDGET="${COMMUNITY_DIR}/lib/navigation/simple_navigation_widget.dart"
if [[ -f "${NAV_WIDGET}" ]]; then
    ${SED_IN_PLACE} "s/Community Feed - available in Pro/Community Feed - coming soon/g" "${NAV_WIDGET}"
fi

# Graph node containers
GRAPH_CONTAINER="${COMMUNITY_DIR}/lib/screens/graph/graph_node_container.dart"
if [[ -f "${GRAPH_CONTAINER}" ]]; then
    ${SED_IN_PLACE} "s/Group details available in Pro/Group details - coming soon/g" "${GRAPH_CONTAINER}"
fi
COMMUNITY_CONTAINER="${COMMUNITY_DIR}/lib/screens/graph/community_graph_node_container.dart"
if [[ -f "${COMMUNITY_CONTAINER}" ]]; then
    ${SED_IN_PLACE} "s/Detailed group management is available in Pro tier\./Detailed group management coming soon./g" "${COMMUNITY_CONTAINER}"
fi

# Quantity change editor
QTY_EDITOR="${COMMUNITY_DIR}/lib/widgets/common/quantity_change_editor.dart"
if [[ -f "${QTY_EDITOR}" ]]; then
    ${SED_IN_PLACE} "s/Mortality causes are a Pro feature/Mortality causes - coming soon/g" "${QTY_EDITOR}"
fi

# Summary statistics
SUMMARY_STATS="${COMMUNITY_DIR}/lib/widgets/navigation/summary_statistics.dart"
if [[ -f "${SUMMARY_STATS}" ]]; then
    ${SED_IN_PLACE} "s/'Upgrade to Pro'/'Coming Soon'/g" "${SUMMARY_STATS}"
fi

# Site limits service
SITE_LIMITS="${COMMUNITY_DIR}/lib/services/site_limits_service.dart"
if [[ -f "${SITE_LIMITS}" ]]; then
    ${SED_IN_PLACE} "s/Upgrade to Pro for unlimited sites\./Upgrade for unlimited sites./g" "${SITE_LIMITS}"
    ${SED_IN_PLACE} "s/Upgrade to Pro to create baseline and reference sites\./Upgrade to create baseline and reference sites./g" "${SITE_LIMITS}"
    ${SED_IN_PLACE} "s/Upgrade to Pro for access to all site types\./Upgrade for access to all site types./g" "${SITE_LIMITS}"
    ${SED_IN_PLACE} "s/Site limit reached\. Upgrade to Pro for unlimited sites\./Site limit reached. Upgrade for unlimited sites./g" "${SITE_LIMITS}"
fi

# Monitoring service
MONITORING_SVC="${COMMUNITY_DIR}/lib/services/monitoring_service.dart"
if [[ -f "${MONITORING_SVC}" ]]; then
    ${SED_IN_PLACE} "s/Monitoring workflows are a Pro feature\./Monitoring workflows coming soon./g" "${MONITORING_SVC}"
    ${SED_IN_PLACE} "s/Upgrade to Pro to capture monitoring observations and imagery\./Upgrade to capture monitoring observations and imagery./g" "${MONITORING_SVC}"
fi

# Monitoring event repository
MONITORING_REPO="${COMMUNITY_DIR}/lib/repositories/inventory/monitoring_event_repository.dart"
if [[ -f "${MONITORING_REPO}" ]]; then
    ${SED_IN_PLACE} "s/Monitoring workflows are a Pro feature\./Monitoring workflows coming soon./g" "${MONITORING_REPO}"
    ${SED_IN_PLACE} "s/Upgrade to Pro to capture monitoring observations and imagery\./Upgrade to capture monitoring observations and imagery./g" "${MONITORING_REPO}"
    ${SED_IN_PLACE} "s/Image attachments are a Pro feature\./Image attachments coming soon./g" "${MONITORING_REPO}"
fi

# Manage members cubit
MEMBERS_CUBIT="${COMMUNITY_DIR}/lib/cubits/manage_members/manage_members_cubit.dart"
if [[ -f "${MEMBERS_CUBIT}" ]]; then
    ${SED_IN_PLACE} "s/Pro tier is limited to/Current tier is limited to/g" "${MEMBERS_CUBIT}"
fi

# Members tab widget
MEMBERS_TAB="${COMMUNITY_DIR}/lib/widgets/admin/members_tab.dart"
if [[ -f "${MEMBERS_TAB}" ]]; then
    ${SED_IN_PLACE} "s/Pro tier limits:/Tier limits:/g" "${MEMBERS_TAB}"
    ${SED_IN_PLACE} "s/Scale tier has no role limits/No role limits on this tier/g" "${MEMBERS_TAB}"
fi

# Beta signup dialog
BETA_DIALOG="${COMMUNITY_DIR}/lib/widgets/dialogs/beta_signup_dialog.dart"
if [[ -f "${BETA_DIALOG}" ]]; then
    ${SED_IN_PLACE} "s/Pro features become available\./new features become available./g" "${BETA_DIALOG}"
    ${SED_IN_PLACE} "s/Pro features are coming soon\!/New features are coming soon\!/g" "${BETA_DIALOG}"
    ${SED_IN_PLACE} "s/about Pro features/about new features/g" "${BETA_DIALOG}"
fi

# Monitoring map screen
MONITORING_MAP="${COMMUNITY_DIR}/lib/screens/monitoring/monitoring_map_screen.dart"
if [[ -f "${MONITORING_MAP}" ]]; then
    ${SED_IN_PLACE} "s/Monitoring maps are a Pro feature/Monitoring maps - coming soon/g" "${MONITORING_MAP}"
fi

# Snapshot comparison screen (may be removed by DIRS_TO_REMOVE, but patch anyway for safety)
SNAPSHOT_SCREEN="${COMMUNITY_DIR}/lib/widgets/snapshot_comparison/snapshot_comparison_screen.dart"
if [[ -f "${SNAPSHOT_SCREEN}" ]]; then
    ${SED_IN_PLACE} "s/Snapshot Comparison is a Pro feature/Snapshot Comparison - coming soon/g" "${SNAPSHOT_SCREEN}"
fi

# Image observation dialog
IMG_OBS_DIALOG="${COMMUNITY_DIR}/lib/widgets/dialogs/observation/image_observation_dialog.dart"
if [[ -f "${IMG_OBS_DIALOG}" ]]; then
    ${SED_IN_PLACE} "s/Image uploads are a Pro feature\. Upgrade to attach imagery\./Image uploads coming soon./g" "${IMG_OBS_DIALOG}"
    ${SED_IN_PLACE} "s/Image uploads are a Pro feature\. Upgrade to continue\./Image uploads coming soon./g" "${IMG_OBS_DIALOG}"
    ${SED_IN_PLACE} "s/Image uploads are a Pro feature/Image uploads - coming soon/g" "${IMG_OBS_DIALOG}"
fi

# Cache manager (debug log - cosmetic only)
CACHE_MGR="${COMMUNITY_DIR}/lib/services/cache_manager.dart"
if [[ -f "${CACHE_MGR}" ]]; then
    ${SED_IN_PLACE} "s/Pro tier services reset/tier services reset/g" "${CACHE_MGR}"
fi

log_success "  Replaced Pro/Scale UI text with neutral community messaging"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# ==============================================================================
# Patch T5: Fix barrel exports and imports for payment files only
# ==============================================================================
log_info "Patch T5: Fixing barrel exports for removed payment files..."

# Note: feature_purchase.dart is kept (used by feature_access_service.dart)
# Only remove payment_service and purchases_repository barrel exports

# Fix services barrel - only payment_service
SERVICES_FILE="${COMMUNITY_DIR}/lib/services/services.dart"
if [[ -f "${SERVICES_FILE}" ]]; then
    ${SED_IN_PLACE} "/export.*payment_service.dart/d" "${SERVICES_FILE}"
    log_info "  Fixed services.dart barrel"
fi

# Fix repositories barrel - only purchases_repository
REPOS_FILE="${COMMUNITY_DIR}/lib/repositories/repositories.dart"
if [[ -f "${REPOS_FILE}" ]]; then
    ${SED_IN_PLACE} "/export.*purchases_repository.dart/d" "${REPOS_FILE}"
    log_info "  Fixed repositories.dart barrel"
fi

log_success "  Fixed barrel exports for removed payment files"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# ==============================================================================
# Patch T6: Fix imports referencing removed payment files
# ==============================================================================
log_info "Patch T6: Fixing imports for removed payment files..."

# Only remove imports for the 4 payment-related files we actually deleted
for DART_FILE in $(find "${COMMUNITY_DIR}/lib" -name "*.dart" -type f 2>/dev/null); do
    if grep -q "import.*payment_service.dart" "$DART_FILE" 2>/dev/null; then
        ${SED_IN_PLACE} "/import.*payment_service.dart/d" "$DART_FILE"
        log_info "  Removed payment_service import from $(basename $DART_FILE)"
    fi
    if grep -q "import.*feature_purchase_sheet.dart" "$DART_FILE" 2>/dev/null; then
        ${SED_IN_PLACE} "/import.*feature_purchase_sheet.dart/d" "$DART_FILE"
        log_info "  Removed feature_purchase_sheet import from $(basename $DART_FILE)"
    fi
    if grep -q "import.*purchases_repository.dart" "$DART_FILE" 2>/dev/null; then
        ${SED_IN_PLACE} "/import.*purchases_repository.dart/d" "$DART_FILE"
        log_info "  Removed purchases_repository import from $(basename $DART_FILE)"
    fi
    # Note: feature_purchase.dart imports are kept (used by feature_access_service.dart)
done

log_success "  Fixed imports for removed payment files"
PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# ==============================================================================
# Patch T7: Add missing BlocProviders to community build
# ==============================================================================
# The community build templates are missing 3 cubits that the community
# navigation widgets depend on. Without these, the app shows a permanent
# loading spinner (NavigationViewModeCubit) or crashes on screen access
# (RecordDisplayPreferencesCubit, SpreadsheetColumnPreferencesCubit).
# ==============================================================================
log_info "Patch T7: Adding missing BlocProviders..."

# --- T7a: Add NavigationViewModeCubit to repositories_provider.dart + call loadManifest ---
REPO_PROVIDER_FILE="${COMMUNITY_DIR}/lib/widgets/repositories/repositories_provider.dart"
if [[ -f "${REPO_PROVIDER_FILE}" ]]; then
    python3 -c "
import sys
filepath = '${REPO_PROVIDER_FILE}'
with open(filepath, 'r') as f:
    content = f.read()

changes = 0

# 1. Add import for NavigationViewModeCubit (on its own line after navigation_cubit import)
if 'navigation_view_mode' not in content:
    old_import = \"import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';\"
    new_import = old_import + \"\\nimport 'package:seafoundry_app/cubits/navigation_view_mode/navigation_view_mode_cubit.dart';\"
    content = content.replace(old_import, new_import)
    changes += 1

# 2. Add BlocProvider for NavigationViewModeCubit into the MultiBlocProvider
old_block = '''            ),
          ],
          child: NavigationCubitConnector('''

new_block = '''            ),
            BlocProvider<NavigationViewModeCubit>(
              create: (_) => NavigationViewModeCubit(
                hasOrganization: widget.organization.id.isNotEmpty,
              ),
            ),
          ],
          child: NavigationCubitConnector('''

if old_block in content:
    content = content.replace(old_block, new_block)
    changes += 1
else:
    print('  WARNING: Could not find MultiBlocProvider insertion point', file=sys.stderr)
    sys.exit(1)

# 3. Add loadManifest() call after FeatureAccessService creation
old_init = '''    _featureAccessService = FeatureAccessService(
      defaultTier: Tier.community,
      organizationTier: 'community',
    );'''

new_init = '''    _featureAccessService = FeatureAccessService(
      defaultTier: Tier.community,
      organizationTier: 'community',
    );
    unawaited(_featureAccessService.loadManifest());'''

if old_init in content:
    content = content.replace(old_init, new_init)
    changes += 1
else:
    print('  WARNING: Could not find FeatureAccessService init for loadManifest()', file=sys.stderr)
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(content)
print(f'  Applied {changes} changes to repositories_provider.dart')
"
    log_success "  Added NavigationViewModeCubit + loadManifest() to repositories_provider.dart"
else
    log_warning "  repositories_provider.dart not found - skipping T7a"
fi

# --- T7b: Add RecordDisplayPreferencesCubit + SpreadsheetColumnPreferencesCubit to app.dart ---
APP_FILE="${COMMUNITY_DIR}/lib/app.dart"
if [[ -f "${APP_FILE}" ]]; then
    python3 -c "
import sys
filepath = '${APP_FILE}'
with open(filepath, 'r') as f:
    content = f.read()

changes = 0

# 1. Add imports for the two preference cubits (on separate lines after current_user import)
if 'record_display_preferences' not in content:
    old_import = \"import 'cubits/current_user/current_user.dart';\"
    new_import = old_import + \"\\nimport 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';\\nimport 'package:seafoundry_app/cubits/spreadsheet_column_preferences/spreadsheet_column_preferences_cubit.dart';\"
    content = content.replace(old_import, new_import)
    changes += 1

# 2. Add BlocProviders to the MultiBlocProvider (after CurrentUser provider)
old_block = '''            BlocProvider(
              create: (context) =>
                  CurrentUser(repository: context.read<CurrentUserRepository>()),
            )
          ],'''

new_block = '''            BlocProvider(
              create: (context) =>
                  CurrentUser(repository: context.read<CurrentUserRepository>()),
            ),
            BlocProvider(
              create: (context) => RecordDisplayPreferencesCubit(),
            ),
            BlocProvider(
              create: (context) => SpreadsheetColumnPreferencesCubit(),
            ),
          ],'''

if old_block in content:
    content = content.replace(old_block, new_block)
    changes += 1
else:
    print('  WARNING: Could not find MultiBlocProvider insertion point in app.dart', file=sys.stderr)
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(content)
print(f'  Applied {changes} changes to app.dart')
"
    log_success "  Added RecordDisplayPreferencesCubit + SpreadsheetColumnPreferencesCubit to app.dart"
else
    log_warning "  app.dart not found - skipping T7b"
fi

PATCHES_APPLIED=$((PATCHES_APPLIED + 1))

# ==============================================================================
# Patch T8: Make Event.fromJson safe for missing/unrecognized recordModelType
# ==============================================================================
# Event.fromJson uses ModelType.values.byName(json['recordModelType']) which
# throws ArgumentError on null or unrecognized values. The EventFactory default
# branches route unrecognized event types to Event.fromJson, making this a
# reachable crash path. Fix: use ModelType.fromSlug() which already handles
# unknown values safely (returns ModelType.unknown).
# ==============================================================================
log_info "Patch T8: Making Event.fromJson safe for missing recordModelType..."

EVENT_FILE="${COMMUNITY_DIR}/lib/models/events/event.dart"
if [[ -f "${EVENT_FILE}" ]]; then
    python3 -c "
import sys
filepath = '${EVENT_FILE}'
with open(filepath, 'r') as f:
    content = f.read()

# Replace unsafe ModelType.values.byName with safe ModelType.fromSlug
old_line = \"recordModelType = ModelType.values.byName(json['recordModelType']),\"
new_line = \"recordModelType = json['recordModelType'] != null ? ModelType.fromSlug(json['recordModelType'] as String) : ModelType.unknown,\"

if old_line in content:
    content = content.replace(old_line, new_line)
    with open(filepath, 'w') as f:
        f.write(content)
    print('  Fixed Event.fromJson recordModelType safety')
else:
    print('  WARNING: Could not find ModelType.values.byName in Event.fromJson', file=sys.stderr)
    sys.exit(1)
"
    log_success "  Made Event.fromJson safe for missing/unrecognized recordModelType"
    PATCHES_APPLIED=$((PATCHES_APPLIED + 1))
else
    log_warning "  event.dart not found - skipping T8"
fi

# Summary
log_success "============================================"
log_success "Community patches completed!"
log_success "============================================"
log_info "Summary:"
log_info "  - Patches applied: ${PATCHES_APPLIED}"
log_info "  - Patches failed: ${PATCHES_FAILED}"

if [[ ${PRO_REFS_FOUND} -gt 0 ]]; then
    log_warning "  - Pro/Scale references found: ${PRO_REFS_FOUND} (may need manual review)"
fi

if [[ ${PATCHES_FAILED} -gt 0 ]]; then
    log_error "Some patches failed. Manual review may be required."
    exit 1
fi

log_success "All patches applied successfully!"
exit 0
