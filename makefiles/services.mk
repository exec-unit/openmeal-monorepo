# ============================================================================
# Service Utilities (exec, backup)
# ============================================================================

.PHONY: exec-postgres exec-mongo exec-redis exec-redpanda exec-keycloak exec-minio exec-nginx exec-certbot exec-prometheus exec-grafana
.PHONY: backup-postgres backup-mongo

# ============================================================================
# Service Exec Commands
# ============================================================================

## exec-postgres: Connect to PostgreSQL
exec-postgres:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec postgres psql -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-openmeal}

## exec-mongo: Connect to MongoDB
exec-mongo:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec mongodb mongosh -u $${MONGO_ROOT_USERNAME:-root} -p

## exec-redis: Connect to Redis CLI
exec-redis:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec redis redis-cli

## exec-redpanda: Connect to Redpanda (Kafka) CLI
exec-redpanda:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec redpanda rpk cluster info

## exec-keycloak: Connect to Keycloak container shell
exec-keycloak:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec keycloak /bin/bash

## exec-minio: Connect to MinIO container shell
exec-minio:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec minio sh

## exec-nginx: Connect to Nginx container shell
exec-nginx:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec nginx sh

## exec-certbot: Connect to Certbot container shell
exec-certbot:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec certbot sh

## exec-prometheus: Connect to Prometheus container shell
exec-prometheus:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) exec prometheus sh

## exec-grafana: Connect to Grafana container shell
exec-grafana:
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) $(COMPOSE_MONITORING) exec grafana sh

# ============================================================================
# Backup Commands
# ============================================================================

## backup-postgres: Create PostgreSQL backup
backup-postgres:
	@echo "$(GREEN)→ Creating PostgreSQL backup...$(RESET)"
	@mkdir -p ./backups
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec -T postgres pg_dump -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-openmeal} > ./backups/postgres_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Backup created in ./backups/$(RESET)"

## backup-mongo: Create MongoDB backup
backup-mongo:
	@echo "$(GREEN)→ Creating MongoDB backup...$(RESET)"
	@mkdir -p ./backups
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec -T mongodb sh -c 'mongodump --username="$$MONGO_INITDB_ROOT_USERNAME" --password="$$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --out /tmp/backup'
	@$(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) exec -T mongodb tar -czf /tmp/mongo_backup.tar.gz -C /tmp backup
	@docker cp $$($(COMPOSE_BASE_CMD) $(COMPOSE_BASE) $(COMPOSE_INFRA) ps -q mongodb):/tmp/mongo_backup.tar.gz ./backups/mongo_$$(date +%Y%m%d_%H%M%S).tar.gz
	@echo "$(GREEN)✓ Backup created in ./backups/$(RESET)"
