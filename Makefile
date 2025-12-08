# Makefile for Trustee Quadlet
# Provides convenient targets for testing, building RPM, and running services

SHELL := /bin/bash
.PHONY: all test test-static test-syntax test-unit test-rpm test-health test-integration \
        build-rpm install start stop restart logs clean help

# Project info
PROJECT_NAME := trustee-quadlet
VERSION := 0.1.0
RELEASE := 1

# Directories
PROJECT_ROOT := $(shell pwd)
QUADLET_DIR := $(PROJECT_ROOT)/quadlet
CONFIG_DIR := $(PROJECT_ROOT)/configs
RPM_DIR := $(PROJECT_ROOT)/rpm
TEST_DIR := $(PROJECT_ROOT)/tests
BUILD_DIR := $(PROJECT_ROOT)/build

# RPM build directories
RPM_BUILD_DIR := $(BUILD_DIR)/rpmbuild
RPM_SOURCES := $(RPM_BUILD_DIR)/SOURCES
RPM_SPECS := $(RPM_BUILD_DIR)/SPECS
RPM_RPMS := $(RPM_BUILD_DIR)/RPMS
RPM_SRPMS := $(RPM_BUILD_DIR)/SRPMS

# Default container registry
REGISTRY ?= registry.redhat.io/rhtas

# ============================================================================
# HELP
# ============================================================================

help:
	@echo "Trustee Quadlet - Makefile targets"
	@echo ""
	@echo "Testing:"
	@echo "  make test           - Run all tests (including container tests)"
	@echo "  make test-static    - Run static tests only (no containers needed)"
	@echo "  make test-syntax    - Run Quadlet syntax tests"
	@echo "  make test-unit      - Run unit generation tests"
	@echo "  make test-rpm       - Run RPM packaging tests"
	@echo "  make test-health    - Run container health tests"
	@echo "  make test-integration - Run integration tests"
	@echo ""
	@echo "Building:"
	@echo "  make build-rpm      - Build RPM package"
	@echo "  make build-srpm     - Build source RPM"
	@echo "  make tarball        - Create source tarball"
	@echo ""
	@echo "Development:"
	@echo "  make install        - Install Quadlet files locally (for testing)"
	@echo "  make uninstall      - Remove locally installed files"
	@echo "  make start          - Start all Trustee services"
	@echo "  make stop           - Stop all Trustee services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - Follow service logs"
	@echo "  make status         - Show service status"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Remove build artifacts"
	@echo "  make clean-containers - Stop and remove containers"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  VERSION=$(VERSION)"

# ============================================================================
# TESTING (TDD)
# ============================================================================

test:
	@echo "Running all tests..."
	@SKIP_RUNTIME_TESTS=false $(TEST_DIR)/test_runner.sh all

test-static:
	@echo "Running static tests (no containers)..."
	@SKIP_RUNTIME_TESTS=true $(TEST_DIR)/test_runner.sh static

test-syntax:
	@echo "Running syntax tests..."
	@$(TEST_DIR)/test_runner.sh syntax

test-unit:
	@echo "Running unit generation tests..."
	@$(TEST_DIR)/test_runner.sh unit

test-rpm:
	@echo "Running RPM tests..."
	@$(TEST_DIR)/test_runner.sh rpm

test-health:
	@echo "Running health tests..."
	@$(TEST_DIR)/test_runner.sh health

test-integration:
	@echo "Running integration tests..."
	@$(TEST_DIR)/test_runner.sh integration

# ============================================================================
# RPM BUILDING
# ============================================================================

$(RPM_BUILD_DIR):
	mkdir -p $(RPM_SOURCES) $(RPM_SPECS) $(RPM_RPMS) $(RPM_SRPMS)

tarball: $(RPM_BUILD_DIR)
	@echo "Creating source tarball..."
	mkdir -p $(BUILD_DIR)/$(PROJECT_NAME)-$(VERSION)
	cp -r quadlet configs scripts docs README.md LICENSE \
		$(BUILD_DIR)/$(PROJECT_NAME)-$(VERSION)/ 2>/dev/null || true
	mkdir -p $(BUILD_DIR)/$(PROJECT_NAME)-$(VERSION)/quadlet
	mkdir -p $(BUILD_DIR)/$(PROJECT_NAME)-$(VERSION)/configs
	tar -C $(BUILD_DIR) -czf $(RPM_SOURCES)/$(PROJECT_NAME)-$(VERSION).tar.gz \
		$(PROJECT_NAME)-$(VERSION)
	rm -rf $(BUILD_DIR)/$(PROJECT_NAME)-$(VERSION)
	@echo "Created: $(RPM_SOURCES)/$(PROJECT_NAME)-$(VERSION).tar.gz"

