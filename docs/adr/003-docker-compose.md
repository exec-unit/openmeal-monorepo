# ADR-003: Docker Compose for Container Management

**Date:** 2025-12-17
**Status:** Accepted  
**Deciders:** Project Lead

## Context

Container management solution needed for microservices architecture with multiple infrastructure components.

**Management Options:**

1. **Kubernetes** - Full-featured container orchestration platform
2. **K3s** - Lightweight Kubernetes distribution
3. **Docker Compose** - Declarative container management

## Decision

Use **Docker Compose** for all environments (local-dev, shared-dev, stage, prod).

## Rationale

### Why Docker Compose

**Operational Clarity:**

- Single source of truth: `docker-compose.yml` defines entire stack
- Standard Docker tooling for troubleshooting
- No hidden cluster state (etcd, control plane internals)
- Deployment process remains transparent and auditable

**Reduced Administrative Burden:**

- No cluster lifecycle management (upgrades, node maintenance)
- No CNI plugin configuration or troubleshooting
- No ingress controller complexity
- No certificate management for cluster components
- Focus remains on application development, not infrastructure operations

**Development Velocity:**

- Same `docker-compose.yml` works locally and in production
- No translation layer between dev and prod (no Helm charts, Kustomize)
- Deploy changes in ~2 minutes
- Rollback via `docker compose up -d --force-recreate`

**Immutability and Reproducibility:**

- Declarative configuration in version control
- Environment-specific behavior via profiles
- Consistent deployment across all environments
- No cluster drift or state divergence

### Alternatives Considered

**Kubernetes:**

- Less aligned with project operational model
- Adds complexity: Pods, Deployments, Services, Ingress, ConfigMaps, Secrets, RBAC, NetworkPolicies
- Current project needs: start containers, manage environment variables, handle secrets
- K8s orchestration features (auto-scaling, multi-region, service mesh) not required for current scope

**K3s:**

- Lighter than K8s but still requires cluster management
- Adds components: Traefik ingress, CoreDNS, embedded etcd
- Manifest complexity remains (YAML for every resource type)
- Operational overhead reduction insufficient to justify adoption

## Implementation

### Profile-Based Environment Management

```yaml
services:
  postgres:
    profiles: ["local-dev", "shared-dev", "stage", "prod"]

  keycloak:
    profiles: ["shared-dev", "stage", "prod"]

  prometheus:
    profiles: ["prod"]
```

Activated via `ENVIRONMENT` variable in `.env.infra`.

### Health Checks

All services have health checks:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 20s
```

### Service Dependencies

```yaml
depends_on:
  postgres:
    condition: service_healthy
```

Ensures proper startup order.

## Consequences

### Positive

✅ **Operational Simplicity:**

- No cluster state management
- Standard Docker tooling
- Transparent deployment process

✅ **Development Velocity:**

- Deploy changes in ~2 minutes
- Simple rollback mechanism
- No translation layer between environments

✅ **Reproducibility:**

- Declarative configuration in Git
- Environment parity across local/stage/prod
- No cluster drift

✅ **Maintainability:**

- Single person can manage entire stack
- Troubleshooting uses familiar Docker commands

### Trade-offs

⚠️ **Limited Horizontal Scaling:**

- Manual scaling required (increase replicas in compose file)
- Acceptable for current project scope
- Vertical scaling available (increase host resources)

⚠️ **Single-Host Architecture:**

- All containers on one host per environment
- No built-in multi-node HA
- Acceptable risk profile for non-critical workloads
- Can be mitigated with host-level HA if needed

⚠️ **Service Discovery:**

- Docker DNS for internal communication
- Nginx reverse proxy for external routing
- Sufficient for current service count

## Evolution Path

### Triggers for Migration to Kubernetes

**Operational triggers:**

- Need for multi-node high availability
- Requirement for automatic horizontal scaling
- Geographic distribution across regions
- Service count exceeds operational comfort zone

**Technical triggers:**

- Advanced networking requirements (service mesh, mTLS)
- Complex deployment strategies (canary, blue-green at scale)
- Need for declarative GitOps workflows (ArgoCD, Flux)

### Migration Strategy

1. **Preparation:**
   - Dockerfiles remain unchanged
   - Extract configuration to ConfigMaps/Secrets
   - Document service dependencies

2. **Conversion:**
   - Use Kompose to generate initial K8s manifests
   - Refactor to Helm charts or Kustomize
   - Migrate Ansible roles to K8s operators or Helm

3. **Validation:**
   - Deploy to test K8s cluster
   - Verify health checks and readiness probes
   - Test service-to-service communication

**Estimated effort:** 1-2 weeks for initial migration, ongoing cluster management overhead.

## Related Decisions

- [ADR-001: Monorepo Strategy](001-monorepo.md)
- [ADR-002: Redpanda for Event Streaming](002-redpanda.md)
- [ADR-005: Ansible for Deployment](005-ansible.md)

## References

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Docker Compose Profiles](https://docs.docker.com/compose/profiles/)
- [When NOT to use Kubernetes](https://www.jeremybrown.tech/8-kubernetes-is-a-red-flag-signalling-premature-optimisation/)
