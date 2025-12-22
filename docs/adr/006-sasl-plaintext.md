# ADR-006: SASL_PLAINTEXT for Redpanda Authentication

**Date:** 2025-12-19
**Status:** Accepted  
**Deciders:** Project Lead

## Context

Redpanda supports multiple security protocols for client authentication:

**Available Options:**

- **PLAINTEXT** - No authentication, no encryption
- **SASL_PLAINTEXT** - Authentication via SASL, no encryption
- **SASL_SSL** - Authentication via SASL, TLS encryption
- **SSL** - TLS encryption, certificate-based authentication

**Deployment Scenarios:**

- **local-dev:** Developers connect to shared-dev Redpanda over internet (port 19092)
- **shared-dev:** Redpanda exposed externally for local developers
- **stage/prod:** Redpanda internal-only (port 9092), no external access

## Decision

Use **SASL_PLAINTEXT** (SASL/SCRAM-SHA-256 authentication without TLS encryption).

## Rationale

### Why SASL_PLAINTEXT

**Network Topology:**

**shared-dev (external port):**

- Only environment with external Redpanda access
- Contains test data only (no production/sensitive data)
- Used for development and testing
- Acceptable risk: credentials exposed in transit

**stage/prod (internal-only):**

- Redpanda port 9092 not exposed externally
- Communication only within Docker network
- Firewall blocks external access
- TLS security benefit exists but risk profile acceptable for current scope

**Operational Complexity vs Security Benefit:**

**TLS Certificate Management Requirements:**

- Certificate generation and rotation automation
- CA certificate distribution to all microservices
- Truststore/keystore management in containers
- Volume mounts for certificate files
- Certificate expiration monitoring
- Debugging TLS handshake failures

**Time Investment:**

- Initial setup: 1 day (certificate generation, Spring Boot configuration, testing, troubleshooting)
- Ongoing maintenance: certificate rotation (quarterly), monitoring
- Focus shift from application architecture to certificate operations

**Spring Boot Configuration Comparison:**

**SASL_PLAINTEXT (current):**

```yaml
security.protocol: SASL_PLAINTEXT
sasl.mechanism: SCRAM-SHA-256
sasl.jaas.config: ScramLoginModule required username="..." password="...";
```

**SASL_SSL (alternative):**

```yaml
security.protocol: SASL_SSL
sasl.mechanism: SCRAM-SHA-256
sasl.jaas.config: ScramLoginModule required username="..." password="...";
ssl.truststore.location: /path/to/truststore.jks
ssl.truststore.password: ${TRUSTSTORE_PASSWORD}
ssl.keystore.location: /path/to/keystore.jks
ssl.keystore.password: ${KEYSTORE_PASSWORD}
ssl.endpoint.identification.algorithm: ""
```

Additional operational burden:

- Truststore/keystore files in Docker images or mounted volumes
- Environment-specific certificate paths
- Certificate validation configuration
- TLS version and cipher suite management

### Risk Assessment

**shared-dev External Exposure:**

**Threat:** Credential interception during transit  
**Likelihood:** Low (requires active network monitoring)  
**Impact:** Access to test environment only  
**Risk Acceptance:**

- Test data only, no sensitive information
- Credential rotation policy in place
- Optional IP allowlist can further reduce exposure

**stage/prod Internal Communication:**

**Threat:** Network sniffing within Docker network  
**Likelihood:** Very low (requires host compromise)  
**Impact:** If host is compromised, TLS provides limited additional protection  
**Risk Acceptance:**

- Attacker with host access has filesystem and memory access
- TLS protects data in transit but not at rest or in memory
- Defense-in-depth focuses on host hardening (SSH keys, fail2ban, firewall, minimal attack surface)

### Security Model Analysis

**Current Approach: Network Boundary Security**

- External firewall blocks unauthorized access
- Docker network isolation for internal communication
- SASL authentication prevents unauthorized clients
- Host hardening as primary security layer

**Alternative: Zero Trust with mTLS**

**Requirements:**

- Mutual TLS between all microservices
- Certificate authority infrastructure
- Certificate lifecycle management (generation, distribution, rotation, revocation)
- Service mesh (Istio/Linkerd) or manual certificate management
- TLS configuration for all service-to-service calls

**Operational Impact:**

- Initial implementation: 2-3 days (CA setup, certificate distribution, service configuration, testing)
- Ongoing maintenance: certificate rotation, monitoring, troubleshooting
- Increased complexity in debugging (encrypted traffic, certificate validation errors)

**Trade-off Analysis:**

Security benefit exists but is limited in current architecture:

- Single-host deployment: network boundary already defined
- Host compromise defeats TLS (attacker has memory/filesystem access)
- No multi-tenant requirements
- No regulatory compliance requirements for encryption in transit

Operational cost is significant:

- Certificate management complexity
- Debugging overhead
- Maintenance burden
- Focus shift from application features to security infrastructure

**Decision:** Accept current risk profile, prioritize application architecture development

## Implementation

### Redpanda Configuration

```yaml
redpanda:
  command:
    - redpanda start
    - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
    - --advertise-kafka-addr internal://redpanda:9092,external://${SHARED_DEV_HOST}:19092
  environment:
    REDPANDA_SUPERUSER_PASSWORD: ${REDPANDA_SUPERUSER_PASSWORD}
```

### Bootstrap Script

```bash
rpk cluster config set superusers [admin]
rpk acl user create admin -p "${REDPANDA_SUPERUSER_PASSWORD}" \
  --mechanism SCRAM-SHA-256
```

### Spring Boot Configuration

```yaml
spring:
  cloud:
    stream:
      kafka:
        binder:
          brokers: ${REDPANDA_BROKERS}
          configuration:
            security.protocol: SASL_PLAINTEXT
            sasl.mechanism: SCRAM-SHA-256
            sasl.jaas.config: org.apache.kafka.common.security.scram.ScramLoginModule required username="${REDPANDA_USERNAME}" password="${REDPANDA_PASSWORD}";
```

## Consequences

### Positive

✅ **Operational Simplicity:**

- No certificate management
- No truststore/keystore distribution
- Simpler debugging (no TLS handshake issues)
- Faster development iteration

✅ **Authentication Enabled:**

- SASL/SCRAM-SHA-256 prevents unauthorized access
- Credentials required for all connections
- ACLs can be configured per user

✅ **Performance:**

- No TLS encryption overhead
- Lower CPU usage
- Lower latency

### Negative

⚠️ **Credentials in Transit (shared-dev only):**

- Credentials visible if network traffic intercepted
- _Mitigation:_ Test data only, regular credential rotation

⚠️ **Not Zero Trust:**

- Assumes VDS network is trusted
- _Mitigation:_ VDS hardening, firewall, SSH key auth

### Migration Path

If security requirements change:

1. Generate TLS certificates (Let's Encrypt or self-signed CA)
2. Update Redpanda configuration to enable TLS
3. Distribute truststore to all microservices
4. Update Spring Boot configuration to `SASL_SSL`
5. Test and deploy

**Estimated effort:** 1 day for single-host deployment

## Related Decisions

- [ADR-002: Redpanda for Event Streaming](002-redpanda.md)
- [ADR-004: Git as Single Source of Truth](004-git-as-single-source-of-truth.md)

## References

- [Redpanda Security Documentation](https://docs.redpanda.com/docs/security/)
- [Kafka SASL/SCRAM Authentication](https://kafka.apache.org/documentation/#security_sasl_scram)
