#!/bin/bash

# WanderList Ansible Monitoring Script
# This script monitors the Ansible container and provides real-time status updates

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/ansible-monitoring.log"
CONTAINER_NAME="wanderlist-ansible"
CHECK_INTERVAL=30
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.ansible.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    log "$message"
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_status $RED "❌ Docker is not running or not accessible"
        return 1
    fi
    return 0
}

# Get container status
get_container_status() {
    if docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
        echo "running"
    elif docker ps -aq -f name="$CONTAINER_NAME" | grep -q .; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

# Get container stats
get_container_stats() {
    if [[ "$(get_container_status)" == "running" ]]; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" "$CONTAINER_NAME"
    fi
}

# Get container logs
get_container_logs() {
    local lines=${1:-50}
    if [[ "$(get_container_status)" != "not_found" ]]; then
        docker logs --tail "$lines" "$CONTAINER_NAME" 2>/dev/null || true
    fi
}

# Check Ansible service health
check_ansible_health() {
    if [[ "$(get_container_status)" == "running" ]]; then
        # Test Ansible version
        if docker exec "$CONTAINER_NAME" ansible --version >/dev/null 2>&1; then
            local version=$(docker exec "$CONTAINER_NAME" ansible --version 2>/dev/null | head -n1)
            print_status $GREEN "✅ Ansible is healthy: $version"
            
            # Test playbook syntax
            if docker exec "$CONTAINER_NAME" ansible-playbook --syntax-check /ansible/playbooks/test-ansible.yml >/dev/null 2>&1; then
                print_status $GREEN "✅ Playbook syntax is valid"
            else
                print_status $YELLOW "⚠️ Playbook syntax check failed"
            fi
            
            return 0
        else
            print_status $RED "❌ Ansible is not responding"
            return 1
        fi
    else
        print_status $RED "❌ Container is not running"
        return 1
    fi
}

# Check AWX status (if enabled)
check_awx_status() {
    if docker ps -q -f name="wanderlist-awx-web" | grep -q .; then
        print_status $GREEN "✅ AWX Web interface is running"
        print_status $CYAN "🌐 AWX URL: http://localhost:8080"
        print_status $CYAN "👤 Default login: admin/password"
        return 0
    else
        print_status $YELLOW "⚠️ AWX Web interface is not running"
        return 1
    fi
}

# Display container information
show_container_info() {
    local status=$(get_container_status)
    
    echo -e "\n${PURPLE}🐳 WanderList Ansible Container Status${NC}"
    echo "=========================================="
    
    case $status in
        "running")
            print_status $GREEN "✅ Container Status: RUNNING"
            
            # Container details
            echo -e "\n${CYAN}📊 Container Details:${NC}"
            docker inspect "$CONTAINER_NAME" --format "
Image: {{.Config.Image}}
Created: {{.Created}}
Started: {{.State.StartedAt}}
Platform: {{.Platform}}
"
            
            # Resource usage
            echo -e "\n${CYAN}📈 Resource Usage:${NC}"
            get_container_stats
            
            # Port mappings
            echo -e "\n${CYAN}🔌 Port Mappings:${NC}"
            docker port "$CONTAINER_NAME" 2>/dev/null || echo "No ports exposed"
            
            # Volume mounts
            echo -e "\n${CYAN}💾 Volume Mounts:${NC}"
            docker inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}}){{"\n"}}{{end}}'
            
            ;;
        "stopped")
            print_status $YELLOW "⚠️ Container Status: STOPPED"
            ;;
        "not_found")
            print_status $RED "❌ Container Status: NOT FOUND"
            ;;
    esac
}

# Show Ansible information
show_ansible_info() {
    if [[ "$(get_container_status)" == "running" ]]; then
        echo -e "\n${PURPLE}🤖 Ansible Information${NC}"
        echo "========================"
        
        # Ansible version
        echo -e "\n${CYAN}📦 Version Information:${NC}"
        docker exec "$CONTAINER_NAME" ansible --version 2>/dev/null || true
        
        # Installed collections
        echo -e "\n${CYAN}📚 Installed Collections (top 10):${NC}"
        docker exec "$CONTAINER_NAME" ansible-galaxy collection list 2>/dev/null | head -20 || true
        
        # Available playbooks
        echo -e "\n${CYAN}📋 Available Playbooks:${NC}"
        docker exec "$CONTAINER_NAME" find /ansible/playbooks -name "*.yml" -type f 2>/dev/null | sed 's|/ansible/playbooks/||' || true
        
        # Inventory hosts
        echo -e "\n${CYAN}🎯 Inventory Hosts:${NC}"
        docker exec "$CONTAINER_NAME" ansible-inventory --list 2>/dev/null | grep -E '"[^"]*":' | head -10 || true
    fi
}

