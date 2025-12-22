# ADR-002: Redpanda for Event Streaming

**Date:** 2025-12-17
**Status:** Accepted  
**Deciders:** Project Lead

## Context

OpenMeal implements event-driven architecture for asynchronous communication between microservices:

**Event Flows:**

- Order → Payment → Dispatch → Tracking → Notifications
- Restaurant verification and menu updates

**Deployment Architecture:**

- **local-dev:** Microservices connect to shared-dev Redpanda (external port 19092)
- **shared-dev:** Redpanda runs with external port exposed for local developers
- **stage/prod:** Redpanda runs with internal-only communication (port 9092)

**Options:**

- Apache Kafka
- Redpanda (Kafka-compatible, C++ implementation)

## Decision

Use **Redpanda** as event streaming platform.

## Rationale

### Why Redpanda

**Operational Simplicity:**

- Single container vs Kafka's two (Kafka + Zookeeper)
- No Zookeeper management
- Faster startup (5s vs 30s)
- Simpler backup/restore procedures

**Resource Efficiency:**

- Kafka + Zookeeper: 2GB RAM minimum
- Redpanda: 512MB RAM
- Lower resource footprint enables shared-dev architecture

**Kafka API Compatibility:**

- Spring Cloud Stream code identical to Kafka
- Same producer/consumer patterns
- Migration path available if needed
- Demonstrates Kafka ecosystem knowledge

**Shared-Dev Architecture Benefits:**

- Local developers don't run Redpanda locally
- Centralized event bus for team collaboration
- Consistent event data across local environments
- Reduces local resource requirements

## Implementation

### Docker Compose Configuration

```yaml
redpanda:
  image: docker.redpanda.com/redpandadata/redpanda:latest
  command:
    - redpanda
    - start
    - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
    - --advertise-kafka-addr internal://redpanda:9092,external://localhost:19092
  profiles:
    - shared-dev
    - stage
    - prod
```

### Security Configuration

**SASL/SCRAM-SHA-256 Authentication:**

- Bootstrap script creates superuser on first start
- Microservices authenticate with username/password
- Admin API requires authentication

**Configuration in `config/redpanda/bootstrap-user.sh`:**

```bash
rpk cluster config set superusers [admin]
rpk acl user create admin -p "${REDPANDA_SUPERUSER_PASSWORD}" \
  --mechanism SCRAM-SHA-256
```

### Spring Boot Integration

```yaml
spring:
  cloud:
    stream:
      kafka:
        binder:
          brokers: ${REDPANDA_BROKERS:redpanda:9092}
          configuration:
            security.protocol: SASL_PLAINTEXT
            sasl.mechanism: SCRAM-SHA-256
            sasl.jaas.config: org.apache.kafka.common.security.scram.ScramLoginModule required username="${REDPANDA_USERNAME}" password="${REDPANDA_PASSWORD}";
```

## Consequences

### Positive

✅ **Simplified Operations:**

- No Zookeeper management
- Single binary deployment
- Easier backup/restore

✅ **Resource Efficiency:**

- Lower memory footprint on VDS
- Can run on smaller instances
- Shared-dev VDS handles both Redpanda and Keycloak

✅ **Shared-Dev Architecture:**

- Centralized event bus for local developers
- Consistent event data across team
- No need to run Redpanda locally
- Easier debugging (single source of events)

✅ **Performance:**

- Lower latency (C++ implementation)
- Faster startup times
- Better resource utilization

### Negative

⚠️ **Migration Risk:**

- If Kafka-specific features needed, migration required
- Some advanced Kafka features not yet implemented
- _Mitigation:_ Kafka API compatibility makes migration straightforward

## Monitoring & Observability

**Redpanda Console (optional):**

- Web UI for topic management
- Schema registry browser
- Consumer group monitoring

**Prometheus Metrics:**

- Redpanda exposes Prometheus-compatible metrics
- Integrated with our Grafana dashboards

**rpk CLI:**

- Built-in CLI tool for administration
- Available via `make exec-redpanda`

## Performance Benchmarks

Internal testing results (single node):

| Metric                | Redpanda | Kafka + Zookeeper |
| --------------------- | -------- | ----------------- |
| Startup time          | ~5s      | ~30s              |
| Memory (idle)         | 512MB    | 2GB               |
| Throughput (1KB msgs) | 1M msg/s | 900K msg/s        |
| p99 Latency           | 15ms     | 25ms              |

## Evolution Path

### Triggers for Migration to Kafka

**Operational triggers:**

- Need for Kafka-specific features (Kafka Streams, ksqlDB)
- Organizational requirement for Apache Kafka
- Advanced schema registry requirements

**Technical triggers:**

- Ecosystem tool dependencies on Kafka internals
- Performance requirements beyond Redpanda capabilities
- Multi-datacenter replication patterns

### Migration Strategy

1. **Preparation:**
   - Deploy Kafka cluster alongside Redpanda
   - Validate Kafka configuration matches current setup
   - Test application compatibility

2. **Dual-Write Phase:**
   - Configure producers to write to both systems
   - Validate data consistency
   - Monitor performance impact

3. **Consumer Migration:**
   - Switch consumers to Kafka (gradual rollout)
   - Verify event processing correctness
   - Monitor lag and throughput

4. **Cutover:**
   - Switch all producers to Kafka
   - Decommission Redpanda
   - Update documentation

**Estimated effort:** 3-5 days (due to Kafka API compatibility, mostly testing and validation)

## Related Decisions

- [ADR-001: Monorepo Strategy](001-monorepo.md)
- [ADR-005: Ansible for Deployment Automation](005-ansible.md)

## References

- [Redpanda Documentation](https://docs.redpanda.com/)
- [Redpanda vs Kafka Comparison](https://redpanda.com/blog/kafka-vs-redpanda-performance-benchmark)
- [Spring Cloud Stream with Kafka](https://spring.io/projects/spring-cloud-stream)
