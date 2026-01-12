#!/bin/bash
set -e

# Superuser credentials
REDPANDA_SUPERUSER=${REDPANDA_SUPERUSER:-"admin"}
REDPANDA_SUPERUSER_PASSWORD=${REDPANDA_SUPERUSER_PASSWORD:-"changeme"}
REDPANDA_SASL_MECHANISM=${REDPANDA_SASL_MECHANISM:-"SCRAM-SHA-256"}
REDPANDA_ADMIN_PORT=${REDPANDA_ADMIN_PORT:-9644}
REDPANDA_INTERNAL_PORT=${REDPANDA_INTERNAL_PORT:-9092}

echo "Waiting for Redpanda Admin API to be ready..."
until curl -fs "http://localhost:${REDPANDA_ADMIN_PORT}/v1/status/ready" >/dev/null 2>&1; do
  sleep 2
done
echo "Redpanda Admin API is ready."

# Configure superuser in cluster config
echo "Configuring superuser in cluster config..."
rpk cluster config set superusers "[\"${REDPANDA_SUPERUSER}\"]" \
  --api-urls localhost:${REDPANDA_ADMIN_PORT} \
  --user "$REDPANDA_SUPERUSER" \
  --password "$REDPANDA_SUPERUSER_PASSWORD"

# Create superuser
echo "Checking if superuser $REDPANDA_SUPERUSER exists..."
if rpk acl user list --api-urls localhost:${REDPANDA_ADMIN_PORT} --user "$REDPANDA_SUPERUSER" \
  --password "$REDPANDA_SUPERUSER_PASSWORD" 2>/dev/null | grep -q "^${REDPANDA_SUPERUSER}$"; then
  echo "Superuser $REDPANDA_SUPERUSER already exists, updating password..."
  rpk acl user update $REDPANDA_SUPERUSER \
    --new-password "$REDPANDA_SUPERUSER_PASSWORD" \
    --mechanism $REDPANDA_SASL_MECHANISM \
    --api-urls localhost:${REDPANDA_ADMIN_PORT} \
    --user "$REDPANDA_SUPERUSER" \
    --password "$REDPANDA_SUPERUSER_PASSWORD" || true
else
  echo "Creating superuser $REDPANDA_SUPERUSER..."
  rpk acl user create $REDPANDA_SUPERUSER \
    --password "$REDPANDA_SUPERUSER_PASSWORD" \
    --mechanism $REDPANDA_SASL_MECHANISM \
    --api-urls localhost:${REDPANDA_ADMIN_PORT}
fi

echo "Superuser $REDPANDA_SUPERUSER created successfully."

# Enable Admin API authentication now that superuser exists
echo "Enabling Admin API authentication..."
rpk cluster config set admin_api_require_auth true \
  --api-urls localhost:${REDPANDA_ADMIN_PORT} \
  --user "$REDPANDA_SUPERUSER" \
  --password "$REDPANDA_SUPERUSER_PASSWORD"

# Wait a moment for the config to apply
sleep 2

# Persist Admin API auth setting in the local config file so it survives restarts
echo "Updating redpanda.yaml to persist admin_api_require_auth: true..."
if [ -f /etc/redpanda/redpanda.yaml ]; then
  sed -i 's/^\(\s*admin_api_require_auth:\s*\)false/\1true/' /etc/redpanda/redpanda.yaml
  echo "✓ Updated /etc/redpanda/redpanda.yaml"
else
  echo "⚠ Warning: /etc/redpanda/redpanda.yaml not found"
fi

# Verify cluster health using SASL authentication via Kafka API
echo "Verifying cluster health with SASL authentication..."
rpk cluster health \
  --user "${REDPANDA_SUPERUSER}" \
  --password "${REDPANDA_SUPERUSER_PASSWORD}" \
  --sasl-mechanism "${REDPANDA_SASL_MECHANISM}"

echo ""
echo "✓ SASL/SCRAM authentication configured successfully."
echo "  Superuser: $REDPANDA_SUPERUSER"
echo "  Mechanism: $REDPANDA_SASL_MECHANISM"
echo "  Admin API authentication: ENABLED"
