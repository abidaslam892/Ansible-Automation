#!/bin/bash

# WanderList Ansible Management Script
# This script helps manage the Ansible Docker container for WanderList

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.ansible.yml"
CONTAINER_NAME="wanderlist-ansible"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to start Ansible container
start_ansible() {
    print_status "Starting Ansible container..."
    docker-compose -f "$COMPOSE_FILE" up -d ansible-controller
    print_success "Ansible container started successfully"
    
    # Wait for container to be ready
    sleep 3
    
    print_status "Container status:"
    docker-compose -f "$COMPOSE_FILE" ps ansible-controller
}

# Function to stop Ansible container
stop_ansible() {
    print_status "Stopping Ansible container..."
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Ansible container stopped successfully"
}

# Function to restart Ansible container
restart_ansible() {
    print_status "Restarting Ansible container..."
    stop_ansible
    start_ansible
}

# Function to access Ansible container shell
shell_ansible() {
    print_status "Accessing Ansible container shell..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

# Function to run Ansible playbook
run_playbook() {
    local playbook="$1"
    if [ -z "$playbook" ]; then
        print_error "Please specify a playbook to run"
        print_status "Available playbooks:"
        ls -la ansible/playbooks/*.yml 2>/dev/null || echo "No playbooks found"
        exit 1
    fi
    
    print_status "Running Ansible playbook: $playbook"
    docker exec -it "$CONTAINER_NAME" ansible-playbook "playbooks/$playbook" "${@:2}"
}

# Function to run Ansible command
run_ansible() {
    print_status "Running Ansible command..."
    docker exec -it "$CONTAINER_NAME" ansible "$@"
}

# Function to install Ansible requirements
install_requirements() {
    print_status "Installing Ansible requirements..."
    docker exec -it "$CONTAINER_NAME" ansible-galaxy install -r requirements.yml --force
    docker exec -it "$CONTAINER_NAME" ansible-galaxy collection install -r requirements.yml --force
    print_success "Ansible requirements installed successfully"
}

# Function to show logs
show_logs() {
    print_status "Showing Ansible container logs..."
    docker-compose -f "$COMPOSE_FILE" logs -f ansible-controller
}

# Function to show status
show_status() {
    print_status "Ansible container status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    print_status "Ansible version in container:"
    docker exec "$CONTAINER_NAME" ansible --version 2>/dev/null || print_warning "Container not running"
}

# Function to start AWX (Ansible Web UI)
start_awx() {
    print_status "Starting AWX (Ansible Web UI)..."
    docker-compose -f "$COMPOSE_FILE" --profile awx up -d
    print_success "AWX started successfully"
    print_status "AWX will be available at: http://localhost:8080"
    print_status "Default credentials: admin/password"
}

# Function to stop AWX
stop_awx() {
    print_status "Stopping AWX..."
    docker-compose -f "$COMPOSE_FILE" --profile awx down
    print_success "AWX stopped successfully"
}

# Function to show help
show_help() {
    echo "WanderList Ansible Management Script"
    echo "====================================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start                    Start Ansible container"
    echo "  stop                     Stop Ansible container"
    echo "  restart                  Restart Ansible container"
    echo "  shell                    Access Ansible container shell"
    echo "  status                   Show container status"
    echo "  logs                     Show container logs"
    echo "  install-requirements     Install Ansible requirements"
    echo "  playbook <name> [args]   Run specific playbook"
    echo "  ansible <args>           Run ansible command"
    echo ""
    echo "AWX Management:"
    echo "  start-awx                Start AWX web interface"
    echo "  stop-awx                 Stop AWX web interface"
    echo "  awx-logs                 Show AWX logs"
    echo ""
    echo "Monitoring & URLs:"
    echo "  monitor                  Start Ansible monitoring"
    echo "  dashboard                Start Ansible web dashboard"
    echo "  urls                     Show all access URLs"
    echo "  help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 playbook deploy-wanderlist.yml"
    echo "  $0 ansible all -m ping"
    echo "  $0 shell"
}

# Main script logic
case "${1:-help}" in
    start)
        check_docker
        start_ansible
        ;;
    stop)
        check_docker
        stop_ansible
        ;;
    restart)
        check_docker
        restart_ansible
        ;;
    shell)
        check_docker
        shell_ansible
        ;;
    status)
        check_docker
        show_status
        ;;
    logs)
        check_docker
        show_logs
        ;;
    install-requirements)
        check_docker
        install_requirements
        ;;
    playbook)
        check_docker
        shift
        run_playbook "$@"
        ;;
    ansible)
        check_docker
        shift
        run_ansible "$@"
        ;;
    start-awx)
        check_docker
        start_awx
        ;;
    stop-awx)
        check_docker
        stop_awx
        ;;
    start-awx)
        echo -e "${BLUE}[INFO]${NC} Starting AWX Web Interface..."
        if docker-compose -f "$COMPOSE_FILE" --profile awx up -d; then
            echo -e "${GREEN}[SUCCESS]${NC} AWX started successfully"
            echo -e "${CYAN}🌐 AWX Web Interface: http://localhost:8080${NC}"
            echo -e "${CYAN}👤 Default Login: admin/password${NC}"
            echo -e "${YELLOW}⏳ Note: AWX may take a few minutes to fully initialize${NC}"
        else
            echo -e "${RED}[ERROR]${NC} Failed to start AWX"
            exit 1
        fi
        ;;
    
    stop-awx)
        echo -e "${BLUE}[INFO]${NC} Stopping AWX Web Interface..."
        if docker-compose -f "$COMPOSE_FILE" --profile awx down; then
            echo -e "${GREEN}[SUCCESS]${NC} AWX stopped successfully"
        else
            echo -e "${RED}[ERROR]${NC} Failed to stop AWX"
            exit 1
        fi
        ;;
    
    awx-logs)
        echo -e "${BLUE}[INFO]${NC} Showing AWX logs..."
        docker-compose -f "$COMPOSE_FILE" --profile awx logs -f
        ;;
    
    monitor)
        ./ansible-monitor "$@"
        ;;
    
    dashboard)
        echo -e "${BLUE}[INFO]${NC} Starting Ansible Dashboard..."
        ./ansible-dashboard 8090
        ;;
    
    urls)
        echo -e "${PURPLE}🌐 WanderList Access URLs${NC}"
        echo "=========================="
        echo -e "${CYAN}Ansible Container:${NC}     ./ansible-manager shell"
        echo -e "${CYAN}Ansible Dashboard:${NC}     http://localhost:8090 (via ./ansible-manager dashboard)"
        echo -e "${CYAN}Ansible Monitoring:${NC}    ./ansible-monitor monitor"
        echo -e "${CYAN}WanderList App:${NC}        http://localhost:9002"
        echo -e "${CYAN}Grafana:${NC}               http://localhost:9001"
        echo -e "${CYAN}Prometheus:${NC}            http://localhost:9090"
        echo -e "${CYAN}Jenkins:${NC}               http://localhost:8080"
        ;;
    
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac