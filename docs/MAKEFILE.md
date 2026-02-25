# Makefile Reference

Complete guide to all `make` commands available in the project.

## Quick Reference

```bash
# Run a command
make <command>

# Show available commands (if implemented)
make help
```

## Environment Management

### Starting & Stopping

| Command                         | Description                                                      |
| ------------------------------- | ---------------------------------------------------------------- |
| `make up`                       | Start all services for current `ENVIRONMENT` (from `.env.infra`) |
| `make up SERVICES=<names>`      | Start specific service(s)                                        |
| `make down`                     | Stop all running services                                        |
| `make down SERVICES=<names>`    | Stop specific service(s)                                         |
| `make restart`                  | Restart all services                                             |
| `make restart SERVICES=<names>` | Restart specific service(s)                                      |
| `make restart-db`               | Restart database containers to apply new user configurations     |
| `make ps`                       | List running containers with status                              |

**Examples:**

```bash
make up
make down

make up SERVICES=user-service
make restart SERVICES="order-service payment-service"
make down SERVICES=api-gateway

make restart-db
```

### Initialization

| Command           | Description                                                                             |
| ----------------- | --------------------------------------------------------------------------------------- |
| `make init`       | Initialize all config files from examples (`.env.infra`, `init-users.conf`, etc.)       |
| `make init-local` | Initialize local development environment (generates `compose/docker-compose.local.yml`) |
| `make check-env`  | Verify `.env.infra` exists                                                              |

**First-time setup:**

```bash
make init
# Edit .env.infra with your settings
make up
```

## Service Interaction

### Exec into Containers

| Command              | Description                      |
| -------------------- | -------------------------------- |
| `make exec-postgres` | Open PostgreSQL shell (`psql`)   |
| `make exec-mongo`    | Open MongoDB shell (`mongosh`)   |
| `make exec-redis`    | Open Redis CLI                   |
| `make exec-redpanda` | Open Redpanda shell (`rpk`)      |
| `make exec-keycloak` | Bash shell in Keycloak container |
| `make exec-minio`    | MinIO client (`mc`)              |
| `make exec-nginx`    | Bash shell in Nginx container    |

**Example:**

```bash
# Connect to Postgres and list databases
make exec-postgres
# Inside: \l
```

### Logs

| Command                          | Description                               |
| -------------------------------- | ----------------------------------------- |
| `make logs`                      | View logs from all services (follow mode) |
| `make logs SERVICE=user-service` | View logs from specific service           |

## Database Management

### Backups

| Command                | Description                                              |
| ---------------------- | -------------------------------------------------------- |
| `make backup-postgres` | Create PostgreSQL backup (stored in `backups/postgres/`) |
| `make backup-mongo`    | Create MongoDB backup (stored in `backups/mongodb/`)     |

**Backup files:**

- Postgres: `backups/postgres/backup_YYYYMMDD_HHMMSS.sql`
- MongoDB: `backups/mongodb/backup_YYYYMMDD_HHMMSS/`

## SSL Certificate Management

| Command               | Description                                        |
| --------------------- | -------------------------------------------------- |
| `make ssl-cert-init`  | Obtain initial SSL certificates from Let's Encrypt |
| `make ssl-cert-renew` | Manually renew SSL certificates                    |
| `make ssl-setup-cron` | Setup automatic renewal via systemd/cron           |

**Requirements:**

- `ENVIRONMENT=stage` or `prod` in `.env.infra`
- Valid `SSL_EMAIL`, `API_DOMAIN_NAME`, `KEYCLOAK_DOMAIN_NAME` configured
- DNS records pointing to server
- Ports 80/443 accessible

**Usage:**

```bash
# First time setup (after DNS configured)
make ssl-cert-init

# Setup automatic renewal
make ssl-setup-cron
```

## Cleanup

| Command              | Description                                                                            |
| -------------------- | -------------------------------------------------------------------------------------- |
| `make clean`         | Remove containers and networks (keeps volumes)                                         |
| `make clean-volumes` | ⚠️ Remove ALL volumes (deletes all data)                                               |
| `make clean-local`   | Remove local development files (`compose/docker-compose.local.yml`, `.env.*` services) |
| `make prune`         | Docker system prune (remove unused images/containers)                                  |

