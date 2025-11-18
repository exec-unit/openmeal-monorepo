#!/usr/bin/env bash
# ============================================================================
# PostgreSQL Initialization Script
# ============================================================================
# Automatically creates users and databases from config file
# Safe to run multiple times - only creates missing users/databases
# ============================================================================

set -e

CONFIG_FILE="/docker-entrypoint-initdb.d/init-users.conf"
PROCESSED_FILE="/var/lib/postgresql/data/.init-users-processed"

echo "Starting PostgreSQL user and database initialization..."

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
            echo "WARNING: Environment variable $value is not set, using placeholder" >&2
            echo "changeme_${value,,}"
        fi
    else
        echo "$value"
    fi
}

# Process configuration file
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    echo "Skipping user initialization"
    exit 0
fi

echo "Reading configuration from: $CONFIG_FILE"

# Track what we're processing
declare -A PROCESSED_USERS

while IFS=: read -r username password_var database || [ -n "$username" ]; do
    # Skip empty lines and comments
    [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace
    username=$(echo "$username" | xargs)
    password_var=$(echo "$password_var" | xargs)
    database=$(echo "$database" | xargs)
    
    # Skip if any field is empty
    if [ -z "$username" ] || [ -z "$password_var" ] || [ -z "$database" ]; then
        echo "WARNING: Skipping invalid line - missing fields"
        continue
    fi
    
    # Resolve password from environment variable or use literal
    password=$(resolve_env_var "$password_var")
    
    echo "Processing: user=$username, database=$database"
    
    # Create user if doesn't exist
    if user_exists "$username"; then
        echo "  ✓ User '$username' already exists, skipping creation"
    else
        echo "  → Creating user '$username'..."
        psql -U "$POSTGRES_USER" <<-EOSQL
            CREATE USER "$username" WITH PASSWORD '$password';
EOSQL
        echo "  ✓ User '$username' created"
    fi
    
    # Create database if doesn't exist
    if db_exists "$database"; then
        echo "  ✓ Database '$database' already exists, skipping creation"
    else
        echo "  → Creating database '$database'..."
        psql -U "$POSTGRES_USER" <<-EOSQL
            CREATE DATABASE "$database" OWNER "$username";
EOSQL
        echo "  ✓ Database '$database' created"
    fi
    
    # Grant privileges (safe to run multiple times)
    echo "  → Granting privileges..."
    psql -U "$POSTGRES_USER" <<-EOSQL
        GRANT ALL PRIVILEGES ON DATABASE "$database" TO "$username";
EOSQL
    echo "  ✓ Privileges granted"
    
    PROCESSED_USERS["$username"]="$database"
    
done < "$CONFIG_FILE"

echo ""
echo "PostgreSQL initialization completed successfully!"
echo "Processed ${#PROCESSED_USERS[@]} user(s)"

# Mark as processed
touch "$PROCESSED_FILE"
