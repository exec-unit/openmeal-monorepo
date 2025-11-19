#!/usr/bin/env bash

# ============================================================================
# OpenMeal Backend - Service Health Check Script
# ============================================================================
# Automatically detects and checks health of all running Docker containers
# Cross-platform compatible: Linux, macOS, Windows (Git Bash/WSL)
# ============================================================================

set -e

# OS Detection and compatibility check
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "linux" ;;
        Darwin*)    echo "macos" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Check if running on Windows without WSL/Git Bash
if [ "$OS_TYPE" = "windows" ]; then
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not found in PATH"
        echo "Please ensure Docker Desktop is installed and running"
        exit 1
    fi
fi

# Terminal color definitions for enhanced output readability
# Disable colors on Windows CMD (but work in Git Bash/WSL)
if [ "$OS_TYPE" = "windows" ] && [ -z "$TERM" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
fi

# Docker Compose configuration with multi-file support
COMPOSE_FILES="-f docker-compose.yml -f compose/infra.yml -f compose/monitoring.yml"
COMPOSE_CMD="docker compose $COMPOSE_FILES"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           OpenMeal - Service Health Assessment                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get healthcheck configuration from docker inspect
get_healthcheck_test() {
    local container_name=$1
    docker inspect --format='{{if .Config.Healthcheck}}{{json .Config.Healthcheck.Test}}{{else}}null{{end}}' "$container_name" 2>/dev/null || echo "null"
}

# Check container health status from Docker
check_container_health() {
    local container_name=$1
    local health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_name" 2>/dev/null || echo "none")
    echo "$health_status"
}

# Service health counters for summary reporting
total=0
healthy=0
unhealthy=0
no_healthcheck=0

# Automatically detect all running containers from our compose project
CONTAINERS=$($COMPOSE_CMD ps --format json 2>/dev/null | grep -o '"Name":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}✗ No running containers detected${NC}"
    echo -e "${YELLOW}→ Start environment: make dev|shared-dev|stage|prod${NC}"
    exit 1
fi

# Check each container dynamically
while IFS= read -r container; do
    [ -z "$container" ] && continue
    
    total=$((total+1))
    
    # Get container name without project prefix for display
    display_name=$(echo "$container" | sed 's/^[^-]*-//')
    
    echo -n "Checking $display_name... "
    
    # Check if container has healthcheck configured
    healthcheck_test=$(get_healthcheck_test "$container")
    
    if [ "$healthcheck_test" = "null" ] || [ -z "$healthcheck_test" ]; then
        # No healthcheck configured - just verify it's running
        if docker ps --filter "name=$container" --filter "status=running" --format '{{.Names}}' | grep -q "$container"; then
            echo -e "${GREEN}✓ Running${NC} ${CYAN}(no healthcheck)${NC}"
            no_healthcheck=$((no_healthcheck+1))
        else
            echo -e "${RED}✗ Not running${NC}"
            unhealthy=$((unhealthy+1))
        fi
    else
        # Healthcheck is configured - check its status
        health_status=$(check_container_health "$container")
        
        case "$health_status" in
            "healthy")
                echo -e "${GREEN}✓ Healthy${NC}"
                healthy=$((healthy+1))
                ;;
            "unhealthy")
                echo -e "${RED}✗ Unhealthy${NC}"
                unhealthy=$((unhealthy+1))
                ;;
            "starting")
                echo -e "${YELLOW}⚠ Starting...${NC}"
                unhealthy=$((unhealthy+1))
                ;;
            "none")
                # Healthcheck defined but not running yet
                echo -e "${YELLOW}⚠ Running (health unknown)${NC}"
                no_healthcheck=$((no_healthcheck+1))
                ;;
            *)
                echo -e "${RED}✗ Unknown status${NC}"
                unhealthy=$((unhealthy+1))
                ;;
        esac
    fi
done <<< "$CONTAINERS"

# Health assessment summary and recommendations
echo ""
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"
echo -e "Total containers: $total"
echo -e "${GREEN}Healthy: $healthy${NC}"
if [ $no_healthcheck -gt 0 ]; then
    echo -e "${CYAN}Running (no healthcheck): $no_healthcheck${NC}"
fi
if [ $unhealthy -gt 0 ]; then
    echo -e "${RED}Unhealthy: $unhealthy${NC}"
fi
echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

if [ $unhealthy -eq 0 ]; then
    echo -e "${GREEN}✓ All services operational${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some services require attention${NC}"
    exit 1
fi