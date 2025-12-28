# ============================================================================
# Docker Compose Management
# ============================================================================

.PHONY: up down restart restart-db ps build build-nocache pull clean clean-volumes prune status health
.PHONY: prepare-db-configs

# ============================================================================
# Unified Environment Controls
# ============================================================================
# Automatically detects environment from ENVIRONMENT variable in .env.infra
# Supported values: local-dev, shared-dev, stage, prod

## up: Start environment (reads ENVIRONMENT from .env.infra)
## Usage: make up [SERVICES="service1 service2"]
up: check-env prepare-db-configs
	@ENV=$$(grep "^ENVIRONMENT=" $(ENV_FILE) | cut -d'=' -f2); \
	if [ -n "$(SERVICES)" ]; then \
		echo "$(GREEN)→ Starting specific services: $(SERVICES)$(RESET)"; \
		$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) up -d $(SERVICES); \
		echo "$(GREEN)✓ Services started: $(SERVICES)$(RESET)"; \
	else \
		case "$$ENV" in \
			local-dev) \
				echo "$(GREEN)→ Starting LOCAL DEV environment...$(RESET)"; \
				echo "$(CYAN)→ Infrastructure: postgres, mongodb, redis, minio$(RESET)"; \
				echo "$(CYAN)→ External deps: shared-dev keycloak & redpanda$(RESET)"; \
				echo "$(CYAN)→ Microservices: from $(MICROSERVICES_LOCAL)$(RESET)"; \
				$(MAKE) check-microservices-config; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile local-dev up -d; \
				$(MAKE) _start-selected-microservices; \
				echo "$(GREEN)✓ LOCAL DEV environment started$(RESET)"; \
				echo "$(YELLOW)→ Configure external connections to shared-dev VDS$(RESET)"; \
				;; \
			shared-dev) \
				echo "$(GREEN)→ Starting SHARED DEV infrastructure...$(RESET)"; \
				echo "$(CYAN)→ Services: keycloak, redpanda, nginx, certbot$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile shared-dev up -d; \
				echo "$(GREEN)✓ SHARED DEV infrastructure started$(RESET)"; \
				echo "$(YELLOW)→ This provides shared services for local dev environments$(RESET)"; \
				;; \
			stage) \
				echo "$(GREEN)→ Starting STAGING environment...$(RESET)"; \
				echo "$(CYAN)→ Full infrastructure stack (no MinIO)$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile stage up -d; \
				echo "$(GREEN)✓ STAGING environment started$(RESET)"; \
				;; \
			prod) \
				echo "$(GREEN)→ Starting PRODUCTION environment...$(RESET)"; \
				echo "$(CYAN)→ Full infrastructure + monitoring stack (no MinIO)$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) --profile prod --profile monitoring up -d; \
				echo "$(GREEN)✓ PRODUCTION environment started$(RESET)"; \
				;; \
			*) \
				echo "$(RED)✗ Unknown ENVIRONMENT: $$ENV$(RESET)"; \
				echo "$(YELLOW)→ Set ENVIRONMENT in .env.infra to: local-dev, shared-dev, stage, or prod$(RESET)"; \
				exit 1; \
				;; \
		esac; \
	fi

## down: Stop and remove containers (preserves volumes)
## Usage: make down [SERVICES="service1 service2"]
down: check-env
	@ENV=$$(grep "^ENVIRONMENT=" $(ENV_FILE) | cut -d'=' -f2); \
	if [ -n "$(SERVICES)" ]; then \
		echo "$(YELLOW)→ Stopping specific services: $(SERVICES)$(RESET)"; \
		$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) stop $(SERVICES); \
		$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) rm -f $(SERVICES); \
		echo "$(GREEN)✓ Services stopped: $(SERVICES)$(RESET)"; \
	else \
		case "$$ENV" in \
			local-dev) \
				echo "$(YELLOW)→ Stopping LOCAL DEV environment...$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile local-dev down --remove-orphans; \
				echo "$(GREEN)✓ LOCAL DEV environment stopped (volumes preserved)$(RESET)"; \
				;; \
			shared-dev) \
				echo "$(YELLOW)→ Stopping SHARED DEV infrastructure...$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile shared-dev down --remove-orphans; \
				echo "$(GREEN)✓ SHARED DEV infrastructure stopped (volumes preserved)$(RESET)"; \
				;; \
			stage) \
				echo "$(YELLOW)→ Stopping STAGING environment...$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) --profile stage down --remove-orphans; \
				echo "$(GREEN)✓ STAGING environment stopped (volumes preserved)$(RESET)"; \
				;; \
			prod) \
				echo "$(YELLOW)→ Stopping PRODUCTION environment...$(RESET)"; \
				$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) --profile prod --profile monitoring down --remove-orphans; \
				echo "$(GREEN)✓ PRODUCTION environment stopped (volumes preserved)$(RESET)"; \
				;; \
			*) \
				echo "$(RED)✗ Unknown ENVIRONMENT: $$ENV$(RESET)"; \
				exit 1; \
				;; \
		esac; \
	fi

