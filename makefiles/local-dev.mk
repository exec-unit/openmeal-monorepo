# ============================================================================
# Local Development Environment Management
# ============================================================================

.PHONY: generate-local-compose init-service-envs init-local check-yq clean-local

## check-yq: Check if yq is installed
check-yq:
	@command -v yq >/dev/null 2>&1 || { \
		echo "$(RED)✗ yq is not installed$(RESET)"; \
		echo "$(YELLOW)→ Install: https://github.com/mikefarah/yq#install$(RESET)"; \
		echo "$(YELLOW)→ Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq$(RESET)"; \
		echo "$(YELLOW)→ macOS: brew install yq$(RESET)"; \
		exit 1; \
	}
	@echo "$(GREEN)✓ yq is installed$(RESET)"

## generate-local-compose: Generate local development compose from production compose
generate-local-compose:
	@echo "$(CYAN)→ Generating compose/docker-compose.local.yml from docker-compose.yml...$(RESET)"
	@mkdir -p compose
	@if [ ! -f docker-compose.yml ]; then \
		echo "$(RED)✗ docker-compose.yml not found$(RESET)"; \
		exit 1; \
	fi
	@cat docker-compose.yml | yq -y ' \
		.services |= with_entries( \
			. as $$parent | .value |= ( \
				if .image then \
					.build = {"context": ("./services/" + $$parent.key), "dockerfile": "Dockerfile"} | del(.image) \
				else . end \
				| .env_file = ["./services/" + $$parent.key + "/.env"] \
				| if .profiles then .profiles = ["local-dev"] else . end \
			) \
		)' > compose/docker-compose.local.yml
	@echo "$(GREEN)✓ Generated compose/docker-compose.local.yml$(RESET)"
	@echo "$(YELLOW)→ File is gitignored and will be regenerated as needed$(RESET)"

## init-service-envs: Initialize .env files for all services from .env.example
init-service-envs:
	@echo "$(CYAN)→ Initializing service environment files...$(RESET)"
	@if [ ! -d "services" ]; then \
		echo "$(YELLOW)⚠ services/ directory not found, skipping$(RESET)"; \
		exit 0; \
	fi
	@service_count=0; \
	for dir in services/*/; do \
		if [ -d "$$dir" ]; then \
			service=$$(basename "$$dir"); \
			if [ -f "$$dir/.env.example" ]; then \
				if [ ! -f "$$dir/.env" ]; then \
					cp "$$dir/.env.example" "$$dir/.env"; \
					echo "$(GREEN)  ✓ Created services/$$service/.env$(RESET)"; \
					service_count=$$((service_count + 1)); \
				else \
					echo "$(YELLOW)  ⚠ services/$$service/.env already exists$(RESET)"; \
				fi; \
			else \
				echo "$(YELLOW)  ⚠ services/$$service/.env.example not found$(RESET)"; \
			fi; \
		fi; \
	done; \
	if [ $$service_count -eq 0 ]; then \
		echo "$(YELLOW)⚠ No service .env files created (either already exist or no .env.example found)$(RESET)"; \
	else \
		echo "$(GREEN)✓ Created $$service_count service environment file(s)$(RESET)"; \
	fi

## init-local: Complete local development environment setup
init-local: init-env init-microservices init-db-users init-minio-users init-service-envs generate-local-compose
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(GREEN)║     Local Development Environment Initialized                  ║$(RESET)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(CYAN)Next steps:$(RESET)"
	@echo "  1. Edit infrastructure config: $(YELLOW).env.infra$(RESET)"
	@echo "  2. Edit service configs: $(YELLOW)services/*/.env$(RESET)"
	@echo "  3. Configure enabled services: $(YELLOW)microservices.local$(RESET)"
	@echo "  4. Start environment: $(YELLOW)make up$(RESET)"
	@echo ""

## clean-local: Remove generated local development files
clean-local:
	@echo "$(YELLOW)→ Cleaning local development files...$(RESET)"
	@rm -f compose/docker-compose.local.yml
	@echo "$(GREEN)✓ Local development files cleaned$(RESET)"
