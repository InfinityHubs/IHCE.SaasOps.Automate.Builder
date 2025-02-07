#!/bin/sh

# ==================================================================================================================== #
# InfinityHubs-Connected-Enterprises.SaasOps.Automate.Builder - Build and Package Docker Image Script                  #
# ==================================================================================================================== #

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Exit immediately if an unset variable is referenced.

# Ensure the script has execution permissions
if [ ! -x "$0" ]; then
  chmod +x "$0"
fi

# ==================================================================================================================== #
# Logging Functions Section                                                                                            #
# ==================================================================================================================== #

# Define log levels as constants
readonly INFO="INFO"
readonly ERROR="ERROR"
readonly SUCCESS="SUCCESS"
readonly UNKNOWN="UNKNOWN"

# Define color codes for log messages (optional for better visibility)
readonly RESET="\033[0m"
readonly GREEN="\033[32m"
readonly RED="\033[31m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"

# Function to print a message in a box
print_box() {
    local COLOR="$1"
    local MESSAGE="$2"
    local BOX_WIDTH=70
    local MESSAGE_LENGTH=${#MESSAGE}
    local PADDING=$(( (BOX_WIDTH - MESSAGE_LENGTH - 2) / 2 ))
    local PADDING_LEFT=$PADDING
    local PADDING_RIGHT=$PADDING

    # Adjust padding if the message length is odd
    if [ $((MESSAGE_LENGTH % 2)) -ne 0 ]; then
        PADDING_RIGHT=$((PADDING_RIGHT + 1))
    fi

    # Print the top border of the box
    printf "${COLOR}╭%*s╮${RESET}\n" "$BOX_WIDTH" "" | tr ' ' '─'

    # Print the message centered in the box
    printf "${COLOR}│%*s%s%*s│${RESET}\n" "$PADDING_LEFT" "" "$MESSAGE" "$PADDING_RIGHT" ""

    # Print the bottom border of the box
    printf "${COLOR}╰%*s╯${RESET}\n" "$BOX_WIDTH" "" | tr ' ' '─'
}

# Function to log messages with timestamps and optional colors
log_message() {
    local LOG_LEVEL="$1"
    local MESSAGE="$2"
    local DATE_TIME
    DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")

    # Determine color based on log level
    local COLOR="$RESET"
    case "$LOG_LEVEL" in
        "$INFO") COLOR="$BLUE" ;;
        "$ERROR") COLOR="$RED" ;;
        "$SUCCESS") COLOR="$GREEN" ;;
        "$UNKNOWN") COLOR="$YELLOW" ;;
    esac

    # Format the log message with timestamp
    local FORMATTED_MESSAGE="[${LOG_LEVEL}] ${DATE_TIME} - ${MESSAGE}"

    # Print the log message in a box
    print_box "$COLOR" "$FORMATTED_MESSAGE"
}

# Shortcut functions to log specific log levels
log_info() { log_message "$INFO" "$1"; }
log_error() { log_message "$ERROR" "$1"; }
log_success() { log_message "$SUCCESS" "$1"; }
log_unknown() { log_message "$UNKNOWN" "$1"; }

# Function to log a block of messages inside a single box
log_box() {
    local COLOR="$1"
    local MESSAGES="$2"
    local BOX_WIDTH=70

    # Print the top border of the box
    printf "${COLOR}╭%*s╮${RESET}\n" "$BOX_WIDTH" "" | tr ' ' '─'

    # Print each message in the box
    echo "$MESSAGES" | while IFS= read -r line; do
        printf "${COLOR}│ %-${BOX_WIDTH}s │${RESET}\n" "$line"
    done

    # Print the bottom border of the box
    printf "${COLOR}╰%*s╯${RESET}\n" "$BOX_WIDTH" "" | tr ' ' '─'
}

# Draw separator line
draw_line() { log_info "==================================================================="; }

# ==================================================================================================================== #
# Map Gitlab CI/CD Variables to Local Variables                                                                        #
# ==================================================================================================================== #

# Map the Gitlab CI/CD variables to local variables for easier use in the build
readonly AUTOMATE_REGISTRY_IMAGE=$(echo "${CI_PROJECT_PATH}" | tr '[:upper:]' '[:lower:]')
readonly AUTOMATE_GIT_VERSION="${GitVersion_FullSemVer}"

# Log the mapped variables (optional for debugging)
log_info "SaaSops.Project.Path --> $AUTOMATE_REGISTRY_IMAGE"
log_info "SaaSops.Git.Version --> $AUTOMATE_GIT_VERSION"

# ==================================================================================================================== #
# Build and Package Function                                                                                           #
# ==================================================================================================================== #

RunContextBuilder() {
    log_info "=== Starting Build-and-Package ==="

    # Pre-build cleanup (optional, to remove dangling images)
    log_info "Cleaning up unused Docker resources..."
    docker system prune --force --filter "until=24h"
    draw_line  # Draw line after cleanup operation

    # Build Docker image
    log_info "🚀🔨 Hold tight! Docker build initiated....... 🔨🚀"
    if docker build --pull --no-cache -t "$AUTOMATE_REGISTRY_IMAGE":"$AUTOMATE_GIT_VERSION" .; then
        # Log the following messages inside a single box
        local BOX_MESSAGES=""
        BOX_MESSAGES+="CI Docker image built successfully\n"
        BOX_MESSAGES+="===================================================================\n"
        BOX_MESSAGES+="| CR-Image-Artifact | $AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION\n"
        BOX_MESSAGES+="===================================================================\n"
        BOX_MESSAGES+="$(docker images | grep "$AUTOMATE_REGISTRY_IMAGE" | grep "$AUTOMATE_GIT_VERSION")\n"
        BOX_MESSAGES+="===================================================================\n"
        BOX_MESSAGES+="[SUCCESS] 🚀 Hold on, moving on to the next step... ✨"

        # Log the box with the messages
        log_box "$GREEN" "$BOX_MESSAGES"
    else
        log_error "[ERROR] Docker image build failed. Please check the build logs for details and ensure that all necessary files and configurations are in place properly."
        exit 1
    fi
    draw_line  # Draw line after build operation

    # Post-build steps (optional)
    log_info "🔍 Post-build validation in progress..."

    # Validate if the image exists
    if docker inspect "$AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION" > /dev/null 2>&1; then
        log_success "✅ [SUCCESS] Image $AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION exists."
        docker save "$AUTOMATE_REGISTRY_IMAGE":"$AUTOMATE_GIT_VERSION" > "$ARTIFACTS_DIR_CR_IMAGE-$AUTOMATE_GIT_VERSION.tar"
        log_info "Container Artifact Capturing"
        log_info "==================================================================="
        log_info "| Status   | ✅ "
        log_info "==================================================================="
        log_success "[SUCCESS] 🚀 Hold on, moving on to the next step... ✨"
    else
        log_error "❌ [ERROR] Post Validation for $AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION failed."
        exit 1
    fi

    draw_line  # Draw line after post-build validation

    log_info "=== Build-and-Package Complete ==="
}

# ==================================================================================================================== #
# Main Script Execution                                                                                                #
# ==================================================================================================================== #

# Now, execute the build with the mapped variables
RunContextBuilder
