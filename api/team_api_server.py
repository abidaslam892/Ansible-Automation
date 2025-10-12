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
