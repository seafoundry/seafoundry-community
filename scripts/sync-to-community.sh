#!/bin/bash
# Community OSS Repository Sync Script
# Syncs the main repository to a community version by removing Pro/Scale tier features
#
# Usage:
#   ./scripts/sync-to-community.sh
#
# Environment Variables:
#   COMMUNITY_REPO_URL - (Optional) Git URL to push community build to
#                        If not set, build will be created locally only
#
# Output:
#   Creates a community build in .community-sync-temp/
#   Removes all @tier: pro files and Pro/Scale directories
#   Validates build with flutter analyze (0 errors required)
#   Optionally pushes to community repository if COMMUNITY_REPO_URL is set
#
# Exit Codes:
#   0 - Success
#   1 - Validation or sync failure

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMP_DIR="${PROJECT_ROOT}/.community-sync-temp"
COMMUNITY_REPO_URL="${COMMUNITY_REPO_URL:-}"

# Validate we're in a Flutter project
if [[ ! -f "${PROJECT_ROOT}/pubspec.yaml" ]]; then
    log_error "Not a Flutter project (pubspec.yaml not found)"
    exit 1
fi

log_info "Starting Community OSS sync process..."
log_info "Project root: ${PROJECT_ROOT}"

# Step 1: Create temporary directory
log_info "Step 1: Creating temporary directory..."
if [[ -d "${TEMP_DIR}" ]]; then
    log_warning "Temporary directory exists, removing..."
    rm -rf "${TEMP_DIR}"
fi
mkdir -p "${TEMP_DIR}"
log_success "Temporary directory created at ${TEMP_DIR}"

# Step 2: Copy main repo (excluding .git)
log_info "Step 2: Copying repository to temporary directory..."
rsync -a \
    --exclude='.git' \
    --exclude='.dart_tool' \
    --exclude='build' \
    --exclude='.flutter-plugins' \
    --exclude='.flutter-plugins-dependencies' \
    --exclude='.community-sync-temp' \
    --exclude='.env' \
    --exclude='.env.local' \
    --exclude='.env.demo' \
    --exclude='firebase-service-account.json' \
    --exclude='**/GoogleService-Info.plist' \
    --exclude='**/google-services.json' \
    --exclude='lib/firebase_options.dart' \
    --exclude='**/*.keystore' \
    --exclude='**/key.properties' \
    --exclude='node_modules' \
    --exclude='crc_db' \
    --exclude='coverage' \
    "${PROJECT_ROOT}/" "${TEMP_DIR}/"
log_success "Repository copied successfully"

# Step 3: Remove files with @tier: pro or @tier: scale annotation
log_info "Step 3: Removing files with @tier: pro or @tier: scale annotation..."
PRO_FILES_COUNT=0

# Find all Dart files and check for @tier: pro or @tier: scale annotation
while IFS= read -r -d '' file; do
    # Skip community template files and core infrastructure that should be preserved
    if [[ "$file" == *"/lib/community_main.dart" ]] || \
       [[ "$file" == *"/lib/community_app.dart" ]] || \
       [[ "$file" == *"/lib/navigation/community_simple_router.dart" ]] || \
       [[ "$file" == *"/lib/widgets/repositories/community_repositories_provider.dart" ]] || \
       [[ "$file" == *"/lib/screens/auth/community_auth_screen.dart" ]] || \
       [[ "$file" == *"/lib/navigation/community_simple_navigation_widget.dart" ]] || \
       [[ "$file" == *"/lib/navigation/navigation_router_delegate.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/graph_node_container.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/site_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/organism_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/organization_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/graph_node_section.dart" ]] || \
       [[ "$file" == *"/lib/navigation/navigation_cubit_connector.dart" ]] || \
       [[ "$file" == *"/lib/widgets/graph_node/site_summary_cards.dart" ]] || \
       [[ "$file" == *"/lib/widgets/navigation/summary_statistics.dart" ]] || \
       [[ "$file" == *"/lib/widgets/navigation/community_summary_statistics.dart" ]] || \
       [[ "$file" == *"/lib/widgets/display/event_display.dart" ]] || \
       [[ "$file" == *"/lib/widgets/display/community_event_display.dart" ]] || \
       [[ "$file" == *"/lib/widgets/graph_node/community_site_summary_cards.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/community_organism_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/community_organization_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/screens/graph/community_site_node_screen.dart" ]] || \
       [[ "$file" == *"/lib/models/validation/validation_rule_type.dart" ]]; then
        continue
    fi

    # Check first 5 lines for tier annotation
    if head -5 "$file" 2>/dev/null | grep -q "^// @tier: pro" || head -5 "$file" 2>/dev/null | grep -q "^// @tier: scale"; then
        rm "$file"
        ((PRO_FILES_COUNT++))
        log_info "  Removed: ${file#$TEMP_DIR/}"
    fi
