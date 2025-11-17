# ============================================================================
# Common Variables and Configuration
# ============================================================================

# Colors for output (works in Linux/macOS/Git Bash)
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# OS detection for cross-platform compatibility
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
else
    DETECTED_OS := $(shell uname -s)
endif

# Project configuration
COMPOSE_PROJECT_NAME := openmeal-backend

# Configuration files
ENV_FILE := .env
ENV_EXAMPLE := .env.example
MICROSERVICES_LOCAL := microservices.local
MICROSERVICES_LOCAL_EXAMPLE := microservices.local.example
POSTGRES_USERS_CONF := config/postgres/init-users.conf
POSTGRES_USERS_EXAMPLE := config/postgres/init-users.conf.example
MONGO_USERS_CONF := config/mongodb/init-users.conf
MONGO_USERS_EXAMPLE := config/mongodb/init-users.conf.example
MINIO_USERS_CONF := config/minio/init-users.conf
MINIO_USERS_EXAMPLE := config/minio/init-users.conf.example

# Docker Compose files
COMPOSE_BASE := -f docker-compose.yml
COMPOSE_INFRA := -f compose/infra.yml
COMPOSE_MONITORING := -f compose/monitoring.yml

# Cross-platform commands
ifeq ($(OS),Windows_NT)
    GREP_CMD := grep
    SED_CMD := sed
    CAT_CMD := cat
else
    GREP_CMD := grep
    SED_CMD := sed
    CAT_CMD := cat
endif

# Export all variables from .env file if it exists
ifneq (,$(wildcard $(ENV_FILE)))
    include $(ENV_FILE)
    export
endif

# Docker Compose command with conditional .env loading
ifeq ($(shell test -f $(ENV_FILE) && echo exists),exists)
    COMPOSE_BASE_CMD := ENV_FILE=$(shell pwd)/$(ENV_FILE) docker compose --env-file $(ENV_FILE)
else
    COMPOSE_BASE_CMD := docker compose
endif

# ============================================================================
# Common Utility Targets
# ============================================================================

.PHONY: check-env check-microservices-config init init-env init-microservices init-db-users

## check-env: Check for .env file existence
check-env:
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(RED)✗ File $(ENV_FILE) not found!$(RESET)"; \
		echo "$(YELLOW)→ Run 'make init' or 'make init-env' to create from template$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ File $(ENV_FILE) found$(RESET)"

## check-microservices-config: Check for microservices.local file existence
check-microservices-config:
	@if [ ! -f "$(MICROSERVICES_LOCAL)" ]; then \
		echo "$(RED)✗ File $(MICROSERVICES_LOCAL) not found!$(RESET)"; \
		echo "$(YELLOW)→ Run 'make init-microservices' to create from template$(RESET)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ File $(MICROSERVICES_LOCAL) found$(RESET)"

## init: Initialize all project configs (.env, microservices, DB users)
init:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║              Project Initialization                            ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@$(MAKE) init-env
	@echo ""
	@$(MAKE) init-microservices
	@echo ""
	@$(MAKE) init-db-users
	@echo ""
	@$(MAKE) init-minio-users
	@echo ""
	@echo "$(GREEN)✓ Project initialization complete!$(RESET)"
	@echo "$(YELLOW)→ Edit generated files for your needs$(RESET)"

## init-env: Initialize .env file from example
init-env:
	@if [ -f "$(ENV_FILE)" ]; then \
		echo "$(YELLOW)⚠ File $(ENV_FILE) already exists$(RESET)"; \
		echo "$(YELLOW)→ Remove it manually if you want to recreate$(RESET)"; \
	elif [ -f "$(ENV_EXAMPLE)" ]; then \
		cp $(ENV_EXAMPLE) $(ENV_FILE); \
		echo "$(GREEN)✓ Created $(ENV_FILE) from template$(RESET)"; \
	else \
		echo "$(RED)✗ File $(ENV_EXAMPLE) not found!$(RESET)"; \
		exit 1; \
	fi

## init-microservices: Initialize microservices config
init-microservices:
	@if [ -f "$(MICROSERVICES_LOCAL)" ]; then \
		echo "$(YELLOW)⚠ File $(MICROSERVICES_LOCAL) already exists$(RESET)"; \
		echo "$(YELLOW)→ Remove it manually if you want to recreate$(RESET)"; \
	elif [ -f "$(MICROSERVICES_LOCAL_EXAMPLE)" ]; then \
		cp $(MICROSERVICES_LOCAL_EXAMPLE) $(MICROSERVICES_LOCAL); \
		echo "$(GREEN)✓ Created $(MICROSERVICES_LOCAL) from template$(RESET)"; \
	else \
		echo "$(RED)✗ File $(MICROSERVICES_LOCAL_EXAMPLE) not found!$(RESET)"; \
		exit 1; \
	fi

## init-db-users: Initialize database user configs from examples
init-db-users:
	@if [ -f "$(POSTGRES_USERS_CONF)" ]; then \
		echo "$(YELLOW)⚠ File $(POSTGRES_USERS_CONF) already exists$(RESET)"; \
	else \
		if [ -f "$(POSTGRES_USERS_EXAMPLE)" ]; then \
			cp $(POSTGRES_USERS_EXAMPLE) $(POSTGRES_USERS_CONF); \
			echo "$(GREEN)✓ Created $(POSTGRES_USERS_CONF) from template$(RESET)"; \
		else \
			echo "$(RED)✗ File $(POSTGRES_USERS_EXAMPLE) not found!$(RESET)"; \
			exit 1; \
		fi; \
	fi
	@if [ -f "$(MONGO_USERS_CONF)" ]; then \
		echo "$(YELLOW)⚠ File $(MONGO_USERS_CONF) already exists$(RESET)"; \
	else \
		if [ -f "$(MONGO_USERS_EXAMPLE)" ]; then \
			cp $(MONGO_USERS_EXAMPLE) $(MONGO_USERS_CONF); \
			echo "$(GREEN)✓ Created $(MONGO_USERS_CONF) from template$(RESET)"; \
		else \
			echo "$(RED)✗ File $(MONGO_USERS_EXAMPLE) not found!$(RESET)"; \
			exit 1; \
		fi; \
	fi

## init-minio-users: Initialize MinIO user config from example
init-minio-users:
	@if [ -f "$(MINIO_USERS_CONF)" ]; then \
		echo "$(YELLOW)⚠ File $(MINIO_USERS_CONF) already exists$(RESET)"; \
	else \
		if [ -f "$(MINIO_USERS_EXAMPLE)" ]; then \
			cp $(MINIO_USERS_EXAMPLE) $(MINIO_USERS_CONF); \
			echo "$(GREEN)✓ Created $(MINIO_USERS_CONF) from template$(RESET)"; \
		else \
			echo "$(RED)✗ File $(MINIO_USERS_EXAMPLE) not found!$(RESET)"; \
			exit 1; \
		fi; \
	fi
