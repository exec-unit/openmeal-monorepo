#!/usr/bin/env bash
# ============================================================================
# MongoDB Runtime Initialization Script
# ============================================================================
# Runs on every container start to ensure users/databases are up to date
# Safe to run multiple times
# ============================================================================

set -e

CONFIG_FILE="/config/init-users.conf"

echo "Checking MongoDB configuration..."

# Wait for MongoDB to be ready
until mongosh --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
    echo "Waiting for MongoDB to be ready..."
    sleep 2
done

echo "MongoDB is ready, checking users and databases..."

# Trim whitespace
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
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

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 0
fi

NEW_USERS=0

while IFS=: read -r username password_var database roles || [ -n "$username" ]; do
    [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
    
    username=$(trim "$username")
    password_var=$(trim "$password_var")
    database=$(trim "$database")
    roles=$(trim "$roles")
    
    [ -z "$username" ] || [ -z "$password_var" ] || [ -z "$database" ] || [ -z "$roles" ] && continue
    
    password=$(resolve_env_var "$password_var")
    
    # Convert roles to JSON array
    IFS=',' read -ra ROLE_ARRAY <<< "$roles"
    ROLES_JSON="["
    for i in "${!ROLE_ARRAY[@]}"; do
        role=$(trim "${ROLE_ARRAY[$i]}")
        [ $i -gt 0 ] && ROLES_JSON+=","
        ROLES_JSON+="{role:\"$role\",db:\"$database\"}"
    done
    ROLES_JSON+="]"
    
    # Try to create user
    mongosh --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin "$database" <<-EOJS > /dev/null 2>&1
        try {
            db.createUser({
                user: "$username",
                pwd: "$password",
                roles: $ROLES_JSON
            });
            print("Created user: $username");
        } catch (err) {
            if (err.code !== 51003) {
                throw err;
            }
        }
EOJS
    
    if [ $? -eq 0 ]; then
        echo "Created new user: $username in database: $database"
        ((NEW_USERS++))
    fi
    
done < "$CONFIG_FILE"

if [ $NEW_USERS -eq 0 ]; then
    echo "✓ All users are up to date"
else
    echo "✓ Created $NEW_USERS new user(s)"
fi
