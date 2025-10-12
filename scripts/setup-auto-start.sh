#!/bin/bash

# 🔄 Auto-Start Setup for Ansible Team Access
# This script configures the services to start automatically when your machine boots

echo "🔄 Setting up auto-start for Ansible Team Access..."

# Copy service file to systemd
sudo cp ansible-team-access.service /etc/systemd/system/

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable ansible-team-access.service

echo "✅ Auto-start configured!"
echo ""
echo "🔧 Service Management Commands:"
echo "   sudo systemctl start ansible-team-access    # Start now"
echo "   sudo systemctl stop ansible-team-access     # Stop service"
echo "   sudo systemctl status ansible-team-access   # Check status"
echo "   sudo systemctl restart ansible-team-access  # Restart service"
echo ""
echo "🚀 The Ansible dashboard will now start automatically when your machine boots!"
echo "📱 Team Access URL: http://172.17.99.74:8093/portal.html"