build-srpm: tarball
	@echo "Building source RPM..."
	cp $(RPM_DIR)/$(PROJECT_NAME).spec $(RPM_SPECS)/
	rpmbuild -bs \
		--define "_topdir $(RPM_BUILD_DIR)" \
		$(RPM_SPECS)/$(PROJECT_NAME).spec
	@echo "SRPM created in $(RPM_SRPMS)/"

build-rpm: tarball
	@echo "Building RPM..."
	cp $(RPM_DIR)/$(PROJECT_NAME).spec $(RPM_SPECS)/
	rpmbuild -bb \
		--define "_topdir $(RPM_BUILD_DIR)" \
		$(RPM_SPECS)/$(PROJECT_NAME).spec
	@echo "RPM created in $(RPM_RPMS)/"

# ============================================================================
# LOCAL DEVELOPMENT
# ============================================================================

install:
	@echo "Installing Quadlet files locally..."
	@if [[ $$(id -u) -eq 0 ]]; then \
		install -d /etc/containers/systemd; \
		install -d /etc/trustee/{kbs,as,rvps}; \
		install -m 0644 $(QUADLET_DIR)/*.container /etc/containers/systemd/; \
		install -m 0644 $(QUADLET_DIR)/*.network /etc/containers/systemd/; \
		install -m 0644 $(QUADLET_DIR)/*.volume /etc/containers/systemd/; \
		install -m 0644 $(CONFIG_DIR)/kbs/* /etc/trustee/kbs/ 2>/dev/null || true; \
		install -m 0644 $(CONFIG_DIR)/as/* /etc/trustee/as/ 2>/dev/null || true; \
		install -m 0644 $(CONFIG_DIR)/rvps/* /etc/trustee/rvps/ 2>/dev/null || true; \
		systemctl daemon-reload; \
		echo "Installed to /etc/containers/systemd/ and /etc/trustee/"; \
	else \
		install -d ~/.config/containers/systemd; \
		install -m 0644 $(QUADLET_DIR)/*.container ~/.config/containers/systemd/; \
		install -m 0644 $(QUADLET_DIR)/*.network ~/.config/containers/systemd/; \
		install -m 0644 $(QUADLET_DIR)/*.volume ~/.config/containers/systemd/; \
		systemctl --user daemon-reload; \
		echo "Installed to ~/.config/containers/systemd/ (user mode)"; \
	fi

uninstall:
	@echo "Removing Quadlet files..."
	@if [[ $$(id -u) -eq 0 ]]; then \
		rm -f /etc/containers/systemd/trustee-*.container; \
		rm -f /etc/containers/systemd/trustee.network; \
		rm -f /etc/containers/systemd/*-config.volume /etc/containers/systemd/*-data.volume; \
		systemctl daemon-reload; \
	else \
		rm -f ~/.config/containers/systemd/trustee-*.container; \
		rm -f ~/.config/containers/systemd/trustee.network; \
		rm -f ~/.config/containers/systemd/*-config.volume ~/.config/containers/systemd/*-data.volume; \
		systemctl --user daemon-reload; \
	fi

start:
	@echo "Starting Trustee services..."
	@if [[ $$(id -u) -eq 0 ]]; then \
		systemctl start trustee-kbs; \
	else \
		systemctl --user start trustee-kbs; \
	fi

stop:
	@echo "Stopping Trustee services..."
	@if [[ $$(id -u) -eq 0 ]]; then \
		systemctl stop trustee-kbs trustee-as trustee-rvps 2>/dev/null || true; \
	else \
		systemctl --user stop trustee-kbs trustee-as trustee-rvps 2>/dev/null || true; \
	fi

restart: stop start

status:
	@echo "Service status:"
	@if [[ $$(id -u) -eq 0 ]]; then \
		systemctl status trustee-kbs trustee-as trustee-rvps --no-pager 2>/dev/null || true; \
	else \
		systemctl --user status trustee-kbs trustee-as trustee-rvps --no-pager 2>/dev/null || true; \
	fi

logs:
	@echo "Following logs (Ctrl+C to exit)..."
	@if [[ $$(id -u) -eq 0 ]]; then \
		journalctl -f -u trustee-kbs -u trustee-as -u trustee-rvps; \
	else \
		journalctl --user -f -u trustee-kbs -u trustee-as -u trustee-rvps; \
	fi

# ============================================================================
# CLEANUP
# ============================================================================

clean:
	rm -rf $(BUILD_DIR)
	rm -rf .generated-units

clean-containers:
	@echo "Stopping and removing containers..."
	podman stop trustee-kbs trustee-as trustee-rvps 2>/dev/null || true
	podman rm trustee-kbs trustee-as trustee-rvps 2>/dev/null || true
	podman network rm trustee 2>/dev/null || true

# ============================================================================
# DEFAULT
# ============================================================================

all: test-static
