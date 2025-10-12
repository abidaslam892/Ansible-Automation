# Ansible Docker Container for WanderList Infrastructure Management
FROM python:3.11-slim

LABEL maintainer="WanderList DevOps Team"
LABEL description="Ansible container for WanderList infrastructure automation"

# Set environment variables
ENV ANSIBLE_HOST_KEY_CHECKING=False
ENV ANSIBLE_RETRY_FILES_ENABLED=False
ENV ANSIBLE_SSH_PIPELINING=True
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    openssh-client \
    sshpass \
    git \
    curl \
    wget \
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible and additional Python packages
RUN pip install --no-cache-dir \
    ansible \
    ansible-core \
    boto3 \
    kubernetes \
    docker \
    jmespath \
    netaddr \
    requests \
    flask \
    flask-cors

# Create ansible user
RUN useradd -m -s /bin/bash ansible && \
    mkdir -p /home/ansible/.ssh && \
    chown -R ansible:ansible /home/ansible

# Create working directories
WORKDIR /ansible
RUN mkdir -p /ansible/{playbooks,inventory,roles,group_vars,host_vars,logs}

# Copy Ansible configuration
COPY ansible.cfg /ansible/
COPY requirements.yml /ansible/

# Set proper permissions
RUN chown -R ansible:ansible /ansible

# Switch to ansible user
USER ansible

# Install Ansible collections and roles
RUN ansible-galaxy install -r requirements.yml || true

# Set default working directory
WORKDIR /ansible

# Default command
CMD ["/bin/bash"]