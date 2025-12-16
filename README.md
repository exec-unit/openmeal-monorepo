# OpenMeal Monorepo

[![Java](https://img.shields.io/badge/Java-21-blue.svg)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.0.3-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)](https://www.docker.com/)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow.svg)

> **⚠️ Project Status:** This repository is under active development. The documentation describes the target architecture for the complete system. See [Implementation Status](#implementation-status) below for current progress.

**OpenMeal** is a server-side platform for food ordering and delivery from restaurants and cafes, uniting all process participants: customers, establishments, couriers, support service, and administrators.

## Platform Capabilities

The platform implements complete food delivery workflow:

- **Customer Experience**: Browse restaurants, order food, track courier in real-time, receive notifications
- **Restaurant Management**: Menu management, order processing, preparation status updates
- **Courier Coordination**: Automated courier assignment algorithm based on proximity and availability
- **Support Operations**: Incident handling, refunds, account management with escalation workflows
- **Administration**: Restaurant verification, permanent account actions, operational analytics

The platform is designed as a backend-ready system with API-first architecture, prepared for frontend integration.

## 🚀 Quick Start

**Prerequisites:**

- Docker & Docker Compose (v2.0+)
- Java 21+
- Make
- yq (for local development with `microservices.local`)

**First Time Setup:**

```bash
# 1. Initialize configuration files
make init

# 2. Configure environment
cp .env.infra.example .env.infra
nano .env.infra
```

Edit `.env.infra`:

- Set `ENVIRONMENT=local-dev`
- Configure passwords for databases
- See `config/` directory documentation below

```bash
# 3. Install pre-commit hooks (recommended)
pipx install pre-commit
pre-commit install --hook-type pre-commit --hook-type commit-msg

# 4. Start infrastructure and services
make up
```

### Verify Everything Works

```bash
# Check health of all services
make check-services

# View logs
make logs
```

**Access Points:**

- API Gateway: http://localhost:8080/api
- Individual microservices: Check `docker-compose.yml` for port mappings

## 🌍 Environment Strategy

The project supports 4 deployment environments with different service activation:

| Environment    | Profile      | Active Services                 | Use Case                             |
| -------------- | ------------ | ------------------------------- | ------------------------------------ |
| **local-dev**  | `local-dev`  | Postgres, MongoDB, Redis, MinIO | Developer laptop (minimal resources) |
| **shared-dev** | `shared-dev` | + Keycloak, Redpanda, Nginx     | Shared development VDS               |
| **stage**      | `stage`      | Full stack (no MinIO)           | Pre-production testing               |
| **prod**       | `prod`       | Full + Prometheus/Grafana       | Production deployment                |

Environment is controlled by `ENVIRONMENT` variable in `.env.infra`.

<span id="implementation-status"></span>

## 🎯 Implementation Status

**Infrastructure & DevOps:**

- ✅ Docker Compose orchestration with multi-environment support
- ✅ Ansible deployment automation (staging/production)
- ✅ GitHub Actions CI/CD pipeline
- ✅ Secrets management (Ansible Vault + GitHub Secrets)
- ✅ SSL/TLS automation (Let's Encrypt)
- ✅ Monitoring stack (Prometheus + Grafana)

**Microservices (Target: 13 services):**

- 🚧 **API Gateway** - Routing, authentication, rate limiting (In Progress)
- 🚧 **User Service** - User profiles, addresses, preferences (In Progress)
- 🚧 **Auth Service** - Authentication, JWT tokens (In Progress)
- ⏳ **Restaurant Service** - Menus, schedules, reviews (Planned)
- ⏳ **Order Service** - Order lifecycle, status management (Planned)
- ⏳ **Payment Service** - ЮKassa integration, refunds (Planned)
- ⏳ **Dispatch Service** - Courier assignment algorithm (Planned)
- ⏳ **Tracking Service** - Real-time location tracking (Planned)
- ⏳ **File Service** - File upload, S3 storage (Planned)
- ⏳ **External Sender** - Push/SMS/Email notifications (Planned)
- ⏳ **Support Service** - Incident handling, escalation (Planned)
- ⏳ **Admin Service** - Verification, analytics (Planned)
- ⏳ **Report Service** - Data aggregation, dashboards (Planned)

> **Note:** Documentation reflects the complete target architecture. Features marked as "Planned" are designed but not yet implemented.

## 📂 Repository Structure

```
.
├── services/
│   └── [microservice-name]/
├── infrastructure/
│   ├── ansible/
│   └── keycloak/
├── compose/
│   ├── infra.yml
│   └── monitoring.yml
├── config/
│   ├── postgres/
│   ├── mongodb/
│   ├── redpanda/
│   └── nginx/
├── scripts/
├── makefiles/
└── docs/
```

**Key directories:**

- `services/` - Spring Boot microservices (domain-driven modules)
- `infrastructure/` - Ansible playbooks, roles, and Keycloak customization
- `compose/` - Docker Compose files for infrastructure and monitoring
- `config/` - Initialization scripts and templates for databases, Redpanda, Nginx
- `scripts/` - Utility scripts for health checks, backups, SSL management
- `makefiles/` - Modular Makefile includes for different concerns
- `docs/` - Architecture documentation and ADRs

## ⚙️ Configuration Management

### The `config/` Directory

This directory contains initialization scripts and configuration templates for infrastructure services. It solves the problem of **environment-aware service initialization** and **secrets injection**.

**Structure:**

```
config/
├── postgres/
│   ├── init-db.sh
│   ├── init-users.conf
│   ├── init-users.conf.example
│   └── check-and-init.sh
├── mongodb/
│   ├── init-db.sh
│   ├── init-users.conf
│   └── init-users.conf.example
├── redpanda/
│   ├── redpanda.yaml.template
│   ├── generate-config.sh
│   └── bootstrap-user.sh
├── nginx/
│   ├── default.conf.template
│   └── default-http-only.conf.template
└── minio/
    ├── init-buckets.sh
    └── init-users.conf.example
```

**How it works:**

1. **Template files** (`.example`, `.template`) are committed to Git
2. **Actual config files** (`.conf`, `.yaml`) are gitignored and generated locally or by Ansible
3. **Init scripts** read config files and create database users, buckets, etc.
4. **Environment variables** from `.env.infra` are resolved at runtime

**Example: PostgreSQL User Initialization**

`config/postgres/init-users.conf`:

```
keycloak:KEYCLOAK_DB_PASSWORD:keycloak
user_service:USER_SERVICE_DB_PASSWORD:users
order_service:ORDER_SERVICE_DB_PASSWORD:orders
```

Format: `username:ENV_VAR_NAME:database`

The `init-db.sh` script:

- Reads this file
- Resolves `$KEYCLOAK_DB_PASSWORD` from environment
- Creates user and database if they don't exist
- Grants necessary privileges

**Environment-Aware Activation:**

The `scripts/prepare-db-configs.sh` script modifies `init-users.conf` based on `ENVIRONMENT`:

- `local-dev` - Comments out Keycloak (uses shared-dev instance)
- `shared-dev` - Only Keycloak active
- `stage/prod` - All users active

This prevents resource waste and ensures proper service isolation.

### Secrets Management Strategy

**Local Development:**

1. Copy example files:

   ```bash
   make init
   ```

2. Edit `.env.infra`:

   ```bash
   POSTGRES_PASSWORD=local_dev_password
   REDIS_PASSWORD=local_dev_redis
   KEYCLOAK_DB_PASSWORD=local_kc_password
   ```

3. Edit `config/postgres/init-users.conf`:

   ```
   user_service:USER_SERVICE_DB_PASSWORD:users
   ```

4. Add to `.env.infra`:
   ```bash
   USER_SERVICE_DB_PASSWORD=user_svc_password
   ```

**Production Deployment:**

GitHub Secrets → `generate-vault.py` → `vault.yml` → Ansible → `.env.infra` on server

See [infrastructure/README.md](infrastructure/README.md) for details.

### Local Development with Selective Services

**Problem:** Running all microservices locally consumes too much RAM.

**Solution:** `microservices.local` file for selective activation.

1. Copy example:

   ```bash
   cp microservices.local.example microservices.local
   ```

2. Uncomment services you want to run:

   ```
   user-service
   order-service
   ```

3. Generate local compose file:

   ```bash
   make init-local
   ```

   This creates `compose/docker-compose.local.yml` that builds images from source.

4. Start only selected services:
   ```bash
   make up
   ```

**How it works:**

- `makefiles/local-dev.mk` reads `microservices.local`
- Uses `yq` to filter services from `docker-compose.yml`
- Generates `compose/docker-compose.local.yml` with `build:` instead of `image:`
- `makefiles/docker.mk` includes this file when `ENVIRONMENT=local-dev`

This allows developers to run only the services they're working on, while infrastructure (Postgres, Redis, etc.) always runs.

## 🛠 Common Commands

**Essential commands:**

```bash
# Start all services
make up
# Stop all services
make down
# View logs
make logs
# Build Maven projects
make build
# Health check
make check-services
```

**Service-specific operations:**

```bash
make up SERVICES=user-service
make restart SERVICES="order-service payment-service"
make logs SERVICES=payment-service
```

For complete command reference including database operations, SSL management, backups, and advanced options, see [docs/MAKEFILE.md](docs/MAKEFILE.md).

## 📖 Documentation

- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design, deployment model, variable flow
- **[Makefile Reference](docs/MAKEFILE.md)** - Complete command guide
- **[Infrastructure Guide](infrastructure/README.md)** - Ansible deployment process
- **[ADRs](docs/adr/)** - Architecture decision records

## 🏗 Technology Stack

**Backend:**

- Java 21, Spring Boot 4.0.3, Spring Cloud 2025.1.1
- Maven (multi-module monorepo)

**Infrastructure:**

- PostgreSQL, MongoDB, Redis
- Redpanda (Kafka-compatible event streaming)
- Keycloak (Identity & Access Management)
- MinIO (S3-compatible storage, local-dev only)
- Nginx (Reverse proxy with SSL)

**DevOps:**

- Docker Compose
- Ansible (deployment automation)
- GitHub Actions (CI/CD)
- Prometheus + Grafana (monitoring, prod only)

**Why Docker Compose over Kubernetes?**

Docker Compose chosen to minimize operational overhead and focus on application architecture. Managing Kubernetes clusters (etcd, control plane, CNI, ingress controllers) would shift focus from building microservices to infrastructure administration. For this project scope, Docker Compose provides sufficient container management without the complexity of cluster orchestration. See [ADR-003](docs/adr/003-docker-compose.md) for detailed rationale.

## 🔐 Security & Secrets

**Local Development:**

- Secrets in `.env.infra` (gitignored)
- Database credentials in `config/*/init-users.conf` (gitignored)

**Production:**

- GitHub Secrets → Ansible Vault → `.env` files
- SSL certificates via Let's Encrypt (automatic renewal)
- SASL/SCRAM authentication for Redpanda

See [infrastructure/README.md](infrastructure/README.md) for details.

## 🧪 Testing

```bash
# Run all tests
make test

# Test specific service
./mvnw -pl services/user-service test

# Ansible role testing (Molecule)
make test-ansible
```

## 📦 Adding a New Microservice

1. Create `services/your-service/` with Spring Boot structure
2. Add module to root `pom.xml`
3. Create `services/your-service/Dockerfile`
4. Add service to `docker-compose.yml`
5. Create `.env.your-service.example`
6. CI/CD workflows auto-detect changes and build new service

See existing services in `services/` directory for reference implementation examples.

## 🚨 Troubleshooting

**Services won't start:**

```bash
make check-services
make logs SERVICE=user-service
```

**Database connection issues:**

```bash
make exec-postgres
```

Inside PostgreSQL shell, list databases with `\l` command.

**Port conflicts:**

```bash
make down
make clean
make up
```

## 📄 License

See [LICENSE](LICENSE) file for details.

---

**Need help?** Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for system overview or [docs/MAKEFILE.md](docs/MAKEFILE.md) for command reference.
