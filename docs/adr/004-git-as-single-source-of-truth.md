# ADR-004: Git Repository as Single Source of Truth

**Date:** 2025-12-19
**Status:** Accepted  
**Deciders:** Project Lead

## Context

In deployment automation, there are different approaches to managing infrastructure and application code:

1. **Direct deployment from CI/CD** - CI/CD server builds and deploys directly to target
2. **Configuration management pulls from artifact repository** - Ansible/Chef pulls artifacts
3. **Git as source of truth** - Clone repository on CI/CD server, sync only necessary files to target
4. **GitOps (pull-based)** - Target cluster pulls desired state from Git (ArgoCD, Flux)

**Project Focus:**

OpenMeal is a Java/Spring Boot microservices portfolio project demonstrating backend architecture, event-driven patterns, and deployment automation. The primary focus is on application development (business logic, microservices communication, data modeling) rather than infrastructure engineering.

**GitOps vs Push-Based Deployment:**

While GitOps (ArgoCD/Flux) provides declarative, pull-based deployments with automatic drift detection, it requires Kubernetes infrastructure and shifts focus to cluster management. For this project, implementing full GitOps would mean:

- Setting up and maintaining Kubernetes clusters
- Converting Docker Compose to Helm/Kustomize
- Managing GitOps operators and reconciliation loops
- Time investment in infrastructure rather than application features

## Decision

We use **Git repository as the single source of truth** with **push-based deployment via Ansible** (not full GitOps).

## Implementation

### Deployment Flow

```
Developer Push → GitHub
                    ↓
              GitHub Actions (CI/CD Server)
                    ↓
              Clone Repository
                    ↓
              Run Ansible Playbook
                    ↓
              Rsync Selected Files → Target Server
                    ↓
              Docker Compose Up
```

### What Gets Synchronized

**From Git repository to target server:**

- `compose/` - Docker Compose files
- `config/` - Initialization scripts and templates
- `scripts/` - Utility scripts
- `Makefile` and `makefiles/` - Orchestration
- `.env.infra.example` - Template for environment file

**NOT synchronized:**

- `services/` - Source code (only Docker images are pulled)
- `.git/` - Git history
- `infrastructure/ansible/` - Ansible playbooks themselves
- Development files (`.devcontainer`, `node_modules`, etc.)

### Why This Approach

**Operational Clarity:**

- Target server contains only runtime-necessary files
- Clear boundary between build-time and runtime artifacts
- Deployment surface area explicitly defined in Ansible playbooks
- Easier to audit what's actually deployed

**Immutability and Reproducibility:**

- All configuration changes versioned in Git
- Rollback via Git checkout and redeploy
- Audit trail for all changes
- Consistent deployment across environments

**Security Boundary:**

