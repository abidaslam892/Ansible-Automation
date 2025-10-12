#!/usr/bin/env python3
"""
Ansible Dashboard API Server
Provides REST API for executing Ansible playbooks and streaming logs
"""

import os
import sys
import json
import subprocess
import threading
import time
from datetime import datetime
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import uuid
import signal
import queue

app = Flask(__name__)
CORS(app)

# Configuration
ANSIBLE_DIR = "/ansible"
PLAYBOOKS_DIR = f"{ANSIBLE_DIR}/infrastructure/playbooks"
LOGS_DIR = f"{ANSIBLE_DIR}/logs"
INVENTORY_FILE = f"{ANSIBLE_DIR}/infrastructure/inventory/hosts"

# Ensure log directory exists
log_dir = "/home/abid/Project/wanderlist-app/ansible/logs"
os.makedirs(log_dir, exist_ok=True)

# Global storage for active executions
active_executions = {}
execution_logs = {}

class PlaybookExecution:
    def __init__(self, execution_id, playbook, extra_vars=None):
        self.execution_id = execution_id
        self.playbook = playbook
        self.extra_vars = extra_vars or {}
        self.status = "pending"
        self.start_time = datetime.now()
        self.end_time = None
        self.process = None
        self.log_queue = queue.Queue()
        self.output_lines = []
        
    def to_dict(self):
        return {
            "execution_id": self.execution_id,
            "playbook": self.playbook,
            "extra_vars": self.extra_vars,
            "status": self.status,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "output_lines": len(self.output_lines)
        }

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "ansible_dir": ANSIBLE_DIR,
        "playbooks_available": os.path.exists(PLAYBOOKS_DIR)
    })

@app.route('/api/playbooks', methods=['GET'])
def list_playbooks():
    """List available Ansible playbooks"""
    try:
        if not os.path.exists(PLAYBOOKS_DIR):
            return jsonify({"error": "Playbooks directory not found"}), 404
            
        playbooks = []
        for file in os.listdir(PLAYBOOKS_DIR):
            if file.endswith('.yml') or file.endswith('.yaml'):
                playbook_path = os.path.join(PLAYBOOKS_DIR, file)
                playbooks.append({
                    "name": file,
                    "path": playbook_path,
                    "size": os.path.getsize(playbook_path),
                    "modified": datetime.fromtimestamp(os.path.getmtime(playbook_path)).isoformat()
                })
        
        return jsonify({"playbooks": playbooks})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/inventory', methods=['GET'])
