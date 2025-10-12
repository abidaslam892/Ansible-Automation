# 🌐 Team Access Guide - Using Ansible Platform

# 🌐 Team Access Guide - Using Ansible Platform

## 🎯 **For Team Members (Windows/Mac Users)**

### **Quick Access**
1. **Connect to the same network** as the host machine
2. **Open your browser** and go to: `http://172.17.99.74:8093/portal.html`
3. **Start automating** with beautiful web dashboards!

### **✅ Direct Access URLs (Available when host machine is ON)**
- **📱 Main Portal**: `http://172.17.99.74:8093/portal.html`
- **🤖 Enhanced Dashboard**: `http://172.17.99.74:8093/dashboard-enhanced.html`
- **🎨 Unified Dashboard**: `http://172.17.99.74:8093/dashboard-unified.html`
- **🔧 API Endpoint**: `http://172.17.99.74:8094/api`

### **🔄 Auto-Start Configured**
✅ **Services start automatically** when the host machine boots  
✅ **No manual intervention** required after restarts  
✅ **Team access available** whenever the machine is powered on  

### **For Windows Host Access**
If the host is a Windows machine with WSL, you may also access via:
- **📱 Portal**: `http://172.17.96.1:8093/portal.html`

> **Note**: Windows users may need to configure port forwarding (see below)

### **What You Can Do**

#### **🎨 Interactive Dashboard**
- **Real-time Ansible Execution**: Click to run playbooks
- **Live Log Streaming**: Watch automation in real-time
- **AI Error Analysis**: Get intelligent troubleshooting
- **Beautiful Interface**: Modern web-based automation

#### **🚀 Available Features**
- ✅ Deploy WanderList Application
- ✅ Setup Infrastructure
- ✅ Configure Monitoring
- ✅ Test Connectivity
- ✅ System Management
- ✅ Real-time Status Monitoring

#### **📱 Multiple Dashboard Options**
- **Portal**: `http://<HOST_IP>:8093/portal.html` (Start here)
- **Enhanced**: `http://<HOST_IP>:8093/dashboard-enhanced.html`
- **Unified**: `http://<HOST_IP>:8093/dashboard-unified.html`

### **API Access**
**Base URL**: `http://<HOST_IP>:8094/api`

**Endpoints**:
- `GET /api/health` - Check API status
- `POST /api/command` - Execute commands
- `GET /api/playbooks` - List available playbooks
- `POST /api/playbook/execute` - Run Ansible playbooks

### **🔧 Troubleshooting**

#### **Can't Access the Dashboard?**
1. **Check Network**: Ensure you're on the same network
2. **Check Firewall**: Host may need firewall rules opened
3. **Check IP**: Verify you're using the correct host IP
4. **Check Ports**: Ensure 8093 and 8094 are accessible

#### **Dashboard Loads but Commands Don't Work?**
1. **Check API**: Try `http://<HOST_IP>:8094/api/health`
2. **CORS Issues**: Modern browsers may block cross-origin requests
3. **Docker Status**: Ensure Docker containers are running on host

#### **Windows-Specific Issues**
If accessing from Windows machines, the host may need to run:
```powershell
# Run as Administrator
netsh interface portproxy add v4tov4 listenport=8093 listenaddress=0.0.0.0 connectport=8093 connectaddress=<WSL_IP>
netsh interface portproxy add v4tov4 listenport=8094 listenaddress=0.0.0.0 connectport=8094 connectaddress=<WSL_IP>

# Open firewall
New-NetFirewallRule -DisplayName 'Ansible Dashboard' -Direction Inbound -Port 8093 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName 'Ansible API' -Direction Inbound -Port 8094 -Protocol TCP -Action Allow
```

### **🎉 Getting Started**
1. **Navigate** to `http://<HOST_IP>:8093/portal.html`
2. **Click** on any command box to execute
3. **Watch** real-time logs and execution
4. **Enjoy** automated infrastructure management!

---

## 📞 **Need Help?**
Contact your DevOps administrator or check the host machine logs:
```bash
docker-compose -f docker-compose.team.yml logs -f
```