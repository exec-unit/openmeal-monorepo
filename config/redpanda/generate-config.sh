#!/bin/bash
set -e

REDPANDA_INTERNAL_PORT=${REDPANDA_INTERNAL_PORT:-9092}
REDPANDA_ADMIN_PORT=${REDPANDA_ADMIN_PORT:-9644}

echo "Generating Redpanda configuration from template..."

# Check if config already exists and has admin_api_require_auth: true
if [ -f /etc/redpanda/redpanda.yaml ] && grep -q "admin_api_require_auth: true" /etc/redpanda/redpanda.yaml 2>/dev/null; then
  echo "Configuration already exists with admin_api_require_auth enabled. Skipping regeneration."
  cat /etc/redpanda/redpanda.yaml
  exit 0
fi

# Generate fresh config from template
sed -e "s/\${REDPANDA_INTERNAL_PORT}/${REDPANDA_INTERNAL_PORT}/g" \
    -e "s/\${REDPANDA_ADMIN_PORT}/${REDPANDA_ADMIN_PORT}/g" \
  /etc/redpanda/redpanda.yaml.template > /etc/redpanda/redpanda.yaml

echo "Configuration generated successfully."
cat /etc/redpanda/redpanda.yaml
