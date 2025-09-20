#!/bin/bash

set -e

# Script location (for finding Dockerfile)
# Resolve symlink to get actual script location
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Default configuration
BASE_IMAGE_NAME="devtainer"
PLATFORM="linux/arm64"
MEMORY="4g"
MEMORY_SWAP="4g"
CPUS="2.0"
PIDS_LIMIT=100

# Generate container name from project path
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Load project configuration from .devtainer/config if it exists
load_project_config() {
    local config_file="$PROJECT_DIR/.devtainer/config"

    if [ -f "$config_file" ]; then
        # Source the config file
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)

            # Remove quotes from value if present
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"

            # Set variables (allow env var overrides with DEVTAINER_ prefix)
            case "$key" in
                MEMORY)
                    MEMORY="${DEVTAINER_MEMORY:-$value}"
                    ;;
                MEMORY_SWAP)
                    MEMORY_SWAP="${DEVTAINER_MEMORY_SWAP:-$value}"
                    ;;
                CPUS)
                    CPUS="${DEVTAINER_CPUS:-$value}"
                    ;;
                PIDS_LIMIT)
                    PIDS_LIMIT="${DEVTAINER_PIDS_LIMIT:-$value}"
                    ;;
                PLATFORM)
                    PLATFORM="${DEVTAINER_PLATFORM:-$value}"
                    ;;
                PORTS)
                    # Will be handled by get_custom_ports
                    ;;
            esac
        done < "$config_file"
    fi
}

# Load configuration
load_project_config

# Detect project-specific Dockerfile
PROJECT_DOCKERFILE=""
if [ -f "$PROJECT_DIR/.devtainer/Dockerfile" ]; then
    PROJECT_DOCKERFILE="$PROJECT_DIR/.devtainer/Dockerfile"
elif [ -f "$PROJECT_DIR/.devcontainer/Dockerfile" ]; then
    # Backward compatibility
    PROJECT_DOCKERFILE="$PROJECT_DIR/.devcontainer/Dockerfile"
elif [ -f "$PROJECT_DIR/Dockerfile.devtainer-local" ]; then
    PROJECT_DOCKERFILE="$PROJECT_DIR/Dockerfile.devtainer-local"
fi

# Set image and container names
if [ -n "$PROJECT_DOCKERFILE" ]; then
    IMAGE_NAME="${BASE_IMAGE_NAME}-${PROJECT_NAME}"
else
    IMAGE_NAME="$BASE_IMAGE_NAME"
fi

CONTAINER_NAME="devtainer-$(echo -n "$PROJECT_DIR" | md5sum | cut -d' ' -f1)"