# Show access URLs and commands
show_access_info() {
    echo -e "\n${PURPLE}🌐 Access Information${NC}"
    echo "======================"
    
    # Ansible container access
    echo -e "\n${CYAN}🐳 Ansible Container Access:${NC}"
    echo "Shell Access:       ./ansible-manager shell"
    echo "Container Logs:     ./ansible-manager logs"
    echo "Run Playbook:       ./ansible-manager playbook <playbook-name.yml>"
    echo "Direct Docker:      docker exec -it $CONTAINER_NAME bash"
    
    # AWX access (if running)
    if docker ps -q -f name="wanderlist-awx-web" | grep -q .; then
        echo -e "\n${CYAN}🎛️ AWX Web Interface:${NC}"
        echo "URL:                http://localhost:8080"
        echo "Username:           admin"
        echo "Password:           password"
        echo "Start AWX:          ./ansible-manager start-awx"
        echo "Stop AWX:           ./ansible-manager stop-awx"
    else
        echo -e "\n${YELLOW}🎛️ AWX Web Interface (Not Running):${NC}"
        echo "Start AWX:          ./ansible-manager start-awx"
        echo "Then access:        http://localhost:8080"
    fi
    
    # Related services
    echo -e "\n${CYAN}🔗 Related WanderList Services:${NC}"
    echo "WanderList App:     http://localhost:9002"
    echo "Grafana:            http://localhost:9001"
    echo "Prometheus:         http://localhost:9090"
}

# Monitor continuously
monitor_continuous() {
    echo -e "${BLUE}🔄 Starting continuous monitoring (Press Ctrl+C to stop)${NC}"
    echo "Check interval: ${CHECK_INTERVAL} seconds"
    
    while true; do
        clear
        echo -e "${PURPLE}🕐 $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        
        if ! check_docker; then
            sleep $CHECK_INTERVAL
            continue
        fi
        
        show_container_info
        check_ansible_health
        check_awx_status
        
        echo -e "\n${BLUE}Next check in $CHECK_INTERVAL seconds...${NC}"
        sleep $CHECK_INTERVAL
    done
}

# Display help
show_help() {
    echo -e "${PURPLE}WanderList Ansible Monitoring Script${NC}"
    echo "====================================="
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  status      Show current status (default)"
    echo "  monitor     Start continuous monitoring"
    echo "  health      Check Ansible health"
    echo "  info        Show detailed information"
    echo "  access      Show access URLs and commands"
    echo "  logs        Show recent container logs"
    echo "  stats       Show container resource stats"
    echo "  awx         Check AWX status"
    echo "  help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0 status           # Show current status"
    echo "  $0 monitor          # Start continuous monitoring"
    echo "  $0 logs             # Show container logs"
    echo "  $0 info             # Show detailed information"
}

# Main function
main() {
    local command=${1:-status}
    
    case $command in
        "status")
            if ! check_docker; then exit 1; fi
            show_container_info
            check_ansible_health
            check_awx_status
            show_access_info
            ;;
        "monitor")
            monitor_continuous
            ;;
        "health")
            if ! check_docker; then exit 1; fi
            check_ansible_health
            ;;
        "info")
            if ! check_docker; then exit 1; fi
            show_container_info
            show_ansible_info
            ;;
        "access")
            show_access_info
            ;;
        "logs")
            if ! check_docker; then exit 1; fi
            echo -e "${CYAN}📜 Container Logs (last 50 lines):${NC}"
            get_container_logs 50
            ;;
        "stats")
            if ! check_docker; then exit 1; fi
            echo -e "${CYAN}📊 Container Resource Statistics:${NC}"
            get_container_stats
            ;;
        "awx")
            check_awx_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}👋 Monitoring stopped${NC}"; exit 0' INT

# Run main function
main "$@"