done < <(find "${TEMP_DIR}/lib" -type f -name "*.dart" -print0 2>/dev/null || true)

# Also check integration_test directory
while IFS= read -r -d '' file; do
    if head -5 "$file" 2>/dev/null | grep -qE "^// @tier: (pro|scale)"; then
        rm "$file"
        ((PRO_FILES_COUNT++))
        log_info "  Removed: ${file#$TEMP_DIR/}"
    fi
done < <(find "${TEMP_DIR}/integration_test" -type f -name "*.dart" -print0 2>/dev/null || true)

# Also check test directory
while IFS= read -r -d '' file; do
    if head -5 "$file" 2>/dev/null | grep -qE "^// @tier: (pro|scale)"; then
        rm "$file"
        ((PRO_FILES_COUNT++))
        log_info "  Removed: ${file#$TEMP_DIR/}"
    fi
done < <(find "${TEMP_DIR}/test" -type f -name "*.dart" -print0 2>/dev/null || true)

log_success "Removed ${PRO_FILES_COUNT} files with @tier: pro or @tier: scale annotation"

# Step 3b: Remove orphaned state files (state without matching cubit or bloc)
log_info "Step 3b: Removing orphaned state files..."
ORPHAN_FILES_COUNT=0
while IFS= read -r -d '' state_file; do
    # Only process files in cubits/ or blocs/ directories
    if [[ "$state_file" != *"/cubits/"* && "$state_file" != *"/blocs/"* ]]; then
        continue
    fi

    # Skip state files with non-standard naming (their consumers have different names)
    if [[ "$state_file" == *"/inventory_event_form_state.dart" ]] || \
       [[ "$state_file" == *"/base_removal_state.dart" ]]; then
        continue
    fi

    # Get the cubit/bloc file path by replacing _state.dart
    cubit_file="${state_file/_state.dart/_cubit.dart}"
    bloc_file="${state_file/_state.dart/_bloc.dart}"

    # Only remove if neither cubit nor bloc file exists
    if [[ ! -f "$cubit_file" && ! -f "$bloc_file" ]]; then
        rm "$state_file"
        ((ORPHAN_FILES_COUNT++))
        log_info "  Removed orphaned state: ${state_file#$TEMP_DIR/}"
    fi
done < <(find "${TEMP_DIR}/lib" -type f -name "*_state.dart" -print0 2>/dev/null || true)
log_success "Removed ${ORPHAN_FILES_COUNT} orphaned state files"

# Step 3c: Clean up empty directories left after annotation-based removal
log_info "Step 3c: Cleaning up empty directories..."
EMPTY_DIRS_COUNT=0
while true; do
    EMPTY_DIRS=$(find "${TEMP_DIR}/lib" -type d -empty 2>/dev/null | wc -l | xargs)
    if [[ "${EMPTY_DIRS}" -eq 0 ]]; then
        break
    fi
    find "${TEMP_DIR}/lib" -type d -empty -delete 2>/dev/null || true
    EMPTY_DIRS_COUNT=$((EMPTY_DIRS_COUNT + EMPTY_DIRS))
