#!/bin/bash

# 🌐 Ansible Team Access Setup Script
# Configure Ansible platform for local network access

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${PURPLE}"
    echo "=================================================="
    echo "🌐 ANSIBLE TEAM ACCESS SETUP"
    echo "=================================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_step() {
    echo -e "${CYAN}[STEP] $1${NC}"
}

# Get WSL IP address
get_wsl_ip() {
    WSL_IP=$(hostname -I | awk '{print $1}')
    WINDOWS_IP=$(ip route | grep default | awk '{print $3}')
    echo "WSL IP: $WSL_IP"
    echo "Windows Host IP: $WINDOWS_IP"
}

# Start team access services
start_team_services() {
    print_step "🚀 Starting Ansible Team Access Services..."
    
    # Stop any existing services
    docker-compose -f docker-compose.team.yml down 2>/dev/null || true
    
    # Build and start the team access container
    docker-compose -f docker-compose.team.yml up -d --build
    
    # Wait for services to start
    print_status "⏳ Waiting for services to start..."
    sleep 10
    
    # Check if services are running
    if docker-compose -f docker-compose.team.yml ps | grep -q "Up"; then
        print_status "✅ Team access services started successfully"
    else
        print_error "❌ Failed to start team access services"
        docker-compose -f docker-compose.team.yml logs
        exit 1
    fi
}

# Configure Windows port forwarding (if needed)
configure_windows_forwarding() {
    print_step "🪟 Windows Port Forwarding Configuration"
    
    echo "To allow access from Windows and other devices, run these commands in"
    echo "Windows PowerShell as Administrator:"
    echo ""
    echo -e "${YELLOW}# Forward dashboard port${NC}"
    echo "netsh interface portproxy add v4tov4 listenport=8093 listenaddress=0.0.0.0 connectport=8093 connectaddress=$WSL_IP"
    echo ""
    echo -e "${YELLOW}# Forward API port${NC}"
    echo "netsh interface portproxy add v4tov4 listenport=8094 listenaddress=0.0.0.0 connectport=8094 connectaddress=$WSL_IP"
    echo ""
    echo -e "${YELLOW}# Check forwarding rules${NC}"
    echo "netsh interface portproxy show v4tov4"
    echo ""
    echo -e "${YELLOW}# Open Windows Firewall (if needed)${NC}"
    echo "New-NetFirewallRule -DisplayName 'Ansible Dashboard' -Direction Inbound -Port 8093 -Protocol TCP -Action Allow"
    echo "New-NetFirewallRule -DisplayName 'Ansible API' -Direction Inbound -Port 8094 -Protocol TCP -Action Allow"
    echo ""
}

# Display access information
show_access_info() {
    print_step "🎯 Team Access Information"
    
    echo ""
    echo -e "${GREEN}✅ Ansible Platform is now accessible to your team!${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access URLs:${NC}"
    echo "   From WSL/Linux:     http://localhost:8093/portal.html"
    echo "   From Windows Host:  http://$WINDOWS_IP:8093/portal.html"
    echo "   From Other Devices: http://<WINDOWS_IP>:8093/portal.html"
    echo ""
    echo -e "${CYAN}🤖 API Endpoints:${NC}"
    echo "   From WSL/Linux:     http://localhost:8094/api"
    echo "   From Windows Host:  http://$WINDOWS_IP:8094/api"
    echo "   From Other Devices: http://<WINDOWS_IP>:8094/api"
    echo ""
    echo -e "${CYAN}📱 Dashboard Features:${NC}"
    echo "   • Enhanced Interactive Dashboard"
    echo "   • Real-time Ansible Playbook Execution"
    echo "   • Live Log Streaming"
    echo "   • AI-Powered Error Analysis"
    echo "   • Beautiful Web Interface"
    echo ""
    echo -e "${YELLOW}📋 For Team Members:${NC}"
    echo "   1. Connect to the same network as your Windows machine"
    echo "   2. Open browser and go to: http://<YOUR_WINDOWS_IP>:8093/portal.html"
    echo "   3. Start using Ansible automation through the web interface"
    echo ""
    echo -e "${YELLOW}🔧 Your Windows IP Address:${NC}"
    echo "   Ask your network admin or run 'ipconfig' in Windows CMD"
    echo "   Look for 'IPv4 Address' under your network adapter"
    echo ""
}

# Main execution
main() {
    print_header
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Get network information
    print_step "🔍 Getting network information..."
    get_wsl_ip
    
    # Start team access services
    start_team_services
    
    # Show Windows port forwarding configuration
    configure_windows_forwarding
    
    # Display access information
    show_access_info
    
    print_status "🎉 Team access setup complete!"
}

# Run main function
main "$@"