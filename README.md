# 🔕 Alertmanager Silence Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue.svg)](https://github.com)

Complete suite of Bash scripts to easily create and manage global silences on Alertmanager via Kubernetes Ingress URL.

## ✨ Features

- 🎯 **Intuitive interface** - Colorized interactive menu
- ⚡ **Quick mode** - One-line silence creation
- 🔍 **Complete management** - List, view, and delete silences
- 🌐 **Direct Ingress** - No port-forward needed
- 🖥️ **Cross-platform** - Linux and macOS compatible
- 🔒 **HTTPS/HTTP support** - Automatically detected from Kubernetes resources
- 🎨 **Colorized output** - Better readability

## 📦 Installation

### Method 1: Automatic installation script (⭐ Recommended)

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/jfpucheu/alertmanager-silence-manager/main/install.sh | bash

# Or download first then install
wget https://raw.githubusercontent.com/jfpucheu/alertmanager-silence-manager/main/install.sh
chmod +x install.sh
./install.sh
```

The script will automatically install to `~/.local/bin` and check dependencies.

### Method 2: Via Git (for developers)

```bash
# Clone the repository
git clone https://github.com/jfpucheu/alertmanager-silence-manager.git
cd alertmanager-silence-manager

# Make scripts executable
chmod +x *.sh am

# Run the intelligent wrapper
./am
```

### Method 3: Direct download

```bash
# Download the archive
wget https://github.com/jfpucheu/alertmanager-silence-manager/archive/main.zip
unzip main.zip
cd alertmanager-silence-manager-main

# Make scripts executable
chmod +x *.sh am
```

## 📋 Prerequisites

| Tool | Linux | macOS | Installation |
|------|-------|-------|--------------|
| `kubectl` | ✅ | ✅ | [Docs](https://kubernetes.io/docs/tasks/tools/) |
| `curl` | ✅ | ✅ | Pre-installed |
| `jq` | ✅ | ✅ | `apt install jq` / `brew install jq` |
| `bash` | ✅ | ✅ | Pre-installed |

### Installing dependencies

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y jq kubectl curl
```

**macOS:**
```bash
brew install jq kubectl
```

## 🚀 Usage

### Option 1: Intelligent wrapper `am` (⭐ Recommended)

The `am` wrapper automatically detects what you want to do:

```bash
# Interactive mode - full menu
./am

# Create a silence quickly
./am create 60                          # 1 hour
./am create 120 "Server maintenance"    # 2 hours with comment

# List silences
./am list

# View silence details
./am show SILENCE_ID

# Delete a silence
./am delete SILENCE_ID

# Complete help
./am help
```

### Option 2: Individual scripts

#### 📝 Script 1: `alertmanager-silence.sh` - Interactive interface

Complete script with user interface and error handling.

```bash
# Make executable
chmod +x alertmanager-silence.sh

# Run the script
./alertmanager-silence.sh
```

**Features:**
- ✨ Interactive menu with duration choices
- 🔍 Automatic Ingress URL detection
- 🔒 Automatic HTTP/HTTPS support
- ✅ Connection validation
- 💬 Custom comment addition
- 🎨 Colorized display

**Available durations:**
- 30 minutes
- 1 hour
- 2 hours
- 4 hours
- 8 hours
- 12 hours
- 24 hours
- Custom duration

---

#### ⚡ Script 2: `silence-quick.sh` - Quick command line

Minimal script for quick use or automation.

```bash
# Make executable
chmod +x silence-quick.sh

# Simple usage (1 hour default)
./silence-quick.sh

# With custom duration (in minutes)
./silence-quick.sh 120

# With duration and comment
./silence-quick.sh 240 "Scheduled maintenance"
```

**Syntax:**
```bash
./silence-quick.sh [DURATION_MINUTES] [COMMENT]
```

---

#### 🔍 Script 3: `manage-silences.sh` - Silence management