done
log_success "Removed ${EMPTY_DIRS_COUNT} empty directories"

# Step 4: Remove Pro/Scale directories
log_info "Step 4: Removing Pro/Scale tier directories..."
DIRS_TO_REMOVE=(
    # Screens (all files pro/scale)
    "lib/screens/training"
    "lib/screens/sebastian"
    "lib/screens/mission_center"

    # Cubits (all files pro/scale, or orphaned after pro cubit removal)
    "lib/cubits/sebastian"
    "lib/cubits/training"
    "lib/cubits/mission"
    "lib/cubits/monitoring_analytics"
    "lib/cubits/notifications"
    "lib/cubits/sync"
    "lib/cubits/chat"
    "lib/cubits/sync_conflict"
    "lib/cubits/deliverable"
    "lib/cubits/genet_profile"
    "lib/cubits/graph_node_events"
    "lib/cubits/task_management"
    "lib/cubits/data_privacy"
    "lib/cubits/site_type_config"
    "lib/cubits/custom_types"
    "lib/cubits/mortality_cause_config"
    "lib/cubits/observation_override_config"
    "lib/cubits/bulk_action"
    "lib/cubits/role_definition"
    "lib/cubits/permit"
    "lib/cubits/funder_roi"
    "lib/cubits/validation_rule_config"
    "lib/cubits/deliverable_form"

    # Widgets (all files pro/scale)
    "lib/widgets/sebastian"
    "lib/widgets/training"
    "lib/widgets/monitoring"
    "lib/widgets/husbandry"
    "lib/widgets/chat"
    "lib/widgets/mission"

    # Services (all files pro/scale)
    "lib/services/sebastian"

    # Models (all files pro/scale)
    "lib/models/sebastian"
    "lib/models/weather"
    "lib/models/chat"

    # Repositories (all files pro/scale)
    "lib/repositories/sebastian"
    "lib/repositories/training"
    "lib/repositories/offline"
    "lib/repositories/husbandry"
    "lib/repositories/environment"
    "lib/repositories/chat"

    # Tests (all removed - depend on test/helpers with pro-only fixtures)
    "integration_test"
    "test"

    # Scripts and support
    "scripts/conflicts"
    "scripts/overrides"
    "test_support"

    # Dead Pro/Scale feature directories (safe to remove — no community code references)
    "lib/services/payment"
    "lib/cubits/billing_portal"
    "lib/widgets/admin/billing_portal"
)

DIRS_REMOVED=0
for dir in "${DIRS_TO_REMOVE[@]}"; do
    TARGET_DIR="${TEMP_DIR}/${dir}"
    if [[ -d "${TARGET_DIR}" ]]; then
        rm -rf "${TARGET_DIR}"
        log_info "  Removed directory: ${dir}"
        ((DIRS_REMOVED++))
    fi
done
log_success "Removed ${DIRS_REMOVED} Pro/Scale directories"

# Step 5: Remove specific Pro service files
log_info "Step 5: Removing specific Pro service files..."
PRO_SERVICES=(
    # Pro-tier files (also caught by Step 3 annotation scan, kept for safety)
    "lib/services/push_notification_service.dart"
    "lib/widgets/spreadsheet/husbandry_tasks_spreadsheet.dart"
    "lib/screens/community/community_page_screen.dart"
    "lib/widgets/community/community_event_feed.dart"
    "lib/screens/graph/graph_node_url_loader.dart"
    "lib/screens/graph/group_node_screen.dart"

    # Files without tier annotations (not caught by Step 3)
    "scripts/reset_and_seed_inventory.dart"

    # Dead Pro/Scale feature files (safe to remove — no community code references)
    "lib/services/payment_service.dart"
    "lib/repositories/purchases_repository.dart"
    "lib/widgets/common/feature_purchase_sheet.dart"
)

