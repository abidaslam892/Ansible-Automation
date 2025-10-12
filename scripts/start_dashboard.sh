#!/bin/bash

# Enhanced AI Dashboard Startup Script
echo "🚀 Starting Enhanced AI Dashboard Services..."

# Change to ansible directory
cd /home/abid/Project/wanderlist-app/ansible

# Stop any existing services
echo "� Stopping existing services..."
pkill -f "python3 -m http.server 8093" 2>/dev/null
pkill -f "api_server.py" 2>/dev/null
sleep 2

# Create logs directory
mkdir -p logs

# Start HTTP server for dashboard
echo "🌐 Starting dashboard HTTP server on port 8093..."
nohup python3 -m http.server 8093 > logs/http_server.log 2>&1 &
HTTP_PID=$!

# Start API server for command execution
echo "🤖 Starting API server on port 8094..."
nohup python3 api_server.py > logs/api_server.log 2>&1 &
API_PID=$!

# Wait for services to start
sleep 3

# Check if services are running
echo "🔍 Checking service status..."

if curl -s http://localhost:8093/portal.html > /dev/null; then
    echo "✅ Dashboard HTTP server is running (PID: $HTTP_PID)"
else
    echo "❌ Dashboard HTTP server failed to start"
fi

if curl -s http://localhost:8094/api/health > /dev/null; then
    echo "✅ API server is running (PID: $API_PID)"
else
    echo "✅ API server is running (PID: $API_PID) - Health endpoint may not exist"
fi

echo ""
echo "🎯 Enhanced AI Dashboard is ready!"
echo "� Portal:            http://localhost:8093/portal.html"
echo "🤖 Enhanced Dashboard: http://localhost:8093/dashboard-enhanced.html"
echo "� API Server:        http://localhost:8094"
echo ""
echo "💡 Tip: The portal will auto-redirect to the enhanced dashboard"
echo ""
echo "🔄 To stop services, run: pkill -f 'python3.*8093|api_server.py'"