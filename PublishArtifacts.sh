

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
draw_line() { log_info "===================================================================================================================="; }

# ==================================================================================================================== #
# Map GitHub CI/CD Variables to Local Variables                                                                        #
# ==================================================================================================================== #

# Map the GitHub CI/CD variables to local variables for easier use in the build
CI_REGISTRY_IMAGE="${GITHUB_REPOSITORY}"
CI_PIPELINE_IID="${GITHUB_RUN_NUMBER}"

# Convert repository name to lowercase for Docker compatibility
CI_REGISTRY_IMAGE=$(echo "$CI_REGISTRY_IMAGE" | tr '[:upper:]' '[:lower:]')

# Define the image name (ensure this matches the loaded image)
IMAGE_NAME="$CI_REGISTRY_IMAGE:$CI_PIPELINE_IID"

# Load the Docker image from the tar file
IMAGE_TAR="$ARTIFACTS_DIR_CR_IMAGE-$CI_PIPELINE_IID.tar"

# Convert Target Destinations repository name to lowercase for Docker compatibility
TargetVersion="${GHP_TargetVersion}"
TargetHub="docker.io/$(echo ${GITHUB_REPOSITORY} | tr '[:upper:]' '[:lower:]')"

# Log the mapped variables (optional for debugging)
log_info "Mapped CI_REGISTRY_IMAGE: $CI_REGISTRY_IMAGE"
log_info "Mapped CI_PIPELINE_IID: $CI_PIPELINE_IID"
log_info "Mapped CI_REGISTRY_IMAGE: $CI_REGISTRY_IMAGE"
log_info "Mapped IMAGE_NAME: $IMAGE_NAME"
log_info "Mapped IMAGE_TAR: $IMAGE_TAR"

# ==================================================================================================================== #
# Function to scan the Docker image for vulnerabilities                                                                #
# ==================================================================================================================== #

RunContextBuilder() {

    # Push Docker image to the registry
    log_info "🔄 Pushing Docker image to the Docker Container Registry..."

    if [ ! -f "$IMAGE_TAR" ]; then
        log_error "❌ Tar file not found: $IMAGE_TAR"
        exit 1
    fi

    log_success "✅ Found tar file: $IMAGE_TAR"

    log_info "🔄 Loading the Docker image from the tar file..."

    if docker load < "$IMAGE_TAR"; then
        log_success "✅ Successfully loaded Docker image from $IMAGE_TAR"
        log_info "Artifactory Images"
        docker images
        draw_line
        docker tag "$CI_REGISTRY_IMAGE":"$CI_PIPELINE_IID" "$TargetHub":"$TargetVersion"
        # echo "$CI_REGISTRY_PASSWORD" | docker login ghcr.io -u "$CI_REGISTRY_USER" --password-stdin
        echo "$DOCKERHUB_PASSWORD" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
        if docker --debug push "$TargetHub":"$TargetVersion"; then
            log_info "\033[1m\033[0;34mCI Publish Artifacts Log Summary \033[0m"
            log_info "------------------------------------------------------------------------------"
            log_info "| SaasOps.Automate.Builder.Runner Artifact       | $CI_REGISTRY_IMAGE:$CI_PIPELINE_IID"
            log_info "| SaasOps.Automate.Builder.Target Artifact       | $TargetHub:$TargetVersion"
            log_info "| SaasOps.Automate.Builder.Target Build Version  | $TargetVersion"
            log_info "------------------------------------------------------------------------------"
            log_success "✅ [SUCCESS] 🚀 Docker image pushed successfully....✨"
        else
            log_error "❌ Docker image push failed. Check detailed logs above for more information."
            exit 1
        fi
    else
        log_error "❌ Failed to load Docker image"
        exit 1
    fi
}

# ==================================================================================================================== #
# Main Script Execution                                                                                                 #
# ==================================================================================================================== #

# Now, execute the RunContextBuilder with the mapped variables
RunContextBuilder