SERVICES_REMOVED=0
for service in "${PRO_SERVICES[@]}"; do
    TARGET_FILE="${TEMP_DIR}/${service}"
    if [[ -f "${TARGET_FILE}" ]]; then
        rm "${TARGET_FILE}"
        log_info "  Removed service: ${service}"
        ((SERVICES_REMOVED++))
    fi
done
log_success "Removed ${SERVICES_REMOVED} Pro service files"

# Step 6: Apply community patches
log_info "Step 6: Applying community-specific patches..."
PATCHES_SCRIPT="${SCRIPT_DIR}/community-patches.sh"
if [[ -f "${PATCHES_SCRIPT}" ]]; then
    chmod +x "${PATCHES_SCRIPT}"
    "${PATCHES_SCRIPT}" "${TEMP_DIR}"
    log_success "Community patches applied successfully"
else
    log_warning "Community patches script not found at ${PATCHES_SCRIPT}"
fi

# Step 6b: Clean up backup files left by sed patching
log_info "Step 6b: Cleaning up backup files..."
BACKUP_COUNT=0
while IFS= read -r -d '' backup_file; do
    rm "$backup_file"
    ((BACKUP_COUNT++))
done < <(find "${TEMP_DIR}" \( -name "*''" -o -name "*.tmp" -o -name "*.bak" \) -print0 2>/dev/null || true)
log_success "Removed ${BACKUP_COUNT} backup/temp files"

# Step 7: Validate build with flutter analyze
log_info "Step 7: Validating build with flutter analyze..."
cd "${TEMP_DIR}"

# Ensure flutter dependencies are fetched
log_info "  Running flutter pub get..."
if ! flutter pub get > /dev/null 2>&1; then
    log_error "flutter pub get failed"
    exit 1
fi

# Run flutter analyze
log_info "  Running flutter analyze..."
if flutter analyze --no-fatal-infos --no-fatal-warnings; then
    log_success "Flutter analyze passed with no errors"
else
    log_error "Flutter analyze failed. The community build has errors."
    log_warning "Check the analysis output above for details."
    exit 1
fi

cd "${PROJECT_ROOT}"

# Step 8: Optionally push to community repo
if [[ -n "${COMMUNITY_REPO_URL}" ]]; then
    log_info "Step 8: Pushing to community repository..."
    cd "${TEMP_DIR}"

    # Initialize git if needed
    if [[ ! -d ".git" ]]; then
        git init
        git remote add origin "${COMMUNITY_REPO_URL}"
    fi

    # Stage all changes
    git add -A

    # Create commit
    COMMIT_MSG="chore: sync from main repository

Automated sync from seafoundry_app main repository
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
"

    git commit -m "${COMMIT_MSG}" || log_warning "No changes to commit"

    # Push to remote
    log_warning "  About to force push to ${COMMUNITY_REPO_URL}"
    log_warning "  This will overwrite the remote main branch"
    git push -u origin main --force

    log_success "Successfully pushed to community repository"
    cd "${PROJECT_ROOT}"
else
    log_info "Step 8: Skipping push to community repository (COMMUNITY_REPO_URL not set)"
    log_info "Community build available at: ${TEMP_DIR}"
fi

# Final summary
log_success "============================================"
log_success "Community OSS sync completed successfully!"
log_success "============================================"
log_info "Summary:"
log_info "  - ${PRO_FILES_COUNT} @tier: pro files removed"
log_info "  - ${DIRS_REMOVED} Pro/Scale directories removed"
log_info "  - ${SERVICES_REMOVED} Pro service files removed"
log_info "  - Build validated with flutter analyze"
log_info ""
log_info "Community build location: ${TEMP_DIR}"

if [[ -z "${COMMUNITY_REPO_URL}" ]]; then
    log_info ""
    log_info "To push to community repository, set COMMUNITY_REPO_URL:"
    log_info "  export COMMUNITY_REPO_URL=git@github.com:seafoundry/seafoundry-community.git"
    log_info "  ./scripts/sync-to-community.sh"
fi
