#!/bin/bash

# ROS2 Workspace Setup Script
# Interactive script to configure ROS2 workspace with Docker Compose

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/docker"
ENV_FILE="${DOCKER_DIR}/.env"
ACTIVE_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.active.yml"
CONFIG_FILE=""
DRY_RUN=false

# Default values
DEFAULT_AMENT_WORKSPACE_DIR="/ros2_ws"
DEFAULT_ROS_DOMAIN_ID="0"
DEFAULT_YOUR_IP="127.0.0.1"
DEFAULT_ROBOT_IP="127.0.0.1"
DEFAULT_ROBOT_HOSTNAME="P500"
DEFAULT_UID=$(id -u)
DEFAULT_GID=$(id -g)

# Configuration variables
SELECTED_VARIANT=""
AMENT_WORKSPACE_DIR=""
ROS_DOMAIN_ID=""
YOUR_IP=""
ROBOT_IP=""
ROBOT_HOSTNAME=""
UID_VALUE=""
GID_VALUE=""

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to print section header
print_header() {
    echo ""
    print_color "${BOLD}${CYAN}" "========================================"
    print_color "${BOLD}${CYAN}" "$1"
    print_color "${BOLD}${CYAN}" "========================================"
    echo ""
}

# Function to print error
print_error() {
    print_color "${RED}" "ERROR: $1"
}

# Function to print success
print_success() {
    print_color "${GREEN}" "✓ $1"
}

# Function to print warning
print_warning() {
    print_color "${YELLOW}" "⚠ $1"
}

# Function to print info
print_info() {
    print_color "${BLUE}" "ℹ $1"
}

# Function to show help
show_help() {
    cat << EOF
${BOLD}ROS2 Workspace Setup Script${NC}

${BOLD}USAGE:${NC}
    ./setup-workspace.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help              Show this help message
    -c, --config FILE       Use configuration file (YAML or JSON)
    --dry-run               Preview changes without applying them

${BOLD}DESCRIPTION:${NC}
    This script helps you set up your ROS2 workspace with Docker Compose.
    It provides an interactive menu to select Docker Compose configurations
    and configure environment variables.

${BOLD}INTERACTIVE MODE:${NC}
    Run without arguments for interactive setup:
        ./setup-workspace.sh

${BOLD}CONFIG FILE MODE:${NC}
    Use a configuration file for automated setup:
        ./setup-workspace.sh -c setup.yaml
        ./setup-workspace.sh --config setup.json

    See setup.example.yaml for configuration file format.

${BOLD}DOCKER COMPOSE VARIANTS:${NC}
    - base:         Basic ROS2 setup without GUI
    - gui:          Adds X11 forwarding for GUI applications
    - nvidia:       Adds NVIDIA GPU support
    - gui-nvidia:   Combines GUI and NVIDIA GPU support
    - vscode:       Development setup for VSCode

${BOLD}ENVIRONMENT VARIABLES:${NC}
    AMENT_WORKSPACE_DIR    Workspace directory (default: /ros2_ws)
    ROS_DOMAIN_ID          ROS 2 domain ID (default: 0)
    YOUR_IP                Your machine's IP address
    ROBOT_IP               Robot's IP address
    ROBOT_HOSTNAME         Robot's hostname
    UID                    User ID (auto-detected)
    GID                    Group ID (auto-detected)

EOF
}

