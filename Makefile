.PHONY: help install test clean shellcheck format

# Variables
INSTALL_DIR ?= $(HOME)/.local/bin
SCRIPTS = alertmanager-silence.sh silence-quick.sh manage-silences.sh am

help: ## Show help
	@echo "╔═══════════════════════════════════════════════╗"
	@echo "║  🔕 Alertmanager Silence Manager             ║"
	@echo "║     Makefile - Available commands            ║"
	@echo "╚═══════════════════════════════════════════════╝"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install scripts to ~/.local/bin
	@echo "📦 Installing to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@cp $(SCRIPTS) $(INSTALL_DIR)/
	@chmod +x $(addprefix $(INSTALL_DIR)/,$(SCRIPTS))
	@echo "✅ Installation completed!"
	@echo ""
	@echo "💡 Add $(INSTALL_DIR) to your PATH if not already done:"
	@echo "   export PATH=\"\$$PATH:$(INSTALL_DIR)\""

uninstall: ## Uninstall scripts
	@echo "🗑️  Uninstalling..."
	@cd $(INSTALL_DIR) && rm -f $(SCRIPTS)
	@echo "✅ Uninstallation completed!"

test: ## Test script syntax
	@echo "🧪 Testing syntax..."
	@for script in $(SCRIPTS); do \
		echo "  Checking $$script..."; \
		bash -n $$script || exit 1; \
	done
	@echo "✅ All tests pass!"

shellcheck: ## Check with ShellCheck
	@echo "🔍 Checking with ShellCheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck $(SCRIPTS); \
		echo "✅ ShellCheck OK!"; \
	else \
		echo "⚠️  ShellCheck not installed"; \
		echo "   Ubuntu: sudo apt install shellcheck"; \
		echo "   macOS: brew install shellcheck"; \
		exit 1; \
	fi

format: ## Format scripts (whitespace, etc)
	@echo "✨ Formatting scripts..."
	@for script in $(SCRIPTS); do \
		sed -i.bak 's/[[:space:]]*$$//' $$script && rm -f $$script.bak; \
	done
	@echo "✅ Formatting completed!"

clean: ## Clean temporary files
	@echo "🧹 Cleaning..."
	@find . -name "*.bak" -delete
	@find . -name "*.tmp" -delete
	@find . -name "*~" -delete
	@echo "✅ Cleanup completed!"

check-deps: ## Check dependencies
	@echo "🔍 Checking dependencies..."
	@for cmd in kubectl curl jq; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			echo "  ✅ $$cmd"; \
		else \
			echo "  ❌ $$cmd missing"; \
		fi; \
	done

demo: ## Run interactive demo
	@echo "🎬 Alertmanager Silence Manager Demo"
	@echo ""
	@./am help

version: ## Show version
	@echo "Alertmanager Silence Manager v1.0.0"
	@echo "Scripts: $(SCRIPTS)"

list-silences: ## List active silences (requires kubectl)
	@./am list

create-test-silence: ## Create test silence (5 minutes)
	@./am create 5 "Test silence via Makefile"

zip: ## Create ZIP archive for distribution
	@echo "📦 Creating archive..."
	@zip -r alertmanager-silence-manager.zip . -x "*.git*" "*.zip" "*.bak" "*~"
	@echo "✅ Archive created: alertmanager-silence-manager.zip"
	@ls -lh alertmanager-silence-manager.zip

# Aliases
all: help
.DEFAULT_GOAL := help
