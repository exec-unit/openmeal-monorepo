#!/usr/bin/env bash
# ============================================================================
# MongoDB Initialization Script
# ============================================================================
# Automatically creates users and databases from config file
# Safe to run multiple times - only creates missing users/databases
# ============================================================================

set -e

CONFIG_FILE="/docker-entrypoint-initdb.d/init-users.conf"

echo "Starting MongoDB user and database initialization..."

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

while IFS=: read -r username password_var database roles || [ -n "$username" ]; do
    # Skip empty lines and comments
    [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace
    username=$(echo "$username" | xargs)
    password_var=$(echo "$password_var" | xargs)
    database=$(echo "$database" | xargs)
    roles=$(echo "$roles" | xargs)
    
    # Skip if any field is empty
    if [ -z "$username" ] || [ -z "$password_var" ] || [ -z "$database" ] || [ -z "$roles" ]; then
        echo "WARNING: Skipping invalid line - missing fields"
        continue
    fi
    
    # Resolve password from environment variable
    password=$(resolve_env_var "$password_var")
    
    echo "Processing: user=$username, database=$database, roles=$roles"
    
    # Convert comma-separated roles to MongoDB array format
    IFS=',' read -ra ROLE_ARRAY <<< "$roles"
    ROLES_JSON="["
    for i in "${!ROLE_ARRAY[@]}"; do
        role=$(echo "${ROLE_ARRAY[$i]}" | xargs)
        if [ $i -gt 0 ]; then
            ROLES_JSON+=","
        fi
        ROLES_JSON+="{role:\"$role\",db:\"$database\"}"
    done
    ROLES_JSON+="]"
    
    # Create user in the specific database
    echo "  → Creating user '$username' in database '$database'..."
    mongosh --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin "$database" <<-EOJS
        try {
            db.createUser({
                user: "$username",
                pwd: "$password",
                roles: $ROLES_JSON
            });
            print("  ✓ User '$username' created successfully");
        } catch (err) {
            if (err.code === 51003) {
                print("  ✓ User '$username' already exists, skipping");
            } else {
                print("  ✗ Error creating user: " + err.message);
                throw err;
            }
        }
EOJS
    
done < "$CONFIG_FILE"

echo ""
echo "MongoDB initialization completed successfully!"