```bash
# Make executable
chmod +x manage-silences.sh

# Interactive mode
./manage-silences.sh

# Command line mode
./manage-silences.sh list                # List all
./manage-silences.sh show SILENCE_ID     # View details
./manage-silences.sh delete SILENCE_ID   # Delete one
./manage-silences.sh delete-all          # Delete all (with confirmation)
```

## ⚙️ Configuration

### Environment variables

Scripts use environment variables for configuration:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `NAMESPACE` | Kubernetes namespace | `monitoring` | `observability` |
| `INGRESS_NAME` | Optional Ingress name used as fallback | empty | `alertmanager-public` |
| `HTTPROUTE_NAME` | HttpRoute name searched first | `alertmanager` | `alertmanager-route` |

`INGRESS_NAME` and `HTTPROUTE_NAME` are Kubernetes resource names, not hostnames. The script searches the HttpRoute first. `INGRESS_NAME` is optional and is used only if the HttpRoute is not found.

### Configuration examples

**Temporary configuration:**
```bash
NAMESPACE=production INGRESS_NAME=alertmanager-prod ./am create 60
```

**Permanent configuration:**
```bash
export NAMESPACE="production"
export INGRESS_NAME="alertmanager-prod"
export HTTPROUTE_NAME="alertmanager-prod"
./am list
```

**Configuration file (optional):**
```bash
# Create a .env file
cat > .env << EOF
export NAMESPACE="production"
export INGRESS_NAME="alertmanager-prod"
export HTTPROUTE_NAME="alertmanager-prod"
EOF

# Source before use
source .env
./am create 120
```

## 🔧 How it works

1. **URL retrieval**
  - Script queries the Kubernetes HttpRoute named by `HTTPROUTE_NAME` first
  - If that HttpRoute does not exist and `INGRESS_NAME` is set, it queries the Ingress
  - For an Ingress, uses HTTPS when `.spec.tls` is configured and HTTP otherwise
  - For an HttpRoute, reads the protocol from the listener of its parent Gateway
   
2. **Connection test**
   - Checks Alertmanager's `/-/ready` endpoint
   
3. **Silence creation**
   - Generates global regex matcher: `alertname=~".+"`
   - Calculates UTC timestamps
   - Sends POST request to `/api/v2/silences`

## 📝 Usage examples

### Common use cases

#### 🔧 Scheduled maintenance

```bash
# 4-hour silence for infrastructure maintenance
./am create 240 "Infrastructure maintenance - Server updates"

# Or interactive mode with menu choice
./alertmanager-silence.sh
```

#### 🚀 Application deployment

```bash
# Quick 30-minute silence during deployment
./silence-quick.sh 30 "Application deployment v2.3.1"
```

#### 🔍 Check active silences

```bash
# List all silences
./am list

# View complete details of a silence
./am show abc123def456
```

#### 🗑️ Cleanup

```bash
# Delete a specific silence
./am delete abc123def456

# Delete all silences (with confirmation)
./am clean
```

### CI/CD Integration

#### GitLab CI
```yaml
deploy_production:
  script:
    - ./am create 60 "CI/CD Deployment - Pipeline #${CI_PIPELINE_ID}"
    - kubectl apply -f k8s/production/
  after_script:
    - echo "Silence will lift automatically after 60 minutes"
```

#### GitHub Actions
```yaml
- name: Create Alertmanager Silence
  run: |
    ./am create 45 "GitHub Actions Deploy - Run #${{ github.run_number }}"
    
- name: Deploy Application
  run: kubectl apply -f manifests/
```

#### Jenkins
```groovy
pipeline {
    stages {
        stage('Silence Alerts') {
            steps {
                sh './am create 60 "Jenkins Deploy - Build #${BUILD_NUMBER}"'
            }
        }
        stage('Deploy') {
            steps {
                sh 'kubectl apply -f deployment.yaml'
            }
        }
    }
}
```

### Automation with Cron

```bash
# Automatic silence every night during backup (2am-4am)
0 2 * * * cd /path/to/scripts && ./silence-quick.sh 120 "Automatic nightly backup"

# Silence for weekly maintenance window (Sunday 3am-7am)
0 3 * * 0 cd /path/to/scripts && ./silence-quick.sh 240 "Weekly maintenance"
```

