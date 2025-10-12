#!/usr/bin/env python3
"""
Team Authentication Middleware for Ansible Dashboard
Provides simple token-based authentication for team access
"""

import os
import hashlib
import secrets
import json
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify, make_response

# Configuration
AUTH_ENABLED = os.getenv('TEAM_AUTH_ENABLED', 'false').lower() == 'true'
TOKEN_EXPIRY_HOURS = int(os.getenv('TOKEN_EXPIRY_HOURS', '24'))
TEAM_TOKENS_FILE = '/var/log/ansible/team_tokens.json'

# Default team members (update these!)
DEFAULT_TEAM = {
    'admin': {
        'password_hash': hashlib.sha256('admin123'.encode()).hexdigest(),
        'role': 'admin',
        'email': 'admin@company.com'
    },
    'devops': {
        'password_hash': hashlib.sha256('devops123'.encode()).hexdigest(),
        'role': 'operator',
        'email': 'devops@company.com'
    },
    'developer': {
        'password_hash': hashlib.sha256('dev123'.encode()).hexdigest(),
        'role': 'viewer',
        'email': 'dev@company.com'
    }
}

class TeamAuth:
    def __init__(self):
        self.active_tokens = {}
        self.team_members = DEFAULT_TEAM.copy()
        self.load_tokens()
    
    def load_tokens(self):
        """Load active tokens from file"""
        try:
            if os.path.exists(TEAM_TOKENS_FILE):
                with open(TEAM_TOKENS_FILE, 'r') as f:
                    data = json.load(f)
                    self.active_tokens = data.get('tokens', {})
                    self.team_members.update(data.get('team_members', {}))
        except Exception as e:
            print(f"Warning: Could not load tokens: {e}")
    
    def save_tokens(self):
        """Save active tokens to file"""
        try:
            os.makedirs(os.path.dirname(TEAM_TOKENS_FILE), exist_ok=True)
            with open(TEAM_TOKENS_FILE, 'w') as f:
                json.dump({
                    'tokens': self.active_tokens,
                    'team_members': self.team_members,
                    'last_updated': datetime.now().isoformat()
                }, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save tokens: {e}")
    
    def authenticate(self, username, password):
        """Authenticate user credentials"""
        if username not in self.team_members:
            return None
        
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        if self.team_members[username]['password_hash'] == password_hash:
            # Generate new token
            token = secrets.token_urlsafe(32)
            expiry = datetime.now() + timedelta(hours=TOKEN_EXPIRY_HOURS)
            
            self.active_tokens[token] = {
                'username': username,
                'role': self.team_members[username]['role'],
                'email': self.team_members[username]['email'],
                'created': datetime.now().isoformat(),
                'expires': expiry.isoformat()
            }
            
            self.save_tokens()
            return token
        
        return None
    
    def validate_token(self, token):
        """Validate authentication token"""
        if not AUTH_ENABLED:
            return True, {'username': 'anonymous', 'role': 'admin'}
        
        if token not in self.active_tokens:
            return False, None
        
        token_data = self.active_tokens[token]
        expiry = datetime.fromisoformat(token_data['expires'])
        
        if datetime.now() > expiry:
            # Token expired
            del self.active_tokens[token]
            self.save_tokens()
            return False, None
        
        return True, token_data
    
    def revoke_token(self, token):
        """Revoke authentication token"""
        if token in self.active_tokens:
            del self.active_tokens[token]
            self.save_tokens()
            return True
        return False
    
    def add_team_member(self, username, password, role='viewer', email=''):
        """Add new team member"""
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        self.team_members[username] = {
            'password_hash': password_hash,
            'role': role,
            'email': email
        }
        self.save_tokens()
    
    def list_team_members(self):
        """List all team members (without passwords)"""
        return {
            username: {
                'role': data['role'],
                'email': data['email']
            }
            for username, data in self.team_members.items()
        }

# Global auth instance
team_auth = TeamAuth()

def require_auth(f):
    """Decorator to require authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not AUTH_ENABLED:
            return f(*args, **kwargs)
        
        # Check for token in header or cookie
        token = None
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
        elif 'ansible_token' in request.cookies:
            token = request.cookies['ansible_token']
        
        if not token:
            return jsonify({'error': 'Authentication required'}), 401
        
        valid, user_data = team_auth.validate_token(token)
        if not valid:
            return jsonify({'error': 'Invalid or expired token'}), 401
        
        # Add user data to request context
        request.user = user_data
        return f(*args, **kwargs)
    
    return decorated_function

def require_role(required_role):
    """Decorator to require specific role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not AUTH_ENABLED:
                return f(*args, **kwargs)
            
            user_data = getattr(request, 'user', None)
            if not user_data:
                return jsonify({'error': 'Authentication required'}), 401
            
            user_role = user_data.get('role', 'viewer')
            role_hierarchy = {'viewer': 0, 'operator': 1, 'admin': 2}
            
            if role_hierarchy.get(user_role, 0) < role_hierarchy.get(required_role, 2):
                return jsonify({'error': f'Role {required_role} required'}), 403
            
            return f(*args, **kwargs)
        
        return decorated_function
    return decorator

# Authentication routes
def add_auth_routes(app):
    """Add authentication routes to Flask app"""
    
    @app.route('/api/auth/login', methods=['POST'])
    def login():
        """Team member login"""
        try:
            data = request.get_json()
            username = data.get('username')
            password = data.get('password')
            
            if not username or not password:
                return jsonify({'error': 'Username and password required'}), 400
            
            token = team_auth.authenticate(username, password)
            if token:
                user_data = team_auth.active_tokens[token]
                response = make_response(jsonify({
                    'token': token,
                    'username': username,
                    'role': user_data['role'],
                    'email': user_data['email'],
                    'expires': user_data['expires']
                }))
                
                # Set cookie for browser access
                response.set_cookie('ansible_token', token, 
                                  max_age=TOKEN_EXPIRY_HOURS*3600,
                                  httponly=True, secure=False)
                return response
            else:
                return jsonify({'error': 'Invalid credentials'}), 401
                
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    @app.route('/api/auth/logout', methods=['POST'])
    @require_auth
    def logout():
        """Team member logout"""
        try:
            # Get token from header or cookie
            token = None
            auth_header = request.headers.get('Authorization')
            if auth_header and auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]
            elif 'ansible_token' in request.cookies:
                token = request.cookies['ansible_token']
            
            if token:
                team_auth.revoke_token(token)
            
            response = make_response(jsonify({'message': 'Logged out successfully'}))
            response.set_cookie('ansible_token', '', expires=0)
            return response
            
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    
    @app.route('/api/auth/status', methods=['GET'])
    def auth_status():
        """Check authentication status"""
        return jsonify({
            'auth_enabled': AUTH_ENABLED,
            'token_expiry_hours': TOKEN_EXPIRY_HOURS,
            'authenticated': hasattr(request, 'user'),
            'user': getattr(request, 'user', None)
        })
    
    @app.route('/api/auth/team', methods=['GET'])
    @require_auth
    @require_role('admin')
    def list_team():
        """List team members (admin only)"""
        return jsonify({
            'team_members': team_auth.list_team_members(),
            'active_tokens': len(team_auth.active_tokens)
        })
    
    @app.route('/api/auth/team', methods=['POST'])
    @require_auth
    @require_role('admin')
    def add_team_member():
        """Add team member (admin only)"""
        try:
            data = request.get_json()
            username = data.get('username')
            password = data.get('password')
            role = data.get('role', 'viewer')
            email = data.get('email', '')
            
            if not username or not password:
                return jsonify({'error': 'Username and password required'}), 400
            
            if role not in ['viewer', 'operator', 'admin']:
                return jsonify({'error': 'Invalid role'}), 400
            
            team_auth.add_team_member(username, password, role, email)
            return jsonify({'message': f'Team member {username} added successfully'})
            
        except Exception as e:
            return jsonify({'error': str(e)}), 500

# Export the auth components
__all__ = ['require_auth', 'require_role', 'add_auth_routes', 'team_auth', 'AUTH_ENABLED']