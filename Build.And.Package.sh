#!/bin/sh

# ==================================================================================================================== #
# InfinityHubs-Connected-Enterprises.SaasOps.Automate.Builder - Build and Package Docker Image Script                  #
# ==================================================================================================================== #

set -e  # Exit immediately if a command exits with a non-zero status.

# Ensure the script has execution permissions
if [ ! -x "$0" ]; then
  chmod +x "$0"
fi

# ==================================================================================================================== #
# Logging Functions Section                                                                                            #
# ==================================================================================================================== #

# Define log levels as constants
INFO="INFO"
ERROR="ERROR"
SUCCESS="SUCCESS"
UNKNOWN="UNKNOWN"

# Define color codes for log messages (optional for better visibility)
RESET="\033[0m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"

# Function to log messages with timestamps and optional colors
log_message() {
    local LOG_LEVEL="$1"
    local MESSAGE="$2"
    local DATE_TIME
    DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")

    # Determine color based on log level
    local COLOR="$RESET"
    case "$LOG_LEVEL" in
        $INFO)
            COLOR="$BLUE"
            ;;
        $ERROR)
            COLOR="$RED"
            ;;
        $SUCCESS)
            COLOR="$GREEN"
            ;;
        $UNKNOWN)
            COLOR="$YELLOW"
            ;;
    esac

    # Print the log message with color and timestamp
    echo -e "${COLOR}[$LOG_LEVEL] $DATE_TIME - $MESSAGE${RESET}"
}

# Shortcut functions to log specific log levels
log_info() { log_message "$INFO" "$1"; }
log_error() { log_message "$ERROR" "$1"; }
log_success() { log_message "$SUCCESS" "$1"; }
log_unknown() { log_message "$UNKNOWN" "$1"; }

# Draw separator line
draw_line() { echo "------------------------------------------------------------"; }

# ==================================================================================================================== #
# Map GitHub CI/CD Variables to Local Variables                                                                        #
# ==================================================================================================================== #

# Map the GitHub CI/CD variables to local variables for easier use in the build
CI_REGISTRY_IMAGE="${GITHUB_REPOSITORY}"
CI_PIPELINE_IID="${GITHUB_RUN_NUMBER}"

# Convert repository name to lowercase for Docker compatibility
CI_REGISTRY_IMAGE=$(echo "$CI_REGISTRY_IMAGE" | tr '[:upper:]' '[:lower:]')

# Log the mapped variables (optional for debugging)
log_info "Mapped CI_REGISTRY_IMAGE: $CI_REGISTRY_IMAGE"
log_info "Mapped CI_PIPELINE_IID: $CI_PIPELINE_IID"

# ==================================================================================================================== #
# Build and Package Function                                                                                           #
# ==================================================================================================================== #

Run() {
    log_info "=== Starting Build-and-Package ==="

    # Pre-build cleanup (optional, to remove dangling images)
    log_info "Cleaning up unused Docker resources..."
    docker system prune --force --filter "until=24h"
    draw_line  # Draw line after cleanup operation

    # Build Docker image
    log_info "🚀🔨 \033[1mHold tight! Docker build initiated.......\033[0m 🔨🚀\n\n"
    if docker build --pull --no-cache -t "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID" .; then
        log_info "\033[1m\033[0;34m CI Docker image built successfully \033[0m"
        log_info "------------------------------------------------------------------------------"
        log_info "| Container Registry Image | $CI_REGISTRY_IMAGE:$CI_PIPELINE_IID"
        log_info "------------------------------------------------------------------------------"
        docker images | grep "$CI_REGISTRY_IMAGE" | grep "$CI_PIPELINE_IID"
        log_info "------------------------------------------------------------------------------"
        log_success "[SUCCESS] 🚀 Hold on, moving on to the next step... ✨"
    else
        log_error "[ERROR] Docker image build failed. Please check the build logs for details and ensure that all necessary files and configurations are in place properly."
        exit 1
    fi
    draw_line  # Draw line after build operation

    # Post-build steps (optional)
    log_info "🔍 Post-build validation in progress..."

    # Validate if the image exists
    if docker inspect "$CI_REGISTRY_IMAGE:$CI_PIPELINE_IID" > /dev/null 2>&1; then
        log_success "✅ [SUCCESS] Image $CI_REGISTRY_IMAGE:$CI_PIPELINE_IID exists."
        docker save "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID" > $ARTIFACTS_DIR_CR_IMAGE-"$CI_PIPELINE_IID".tar
        log_info "\033[1m\033[0;34m Container Artifact Capturing \033[0m"
        log_info "------------------------------------------------------------------------------"
        log_info "| Status   | ✅"
        log_info "------------------------------------------------------------------------------"
        log_success "[SUCCESS] 🚀 Hold on, moving on to the next step... ✨"
    else
        log_error "❌ [ERROR] Post Validation for $CI_REGISTRY_IMAGE:$CI_PIPELINE_IID failed."
        exit 1
    fi

    draw_line  # Draw line after post-build validation

    log_info "=== Build-and-Package Complete ==="
}

# ==================================================================================================================== #
# Main Script Execution                                                                                                 #
# ==================================================================================================================== #

# Now, execute the build with the mapped variables
Run
