#!/usr/bin/env bash
# ============================================================================
# MinIO Initialization Script
# ============================================================================
# Automatically creates users and buckets from config file
# Safe to run multiple times - only creates missing users/buckets
# ============================================================================

set +e

CONFIG_FILE="/config/init-users.conf"
MC_ALIAS="local"

echo "Starting MinIO user and bucket initialization..."

# Wait for MinIO to be ready
until mc alias set "$MC_ALIAS" "http://localhost:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" > /dev/null 2>&1; do
    echo "Waiting for MinIO to be ready..."
    sleep 2
done

echo "MinIO is ready, processing configuration..."

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
    exit 0
fi

NEW_USERS=0
NEW_BUCKETS=0

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

while IFS=: read -r username password_var buckets policy || [ -n "$username" ]; do
    [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]] && continue
    
    username=$(trim "$username")
    password_var=$(trim "$password_var")
    buckets=$(trim "$buckets")
    policy=$(trim "$policy")
    
    [ -z "$username" ] || [ -z "$password_var" ] || [ -z "$buckets" ] || [ -z "$policy" ] && continue
    
    password=$(resolve_env_var "$password_var")
    
    echo "Processing: user=$username, buckets=$buckets, policy=$policy"
    
    # Check if user exists (using pure bash)
    USER_EXISTS=false
    while IFS= read -r line; do
        first_word="${line%% *}"
        if [ "$first_word" = "$username" ]; then
            USER_EXISTS=true
            break
        fi
    done < <(mc admin user list "$MC_ALIAS" 2>/dev/null || echo "")
    
    if [ "$USER_EXISTS" = true ]; then
        echo "  ✓ User '$username' already exists"
    else
        echo "  → Creating user '$username'..."
        if mc admin user add "$MC_ALIAS" "$username" "$password" 2>&1; then
            echo "  ✓ User '$username' created"
            ((NEW_USERS++))
        else
            echo "  ✗ Failed to create user '$username'"
        fi
    fi
    
    # Process buckets
    IFS=',' read -ra BUCKET_ARRAY <<< "$buckets"
    for bucket in "${BUCKET_ARRAY[@]}"; do
        bucket=$(trim "$bucket")
        [ -z "$bucket" ] && continue
        
        echo "  → Checking bucket '$bucket'..."
        if mc ls "$MC_ALIAS/$bucket" > /dev/null 2>&1; then
            echo "  ✓ Bucket '$bucket' already exists"
        else
            echo "  → Creating bucket '$bucket'..."
            if mc mb "$MC_ALIAS/$bucket" 2>&1; then
                echo "  ✓ Bucket '$bucket' created"
                ((NEW_BUCKETS++))
            else
                echo "  ✗ Failed to create bucket '$bucket'"
                continue
            fi
        fi
        
        # Set policy for user on bucket
        echo "  → Setting $policy policy for '$username' on '$bucket'..."
        if mc admin policy attach "$MC_ALIAS" "$policy" --user "$username" 2>&1; then
            echo "  ✓ Policy attached"
        else
            echo "  ✗ Failed to attach policy"
        fi
    done
    
done < "$CONFIG_FILE"

echo ""
echo "MinIO initialization completed!"
echo "Created $NEW_USERS new user(s) and $NEW_BUCKETS new bucket(s)"
