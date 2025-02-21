

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
# SCE.Automate.Pipelines                                                                                               #
# ==================================================================================================================== #

# Fetch the build script using curl
Roadmap="${Sce_Automate_Source}/${Sce_Automate_Pipelines}/$(echo "${CI_PROJECT_NAME}" | tr '[:upper:]' '[:lower:]')/roadmap.json"

# Fetch the JSON content and store it in a variable
Roadmap_Raw_Json=$(curl -sSL "$Roadmap")

# Check if the curl call failed
if [ $? -ne 0 ]; then
    echo "Failed to fetch the Sce_Automate_Pipelines artifactory hub details for ${CI_PROJECT_NAME} project."
    exit 1
fi

# ==================================================================================================================== #
# Parse the JSON into separate variables using basic shell tools (no associative arrays)                              #
# ==================================================================================================================== #

# Extract key-value pairs using jq, and store them into regular shell variables
R_ID=$(echo "$Roadmap_Raw_Json" | jq -r '.id // ""')
R_UNITY=$(echo "$Roadmap_Raw_Json" | jq -r '.unity // ""')
R_OFFERING=$(echo "$Roadmap_Raw_Json" | jq -r '.offering // ""')
R_PIPELINE=$(echo "$Roadmap_Raw_Json" | jq -r '.pipeline // ""')
R_INDEX=$(echo "$Roadmap_Raw_Json" | jq -r '.index // ""')
R_NAMESPACE=$(echo "$Roadmap_Raw_Json" | jq -r '.namespace // ""')
R_ARTIFACT_ID=$(echo "$Roadmap_Raw_Json" | jq -r '.artifact_id // ""')
R_TAG=$(echo "$Roadmap_Raw_Json" | jq -r '.tag // ""')

# ==================================================================================================================== #
# Map Gitlab CI/CD Variables to Local Variables                                                                        #
# ==================================================================================================================== #

# Map the Gitlab CI/CD variables to local variables for easier use in the build
readonly AUTOMATE_REGISTRY_IMAGE=$(echo "${CI_PROJECT_PATH}" | tr '[:upper:]' '[:lower:]')
#readonly AUTOMATE_REGISTRY_IMAGE2=$(echo "${CI_PROJECT_NAME}" | tr '[:upper:]' '[:lower:]')
readonly AUTOMATE_GIT_VERSION=$(echo "${GitVersion_FullSemVer}" | tr '[:upper:]' '[:lower:]')

# Define the image name (ensure this matches the loaded image)
readonly AUTOMATE_IMAGE_NAME="$AUTOMATE_REGISTRY_IMAGE:$AUTOMATE_GIT_VERSION"

# Load the Docker image from the tar file
readonly AUTOMATE_IMAGE_TAR="$ARTIFACTS_DIR_CR_IMAGE-$AUTOMATE_GIT_VERSION.tar"

# Load the Docker image from the tar file
readonly AUTOMATE_ARTIFACTORY_REPOSITORY="${R_INDEX}-${R_NAMESPACE}-${R_ARTIFACT_ID}"

# Convert Target Destinations repository name to lowercase for Docker compatibility
readonly AUTOMATE_TARGET_CR="${Sce_Automate_Docker_Hub}${AUTOMATE_ARTIFACTORY_REPOSITORY}:${AUTOMATE_GIT_VERSION}"

# Log the mapped variables (optional for debugging)
log_info "Automate.Git.Version -----> $AUTOMATE_GIT_VERSION"
log_info "Automate.Git.Pipeline ----> $AUTOMATE_REGISTRY_IMAGE"
log_info "Automate.Runner.Artifact -> $AUTOMATE_IMAGE_TAR"

# ==================================================================================================================== #
# Function to scan the Docker image for vulnerabilities                                                                #
# ==================================================================================================================== #

RunContextBuilder() {

    # Push Docker image to the registry
    log_info "🔄 Pushing Docker image to the Docker Container Registry..."

    if [ ! -f "$AUTOMATE_IMAGE_TAR" ]; then
        log_error "❌ Tar file not found: $AUTOMATE_IMAGE_TAR"
        exit 1
    fi

    log_success "✅ Found tar file: $AUTOMATE_IMAGE_TAR"

    log_info "🔄 Loading the Docker image from the tar file..."

    if docker load < "$AUTOMATE_IMAGE_TAR"; then
        log_success "✅ Successfully loaded Docker image from $AUTOMATE_IMAGE_TAR"
        log_info "Artifactory Images"
        docker images
        draw_line
        docker tag "$AUTOMATE_REGISTRY_IMAGE":"$AUTOMATE_GIT_VERSION" "$AUTOMATE_TARGET_CR"
        echo "$Sce_Automate_Docker_Hub_User_PAT" | docker login -u "$Sce_Automate_Docker_Hub_User" --password-stdin
        if docker --debug push "$AUTOMATE_TARGET_CR"; then
            log_info "\033[1m\033[0;34mCI Publish Artifacts Log Summary \033[0m"
            log_info "------------------------------------------------------------------------------"
            log_info "| SaasOps.Automate.Builder.Runner Artifact       | $AUTOMATE_REGISTRY_IMAGE"
            log_info "| SaasOps.Automate.Builder.Target Artifact       | $AUTOMATE_TARGET_CR"
            log_info "| SaasOps.Automate.Builder.Target Build Version  | $AUTOMATE_GIT_VERSION"
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