**⚠️ Warning:** `make clean-volumes` is destructive and will delete all database data!

## Testing

| Command                                       | Description                                     |
| --------------------------------------------- | ----------------------------------------------- |
| `make test`                                   | Run all Ansible tests (Molecule + ansible-lint) |
| `make test-ansible`                           | Run Molecule tests for all roles                |
| `make test-ansible-role ROLE=openmeal-deploy` | Test specific Ansible role                      |
| `make test-ansible-lint`                      | Run ansible-lint on playbooks/roles             |
| `make test-ansible-syntax`                    | Check Ansible syntax                            |

**Java tests:**

```bash
# Run tests for specific service
./mvnw -pl services/user-service test

# Run all tests
./mvnw test
```

## Utilities

| Command               | Description                                                        |
| --------------------- | ------------------------------------------------------------------ |
| `make check-services` | Run `scripts/check-services.sh` to verify health of all containers |
| `make check-yq`       | Verify `yq` is installed (required for local dev)                  |

## Environment-Specific Behavior

The `ENVIRONMENT` variable in `.env.infra` controls which services start:

### local-dev

```bash
ENVIRONMENT=local-dev make up
```

**Starts:** Postgres, MongoDB, Redis, MinIO, microservices

**Skips:** Keycloak, Redpanda, Nginx, Certbot, Monitoring

**Use case:** Developer laptop with limited resources

### shared-dev

```bash
ENVIRONMENT=shared-dev make up
```

**Starts:** Keycloak, Redpanda, Nginx

**Use case:** Shared VDS for team development

### stage

```bash
ENVIRONMENT=stage make up
```

**Starts:** Full stack (no MinIO, uses cloud S3)

**Use case:** Pre-production testing

### prod

```bash
ENVIRONMENT=prod make up
```

**Starts:** Full stack + Prometheus/Grafana monitoring

**Use case:** Production deployment

## Advanced Usage

### Custom Docker Compose Commands

The Makefile constructs Docker Compose commands based on environment. You can run custom commands:

```bash
# View constructed command
make ps

# Run custom compose command
docker compose -f docker-compose.yml -f compose/infra.yml --profile local-dev <command>
```

### Selective Service Management

```bash
# Start only specific services
docker compose up -d user-service postgres redis

# Restart single service
docker compose restart user-service

# View logs from multiple services
docker compose logs -f user-service api-gateway
```

### Local Development with Code Changes

```bash
# 1. Generate local compose file (builds from source)
make init-local

# 2. Edit microservices.local to select which services to run
nano microservices.local
# Uncomment: user-service

# 3. Build and start
make docker-build
make up
```

## Troubleshooting

### Services won't start

```bash
# Check what's running
make ps

# Check health status
make check-services

# View logs
make logs SERVICE=user-service

# Clean restart
make down
make clean
make up
```

### Port conflicts

```bash
# Check what's using ports
sudo lsof -i :8080
sudo lsof -i :5432

# Stop conflicting services or change ports in .env.infra
```

### Database connection issues

```bash
# Verify database is running
make exec-postgres

# Check database users
make exec-postgres
# Inside: \du

# Recreate database configs
make prepare-db-configs
make restart
```

### SSL certificate issues

```bash
# Check certificate status
make exec-certbot
# Inside: certbot certificates

# Force renewal
make ssl-cert-renew

# Check Nginx config
make exec-nginx
# Inside: nginx -t
```

## Makefile Structure

The main `Makefile` includes several modular files:

- `makefiles/common.mk` - Common variables, colors, OS detection
- `makefiles/docker.mk` - Docker Compose orchestration
- `makefiles/services.mk` - Service exec commands and backups
- `makefiles/ssl.mk` - SSL certificate management
- `makefiles/ansible.mk` - Ansible testing
- `makefiles/local-dev.mk` - Local development utilities

This modular approach keeps the Makefile maintainable and organized.

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md) - System design and deployment model
- [Infrastructure Guide](../infrastructure/README.md) - Ansible deployment
- [Root README](../README.md) - Quick start guide