- Source code isolation from runtime environment
- Blast radius reduction (compromised target doesn't expose source)
- Secrets injected at deployment time, never in repository
- No Git history accessible on production hosts

**Ansible Orchestration:**

- Runs on CI/CD server with full repository access
- Selective synchronization via rsync
- Generates environment-specific configuration from vault
- Coordinates multi-step deployment process

## Rationale

### Problem Solved

**Before (naive approach):**

```bash
# On target server
git clone https://github.com/org/openmeal.git
cd openmeal
docker compose up
```

**Issues:**

- Entire repository on production server
- Source code accessible in runtime environment
- Git history and metadata present
- Unclear deployment boundary
- Potential secrets exposure via Git history

**Our approach:**

```bash
# On CI/CD server
git clone https://github.com/org/openmeal.git
cd openmeal
ansible-playbook -i inventories/prod playbooks/release.yml
```

**Ansible playbook:**

```yaml
- name: Sync compose files
  ansible.posix.synchronize:
    src: "{{ project_root }}/compose/"
    dest: "{{ app_home }}/compose/"

- name: Sync config files
  ansible.posix.synchronize:
    src: "{{ project_root }}/config/"
    dest: "{{ app_home }}/config/"
```

### Advantages

**Security Boundary:**

- Source code isolation from runtime environment
- Operational files only on target hosts
- Secrets injected at deployment time via Ansible vault
- No Git metadata on production

**Operational Clarity:**

- Explicit deployment surface area
- Clear separation between build and runtime artifacts
- Ansible playbooks document exactly what's deployed
- Easier to audit and verify deployments

**Maintainability:**

- CI/CD server maintains full repository context
- Target hosts contain minimal, focused file set
- Faster synchronization (rsync delta transfers)
- Docker images pulled from registry (build once, deploy many)

**Flexibility:**

- Environment-specific deployments via Git branches
- Selective file synchronization for hotfixes
- Per-environment configuration overrides

## Consequences

### Positive

✅ **Clean Separation:**

- CI/CD server: full repository access
- Target server: only runtime files

✅ **Version Control:**

- All changes tracked in Git
- Easy rollback to any commit

✅ **Security:**

- Source code isolation
- No Git history on production

✅ **Operational Efficiency:**

- Fast synchronization via rsync delta transfers
- Minimal deployment surface area

### Trade-offs

⚠️ **Ansible Dependency:**

- Deployment requires Ansible on CI/CD server
- Less aligned with push-based CD tools (ArgoCD, Flux)
- Acceptable for current operational model

⚠️ **Two-Phase Deployment:**

- Build images → Push to registry → Ansible synchronizes and deploys
- Standard practice for container-based deployments
- Enables build once, deploy many pattern

⚠️ **Runtime Debugging:**

- Source code not available on target hosts
- Debugging relies on logs, metrics, and remote debugging tools
- Acceptable trade-off for security boundary

## Configuration

### Ansible Synchronization Rules

Defined in `infrastructure/ansible/roles/openmeal-deploy/defaults/main.yml`:

```yaml
sync_directories:
  - src: compose
    dest: compose
  - src: config
    dest: config
  - src: scripts
    dest: scripts
  - src: makefiles
    dest: makefiles

sync_files:
  - src: docker-compose.yml
    dest: docker-compose.yml
  - src: Makefile
    dest: Makefile
  - src: .env.infra.example
    dest: .env.infra.example
```

### Rsync Options

```yaml
rsync_opts:
  - --archive
  - --compress
  - --delete
  - --exclude=.git
  - --exclude=*.md
  - --exclude=.example
```

## Alternatives Considered

### Direct Git Clone on Target

**Less aligned with operational model:**

- Entire repository accessible on runtime hosts
- Git history and metadata present
- Unclear deployment boundary
- Source code in runtime environment

### Artifact-Based Deployment

**Less aligned with current needs:**

- Requires artifact repository infrastructure
- Configuration files still need separate versioning mechanism
- Docker images already serve as application artifacts
- Additional complexity for configuration management

### Configuration Management Database (CMDB)

**Less aligned with team workflow:**

- Additional system to operate and maintain
- Git already provides versioning and audit trail
- Team workflow optimized for Git-based processes
- CMDB benefits not realized at current scale

## Evolution Path

### Triggers for Alternative Approaches

**GitOps (ArgoCD/Flux):**

- Migration to Kubernetes
- Need for declarative, pull-based deployments
- Multiple teams requiring self-service deployments

**Artifact Repository:**

- Regulatory requirements for artifact retention
- Need for binary provenance tracking
- Complex artifact dependency management

### Migration Strategy

**To GitOps:**

1. Migrate to Kubernetes (see ADR-003)
2. Restructure repository for Kustomize/Helm
3. Deploy ArgoCD/Flux to cluster
4. Configure Git repository as source of truth
5. Transition from Ansible push to GitOps pull

**Estimated effort:** 3-5 days after Kubernetes migration

## Related Decisions

- [ADR-001: Monorepo Strategy](001-monorepo.md)
- [ADR-003: Docker Compose for Orchestration](003-docker-compose.md)
- [ADR-005: Ansible for Deployment Automation](005-ansible.md)

## References

- [GitOps Principles](https://www.gitops.tech/)
- [Ansible Synchronize Module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/synchronize_module.html)
- [12-Factor App: Config](https://12factor.net/config)