## 🔍 Verify active silences

```bash
# Via kubectl
INGRESS_HOST=$(kubectl get ingress alertmanager -n monitoring -o jsonpath='{.spec.rules[0].host}')

# List silences
curl -s "https://${INGRESS_HOST}/api/v2/silences" | jq .

# View specific silence
curl -s "https://${INGRESS_HOST}/api/v2/silence/SILENCE_ID" | jq .
```

## 🗑️ Delete a silence

```bash
# Get silence ID
SILENCE_ID="xyz123"
INGRESS_HOST=$(kubectl get ingress alertmanager -n monitoring -o jsonpath='{.spec.rules[0].host}')

# Delete silence
curl -X DELETE "https://${INGRESS_HOST}/api/v2/silence/${SILENCE_ID}"
```

## 🐛 Troubleshooting

### ❌ Error: "Cannot find Ingress"

**Problem:** Script cannot find Alertmanager Ingress

**Solutions:**
```bash
# 1. Check available Ingresses
kubectl get ingress -n monitoring

# 2. List all namespaces
kubectl get ingress --all-namespaces | grep alertmanager

# 3. Use correct Ingress name
INGRESS_NAME="your-ingress" ./am list

# 4. Check namespace
NAMESPACE="your-namespace" ./am list
```

### ❌ Error: "Cannot reach Alertmanager"

**Problem:** Script cannot connect to URL

**Solutions:**
```bash
# 1. Check Ingress is accessible
kubectl get ingress alertmanager -n monitoring

# 2. Test URL manually
INGRESS_HOST=$(kubectl get ingress alertmanager -n monitoring -o jsonpath='{.spec.rules[0].host}')
curl -k https://${INGRESS_HOST}/-/ready

# 3. Check TLS certificates
kubectl get ingress alertmanager -n monitoring -o yaml | grep tls -A 5

# 4. Test HTTP if HTTPS doesn't work
curl http://${INGRESS_HOST}/-/ready
```

### ❌ Error: "Command missing: jq"

**Problem:** jq is not installed

**Solutions:**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y jq

# macOS
brew install jq

# Verify installation
jq --version
```

### ⚠️ Issue: Date format difference (macOS vs Linux)

**This is normal!** Scripts automatically detect the system:
- **Linux**: Uses GNU date (`-d` option)
- **macOS**: Uses BSD date (`-v` option)

No action required, detection is automatic.

### 🔍 Debug Mode

To see more details during execution:

```bash
# Enable verbose mode
set -x
./am create 60
set +x

# View Kubernetes logs
kubectl logs -n monitoring -l app=alertmanager --tail=50

# Test connection manually
INGRESS_HOST=$(kubectl get ingress alertmanager -n monitoring -o jsonpath='{.spec.rules[0].host}')
curl -v https://${INGRESS_HOST}/api/v2/silences
```

## 🏗️ Architecture

### File structure

```
alertmanager-silence-manager/
├── am                          # 🎯 Intelligent wrapper (main entry point)
├── alertmanager-silence.sh     # 📝 Complete interactive interface
├── silence-quick.sh            # ⚡ Quick CLI creation
├── manage-silences.sh          # 🔍 Manage existing silences
├── README.md                   # 📚 Complete documentation
└── QUICKSTART.md               # 🚀 Quick start guide
```

### Workflow

```
┌─────────────────────────────────────────────────────────┐
│                    Wrapper "am"                          │
│              (Automatic detection)                       │
└───────────────┬─────────────────────────────────────────┘
                │
    ┌───────────┼───────────┬──────────────┐
    │           │           │              │
    ▼           ▼           ▼              ▼
┌────────┐ ┌────────┐ ┌─────────┐  ┌──────────────┐
│ create │ │  list  │ │ delete  │  │    help      │
└───┬────┘ └───┬────┘ └────┬────┘  └──────────────┘
    │          │           │
    ▼          ▼           ▼
