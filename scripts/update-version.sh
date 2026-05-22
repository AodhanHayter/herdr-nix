#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly UPSTREAM_REPO="ogulcancelik/herdr"
readonly RELEASE_BASE_URL="https://github.com/${UPSTREAM_REPO}/releases/download"
readonly LATEST_RELEASE_API="https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"

readonly NATIVE_PLATFORMS=("macos-aarch64" "macos-x86_64" "linux-x86_64" "linux-aarch64")

readonly MAX_RETRIES=3
readonly RETRY_BASE_DELAY=2

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

retry() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        local result
        result=$("$@") && [ -n "$result" ] && { echo "$result"; return 0; }

        if ((attempt < max_attempts)); then
            local delay=$((base_delay ** attempt))
            log_warn "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
    done

    return 1
}

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' package.nix | head -1 || echo "unknown"
}

fetch_latest_tag() {
    local auth_header=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    curl -sf --max-time 15 "${auth_header[@]}" "$LATEST_RELEASE_API" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
        | head -1
}

get_latest_version_from_github() {
    local tag
    tag=$(retry "$MAX_RETRIES" "$RETRY_BASE_DELAY" fetch_latest_tag) || return 1
    # strip leading "v"
    echo "${tag#v}"
}

fetch_native_hash() {
    local version="$1"
    local platform="$2"
    local binary_url="${RELEASE_BASE_URL}/v${version}/herdr-${platform}"
    nix-prefetch-url --type sha256 "$binary_url" 2>/dev/null | tail -1 | tr -d '\n'
}

update_package_version() {
    local version="$1"
    sed -i.bak "s/version = \".*\"/version = \"$version\"/" package.nix
}

update_native_hash() {
    local platform="$1"
    local hash="$2"
    local temp_file=$(mktemp)

    awk -v platform="$platform" -v hash="$hash" '
        /nativeHashes = \{/ { in_native_block=1 }
        in_native_block && $0 ~ "\"" platform "\"" {
            sub(/= "[^"]*"/, "= \"" hash "\"")
        }
        in_native_block && /\};/ { in_native_block=0 }
        { print }
    ' package.nix > "$temp_file"
    mv "$temp_file" package.nix
}

cleanup_backup_files() {
    rm -f package.nix.bak
}

update_to_version() {
    local new_version="$1"

    log_info "Updating to version $new_version..."

    update_package_version "$new_version"

    log_info "Fetching native binary hashes..."
    for platform in "${NATIVE_PLATFORMS[@]}"; do
        log_info "  Fetching hash for $platform..."
        local native_hash
        native_hash=$(fetch_native_hash "$new_version" "$platform")
        if [ -z "$native_hash" ]; then
            log_error "Failed to fetch native hash for $platform"
            mv package.nix.bak package.nix
            exit 1
        fi
        log_info "  $platform: $native_hash"
        update_native_hash "$platform" "$native_hash"
    done

    cleanup_backup_files

    log_info "Verifying build..."
    if ! nix build .#herdr --no-link > /dev/null 2>&1; then
        log_warn "Build verification skipped or failed for current host platform (cross-platform hashes still updated)."
    else
        log_info "Build successful!"
    fi
    return 0
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "package.nix" ]; then
        log_error "flake.nix or package.nix not found. Please run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v nix-prefetch-url >/dev/null 2>&1 || { log_error "nix-prefetch-url is required but not installed."; exit 1; }
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to specific version"
    echo "  --check            Only check for updates, don't apply"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Update to latest version"
    echo "  $0 --check            # Check if update is available"
    echo "  $0 --version 0.6.1    # Update to specific version"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

update_flake_lock() {
    if command -v nix >/dev/null 2>&1; then
        log_info "Updating flake.lock..."
        nix flake update
    fi
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat package.nix flake.lock 2>/dev/null || true
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args
    args=$(parse_arguments "$@")
    local target_version
    target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only
    check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version
    current_version=$(get_current_version)
    local latest_version

    if [ -n "$target_version" ]; then
        latest_version="${target_version#v}"
    else
        latest_version=$(get_latest_version_from_github) || true
        if [ -z "$latest_version" ]; then
            log_error "Failed to fetch latest version from GitHub after $MAX_RETRIES attempts"
            exit 1
        fi
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date!"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version → $latest_version"
        exit 1  # Non-zero signals that an update is available
    fi

    update_to_version "$latest_version"

    log_info "Successfully updated herdr from $current_version to $latest_version"

    update_flake_lock
    show_changes
}

main "$@"
