#!/usr/bin/env bash
# ============================================================================
# Database Configuration Preparation Script
# ============================================================================
# Prepares database configuration files based on deployment environment
# Manages keycloak user in PostgreSQL config for different environments
# ============================================================================

set -e

ENVIRONMENT=${ENVIRONMENT:-local-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

POSTGRES_CONFIG="$PROJECT_ROOT/config/postgres/init-users.conf"

echo "→ Preparing database configurations for environment: $ENVIRONMENT"

# Uncomment all non-comment lines
uncomment_all() {
    local file=$1
    if [ -f "$file" ]; then
        sed -i "s/^# *\([^#].*\)/\1/" "$file"
    fi
}

# Comment lines matching pattern
comment_line() {
    local file=$1
    local pattern=$2
    if [ -f "$file" ]; then
        sed -i "s/^\($pattern.*\)/# \1/" "$file"
    fi
}

# Uncomment lines matching pattern
uncomment_line() {
    local file=$1
    local pattern=$2
    if [ -f "$file" ]; then
        sed -i "s/^# *\($pattern.*\)/\1/" "$file"
    fi
}

# Comment all lines except pattern
comment_all_except() {
    local file=$1
    local pattern=$2
    if [ -f "$file" ]; then
        # First uncomment everything
        sed -i "s/^# *\([^#].*\)/\1/" "$file"
        # Then comment everything that doesn't match the pattern
        sed -i "/^$pattern/!s/^\([^#].*\)/# \1/" "$file"
    fi
}

# PostgreSQL configuration - only manage keycloak user
if [ -f "$POSTGRES_CONFIG" ]; then
    echo "Configuring PostgreSQL users..."
    
    case "$ENVIRONMENT" in
        local-dev)
            # For local-dev: uncomment all except keycloak (uses shared-dev keycloak)
            comment_line "$POSTGRES_CONFIG" "keycloak:"
            echo "  ✓ All users enabled except Keycloak (uses shared-dev)"
            ;;
        shared-dev)
            # For shared-dev: uncomment keycloak only, comment all others
            comment_all_except "$POSTGRES_CONFIG" "keycloak:"
            echo "  ✓ Only Keycloak user enabled for shared-dev"
            ;;
        stage|prod)
            # For stage/prod: enable all users
            uncomment_line "$POSTGRES_CONFIG" "keycloak:"
            echo "  ✓ All users enabled for $ENVIRONMENT"
            ;;
        *)
            echo "  ⚠ Unknown environment: $ENVIRONMENT, using default configuration"
            ;;
    esac
fi

echo ""
echo "✓ Database configurations prepared for $ENVIRONMENT environment"
echo ""