┌─────────────────────────────────────────────────┐
│     Individual scripts (*.sh)                    │
│  • alertmanager-silence.sh                      │
│  • silence-quick.sh                             │
│  • manage-silences.sh                           │
└──────────────┬──────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────┐
│    Kubernetes Ingress → Alertmanager           │
│    (Direct HTTP/HTTPS connection)              │
└─────────────────────────────────────────────────┘
```

## 📚 Alertmanager API

Complete documentation: https://prometheus.io/docs/alerting/latest/clients/

### Endpoints used

| Endpoint | Method | Description | Usage |
|----------|--------|-------------|-------|
| `/-/ready` | GET | Health check | Connection test |
| `/api/v2/silences` | GET | List silences | `./am list` |
| `/api/v2/silences` | POST | Create silence | `./am create` |
| `/api/v2/silence/{id}` | GET | Silence details | `./am show ID` |
| `/api/v2/silence/{id}` | DELETE | Delete silence | `./am delete ID` |

### Silence format

```json
{
  "matchers": [
    {
      "name": "alertname",
      "value": ".+",
      "isRegex": true
    }
  ],
  "startsAt": "2026-01-17T14:00:00Z",
  "endsAt": "2026-01-17T15:00:00Z",
  "createdBy": "alertmanager-silence-script",
  "comment": "Scheduled maintenance"
}
```

## 🤝 Comparison with old script

| Feature | Old script | New script |
|---------|-----------|------------|
| **Port-forward** | ✅ Yes (complex) | ❌ No (direct Ingress) |
| **Dependencies** | kubectl, curl, python3 | kubectl, curl, jq, date |
| **Speed** | 🐢 Slow (PF wait) | ⚡ Fast (direct) |
| **Stability** | ⚠️ PF issues | ✅ Very stable |
| **Interface** | Basic | 🎨 Colorized and modern |
| **Quick mode** | ❌ Not available | ✅ Yes (`silence-quick.sh`) |
| **Silence management** | ❌ No | ✅ Yes (`manage-silences.sh`) |
| **Cross-platform** | Linux only | ✅ Linux + macOS |
| **Intelligent wrapper** | ❌ No | ✅ Yes (`am`) |
| **Documentation** | Minimal | 📚 Complete |

## 🔒 Security

### Best practices

- ✅ Scripts **never store** passwords or secrets
- ✅ **HTTPS/TLS** support for secure connections
- ✅ Uses existing **Kubernetes RBAC**
- ✅ No sensitive data in logs

### Required Kubernetes permissions

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: monitoring
  name: alertmanager-silence-manager
rules:
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list"]
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["httproutes", "gateways"]
  verbs: ["get", "list"]
```

## 🤝 Contributing

Contributions are welcome! 

### How to contribute

1. **Fork** the project
2. **Create** a branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### Guidelines

- Test your changes on Linux **and** macOS if possible
- Add comments for complex code
- Update documentation if necessary
- Follow existing code style (bash best practices)

### Report a bug

Open an [issue](https://github.com/jfpucheu/alertmanager-silence-manager/issues) with:
- Problem description
- Command executed
- Complete error message
- Operating system
- Versions of kubectl, bash, jq

## 📜 Changelog

### v1.0.0 (2026-01-17)
- ✨ Initial release
- 🎯 Intelligent wrapper `am`
- 📝 Complete interactive script
- ⚡ Quick CLI mode
- 🔍 Complete silence management
- 🖥️ macOS and Linux support
- 📚 Complete documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Prometheus Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/) - For the excellent API
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) - Kubernetes client
- [jq](https://stedolan.github.io/jq/) - Command-line JSON processor

## 💬 Support

- 📖 [Complete documentation](README.md)
- 🚀 [Quick start guide](QUICKSTART.md)
- 🐛 [Report a bug](https://github.com/jfpucheu/alertmanager-silence-manager/issues)
- 💡 [Request a feature](https://github.com/jfpucheu/alertmanager-silence-manager/issues)

---

<div align="center">

**⭐ If this project helps you, please give it a star! ⭐**

Made with ❤️ for DevOps and SRE teams

</div>
