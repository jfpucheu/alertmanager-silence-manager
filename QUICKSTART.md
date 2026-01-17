# 🚀 Quick Start Guide

## Installation

```bash
# Clone or download the scripts
chmod +x *.sh am
```

## Quick Usage

### 🔕 Create a silence

**Interactive mode (recommended):**
```bash
./am
```

**Quick mode (1 hour):**
```bash
./silence-quick.sh
```

**Quick mode (custom duration):**
```bash
# 2 hours with comment
./silence-quick.sh 120 "Scheduled maintenance"
```

### 📋 Manage existing silences

**Interactive mode:**
```bash
./manage-silences.sh
```

**Command line:**
```bash
# List
./manage-silences.sh list

# View details
./manage-silences.sh show SILENCE_ID

# Delete
./manage-silences.sh delete SILENCE_ID

# Delete all
./manage-silences.sh delete-all
```

## Configuration

```bash
# Change namespace (default: monitoring)
export NAMESPACE="observability"

# Change Ingress name (default: alertmanager)
export INGRESS_NAME="alertmanager-ingress"

# Then run the script
./am
```

## 📦 Available Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `am` | Intelligent wrapper | Interactive or `./am [command]` |
| `alertmanager-silence.sh` | Interactive menu for creating silences | Interactive |
| `silence-quick.sh` | Quick CLI creation | `./silence-quick.sh [min] [comment]` |
| `manage-silences.sh` | Complete silence management | Interactive or CLI |

## 💡 Common Use Cases

### Scheduled maintenance (4 hours)
```bash
./silence-quick.sh 240 "Infrastructure maintenance"
```

### Quick deployment (30 min)
```bash
./silence-quick.sh 30 "Deployment v2.3.1"
```

### View all active silences
```bash
./am list
```

### Clean all silences
```bash
./am clean
```

## 🆘 Help

See the complete README.md for more details and examples.
