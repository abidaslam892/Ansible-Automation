#!/bin/bash

# Production Ansible Automation Dashboard Startup Script
# Designed for 24/7 team access

set -e

echo "🚀 Starting Ansible Automation Platform for Team Access..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Create log directory
mkdir -p /var/log/ansible

# Check if running in production mode
if [[ "${ENV}" == "production" ]]; then
    print_status "🌐 Running in PRODUCTION mode for team access"
    DASHBOARD_HOST=${DASHBOARD_HOST:-0.0.0.0}
    API_HOST=${API_HOST:-0.0.0.0}
else
    print_status "🔧 Running in DEVELOPMENT mode"
    DASHBOARD_HOST=${DASHBOARD_HOST:-localhost}
    API_HOST=${API_HOST:-localhost}
fi

DASHBOARD_PORT=${DASHBOARD_PORT:-8093}
API_PORT=${API_PORT:-8094}

print_status "📊 Dashboard will be available at: http://${DASHBOARD_HOST}:${DASHBOARD_PORT}"
print_status "🔌 API will be available at: http://${API_HOST}:${API_PORT}"

# Start the API server in background
print_status "🔧 Starting API server..."
cd /app/api
python3 api_server.py --host ${API_HOST} --port ${API_PORT} > /var/log/ansible/api.log 2>&1 &
API_PID=$!

# Wait for API to start
sleep 5

# Check if API is running
if kill -0 ${API_PID} 2>/dev/null; then
    print_status "✅ API server started successfully (PID: ${API_PID})"
else
    print_error "❌ Failed to start API server"
    exit 1
fi

# Start the dashboard server
print_status "🎨 Starting dashboard server..."
cd /app/dashboards

# Create a simple Python HTTP server that serves the dashboard
cat > dashboard_server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys
from urllib.parse import urlparse, parse_qs
import json

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="/app/dashboards", **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_GET(self):
        if self.path == '/':
            self.path = '/portal.html'
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "healthy", "service": "ansible-dashboard"}')
            return
        super().do_GET()

if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) > 1 else "0.0.0.0"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8093
    
    with socketserver.TCPServer((host, port), DashboardHandler) as httpd:
        print(f"🌐 Dashboard server running on http://{host}:{port}")
        print(f"📱 Team access available at: http://{host}:{port}/portal.html")
        print(f"🤖 Enhanced dashboard at: http://{host}:{port}/dashboard-enhanced.html")
        httpd.serve_forever()
EOF

python3 dashboard_server.py ${DASHBOARD_HOST} ${DASHBOARD_PORT} > /var/log/ansible/dashboard.log 2>&1 &
DASHBOARD_PID=$!

# Wait for dashboard to start
sleep 3

# Check if dashboard is running
if kill -0 ${DASHBOARD_PID} 2>/dev/null; then
    print_status "✅ Dashboard server started successfully (PID: ${DASHBOARD_PID})"
else
    print_error "❌ Failed to start dashboard server"
    kill ${API_PID} 2>/dev/null
    exit 1
fi

# Display team access information
echo ""
echo "🎉======================================"
echo "🚀 ANSIBLE AUTOMATION PLATFORM READY!"
echo "======================================="
echo ""
echo "🌐 Team Access URLs:"
echo "   📱 Main Portal: http://${DASHBOARD_HOST}:${DASHBOARD_PORT}/portal.html"
echo "   🤖 Enhanced Dashboard: http://${DASHBOARD_HOST}:${DASHBOARD_PORT}/dashboard-enhanced.html"
echo "   🎨 Unified Dashboard: http://${DASHBOARD_HOST}:${DASHBOARD_PORT}/dashboard-unified.html"
echo "   🔌 API Endpoint: http://${API_HOST}:${API_PORT}/api"
echo ""
echo "📊 Services Running:"
echo "   ✅ API Server (PID: ${API_PID})"
echo "   ✅ Dashboard Server (PID: ${DASHBOARD_PID})"
echo ""
echo "📝 Logs:"
echo "   📄 API Logs: /var/log/ansible/api.log"
echo "   📄 Dashboard Logs: /var/log/ansible/dashboard.log"
echo ""
echo "🔧 For team members:"
echo "   - Share the URLs above with your team"
echo "   - No additional setup required"
echo "   - Available 24/7 while container is running"
echo ""
echo "⚡ Ready for team collaboration!"
echo "======================================"

# Function to cleanup on exit
cleanup() {
    print_warning "🛑 Shutting down services..."
    kill ${API_PID} 2>/dev/null
    kill ${DASHBOARD_PID} 2>/dev/null
    print_status "✅ Services stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Keep the container running and monitor services
while true; do
    # Check if API is still running
    if ! kill -0 ${API_PID} 2>/dev/null; then
        print_error "❌ API server died, restarting..."
        cd /app/api
        python3 api_server.py --host ${API_HOST} --port ${API_PORT} > /var/log/ansible/api.log 2>&1 &
        API_PID=$!
    fi
    
    # Check if dashboard is still running
    if ! kill -0 ${DASHBOARD_PID} 2>/dev/null; then
        print_error "❌ Dashboard server died, restarting..."
        cd /app/dashboards
        python3 dashboard_server.py ${DASHBOARD_HOST} ${DASHBOARD_PORT} > /var/log/ansible/dashboard.log 2>&1 &
        DASHBOARD_PID=$!
    fi
    
    sleep 30
done