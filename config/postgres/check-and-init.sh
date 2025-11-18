#!/usr/bin/env bash
# ============================================================================
# PostgreSQL Runtime Initialization Script
# ============================================================================
# Runs on every container start to ensure users/databases are up to date
# Safe to run multiple times
# ============================================================================

set -e

CONFIG_FILE="/config/init-users.conf"

echo "Checking PostgreSQL configuration..."

# Wait for PostgreSQL to be ready
until pg_isready -U "$POSTGRES_USER" > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

echo "PostgreSQL is ready, checking users and databases..."

# Check if user exists
user_exists() {
    local username=$1
    psql -U "$POSTGRES_USER" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'" | grep -q 1
}

# Check if database exists
db_exists() {
    local dbname=$1
    psql -U "$POSTGRES_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='$dbname'" | grep -q 1
}

# Resolve environment variable or return placeholder
resolve_env_var() {
    local value=$1
    if [[ $value =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        local resolved="${!value}"
        if [ -n "$resolved" ]; then
            echo "$resolved"
        else
            echo "changeme_${value,,}"
        fi
    else
        echo "$value"
    fi
}

# Process configuration file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 0
fi

NEW_USERS=0
NEW_DBS=0

while IFS=: read -r username password_var database || [ -n "$username" ]; do
    [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
    
    username=$(echo "$username" | xargs)
    password_var=$(echo "$password_var" | xargs)
    database=$(echo "$database" | xargs)
    
    [ -z "$username" ] || [ -z "$password_var" ] || [ -z "$database" ] && continue
    
    password=$(resolve_env_var "$password_var")
    
    if ! user_exists "$username"; then
        echo "Creating new user: $username"
        psql -U "$POSTGRES_USER" <<-EOSQL
            CREATE USER "$username" WITH PASSWORD '$password';
EOSQL
        ((NEW_USERS++))
    fi
    
    if ! db_exists "$database"; then
        echo "Creating new database: $database"
        psql -U "$POSTGRES_USER" <<-EOSQL
            CREATE DATABASE "$database" OWNER "$username";
            GRANT ALL PRIVILEGES ON DATABASE "$database" TO "$username";
EOSQL
        ((NEW_DBS++))
    fi
    
done < "$CONFIG_FILE"

if [ $NEW_USERS -eq 0 ] && [ $NEW_DBS -eq 0 ]; then
    echo "✓ All users and databases are up to date"
else
    echo "✓ Created $NEW_USERS new user(s) and $NEW_DBS new database(s)"
fi