# Function to detect NVIDIA GPU
detect_nvidia_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to get network interfaces and IPs
get_network_interfaces() {
    if command -v ip &> /dev/null; then
        ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1"
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1"
    else
        echo "127.0.0.1"
    fi
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if ((octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate number
validate_number() {
    local num=$1
    if [[ $num =~ ^[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# Function to backup existing configuration
backup_config() {
    if [ -f "$ENV_FILE" ] && [ "$DRY_RUN" = false ]; then
        local backup_file="${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        print_success "Backed up existing configuration to: $backup_file"
    fi
}

# Function to read configuration from YAML file
read_yaml_config() {
    local config_file=$1
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_info "Reading configuration from: $config_file"
    
    # Parse YAML using basic grep/sed (works for simple YAML)
    SELECTED_VARIANT=$(grep "variant:" "$config_file" | sed 's/.*variant:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    AMENT_WORKSPACE_DIR=$(grep "ament_workspace_dir:" "$config_file" | sed 's/.*ament_workspace_dir:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    ROS_DOMAIN_ID=$(grep "ros_domain_id:" "$config_file" | sed 's/.*ros_domain_id:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    YOUR_IP=$(grep "your_ip:" "$config_file" | sed 's/.*your_ip:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    ROBOT_IP=$(grep "robot_ip:" "$config_file" | sed 's/.*robot_ip:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    ROBOT_HOSTNAME=$(grep "robot_hostname:" "$config_file" | sed 's/.*robot_hostname:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    UID_VALUE=$(grep "uid:" "$config_file" | sed 's/.*uid:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    GID_VALUE=$(grep "gid:" "$config_file" | sed 's/.*gid:\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' ' || echo "")
    
    # Handle "auto" values
    if [ "$YOUR_IP" = "auto" ]; then
        YOUR_IP=$(get_network_interfaces | head -n 1)
        [ -z "$YOUR_IP" ] && YOUR_IP="$DEFAULT_YOUR_IP"
    fi
    
    if [ "$UID_VALUE" = "auto" ]; then
        UID_VALUE="$DEFAULT_UID"
    fi
    
    if [ "$GID_VALUE" = "auto" ]; then
        GID_VALUE="$DEFAULT_GID"
    fi
    
    # Set defaults if not found
    [ -z "$AMENT_WORKSPACE_DIR" ] && AMENT_WORKSPACE_DIR="$DEFAULT_AMENT_WORKSPACE_DIR"
    [ -z "$ROS_DOMAIN_ID" ] && ROS_DOMAIN_ID="$DEFAULT_ROS_DOMAIN_ID"
    [ -z "$YOUR_IP" ] && YOUR_IP="$DEFAULT_YOUR_IP"
    [ -z "$ROBOT_IP" ] && ROBOT_IP="$DEFAULT_ROBOT_IP"
    [ -z "$ROBOT_HOSTNAME" ] && ROBOT_HOSTNAME="$DEFAULT_ROBOT_HOSTNAME"
    [ -z "$UID_VALUE" ] && UID_VALUE="$DEFAULT_UID"
    [ -z "$GID_VALUE" ] && GID_VALUE="$DEFAULT_GID"
}

# Function to select Docker Compose variant
select_compose_variant() {
    print_header "Select Docker Compose Configuration"
    
    print_info "Available variants:"
    echo "  1) base         - Basic ROS2 setup without GUI"
    echo "  2) gui          - Adds X11 forwarding for GUI applications"
    echo "  3) nvidia       - Adds NVIDIA GPU support"
    echo "  4) gui-nvidia   - Combines GUI and NVIDIA GPU support"
    echo "  5) vscode       - Development setup for VSCode"
    echo ""
    
    # Auto-detect GPU
    if detect_nvidia_gpu; then
        print_success "NVIDIA GPU detected!"
        print_info "Consider using 'nvidia' or 'gui-nvidia' variant for GPU acceleration"
    fi
    
    echo ""
    while true; do
        read -p "$(print_color ${CYAN} "Enter your choice (1-5): ")" choice
        case $choice in
            1) SELECTED_VARIANT="base"; break;;
            2) SELECTED_VARIANT="gui"; break;;
            3) SELECTED_VARIANT="nvidia"; break;;
            4) SELECTED_VARIANT="gui-nvidia"; break;;
            5) SELECTED_VARIANT="vscode"; break;;
            *) print_error "Invalid choice. Please enter 1-5.";;
        esac
    done
    
    print_success "Selected variant: $SELECTED_VARIANT"
}

# Function to configure environment variables
configure_environment() {
    print_header "Configure Environment Variables"
    
    # AMENT_WORKSPACE_DIR
    read -p "$(print_color ${CYAN} "Workspace directory [${DEFAULT_AMENT_WORKSPACE_DIR}]: ")" input
    AMENT_WORKSPACE_DIR="${input:-$DEFAULT_AMENT_WORKSPACE_DIR}"
    
    # ROS_DOMAIN_ID
    while true; do
        read -p "$(print_color ${CYAN} "ROS Domain ID [${DEFAULT_ROS_DOMAIN_ID}]: ")" input
        ROS_DOMAIN_ID="${input:-$DEFAULT_ROS_DOMAIN_ID}"
        if validate_number "$ROS_DOMAIN_ID"; then
            break
        else
            print_error "Invalid domain ID. Please enter a number."
        fi
    done
    
    # YOUR_IP
    print_info "Detected network interfaces:"
    local ips=$(get_network_interfaces)
    if [ -n "$ips" ]; then
        local i=1
        while IFS= read -r ip; do
            echo "  $i) $ip"
            ((i++))
        done <<< "$ips"
        echo "  $i) Enter manually"
        echo "  $((i+1))) Use localhost (127.0.0.1)"
    else
        print_warning "No network interfaces detected"
    fi
    
    while true; do
        read -p "$(print_color ${CYAN} "Select your IP or enter manually [${DEFAULT_YOUR_IP}]: ")" input
        if [ -z "$input" ]; then
            YOUR_IP="$DEFAULT_YOUR_IP"
            break
        elif validate_number "$input"; then
            local selected_ip=$(echo "$ips" | sed -n "${input}p")
            if [ -n "$selected_ip" ]; then
                YOUR_IP="$selected_ip"
                break
            else
                YOUR_IP="$DEFAULT_YOUR_IP"
                break
            fi
        elif validate_ip "$input"; then
            YOUR_IP="$input"
            break
        else
            print_error "Invalid IP address. Please try again."
        fi
    done
    
    # ROBOT_IP
    while true; do
        read -p "$(print_color ${CYAN} "Robot IP address [${DEFAULT_ROBOT_IP}]: ")" input
        ROBOT_IP="${input:-$DEFAULT_ROBOT_IP}"
        if validate_ip "$ROBOT_IP"; then
            break
        else
            print_error "Invalid IP address. Please try again."
        fi
    done
    
    # ROBOT_HOSTNAME
    read -p "$(print_color ${CYAN} "Robot hostname [${DEFAULT_ROBOT_HOSTNAME}]: ")" input
    ROBOT_HOSTNAME="${input:-$DEFAULT_ROBOT_HOSTNAME}"
    
    # UID/GID
    print_info "Current user: $(whoami)"
    print_info "Current UID: $DEFAULT_UID"
    print_info "Current GID: $DEFAULT_GID"
    
    while true; do
        read -p "$(print_color ${CYAN} "User ID [${DEFAULT_UID}]: ")" input
        UID_VALUE="${input:-$DEFAULT_UID}"
        if validate_number "$UID_VALUE"; then
            break
        else
            print_error "Invalid UID. Please enter a number."
        fi
    done
    
    while true; do
        read -p "$(print_color ${CYAN} "Group ID [${DEFAULT_GID}]: ")" input
        GID_VALUE="${input:-$DEFAULT_GID}"
        if validate_number "$GID_VALUE"; then
            break
        else
            print_error "Invalid GID. Please enter a number."
        fi
    done
}

# Function to display summary
display_summary() {
    print_header "Configuration Summary"
    
    print_color "${BOLD}" "Docker Compose Variant:"
    echo "  ${SELECTED_VARIANT}"
    echo ""
    
    print_color "${BOLD}" "Environment Variables:"
    echo "  AMENT_WORKSPACE_DIR = ${AMENT_WORKSPACE_DIR}"
    echo "  ROS_DOMAIN_ID       = ${ROS_DOMAIN_ID}"
    echo "  YOUR_IP             = ${YOUR_IP}"
    echo "  ROBOT_IP            = ${ROBOT_IP}"
    echo "  ROBOT_HOSTNAME      = ${ROBOT_HOSTNAME}"
    echo "  UID                 = ${UID_VALUE}"
    echo "  GID                 = ${GID_VALUE}"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be applied"
        return
    fi
    
    read -p "$(print_color ${YELLOW} "Apply this configuration? (y/n): ")" confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Configuration cancelled"
        exit 0
    fi
}

# Function to apply configuration
apply_configuration() {
    if [ "$DRY_RUN" = true ]; then
        print_info "Would create/update: $ENV_FILE"
        print_info "Would create symlink: $ACTIVE_COMPOSE_FILE"
        return
    fi
    
    print_header "Applying Configuration"
    
    # Backup existing configuration
    backup_config
    
    # Write .env file
    cat > "$ENV_FILE" << EOF
AMENT_WORKSPACE_DIR=${AMENT_WORKSPACE_DIR}
ROS_DOMAIN_ID=${ROS_DOMAIN_ID}
YOUR_IP=${YOUR_IP}
ROBOT_IP=${ROBOT_IP}
ROBOT_HOSTNAME=${ROBOT_HOSTNAME}
UID=${UID_VALUE}
GID=${GID_VALUE}
EOF
    
    print_success "Updated: $ENV_FILE"
    
    # Create symlink for docker-compose file
    local compose_file="${DOCKER_DIR}/docker-compose"
    if [ "$SELECTED_VARIANT" != "base" ]; then
        compose_file="${compose_file}-${SELECTED_VARIANT}"
    fi
    compose_file="${compose_file}.yml"
    
    if [ ! -f "$compose_file" ]; then
        print_error "Docker compose file not found: $compose_file"
        exit 1
    fi
    
    # Remove old symlink if exists
    [ -L "$ACTIVE_COMPOSE_FILE" ] && rm "$ACTIVE_COMPOSE_FILE"
    [ -f "$ACTIVE_COMPOSE_FILE" ] && rm "$ACTIVE_COMPOSE_FILE"
    
    # Create new symlink
    ln -s "$compose_file" "$ACTIVE_COMPOSE_FILE"
    print_success "Created symlink: $ACTIVE_COMPOSE_FILE -> $compose_file"
}

# Function to display next steps
display_next_steps() {
    print_header "Setup Complete!"
    
    print_color "${BOLD}${GREEN}" "Your ROS2 workspace is now configured."
    echo ""
    print_color "${BOLD}" "Next Steps:"
    echo ""
    echo "1. Import VCS repositories (if not done already):"
    print_color "${CYAN}" "   cd src/ && vcs import < .repos"
    echo ""
    echo "2. Start the Docker container:"
    if [ "$SELECTED_VARIANT" = "vscode" ]; then
        print_color "${CYAN}" "   Open this folder in VSCode and reopen in container"
    else
        print_color "${CYAN}" "   docker compose -f docker-compose.active.yml up -d"
    fi
    echo ""
    echo "3. Connect to the container:"
    print_color "${CYAN}" "   docker exec -it ros2_docker bash"
    echo ""
    
    if [[ "$SELECTED_VARIANT" == *"gui"* ]]; then
        echo "4. For GUI applications, run on host:"
        print_color "${CYAN}" "   xhost +"
        echo ""
    fi
    
    print_info "Configuration file: $ENV_FILE"
    print_info "Active compose file: $ACTIVE_COMPOSE_FILE"
    echo ""
    print_color "${GREEN}" "Happy coding! 🚀"
}

# Main function
main() {
    print_header "ROS2 Workspace Setup"
    
    # Check if docker directory exists
    if [ ! -d "$DOCKER_DIR" ]; then
        print_error "Docker directory not found: $DOCKER_DIR"
        exit 1
    fi
    
    # If config file is provided, read from it
    if [ -n "$CONFIG_FILE" ]; then
        read_yaml_config "$CONFIG_FILE"
    else
        # Interactive mode
        select_compose_variant
        configure_environment
    fi
    
    # Display summary and confirm
    display_summary
    
    # Apply configuration
    apply_configuration
    
    # Display next steps
    display_next_steps
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