def get_inventory():
    """Get Ansible inventory information"""
    try:
        if os.path.exists(INVENTORY_FILE):
            with open(INVENTORY_FILE, 'r') as f:
                content = f.read()
            return jsonify({"inventory": content, "file": INVENTORY_FILE})
        else:
            return jsonify({"error": "Inventory file not found", "file": INVENTORY_FILE}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/execute', methods=['POST'])
def execute_playbook():
    """Execute an Ansible playbook"""
    try:
        data = request.get_json()
        playbook = data.get('playbook')
        extra_vars = data.get('extra_vars', {})
        
        if not playbook:
            return jsonify({"error": "Playbook name is required"}), 400
            
        playbook_path = os.path.join(PLAYBOOKS_DIR, playbook)
        if not os.path.exists(playbook_path):
            return jsonify({"error": f"Playbook {playbook} not found"}), 404
            
        # Generate unique execution ID
        execution_id = str(uuid.uuid4())
        
        # Create execution object
        execution = PlaybookExecution(execution_id, playbook, extra_vars)
        active_executions[execution_id] = execution
        execution_logs[execution_id] = []
        
        # Start playbook execution in background thread
        thread = threading.Thread(target=run_playbook, args=(execution,))
        thread.daemon = True
        thread.start()
        
        return jsonify({
            "execution_id": execution_id,
            "status": "started",
            "playbook": playbook,
            "message": "Playbook execution started"
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def run_playbook(execution):
    """Run the actual Ansible playbook"""
    try:
        execution.status = "running"
        
        # Build ansible-playbook command
        cmd = ["ansible-playbook", "-i", INVENTORY_FILE, execution.playbook]
        
        # Add extra vars if provided
        if execution.extra_vars:
            extra_vars_str = json.dumps(execution.extra_vars)
            cmd.extend(["--extra-vars", extra_vars_str])
        
        # Add verbose output
        cmd.extend(["-v"])
        
        # Set working directory to playbooks directory
        execution.status = "running"
        
        # Execute the playbook
        process = subprocess.Popen(
            cmd,
            cwd=PLAYBOOKS_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
            bufsize=1
        )
        
        execution.process = process
        
        # Stream output
        for line in iter(process.stdout.readline, ''):
            if line:
                log_entry = {
                    "timestamp": datetime.now().isoformat(),
                    "line": line.rstrip(),
                    "type": "stdout"
                }
                execution.output_lines.append(log_entry)
                execution_logs[execution.execution_id].append(log_entry)
        
        # Wait for completion
        return_code = process.wait()
        execution.end_time = datetime.now()
        
        if return_code == 0:
            execution.status = "completed"
            final_log = {
                "timestamp": datetime.now().isoformat(),
                "line": f"✅ Playbook completed successfully (exit code: {return_code})",
                "type": "success"
            }
        else:
            execution.status = "failed"
            final_log = {
                "timestamp": datetime.now().isoformat(),
                "line": f"❌ Playbook failed (exit code: {return_code})",
                "type": "error"
            }
            
        execution.output_lines.append(final_log)
        execution_logs[execution.execution_id].append(final_log)
        
    except Exception as e:
        execution.status = "error"
        execution.end_time = datetime.now()
        error_log = {
            "timestamp": datetime.now().isoformat(),
            "line": f"💥 Execution error: {str(e)}",
            "type": "error"
        }
        execution.output_lines.append(error_log)
        execution_logs[execution.execution_id].append(error_log)

@app.route('/api/executions', methods=['GET'])
def list_executions():
    """List all playbook executions"""
    executions = [exec.to_dict() for exec in active_executions.values()]
    return jsonify({"executions": executions})

@app.route('/api/executions/<execution_id>', methods=['GET'])
def get_execution_status(execution_id):
    """Get status of a specific execution"""
    if execution_id not in active_executions:
        return jsonify({"error": "Execution not found"}), 404
        
    execution = active_executions[execution_id]
    return jsonify(execution.to_dict())

@app.route('/api/executions/<execution_id>/logs', methods=['GET'])
def get_execution_logs(execution_id):
    """Get logs for a specific execution"""
    if execution_id not in execution_logs:
        return jsonify({"error": "Execution not found"}), 404
        
    logs = execution_logs[execution_id]
    return jsonify({"logs": logs, "total_lines": len(logs)})

@app.route('/api/executions/<execution_id>/logs/stream')
def stream_execution_logs(execution_id):
    """Stream logs for a specific execution using Server-Sent Events"""
    if execution_id not in execution_logs:
        return jsonify({"error": "Execution not found"}), 404
    
    def generate():
        last_line = 0
        while True:
            current_logs = execution_logs.get(execution_id, [])
            
            # Send new lines
            if len(current_logs) > last_line:
                for log_entry in current_logs[last_line:]:
                    yield f"data: {json.dumps(log_entry)}\n\n"
                last_line = len(current_logs)
            
            # Check if execution is complete
            execution = active_executions.get(execution_id)
            if execution and execution.status in ['completed', 'failed', 'error']:
                yield f"event: complete\ndata: {json.dumps({'status': execution.status})}\n\n"
                break
                
            time.sleep(0.5)  # Poll every 500ms
    
    return Response(generate(), mimetype='text/plain')

@app.route('/api/executions/<execution_id>/stop', methods=['POST'])
def stop_execution(execution_id):
    """Stop a running execution"""
    if execution_id not in active_executions:
        return jsonify({"error": "Execution not found"}), 404
        
    execution = active_executions[execution_id]
    
    if execution.process and execution.status == "running":
        try:
            execution.process.terminate()
            execution.status = "stopped"
            execution.end_time = datetime.now()
            
            stop_log = {
                "timestamp": datetime.now().isoformat(),
                "line": "🛑 Execution stopped by user",
                "type": "warning"
            }
            execution.output_lines.append(stop_log)
            execution_logs[execution_id].append(stop_log)
            
            return jsonify({"message": "Execution stopped"})
        except Exception as e:
            return jsonify({"error": f"Failed to stop execution: {str(e)}"}), 500
    else:
        return jsonify({"error": "Execution is not running"}), 400

@app.route('/api/command', methods=['POST'])
def execute_command():
    """Execute a direct shell command"""
    try:
        data = request.json
        command = data.get('command')
        description = data.get('description', 'Command execution')
        
        if not command:
            return jsonify({"error": "Command is required"}), 400
        
        # Create execution ID
        execution_id = str(uuid.uuid4())
        
        # Execute command
        import subprocess
        import threading
        
        def run_command():
            try:
                process = subprocess.Popen(
                    command,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    universal_newlines=True,
                    bufsize=1
                )
                
                # Initialize logs for this execution
                execution_logs[execution_id] = []
                
                # Stream output
                for line in iter(process.stdout.readline, ''):
                    if line:
                        log_entry = {
                            "timestamp": datetime.now().isoformat(),
                            "line": line.strip(),
                            "type": "info"
                        }
                        execution_logs[execution_id].append(log_entry)
                
                process.wait()
                
                # Add completion message
                final_log = {
                    "timestamp": datetime.now().isoformat(),
                    "line": f"✅ Command completed with exit code: {process.returncode}",
                    "type": "success" if process.returncode == 0 else "error"
                }
                execution_logs[execution_id].append(final_log)
                
            except Exception as e:
                error_log = {
                    "timestamp": datetime.now().isoformat(),
                    "line": f"💥 Command error: {str(e)}",
                    "type": "error"
                }
                execution_logs[execution_id] = execution_logs.get(execution_id, [])
                execution_logs[execution_id].append(error_log)
        
        # Start command in background thread
        thread = threading.Thread(target=run_command)
        thread.daemon = True
        thread.start()
        
        return jsonify({
            "execution_id": execution_id,
            "status": "started",
            "description": description,
            "command": command
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/command/<execution_id>/logs', methods=['GET'])
def get_command_logs(execution_id):
    """Get logs for a specific command execution"""
    logs = execution_logs.get(execution_id, [])
    return jsonify({"logs": logs})

if __name__ == '__main__':
    print(f"🚀 Starting Ansible Dashboard API Server...")
    print(f"📁 Ansible Directory: {ANSIBLE_DIR}")
    print(f"📚 Playbooks Directory: {PLAYBOOKS_DIR}")
    print(f"📋 Inventory File: {INVENTORY_FILE}")
    print(f"🌐 Server will be available at: http://localhost:8094")
    
    app.run(host='0.0.0.0', port=8094, debug=True, threaded=True)