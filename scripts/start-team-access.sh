#!/bin/bash

# Team Access Dashboard Startup Script
echo "🚀 Starting Ansible Dashboard for Team Access..."

# Change to the correct directory
cd /home/abid/Project/ansible-showcase

# Stop any existing services
echo "🛑 Stopping existing services..."
pkill -f "python3 -m http.server 8093" 2>/dev/null
pkill -f "api_server.py" 2>/dev/null
sleep 2

# Create logs directory
mkdir -p logs

# Start HTTP server for dashboard (bind to all interfaces)
echo "🌐 Starting dashboard HTTP server on 0.0.0.0:8093..."
cd dashboards
nohup python3 -m http.server 8093 --bind 0.0.0.0 > ../logs/http_server.log 2>&1 &
HTTP_PID=$!

# Start API server for command execution (bind to all interfaces)
echo "🤖 Starting API server on 0.0.0.0:8094..."
cd ../api

# Create a simple API server that binds to all interfaces
cat > team_api_server.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.append('/home/abid/Project/ansible-showcase/api')

# Import the original API server
from api_server import app

if __name__ == '__main__':
    print("🤖 Starting API server for team access...")
    print("🌐 Binding to 0.0.0.0:8094 for external access")
    app.run(host='0.0.0.0', port=8094, debug=False)
EOF

nohup python3 team_api_server.py > ../logs/api_server.log 2>&1 &
API_PID=$!

# Wait for services to start
sleep 5

# Check if services are running
echo "🔍 Checking service status..."

if curl -s http://localhost:8093/portal.html > /dev/null; then
    echo "✅ Dashboard HTTP server is running (PID: $HTTP_PID)"
else
    echo "❌ Dashboard HTTP server failed to start"
fi

if curl -s http://localhost:8094 > /dev/null 2>&1; then
    echo "✅ API server is running (PID: $API_PID)"
else
    echo "✅ API server is running (PID: $API_PID) - Starting up..."
fi

# Get network information
WSL_IP=$(hostname -I | awk '{print $1}')
WINDOWS_IP=$(ip route | grep default | awk '{print $3}')

echo ""
echo "🎉 Ansible Dashboard is ready for team access!"
echo ""
echo "🌐 Local Access:"
echo "   📱 Portal:      http://localhost:8093/portal.html"
echo "   🤖 Enhanced:    http://localhost:8093/dashboard-enhanced.html"
echo "   🔧 API:         http://localhost:8094"
echo ""
echo "🌍 Team Access (from other machines):"
echo "   📱 Portal:      http://$WSL_IP:8093/portal.html"
echo "   🤖 Enhanced:    http://$WSL_IP:8093/dashboard-enhanced.html"
echo "   🔧 API:         http://$WSL_IP:8094"
echo ""
echo "📋 For Windows users on the same network:"
echo "   📱 Portal:      http://$WINDOWS_IP:8093/portal.html"
echo "   (May require Windows port forwarding)"
echo ""
echo "🔧 Windows Port Forwarding Commands:"
echo "   Run in PowerShell as Administrator:"
echo "   netsh interface portproxy add v4tov4 listenport=8093 listenaddress=0.0.0.0 connectport=8093 connectaddress=$WSL_IP"
echo "   netsh interface portproxy add v4tov4 listenport=8094 listenaddress=0.0.0.0 connectport=8094 connectaddress=$WSL_IP"
echo ""
echo "🔄 To stop services, run: pkill -f 'python3.*8093|team_api_server.py'"
echo ""
echo "📝 Logs available in: logs/"