#!/bin/bash

# 🚀 Ansible Automation Platform - Team Deployment Script
# Deploy anywhere: AWS EC2, Azure VM, DigitalOcean, Google Cloud, or any VPS

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
    echo "🚀 ANSIBLE AUTOMATION PLATFORM DEPLOYMENT"
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. This is acceptable for cloud deployment."
    fi
}

# Detect OS and install Docker
install_docker() {
    print_step "🐳 Installing Docker and Docker Compose..."
    
    if command -v docker &> /dev/null; then
        print_status "Docker already installed"
    else
        # Install Docker based on OS
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        elif [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS/Amazon Linux
            yum update -y
            yum install -y docker
            systemctl start docker
            systemctl enable docker
            # Install docker-compose
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        fi
        
        # Start Docker service
        systemctl start docker
        systemctl enable docker
        
        print_status "✅ Docker installed successfully"
    fi
    
    # Add current user to docker group if not root
    if [[ $EUID -ne 0 ]]; then
        usermod -aG docker $USER
        print_warning "Please log out and back in for Docker permissions to take effect"
    fi
}

# Create deployment directory
setup_deployment() {
    print_step "📂 Setting up deployment directory..."
    
    DEPLOY_DIR="/opt/ansible-automation"
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR
    
    print_status "✅ Deployment directory created: $DEPLOY_DIR"
}

# Download or clone the project
get_project() {
    print_step "📥 Getting Ansible Automation project..."
    
    if [[ -n "$1" ]]; then
        # Use provided path (for local deployment)
        cp -r "$1"/* .
        print_status "✅ Project copied from local path"
    else
        # Clone from GitHub
        if command -v git &> /dev/null; then
            git clone https://github.com/abidaslam892/Ansible-Automation.git .
            print_status "✅ Project cloned from GitHub"
        else
            print_error "Git not found. Please install git or provide local project path."
            exit 1
        fi
    fi
}

# Configure for production
configure_production() {
    print_step "⚙️ Configuring for production deployment..."
    
    # Get public IP
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "localhost")
    
    # Create environment file
    cat > .env << EOF
# Production Configuration
ENV=production
DASHBOARD_HOST=0.0.0.0
DASHBOARD_PORT=8093
API_HOST=0.0.0.0
API_PORT=8094
TEAM_ACCESS=enabled
PUBLIC_IP=${PUBLIC_IP}
EOF

    # Update docker-compose for production
    if [[ ! -f docker/docker-compose.production.yml ]]; then
        print_warning "Production docker-compose file not found, creating one..."
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  ansible-dashboard:
    build: .
    container_name: ansible-automation-dashboard
    restart: unless-stopped
    ports:
      - "80:8093"
      - "8094:8094"
    environment:
      - ENV=production
      - DASHBOARD_HOST=0.0.0.0
      - DASHBOARD_PORT=8093
      - API_HOST=0.0.0.0
      - API_PORT=8094
      - TEAM_ACCESS=enabled
    volumes:
      - ./playbooks:/ansible/playbooks:ro
      - ./inventory:/ansible/inventory:ro
      - ./group_vars:/ansible/group_vars:ro
      - ./host_vars:/ansible/host_vars:ro
      - ./roles:/ansible/roles:ro
      - ansible_logs:/var/log/ansible
    networks:
      - ansible-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8093/portal.html"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  ansible_logs:

networks:
  ansible-network:
    driver: bridge
EOF
    else
        cp docker/docker-compose.production.yml docker-compose.yml
    fi
    
    print_status "✅ Production configuration complete"
    print_status "🌐 Public IP detected: $PUBLIC_IP"
}

# Deploy the application
deploy_application() {
    print_step "🚀 Deploying Ansible Automation Platform..."
    
    # Build and start the application
    docker-compose down 2>/dev/null || true
    docker-compose build --no-cache
    docker-compose up -d
    
    # Wait for services to start
    print_status "⏳ Waiting for services to start..."
    sleep 30
    
    # Check if services are running
    if docker-compose ps | grep -q "Up"; then
        print_status "✅ Services deployed successfully"
    else
        print_error "❌ Deployment failed"
        docker-compose logs
        exit 1
    fi
}

# Configure firewall
configure_firewall() {
    print_step "🔥 Configuring firewall..."
    
    # Open required ports
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian firewall
        ufw allow 80/tcp
        ufw allow 8094/tcp
        ufw allow 22/tcp
        ufw --force enable
        print_status "✅ UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        # RHEL/CentOS firewall
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=8094/tcp
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --reload
        print_status "✅ Firewalld configured"
    else
        print_warning "⚠️ No firewall detected. Please manually open ports 80 and 8094"
    fi
}

# Create systemd service for auto-start
create_systemd_service() {
    print_step "🔧 Creating systemd service for auto-start..."
    
    cat > /etc/systemd/system/ansible-automation.service << EOF
[Unit]
Description=Ansible Automation Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/ansible-automation
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ansible-automation
    systemctl start ansible-automation
    
    print_status "✅ Systemd service created and enabled"
}

# Display final information
show_completion_info() {
    PUBLIC_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || echo "localhost")
    
    echo ""
    echo -e "${PURPLE}"
    echo "🎉========================================"
    echo "   DEPLOYMENT COMPLETED SUCCESSFULLY!"
    echo "========================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Team Access URLs:${NC}"
    echo -e "${GREEN}   📱 Main Portal: http://${PUBLIC_IP}/portal.html${NC}"
    echo -e "${GREEN}   🤖 Enhanced Dashboard: http://${PUBLIC_IP}/dashboard-enhanced.html${NC}"
    echo -e "${GREEN}   🎨 Unified Dashboard: http://${PUBLIC_IP}/dashboard-unified.html${NC}"
    echo -e "${GREEN}   🔌 API Endpoint: http://${PUBLIC_IP}:8094/api${NC}"
    echo ""
    echo -e "${CYAN}🔧 Management Commands:${NC}"
    echo -e "${YELLOW}   View logs: docker-compose logs -f${NC}"
    echo -e "${YELLOW}   Restart: docker-compose restart${NC}"
    echo -e "${YELLOW}   Stop: docker-compose down${NC}"
    echo -e "${YELLOW}   Update: git pull && docker-compose up -d --build${NC}"
    echo ""
    echo -e "${CYAN}📋 Service Status:${NC}"
    docker-compose ps
    echo ""
    echo -e "${GREEN}🎯 Share these URLs with your team for 24/7 access!${NC}"
    echo -e "${GREEN}✅ Platform will auto-start on server reboot${NC}"
    echo ""
}

# Main deployment function
main() {
    print_header
    
    print_status "🔍 Starting deployment process..."
    
    check_root
    install_docker
    setup_deployment
    get_project "$1"
    configure_production
    deploy_application
    configure_firewall
    create_systemd_service
    show_completion_info
    
    print_status "🚀 Deployment complete! Your team can now access the platform 24/7."
}

# Show usage information
show_usage() {
    echo "Usage: $0 [LOCAL_PROJECT_PATH]"
    echo ""
    echo "Deploy Ansible Automation Platform for team access"
    echo ""
    echo "Options:"
    echo "  LOCAL_PROJECT_PATH    Optional: Path to local project directory"
    echo "                       If not provided, will clone from GitHub"
    echo ""
    echo "Examples:"
    echo "  $0                           # Clone from GitHub and deploy"
    echo "  $0 /path/to/local/project    # Deploy from local directory"
    echo ""
    echo "Requirements:"
    echo "  - Ubuntu 18.04+ or RHEL 7+ or Amazon Linux 2"
    echo "  - Root or sudo access"
    echo "  - Internet connection"
    echo ""
    echo "Cloud Platform Examples:"
    echo "  AWS EC2: curl -L bit.ly/ansible-deploy | bash"
    echo "  Azure VM: wget -O- bit.ly/ansible-deploy | bash"
    echo "  DigitalOcean: curl -s bit.ly/ansible-deploy | bash"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac