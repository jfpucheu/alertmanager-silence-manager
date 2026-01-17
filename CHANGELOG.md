# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-17

### ✨ Added
- Initial release of Alertmanager Silence Manager
- `am` wrapper with intelligent command detection
- `alertmanager-silence.sh` - Interactive menu for creating silences
- `silence-quick.sh` - Quick CLI silence creation
- `manage-silences.sh` - Full silence management (list, view, delete)
- Support for both Linux (GNU) and macOS (BSD) date commands
- Automatic HTTPS/HTTP detection from Kubernetes Ingress
- Colorized output for better user experience
- Comprehensive documentation (README, QUICKSTART, CONTRIBUTING)
- GitHub Actions workflow for automated testing
- Issue templates for bug reports and feature requests

### 🎯 Features
- Create global silences with custom durations (30min to 24h)
- List all active silences with formatted output
- View detailed information for specific silences
- Delete individual or all silences with confirmation
- Direct Ingress connection (no port-forward needed)
- Environment variable configuration (NAMESPACE, INGRESS_NAME)
- Multi-platform compatibility (Linux + macOS)

### 📚 Documentation
- Complete README with examples and troubleshooting
- Quick start guide for immediate usage
- Contribution guidelines
- MIT License
- Architecture diagrams and API reference

### 🔧 Technical
- Bash best practices with `set -euo pipefail`
- Error handling and validation
- Health check before operations
- JSON payload generation with jq
- UTC timestamp calculation

[Unreleased]: https://github.com/YOUR_USERNAME/alertmanager-silence-manager/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/YOUR_USERNAME/alertmanager-silence-manager/releases/tag/v1.0.0
