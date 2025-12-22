# ADR-001: Monorepo Strategy for Microservices

**Date:** 2025-12-17  
**Status:** Accepted  
**Deciders:** Project Lead

## Context

OpenMeal is a pet project designed to demonstrate enterprise-grade architecture and development practices. The platform consists of multiple microservices (Auth, User, Restaurant, Order, Payment, Dispatch, Tracking, File, External Sender, Support, Admin, Report) plus infrastructure.

**Project Goals:**

- Showcase architectural decisions and development methodologies
- Demonstrate end-to-end food delivery platform implementation
- Serve as portfolio piece highlighting technical skills
- Maintain rapid development velocity as solo developer

**Repository Organization Options:**

1. **Polyrepo** - Each microservice in separate repository (11+ repos)
2. **Monorepo** - All services in single repository
3. **Hybrid** - Core services together, auxiliary services separate

## Decision

Use **monorepo** with Maven multi-module structure.

## Rationale

### Why Monorepo for This Project

**Solo Developer Efficiency:**

- Single `git clone` for entire platform
- All code searchable in one IDE workspace
- No context switching between 11+ repositories

**Atomic Cross-Service Changes:**

- Update event schemas across publishers/subscribers in one commit
- Refactor shared DTOs or authentication in single PR
- No version coordination between repositories

**Unified CI/CD:**

- Single GitHub Actions workflow
- Incremental builds (only changed services)
- Shared Docker layer cache

**Portfolio Value:**

- Complete system visible in one repository
- Single entry point for reviewers
- Demonstrates full-stack architecture understanding

### Trade-offs

**Not Polyrepo Because:**

- 11 repositories = 11 CI/CD configurations to maintain
- Cross-service changes require multiple PRs and coordination
- Dependency version drift between services
- Harder to demonstrate cohesive architecture
- Overkill for solo developer pet project

**Not Hybrid Because:**

- Adds complexity without benefits at this scale
- Still requires coordination between repos
- Unclear boundaries: which services go where?
- Portfolio presentation becomes fragmented

## Implementation

### Repository Structure

```
.
├── pom.xml
├── services/
│   ├── api-gateway/
│   └── user-service/
├── infrastructure/
├── compose/
├── config/
└── makefiles/
```

### Maven Multi-Module

- Parent POM defines dependency management
- Each service is a Maven module
- Modules can be built independently: `./mvnw -pl services/user-service package`

### CI/CD Strategy

- Detect changed services via `git diff`
- Build only changed Docker images
- Deploy only updated services (incremental deployment)

## Consequences

### Positive

- ✅ Faster development velocity (no cross-repo coordination)
- ✅ Easier refactoring and code sharing
- ✅ Consistent tooling and standards
- ✅ Simplified local development setup

### Negative

- ⚠️ Requires discipline to avoid tight coupling between services
- ⚠️ Need clear module boundaries and ownership
- ⚠️ Larger initial clone size (acceptable trade-off)

## Alternatives Considered

### Polyrepo

**Rejected because:**

- Overhead of maintaining multiple CI/CD pipelines
- Difficult to make atomic changes across services
- Dependency version drift between services
- Complicated local development setup

### Hybrid (Monorepo + Polyrepo)

**Rejected because:**

- Adds complexity without clear benefits for our team size
- Still requires cross-repo coordination for some changes
- May revisit if team grows significantly (>20 developers)

## Related Decisions

- [ADR-002: Redpanda vs Kafka](002-redpanda.md)
- [ADR-003: Docker Compose for Container Management](003-docker-compose.md)

## References

- [Monorepo.tools](https://monorepo.tools/)
- [Google's Monorepo Philosophy](https://research.google/pubs/pub45424/)
- [Maven Multi-Module Projects](https://maven.apache.org/guides/mini/guide-multiple-modules.html)
