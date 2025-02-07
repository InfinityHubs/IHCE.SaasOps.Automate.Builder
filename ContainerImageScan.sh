
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
# Map Gitlab CI/CD Variables to Local Variables                                                                        #
# ==================================================================================================================== #

# Map the Gitlab CI/CD variables to local variables for easier use in the build
readonly AUTOMATE_REGISTRY_IMAGE=$(echo "${CI_PROJECT_PATH}" | tr '[:upper:]' '[:lower:]')
readonly AUTOMATE_GIT_VERSION="${GitVersion_FullSemVer}"

# Define the image name (ensure this matches the loaded image)
readonly AUTOMATE_IMAGE_NAME="$AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION"

# Load the Docker image from the tar file
readonly AUTOMATE_IMAGE_TAR="$ARTIFACTS_DIR_CR_IMAGE-$AUTOMATE_GIT_VERSION.tar"

# Log the mapped variables (optional for debugging)
log_info "Automate.Git.Version -----> $AUTOMATE_GIT_VERSION"
log_info "Automate.Git.Pipeline ----> $AUTOMATE_REGISTRY_IMAGE"
log_info "Automate.Runner.Artifact -> $AUTOMATE_IMAGE_TAR"

# ==================================================================================================================== #
# Function to scan the Docker image for vulnerabilities                                                                #
# ==================================================================================================================== #

RunContextBuilder() {
    log_info "🔄 Container-Image-Scan"

    if [ ! -f "$AUTOMATE_IMAGE_TAR" ]; then
        log_error "❌ Tar file not found: $AUTOMATE_IMAGE_TAR"
        exit 1
    fi

    log_success "✅ Found tar file: $AUTOMATE_IMAGE_TAR"

    log_info "🔄 Loading the Docker image from the tar file..."
    if docker load < "$AUTOMATE_IMAGE_TAR"; then
        log_success "✅ Successfully loaded Docker image from $AUTOMATE_IMAGE_TAR"
    else
        log_error "❌ Failed to load Docker image"
        exit 1
    fi

    # Pull the Trivy scanner
    if docker pull aquasec/trivy:latest; then
        log_success "✅ Successfully pulled Trivy image"
    else
        log_error "❌ Failed to pull Trivy image"
        exit 1
    fi

    # Check if the image exists locally
    if docker images | grep -q "$AUTOMATE_REGISTRY_IMAGE"; then
        log_success "✅ Image $AUTOMATE_IMAGE_NAME is available locally."
    else
        log_error "❌ Image $AUTOMATE_IMAGE_NAME not found locally. Exiting."
        exit 1
    fi

    # Verify loaded Docker images
    log_info "🔍 Checking available Docker images..."
    docker images
    draw_line

    # Run the Trivy scan
    log_info "🔍 Starting Trivy scan for vulnerabilities..."

    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $(pwd):/project \
        aquasec/trivy:latest image \
        --format table \
        --exit-code 0 \
        --scanners vuln,secret \
        --show-suppressed \
        --severity CRITICAL,HIGH,MEDIUM \
        "$AUTOMATE_IMAGE_NAME"

    # --ignorefile /project/.trivyignore \

    draw_line  # Draw a separator
    log_success "✅ Scan completed successfully"
}

# ==================================================================================================================== #
# Main Script Execution                                                                                                 #
# ==================================================================================================================== #

# Now, execute the RunContextBuilder with the mapped variables
RunContextBuilder