## restart: Restart environment
## Usage: make restart [SERVICES="service1 service2"]
restart:
	@if [ -n "$(SERVICES)" ]; then \
		echo "$(YELLOW)→ Restarting specific services: $(SERVICES)$(RESET)"; \
		$(MAKE) down SERVICES="$(SERVICES)"; \
		$(MAKE) up SERVICES="$(SERVICES)"; \
		echo "$(GREEN)✓ Services restarted: $(SERVICES)$(RESET)"; \
	else \
		$(MAKE) down; \
		$(MAKE) up; \
		ENV=$$(grep "^ENVIRONMENT=" $(ENV_FILE) | cut -d'=' -f2); \
		echo "$(GREEN)✓ $$ENV environment restarted$(RESET)"; \
	fi

## restart-db: Restart database containers to apply new user configurations
restart-db: check-env
	@echo "$(YELLOW)→ Restarting database containers...$(RESET)"
	@docker restart $${CONTAINER_PREFIX:-openmeal}-postgres $${CONTAINER_PREFIX:-openmeal}-mongodb 2>/dev/null || true
	@echo "$(GREEN)✓ Database containers restarted$(RESET)"
	@echo "$(CYAN)→ New users from init-users.conf will be created on restart$(RESET)"

# ============================================================================
# Generic Container Management
# ============================================================================

## ps: Show container status
ps:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) ps

## status: Detailed status of all services
status:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║              OpenMeal Services Status                          ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) ps -a

## health: Check service health
health:
	@if [ -f "./scripts/check-services.sh" ]; then \
		chmod +x ./scripts/check-services.sh; \
		./scripts/check-services.sh; \
	else \
		echo "$(CYAN)→ Checking service health...$(RESET)"; \
		$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) ps --format json | $(GREP_CMD) -q "running" && echo "$(GREEN)✓ Running services found$(RESET)" || echo "$(RED)✗ No running services$(RESET)"; \
	fi

# ============================================================================
# Build & Update
# ============================================================================

## build: Build all images
build: check-env
	@echo "$(GREEN)→ Building images...$(RESET)"
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) build
	@echo "$(GREEN)✓ Images built$(RESET)"

## build-nocache: Build images without cache
build-nocache: check-env
	@echo "$(GREEN)→ Building images without cache...$(RESET)"
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) build --no-cache
	@echo "$(GREEN)✓ Images built$(RESET)"

## pull: Update images from registry
pull: check-env
	@echo "$(GREEN)→ Updating images...$(RESET)"
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) pull
	@echo "$(GREEN)✓ Images updated$(RESET)"

# ============================================================================
# Cleanup
# ============================================================================

## clean: Stop and remove containers, networks
clean:
	@echo "$(YELLOW)→ Cleaning environment...$(RESET)"
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) down --remove-orphans
	@echo "$(GREEN)✓ Environment cleaned$(RESET)"

## clean-volumes: Remove containers, networks and volumes (DANGEROUS!)
clean-volumes:
	@echo "$(RED)⚠ WARNING: ALL data in volumes will be deleted!$(RESET)"
	@echo "$(YELLOW)→ Press Ctrl+C to cancel, or Enter to continue...$(RESET)"
	@read -r dummy
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) down -v --remove-orphans
	@echo "$(GREEN)✓ Environment and volumes removed$(RESET)"

## prune: Clean unused Docker resources
prune:
	@echo "$(YELLOW)→ Cleaning unused Docker resources...$(RESET)"
	docker system prune -f
	@echo "$(GREEN)✓ Cleanup completed$(RESET)"

# ============================================================================
# Internal Helpers
# ============================================================================

_start-selected-microservices:
	@echo "$(CYAN)→ Starting selected microservices...$(RESET)"
	@ENV=$$(grep "^ENVIRONMENT=" $(ENV_FILE) | cut -d'=' -f2); \
	if [ "$$ENV" = "local-dev" ]; then \
		if [ ! -f compose/docker-compose.local.yml ]; then \
			echo "$(YELLOW)→ Generating local compose file...$(RESET)"; \
			$(MAKE) generate-local-compose; \
		fi; \
		COMPOSE_FILE="compose/docker-compose.local.yml"; \
		BUILD_FLAG="--build"; \
	else \
		COMPOSE_FILE="docker-compose.yml"; \
		BUILD_FLAG=""; \
	fi; \
	if [ -f "$(MICROSERVICES_LOCAL)" ]; then \
		services=$$($(GREP_CMD) -v '^#' $(MICROSERVICES_LOCAL) | $(GREP_CMD) -v '^$$' | tr '\n' ' '); \
		if [ -n "$$services" ]; then \
			echo "$(CYAN)→ Enabled services: $$services$(RESET)"; \
			for service in $$services; do \
				echo "$(YELLOW)→ Starting $$service...$(RESET)"; \
				$(COMPOSE_BASE_CMD) -f $$COMPOSE_FILE up -d $$BUILD_FLAG $$service 2>/dev/null || \
					echo "$(RED)✗ Service $$service not found in $$COMPOSE_FILE$(RESET)"; \
			done; \
		else \
			echo "$(YELLOW)⚠ No microservices enabled in $(MICROSERVICES_LOCAL)$(RESET)"; \
		fi; \
	else \
		echo "$(RED)✗ $(MICROSERVICES_LOCAL) not found$(RESET)"; \
	fi

# ============================================================================
# Database Configuration Preparation
# ============================================================================

## prepare-db-configs: Prepare database user configs based on environment
prepare-db-configs:
	@if [ -f scripts/prepare-db-configs.sh ]; then \
		ENVIRONMENT=$${ENVIRONMENT:-local-dev} bash scripts/prepare-db-configs.sh; \
	else \
		echo "$(YELLOW)⚠ Database config preparation script not found$(RESET)"; \
	fi
