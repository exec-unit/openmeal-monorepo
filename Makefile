# ============================================================================
# OpenMeal Backend - Multi-Environment Docker Compose Management
# ============================================================================
# Supported platforms: Linux, macOS, Windows (Git Bash/WSL)
# Architecture: Four-tier deployment strategy
#
# Environment Types:
#   dev        - Local development (weak PC friendly)
#   shared-dev - Shared development infrastructure on VDS
#   stage      - Full staging environment
#   prod       - Production with monitoring
#
# ============================================================================

.DEFAULT_GOAL := help
include makefiles/common.mk
include makefiles/docker.mk
include makefiles/services.mk
include makefiles/ssl.mk
include makefiles/ansible.mk

.PHONY: help

## help: Show this help message
help:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║         OpenMeal Backend - Control Panel                       ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)Core Commands (reads ENVIRONMENT from .env):$(RESET)"
	@echo "  $(YELLOW)make up$(RESET)              - Start environment"
	@echo "  $(YELLOW)make down$(RESET)            - Stop and remove containers"
	@echo "  $(YELLOW)make restart$(RESET)         - Restart environment"
	@echo ""
	@echo "$(GREEN)Environment Configuration:$(RESET)"
	@echo "  Set ENVIRONMENT in .env to one of:"
	@echo "    $(CYAN)local-dev$(RESET)   - Local dev (infra only, microservices via IDE)"
	@echo "    $(CYAN)shared-dev$(RESET)  - Shared dev infrastructure (keycloak, redpanda)"
	@echo "    $(CYAN)stage$(RESET)       - Full staging environment"
	@echo "    $(CYAN)prod$(RESET)        - Production with monitoring"
	@echo ""
	@echo "$(GREEN)Information & Monitoring:$(RESET)"
	@echo "  $(YELLOW)make ps$(RESET)              - Show container status"
	@echo "  $(YELLOW)make status$(RESET)          - Detailed status of all services"
	@echo "  $(YELLOW)make health$(RESET)          - Check service health"
	@echo ""
	@echo "$(GREEN)Build & Update:$(RESET)"
	@echo "  $(YELLOW)make build$(RESET)           - Build all images"
	@echo "  $(YELLOW)make build-nocache$(RESET)   - Build images without cache"
	@echo "  $(YELLOW)make pull$(RESET)            - Update images from registry"
	@echo ""
	@echo "$(GREEN)Cleanup:$(RESET)"
	@echo "  $(YELLOW)make clean$(RESET)           - Stop and remove containers, networks"
	@echo "  $(YELLOW)make clean-volumes$(RESET)   - Remove all volumes too (DANGEROUS!)"
	@echo "  $(YELLOW)make prune$(RESET)           - Clean unused Docker resources"
	@echo ""
	@echo "$(GREEN)Backups:$(RESET)"
	@echo "  $(YELLOW)make backup-postgres$(RESET) - Dump PostgreSQL database to ./backups"
	@echo "  $(YELLOW)make backup-mongo$(RESET)    - Dump MongoDB databases to ./backups"
	@echo ""
	@echo "$(GREEN)SSL Certificates:$(RESET)"
	@echo "  $(YELLOW)make ssl-cert-init$(RESET)   - Initialize Let's Encrypt SSL certificates"
	@echo "  $(YELLOW)make ssl-cert-renew$(RESET)  - Manually renew SSL certificates"
	@echo "  $(YELLOW)make ssl-setup-cron$(RESET)  - Setup automatic renewal (systemd/cron)"
	@echo ""
	@echo "$(GREEN)Quick Exec:$(RESET)"
	@echo "  $(YELLOW)make exec-postgres$(RESET)   - psql interactive shell"
	@echo "  $(YELLOW)make exec-mongo$(RESET)      - mongosh interactive shell"
	@echo "  $(YELLOW)make exec-redis$(RESET)      - redis-cli shell"
	@echo "  $(YELLOW)make exec-redpanda$(RESET)   - rpk cluster info"
	@echo "  $(YELLOW)make exec-keycloak$(RESET)   - keycloak bash shell"
	@echo "  $(YELLOW)make exec-minio$(RESET)      - minio shell"
	@echo "  $(YELLOW)make exec-nginx$(RESET)      - nginx shell"
	@echo "  $(YELLOW)make exec-certbot$(RESET)    - certbot shell"
	@echo "  $(YELLOW)make exec-prometheus$(RESET) - prometheus shell"
	@echo "  $(YELLOW)make exec-grafana$(RESET)    - grafana shell"
	@echo ""
	@echo "$(GREEN)Database Configuration:$(RESET)"
	@echo "  $(YELLOW)make prepare-db-configs$(RESET) - Prepare database configs for current environment"
	@echo ""
	@echo "$(GREEN)Quick Start:$(RESET)"
	@echo "  $(YELLOW)make init$(RESET)            - Initialize all configs (.env, microservices, DB users)"
	@echo "  $(YELLOW)make init-env$(RESET)        - Initialize .env file only"
	@echo "  $(YELLOW)make init-microservices$(RESET) - Initialize microservices config only"
	@echo "  $(YELLOW)make init-db-users$(RESET)   - Initialize database user configs only"
	@echo ""
	@echo "$(GREEN)Testing:$(RESET)"
	@echo "  $(YELLOW)make test$(RESET)            - Run all tests (lint + syntax + molecule)"
	@echo "  $(YELLOW)make test-ansible$(RESET)    - Run Molecule tests for all roles"
	@echo "  $(YELLOW)make test-ansible-role ROLE=common$(RESET) - Test single role"
	@echo "  $(YELLOW)make test-ansible-lint$(RESET) - Run ansible-lint"
	@echo ""
	@echo "$(GREEN)Profiles (activated automatically by environment commands):$(RESET)"
	@echo "  $(YELLOW)infra$(RESET)                - Core infrastructure (postgres, redis, nginx...)"
	@echo "  $(YELLOW)monitoring$(RESET)           - Monitoring stack (prometheus, grafana)"
	@echo "  $(YELLOW)local-dev$(RESET)            - Local development services (postgres, mongodb, redis, minio)"
	@echo "  $(YELLOW)shared-dev$(RESET)           - Shared development services (redpanda, keycloak, nginx, certbot)"
	@echo ""
	@echo "$(CYAN)Detected OS: $(DETECTED_OS)$(RESET)"
	@echo ""
