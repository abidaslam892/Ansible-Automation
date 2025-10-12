# Production Ansible Automation Platform
FROM ubuntu:22.04

LABEL maintainer="Ansible Automation Team"
LABEL description="Professional Ansible Dashboard for Team Collaboration"
LABEL version="1.0.0"

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV ANSIBLE_STDOUT_CALLBACK=yaml
ENV TEAM_ACCESS=enabled

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    curl \
    wget \
    git \
    openssh-client \
    sshpass \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    ansible>=6.0.0 \
    flask \
    flask-cors \
    flask-socketio \
    requests \
    pyyaml \
    jinja2 \
    boto3 \
    kubernetes \
    docker \
    jmespath \
    netaddr

# Install Ansible collections
RUN ansible-galaxy collection install \
    community.general \
    ansible.posix \
    community.docker \
    kubernetes.core

# Create working directories
WORKDIR /ansible
RUN mkdir -p /ansible/{playbooks,inventory,group_vars,host_vars,roles,logs} \
    && mkdir -p /var/log/ansible \
    && mkdir -p /app/{dashboards,api,scripts}

# Copy application files
COPY dashboards/ /app/dashboards/
COPY api/ /app/api/
COPY scripts/ /app/scripts/
COPY ansible.cfg /ansible/
COPY requirements.yml /ansible/

# Copy startup script
COPY docker/start-production.sh /start-production.sh
RUN chmod +x /start-production.sh

# Create non-root user
RUN useradd -r -s /bin/bash -d /ansible ansible \
    && chown -R ansible:ansible /ansible /app /var/log/ansible

# Switch to non-root user
USER ansible

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8093/portal.html || exit 1

# Expose ports
EXPOSE 8093 8094

# Start command
CMD ["/start-production.sh"]