# Helper functions
get_custom_ports() {
    local custom_ports=()

    # Read from .devtainer/config PORTS setting
    if [ -f "$PROJECT_DIR/.devtainer/config" ]; then
        local ports_value=$(grep "^PORTS=" "$PROJECT_DIR/.devtainer/config" | cut -d'=' -f2- | xargs)
        # Remove quotes if present
        ports_value="${ports_value%\"}"
        ports_value="${ports_value#\"}"
        ports_value="${ports_value%\'}"
        ports_value="${ports_value#\'}"

        if [ -n "$ports_value" ]; then
            IFS=',' read -ra config_ports <<< "$ports_value"
            for port in "${config_ports[@]}"; do
                port=$(echo "$port" | xargs)
                if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                    custom_ports+=("$port")
                fi
            done
        fi
    fi

    # Read from .devtainer.ports file if it exists (backward compatibility)
    if [ -f "$PROJECT_DIR/.devtainer.ports" ]; then
        while IFS= read -r port; do
            # Skip empty lines and comments
            [[ -z "$port" || "$port" =~ ^[[:space:]]*# ]] && continue
            # Trim whitespace
            port=$(echo "$port" | xargs)
            # Validate port number
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                custom_ports+=("$port")
            fi
        done < "$PROJECT_DIR/.devtainer.ports"
    fi

    # Read from DEVTAINER_PORTS environment variable (highest priority)
    if [ -n "$DEVTAINER_PORTS" ]; then
        IFS=',' read -ra env_ports <<< "$DEVTAINER_PORTS"
        for port in "${env_ports[@]}"; do
            port=$(echo "$port" | xargs)
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
                custom_ports+=("$port")
            fi
        done
    fi

    # Return unique ports
    printf '%s\n' "${custom_ports[@]}" | sort -u
}

build_port_flags() {
    local port_flags=""
    local all_ports=()

    # Add ports from config file or environment variable
    while IFS= read -r port; do
        all_ports+=("$port")
    done < <(get_custom_ports)

    # Build -p flags for each unique port
    for port in $(printf '%s\n' "${all_ports[@]}" | sort -u -n); do
        port_flags="$port_flags -p $port:$port"
    done

    echo "$port_flags"
}

build_project_image() {
    if [ -z "$PROJECT_DOCKERFILE" ]; then
        return 0
    fi

    echo "Building project-specific image: $IMAGE_NAME"
    echo "Using: $PROJECT_DOCKERFILE"

    # Check if base image exists
    if ! docker image inspect "$BASE_IMAGE_NAME" >/dev/null 2>&1; then
        echo "Base image '$BASE_IMAGE_NAME' not found. Building it first..."
        cmd_base_rebuild
    fi

    # Build project-specific image
    docker build --platform="$PLATFORM" -f "$PROJECT_DOCKERFILE" -t "$IMAGE_NAME" "$(dirname "$PROJECT_DOCKERFILE")"
    echo "Project image built successfully: $IMAGE_NAME"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [ARGS...]

Commands:
    shell                 Start interactive bash shell in project container
    exec <command>        Execute command in project container
    stop                  Stop the project container
    clean                 Stop and remove the project container
    rebuild               Rebuild the current image (base or project-specific)
    base-rebuild          Rebuild the base devtainer image
    init [--with-dockerfile]  Initialize .devtainer/ configuration for current project
    path                  Show path to base Dockerfile
    edit                  Edit base Dockerfile in \$EDITOR
    info                  Show devtainer configuration and status
    help                  Show this help message

Project Configuration (.devtainer/):
    Run 'devtainer init' to create a .devtainer/ directory with:

    .devtainer/config     - Resource limits, ports, platform settings
    .devtainer/Dockerfile - Optional: extend base image with project dependencies

Networking:
    - No ports forwarded by default (prevents conflicts between multiple containers)
    - Forward ports via .devtainer/config PORTS setting or DEVTAINER_PORTS env var
    - Access host services from container via: host.docker.internal:PORT

Quick Start:
    # Initialize a new project
    $(basename "$0") init --with-dockerfile

    # Edit configuration
    vim .devtainer/config

    # Start development environment
    $(basename "$0") shell

Examples:
    $(basename "$0") init --with-dockerfile  # Initialize with Dockerfile template
    $(basename "$0") shell                   # Start shell (auto-builds if needed)
    $(basename "$0") exec make test          # Run command in container

    # Override settings with environment variables
    DEVTAINER_MEMORY=16g DEVTAINER_CPUS=8.0 $(basename "$0") shell

Accessing host services from container:
    psql -h host.docker.internal -p 5432 -U postgres
    redis-cli -h host.docker.internal -p 6379

For more information, see the documentation or run 'devtainer info' in your project.
EOF
}

ensure_container_running() {
    # Build project-specific image if needed
    if [ -n "$PROJECT_DOCKERFILE" ]; then
        if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
            build_project_image
        fi
    fi

    # Check if image exists
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "Error: Image '$IMAGE_NAME' not found. Run '$(basename "$0") rebuild' first."
        exit 1
    fi

    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        # Container exists, check if it's running
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Starting existing container: $CONTAINER_NAME"
            docker start "$CONTAINER_NAME" > /dev/null
        fi
    else
        # Build port forwarding flags
        local port_flags=$(build_port_flags)

        # Create new container
        echo "Creating new container: $CONTAINER_NAME"
        echo "Image: $IMAGE_NAME"
        echo "Project: $PROJECT_DIR"
        local forwarded_ports=$(get_custom_ports | xargs)
        if [ -n "$forwarded_ports" ]; then
            echo "Forwarding ports: $forwarded_ports"
        else
            echo "Forwarding ports: none"
        fi

        docker run -d \
            --name "$CONTAINER_NAME" \
            --platform="$PLATFORM" \
            --memory="$MEMORY" \
            --memory-swap="$MEMORY_SWAP" \
            --cpus="$CPUS" \
            --pids-limit=$PIDS_LIMIT \
            --add-host=host.docker.internal:host-gateway \
            $port_flags \
            -v "$PROJECT_DIR:$PROJECT_DIR" \
            -w "$PROJECT_DIR" \
            "$IMAGE_NAME" \
            tail -f /dev/null > /dev/null
    fi
}

cmd_shell() {
    ensure_container_running
    echo "Entering shell in container: $CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_exec() {
    if [ $# -eq 0 ]; then
        echo "Error: exec command requires arguments"
        usage
        exit 1
    fi
    ensure_container_running
    docker exec -it "$CONTAINER_NAME" "$@"
}

cmd_stop() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Stopping container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" > /dev/null
    else
        echo "Container $CONTAINER_NAME is not running"
    fi
}

cmd_clean() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Removing container: $CONTAINER_NAME"
        docker rm -f "$CONTAINER_NAME" > /dev/null
    else
        echo "Container $CONTAINER_NAME does not exist"
    fi
}

cmd_rebuild() {
    if [ -n "$PROJECT_DOCKERFILE" ]; then
        echo "Rebuilding project-specific image: $IMAGE_NAME"
        build_project_image
    else
        echo "Rebuilding base image: $BASE_IMAGE_NAME"
        cmd_base_rebuild
    fi
    echo "Rebuild complete. Run '$(basename "$0") clean' to recreate containers with new image."
}

cmd_base_rebuild() {
    echo "Rebuilding base $BASE_IMAGE_NAME image..."
    docker build --platform="$PLATFORM" -f "$SCRIPT_DIR/Dockerfile.devtainer" -t "$BASE_IMAGE_NAME" "$SCRIPT_DIR"
    echo "Base image rebuild complete."
}

cmd_path() {
    echo "$SCRIPT_DIR/Dockerfile.devtainer"
}

cmd_edit() {
    local dockerfile="$SCRIPT_DIR/Dockerfile.devtainer"
    local editor="${EDITOR:-${VISUAL:-vim}}"

    if [ ! -f "$dockerfile" ]; then
        echo "Error: Dockerfile not found at $dockerfile"
        exit 1
    fi

    echo "Opening $dockerfile in $editor..."
    "$editor" "$dockerfile"
}

cmd_info() {
    echo "=== Devtainer Configuration ==="
    echo "Script location:      $SCRIPT_DIR"
    echo "Base Dockerfile:      $SCRIPT_DIR/Dockerfile.devtainer"
    echo "Base image:           $BASE_IMAGE_NAME"
    echo ""
    echo "=== Current Project ==="
    echo "Project directory:    $PROJECT_DIR"
    echo "Project name:         $PROJECT_NAME"

    if [ -f "$PROJECT_DIR/.devtainer/config" ]; then
        echo "Config file:          .devtainer/config (found)"
    else
        echo "Config file:          None (using defaults)"
    fi

    if [ -n "$PROJECT_DOCKERFILE" ]; then
        echo "Project Dockerfile:   $PROJECT_DOCKERFILE"
        echo "Project image:        $IMAGE_NAME"
        echo "Type:                 Project-specific (extends base)"
    else
        echo "Type:                 Using base image"
        echo "Image:                $IMAGE_NAME"
    fi

    echo ""
    echo "=== Container Status ==="
    echo "Container name:       $CONTAINER_NAME"

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            echo "Status:               Running"
        else
            echo "Status:               Stopped"
        fi
    else
        echo "Status:               Not created"
    fi

    echo ""
    echo "=== Resource Limits ==="
    echo "Platform:             $PLATFORM"
    echo "Memory:               $MEMORY"
    echo "CPUs:                 $CPUS"
    echo "PIDs limit:           $PIDS_LIMIT"

    echo ""
    echo "=== Port Forwarding ==="
    local custom_ports=$(get_custom_ports | xargs)
    if [ -n "$custom_ports" ]; then
        echo "Forwarding ports:     $custom_ports"
    else
        echo "Forwarding ports:     none (configure in .devtainer/config or DEVTAINER_PORTS)"
    fi
}

cmd_init() {
    local with_dockerfile=false

    # Parse flags
    for arg in "$@"; do
        case "$arg" in
            --with-dockerfile)
                with_dockerfile=true
                ;;
        esac
    done

    # Check if .devtainer already exists
    if [ -d "$PROJECT_DIR/.devtainer" ]; then
        echo "Error: .devtainer directory already exists"
        echo "Remove it first or edit the existing configuration"
        exit 1
    fi

    echo "Initializing devtainer configuration for: $PROJECT_NAME"
    echo ""

    # Create .devtainer directory
    mkdir -p "$PROJECT_DIR/.devtainer"

    # Create config file with template
    cat > "$PROJECT_DIR/.devtainer/config" <<'EOF'
# Devtainer Configuration
# All settings are optional. Uncomment and modify as needed.

# === Resource Limits ===
# Memory limit for the container
#MEMORY=4g

# Memory + swap limit
#MEMORY_SWAP=4g

# CPU limit (number of CPUs, can be fractional like 2.5)
#CPUS=2.0

# Maximum number of processes
#PIDS_LIMIT=100

# === Platform ===
# Target platform (linux/arm64, linux/amd64, etc.)
#PLATFORM=linux/arm64

# === Port Forwarding ===
# Comma-separated list of ports to forward from container to host
# No ports are forwarded by default - only forward what you need
#PORTS=3000,5432,6379

# === Custom Environment Variables ===
# Add any custom variables your project needs
# CUSTOM_VAR=value
EOF

    echo "✓ Created .devtainer/config"

    # Create Dockerfile template if requested
    if [ "$with_dockerfile" = true ]; then
        cat > "$PROJECT_DIR/.devtainer/Dockerfile" <<'EOF'
# Extend the base devtainer image
FROM devtainer:latest

# Switch to root for system package installation
# (base image uses 'dev' user, but apt-get needs root permissions)
USER root

# Add project-specific system packages
# Example:
# RUN apt-get update && apt-get install -y \
#     postgresql-client \
#     redis-tools \
#     && rm -rf /var/lib/apt/lists/*

# Switch back to dev user for non-root operations
USER dev
WORKDIR /home/dev

# Install project-specific Node.js packages (as dev user)
# RUN . $NVM_DIR/nvm.sh && npm install -g some-cli-tool

# Install project-specific Python packages (as dev user)
# RUN pip install --user --no-cache-dir some-package

# Install project-specific Go tools (as dev user)
# RUN . ~/.gvm/scripts/gvm && go install github.com/some/tool@latest

# Set additional environment variables if needed
# ENV MY_VAR=value
EOF
        echo "✓ Created .devtainer/Dockerfile"
    fi

    echo ""
    echo "=== Setup Complete ==="
    echo ""
    echo "Next steps:"
    echo "  1. Edit .devtainer/config to customize resource limits and ports"

    if [ "$with_dockerfile" = true ]; then
        echo "  2. Edit .devtainer/Dockerfile to add project-specific dependencies"
        echo "  3. Run 'devtainer rebuild' to build your project image"
        echo "  4. Run 'devtainer shell' to start your development environment"
    else
        echo "  2. Run 'devtainer shell' to start your development environment"
        echo ""
        echo "To add project-specific dependencies:"
        echo "  - Run 'devtainer init --with-dockerfile' to create a Dockerfile template"
        echo "  - Or manually create .devtainer/Dockerfile"
    fi

    echo ""
    echo "For more information, run 'devtainer help'"
}

# Main command routing
COMMAND=${1:-shell}
shift || true

case "$COMMAND" in
    shell)
        cmd_shell
        ;;
    exec)
        cmd_exec "$@"
        ;;
    stop)
        cmd_stop
        ;;
    clean)
        cmd_clean
        ;;
    rebuild)
        cmd_rebuild
        ;;
    base-rebuild)
        cmd_base_rebuild
        ;;
    init)
        cmd_init "$@"
        ;;
    path)
        cmd_path
        ;;
    edit)
        cmd_edit
        ;;
    info)
        cmd_info
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        usage
        exit 1
        ;;
esac
