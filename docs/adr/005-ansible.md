# ADR-005: Ansible for Deployment Automation

**Date:** 2025-12-19
**Status:** Accepted  
**Deciders:** Project Lead

## Context

OpenMeal requires deployment automation to manage multiple environments (shared-dev, stage, prod). The deployment process involves:

- Synchronizing configuration files from Git to target servers
- Generating environment-specific `.env` files from secrets
- Pulling Docker images from registry
- Starting services via Docker Compose
- Managing SSL certificates
- Configuring backups

**Automation Options:**

1. **Bash Scripts** - Simple shell scripts for deployment
2. **Ansible** - Configuration management and automation
3. **Terraform** - Infrastructure as code
4. **Custom CI/CD Scripts** - GitHub Actions only

## Decision

Use **Ansible** for deployment automation.

## Rationale

### Why Ansible for This Project

**Idempotent Operations:**

- Run playbook multiple times, same result
- Safe to re-run on failures
- No "already exists" errors to handle manually
- Demonstrates understanding of infrastructure automation

**Declarative Configuration:**

- Playbooks describe desired state, not steps
- Easy to read and understand deployment process
- Self-documenting: playbook IS the documentation
- Shows infrastructure-as-code practices

**Secrets Management:**

- Built-in Ansible Vault for encrypting secrets
- Variables can be environment-specific
- Clean separation: vault.yml (secrets) + all.yml (config)
- Demonstrates security best practices

**Selective File Synchronization:**

- Rsync module syncs only necessary files to target
- Source code stays on CI/CD server, not on production
- Efficient: only changed files transferred
- Implements "Git as single source of truth" pattern

**Operational Benefits:**

- Declarative approach reduces cognitive load
- Playbooks serve as executable documentation
- Role-based organization scales with project complexity
- Community modules provide tested solutions

### Why Not Bash Scripts

**Complexity:**

- Would need to handle idempotency manually
- Error handling becomes messy
- No built-in secrets management
- Hard to maintain as project grows

**Example of bash complexity:**

```bash
# Check if user exists, create if not
if ! docker exec postgres psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='user_service'" | grep -q 1; then
    docker exec postgres psql -U postgres -c "CREATE USER user_service..."
fi
```

**Ansible equivalent:**

```yaml
- name: Create database user
  postgresql_user:
    name: user_service
    password: "{{ vault_user_service_db_password }}"
    state: present
```

### Why Not Terraform

**Wrong Tool:**

- Terraform manages infrastructure (VMs, networks, cloud resources)
- We need application deployment automation
- Our VDS instances are manually provisioned
- Terraform would be overkill for Docker Compose deployment

**Could Use Both:**

- Terraform for VDS provisioning (not needed for pet project)
- Ansible for application deployment (what we actually need)

### Why Not Custom CI/CD Scripts

**Reinventing the Wheel:**

- Would need to implement file sync, templating, secrets
- Ansible provides all this out of the box
- More code to maintain
- Less recognizable to employers

## Implementation

### Playbook Structure

**deploy.yml** - Full deployment (initial setup):

```yaml
- hosts: all
  roles:
    # Base system setup
    - common
    # Install Docker
    - docker
    # Firewall, hardening
    - security
    # Application deployment
    - openmeal-deploy
    # Backup automation
    - backup
```

**release.yml** - Incremental release (CI/CD):

```yaml
- hosts: all
  tasks:
    - name: Sync files from Git repo
    - name: Generate .env.infra from vault
    - name: Pull updated images
    - name: Deploy via docker compose
```

### Inventory Structure

```
inventories/
├── stage/
│   ├── hosts.yml       # Server IPs
│   └── group_vars/
│       ├── all.yml     # deployment_type, domains, versions
│       └── vault.yml   # Encrypted secrets (generated)
└── prod/
```

### Variable Flow

```
GitHub Secrets (INFRA_ENV, SERVICES_ENV)
    ↓
generate-vault.py
    ↓
vault.yml (vault_postgres_password, vault_services_env, etc.)
    ↓
Ansible reads vault_* variables
    ↓
generate-configs.yml task
    ↓
.env.infra on target server
```

### Secrets Management

**Local Development:**

- Manually create `vault.yml` with dev secrets
- Or use `.env.infra` directly (simpler)

**CI/CD:**

- GitHub Secrets → `generate-vault.py` → `vault.yml`
- Ansible reads `vault.yml` automatically
- Never committed to Git

## Consequences

### Positive

✅ **Idempotency:**

- Safe to re-run deployments
- Handles failures gracefully

✅ **Readability:**

- Playbooks are self-documenting
- Easy to understand deployment process

✅ **Secrets Management:**

- Ansible Vault encrypts sensitive data
- Clean separation of config and secrets

✅ **Efficiency:**

- Only changed files synchronized
- Parallel execution across hosts (if needed)

✅ **Industry Standard:**

- Recognized skill by employers
- Large community and documentation

### Negative

⚠️ **Learning Curve:**

- Need to learn Ansible syntax and modules
- _Acceptable:_ Good learning investment

⚠️ **Python Dependency:**

- Requires Python 3.13+ on control machine (CI/CD server)
- _Not an issue:_ Python is standard on CI/CD

⚠️ **Overhead:**

- More complex than bash for simple tasks
- _Acceptable:_ Benefits outweigh complexity

## Real-World Usage

### Manual Deployment

```bash
cd infrastructure/ansible
ansible-playbook -i inventories/stage playbooks/deploy.yml
```

### CI/CD Deployment

GitHub Actions workflow:

```yaml
- name: Run Ansible Playbook
  run: |
    cd infrastructure/ansible
    ansible-playbook -i inventories/stage playbooks/release.yml \
      -e "release_map=${{ needs.prepare-release.outputs.release_map }}" \
      -e "registry_id=${{ secrets.YC_REGISTRY_ID }}"
```

### Deployment Flow

1. **CI/CD server** clones Git repository
2. **generate-vault.py** creates `vault.yml` from GitHub Secrets
3. **Ansible** runs on CI/CD server (not on target)
4. **Rsync** syncs files from repo to target server
5. **Templates** generate `.env.infra` on target
6. **Docker Compose** pulls images and starts services

## Evolution Path

### Triggers for Alternative Approaches

**GitOps (ArgoCD/Flux):**

- Migration to Kubernetes
- Need for declarative, pull-based deployments
- Multiple teams requiring self-service deployments
- Drift detection and automatic reconciliation requirements

**Terraform:**

- Need to manage cloud infrastructure (VMs, networks, load balancers)
- Multi-cloud deployment requirements
- Infrastructure state management becomes critical

**Custom Orchestration:**

- Deployment complexity exceeds Ansible capabilities
- Need for complex workflow orchestration
- Integration with specialized deployment tools

### Migration Strategy

**To GitOps:**

1. Migrate to Kubernetes (see ADR-003)
2. Convert Ansible roles to Helm charts or Kustomize
3. Deploy ArgoCD/Flux to cluster
4. Configure Git repository as source of truth
5. Transition from push-based to pull-based deployments

**To Terraform + Ansible:**

1. Extract infrastructure provisioning to Terraform
2. Keep Ansible for application deployment and configuration
3. Use Terraform outputs as Ansible inventory
4. Maintain separation of concerns

**Estimated effort:** 3-5 days for GitOps migration after Kubernetes adoption

## Related Decisions

- [ADR-003: Docker Compose for Orchestration](003-docker-compose.md)
- [ADR-004: Git as Single Source of Truth](004-git-as-single-source-of-truth.md)

## References

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
