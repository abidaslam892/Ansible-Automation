#!/bin/bash

# Simple HTTP server for Ansible Dashboard
# This script serves the Ansible dashboard on http://localhost:8090

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="$SCRIPT_DIR/ansible/dashboard.html"
PORT=${1:-8090}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🌐 Starting Ansible Dashboard Server${NC}"
echo "======================================"
echo -e "${YELLOW}📍 URL: http://localhost:$PORT${NC}"
echo -e "${YELLOW}📁 Serving: $DASHBOARD_FILE${NC}"
echo -e "${GREEN}🔄 Auto-refresh: Every 30 seconds${NC}"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Check if Python is available
if command -v python3 &> /dev/null; then
    cd "$SCRIPT_DIR"
    python3 -m http.server $PORT
elif command -v python &> /dev/null; then
    cd "$SCRIPT_DIR"
    python -m SimpleHTTPServer $PORT
else
    echo "Error: Python not found. Please install Python to run the dashboard server."
    exit 1
fi