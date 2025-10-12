# Ansible Automation & WanderList DevOps Platform - AI Agent Instructions

## Project Overview

This is a multi-component DevOps portfolio showcasing professional Ansible automation, full-stack web applications, and enterprise-grade infrastructure management. The workspace contains:

- **ansible-showcase/**: Professional Ansible automation portfolio with web dashboards
- **wanderlist-app/**: Full-stack travel discovery platform with Node.js/PostgreSQL
- **WanderList-Capstone/**: Legacy capstone project components
- **wanderlist-devops/**: Additional DevOps configurations

## Architecture Patterns

### Dual Automation Approach
The project uses a unique **containerized Ansible controller** pattern:
```bash
# Ansible runs in dedicated containers, NOT in Kubernetes
./ansible-manager start  # Start Ansible automation container
./ansible-manager playbook deploy-wanderlist.yml  # Deploy via container
```

### Service Orchestration
- **WanderList App**: Node.js + PostgreSQL in Kubernetes (3 replicas)
- **Monitoring Stack**: Prometheus + Grafana + Node Exporter
- **Ansible Controller**: Separate Docker container for automation
- **Web Dashboards**: Multiple UI variants (`dashboard-enhanced.html`, `portal.html`)

## Critical Development Workflows

### Starting the Complete Environment
```bash
# 1. Start Ansible dashboard (ansible-showcase/)
./scripts/start_dashboard.sh
# Access: http://localhost:8093/portal.html

# 2. Deploy WanderList infrastructure (wanderlist-app/)
./scripts/deploy_postgres.sh
kubectl apply -f deploy_wanderlist.yml

# 3. Start monitoring and port forwarding
./scripts/check_services.sh  # Verifies all components
```

### Ansible Management Pattern
```bash
# Container-based Ansible execution (NOT local ansible commands)
./ansible-manager start           # Start automation container
./ansible-manager playbook <name> # Execute playbooks via container
./ansible-manager shell          # Interactive container access
```

### Monitoring Access Points
- **WanderList App**: `kubectl port-forward svc/wanderlist-svc 9002:3000`
- **Grafana**: `kubectl port-forward svc/grafana-service 9001:3000`
- **Prometheus**: Automatically accessible on port 9090

## Database Integration Patterns

### PostgreSQL in Kubernetes
The app uses **PostgreSQL 13** with persistent storage:
```javascript
// Database config in index.js uses Kubernetes service discovery
const dbConfig = {
  host: process.env.DB_HOST || 'postgres-service',  // K8s service name
  database: 'wanderlistdb',
  user: 'wanderuser'
};
```

### Schema Structure
```sql
-- Key tables created automatically in index.js
users (id, firstname, lastname, email, bio, created_at)
places (id, name, description, country, coordinates, image_url)
pois (id, name, description, rating, category, reviews_count)
place_user_pois (user_id, place_id, poi_id) -- favorites system
```

## Build & Deployment Conventions

### Frontend Build Process
```bash
# WanderList uses custom frontend build (not typical npm build)
docker build -t wanderlist-frontend:v1.0 .  # Custom Dockerfile
kubectl apply -f k8s/deployment.yml         # Uses local image
```

### Multi-Environment Scripts
```bash
# Production deployment (ansible-showcase/)
./scripts/deploy-anywhere.sh --production

# Development monitoring (wanderlist-app/)
./scripts/comprehensive_monitoring.sh start
```

## Service Integration Points

### API Architecture
```javascript
// index.js serves both API and static files
app.use(express.static('public'));           // Frontend assets
app.get('/api/users', getUsersHandler);      // REST API
app.get('/metrics', (req, res) => {          // Prometheus metrics
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});
```

### Cross-Component Communication
- **Ansible → Kubernetes**: Via mounted `~/.kube` in containers
- **App → Database**: Via Kubernetes service discovery (`postgres-service`)
- **Monitoring → Apps**: Via Prometheus annotations on pods

## Debugging & Troubleshooting

### Container Orchestration Issues
```bash
# Check Ansible container status
docker-compose -f docker-compose.ansible.yml ps

# Access logs for debugging
./ansible-manager logs
kubectl logs deployment/wanderlist-deployment
```

### Database Connection Problems
```bash
# Test PostgreSQL connectivity
kubectl exec -it deployment/postgres-deployment -- psql -U wanderuser -d wanderlistdb
./scripts/check_db.sh  # Automated health check
```

### Port Forwarding Management
```bash
# The scripts handle port forwarding automatically
./scripts/check_services.sh  # Shows active forwards
# Manual forwarding: kubectl port-forward svc/SERVICE PORT:PORT &
```

## Project-Specific Conventions

### Documentation Strategy
Each component has specialized docs:
- `PROJECT_SUMMARY.md`: High-level architecture overview
- `ANSIBLE_ACCESS_GUIDE.md`: Container-based automation workflows
- `SERVICE_URLS.md`: Access points and port mappings
- `HELPER_SCRIPTS.md`: Automation script documentation

### Security Patterns
```yaml
# Kubernetes deployments use non-root security contexts
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001
```

### Monitoring Integration
All services expose Prometheus metrics via:
```yaml
# Pod annotations for automatic scraping
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"
```

## Common Pitfalls to Avoid

1. **Don't run ansible commands directly** - always use `./ansible-manager` wrapper
2. **Don't use `npm build`** - WanderList uses custom Docker builds
3. **Don't access databases directly** - use service names (`postgres-service`)
4. **Always check port forwarding** - services aren't accessible without forwards
5. **Use provided scripts** - manual kubectl commands may miss dependencies

## File Location Patterns

- **Automation**: `scripts/` directories contain all operational scripts
- **Configs**: `k8s/`, `monitoring/`, and `ansible/` for infrastructure
- **Dashboards**: Multiple HTML variants in `dashboards/` or root directories
- **Documentation**: Root-level `.md` files for major topics, `docs/` for detailed guides