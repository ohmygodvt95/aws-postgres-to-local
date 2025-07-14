#!/bin/bash

# Advanced PostgreSQL Backup Script
# This script performs a comprehensive backup that preserves all database objects

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load environment variables
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found.${NC}"
    exit 1
fi
source "$ENV_FILE"

# Print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Advanced backup function
advanced_backup() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_prefix="${BACKUP_PREFIX:-postgres_backup}"
    
    print_info "Starting advanced backup process..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Start postgres client container
    docker compose up -d postgres-client
    sleep 2
    
    # 1. Backup globals (roles, tablespaces)
    print_info "Step 1/4: Backing up global objects (roles, tablespaces)..."
    docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client \
        pg_dumpall \
        -h "$SOURCE_DB_HOST" \
        -p "$SOURCE_DB_PORT" \
        -U "$SOURCE_DB_USER" \
        --globals-only \
        --verbose \
        -f "/backup/${backup_prefix}_${timestamp}_globals.sql"
    
    # 2. Backup schema only (structure, extensions, functions)
    print_info "Step 2/4: Backing up database schema (structure, extensions, functions)..."
    docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client \
        pg_dump \
        -h "$SOURCE_DB_HOST" \
        -p "$SOURCE_DB_PORT" \
        -U "$SOURCE_DB_USER" \
        -d "$SOURCE_DB_NAME" \
        --schema-only \
        --verbose \
        --create \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        --format=custom \
        --compress=6 \
        -f "/backup/${backup_prefix}_${timestamp}_schema.dump"
    
    # 3. Backup data only (preserving data types)
    print_info "Step 3/4: Backing up data with preserved types..."
    docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client \
        pg_dump \
        -h "$SOURCE_DB_HOST" \
        -p "$SOURCE_DB_PORT" \
        -U "$SOURCE_DB_USER" \
        -d "$SOURCE_DB_NAME" \
        --data-only \
        --verbose \
        --disable-triggers \
        --format=custom \
        --compress=6 \
        -f "/backup/${backup_prefix}_${timestamp}_data.dump"
    
    # 4. Complete backup (as fallback)
    print_info "Step 4/4: Creating complete backup (fallback)..."
    docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client \
        pg_dump \
        -h "$SOURCE_DB_HOST" \
        -p "$SOURCE_DB_PORT" \
        -U "$SOURCE_DB_USER" \
        -d "$SOURCE_DB_NAME" \
        --verbose \
        --create \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        --blobs \
        --format=custom \
        --compress=6 \
        -f "/backup/${backup_prefix}_${timestamp}_complete.dump"
    
    print_success "Advanced backup completed successfully!"
    print_success "Files created:"
    print_success "  • ${backup_prefix}_${timestamp}_globals.sql (roles, tablespaces)"
    print_success "  • ${backup_prefix}_${timestamp}_schema.dump (structure, extensions, functions)"
    print_success "  • ${backup_prefix}_${timestamp}_data.dump (data with preserved types)"
    print_success "  • ${backup_prefix}_${timestamp}_complete.dump (complete backup)"
    
    print_info "To restore:"
    print_info "1. First restore globals: psql -f ${backup_prefix}_${timestamp}_globals.sql"
    print_info "2. Then restore schema: pg_restore ${backup_prefix}_${timestamp}_schema.dump"
    print_info "3. Finally restore data: pg_restore ${backup_prefix}_${timestamp}_data.dump"
    print_info "Or use complete backup: pg_restore ${backup_prefix}_${timestamp}_complete.dump"
}

# Advanced restore function
advanced_restore() {
    local backup_timestamp="$1"
    local backup_prefix="${BACKUP_PREFIX:-postgres_backup}"
    
    if [[ -z "$backup_timestamp" ]]; then
        print_error "Please provide backup timestamp (e.g., 20250714_143022)"
        exit 1
    fi
    
    print_info "Starting advanced restore process for timestamp: $backup_timestamp"
    
    # Start postgres client container
    docker compose up -d postgres-client
    sleep 2
    
    # Check if files exist
    local globals_file="${backup_prefix}_${backup_timestamp}_globals.sql"
    local schema_file="${backup_prefix}_${backup_timestamp}_schema.dump"
    local data_file="${backup_prefix}_${backup_timestamp}_data.dump"
    local complete_file="${backup_prefix}_${backup_timestamp}_complete.dump"
    
    if [[ -f "$BACKUP_DIR/$complete_file" ]]; then
        print_info "Using complete backup file..."
        docker exec -e PGPASSWORD="$TARGET_DB_PASSWORD" postgres-client \
            pg_restore \
            -h "$TARGET_DB_HOST" \
            -p "$TARGET_DB_PORT" \
            -U "$TARGET_DB_USER" \
            -d "$TARGET_DB_NAME" \
            --verbose \
            --clean \
            --if-exists \
            --create \
            --exit-on-error \
            "/backup/$complete_file"
    else
        # Step by step restore
        if [[ -f "$BACKUP_DIR/$globals_file" ]]; then
            print_info "Step 1/3: Restoring global objects..."
            docker exec -e PGPASSWORD="$TARGET_DB_PASSWORD" postgres-client \
                psql \
                -h "$TARGET_DB_HOST" \
                -p "$TARGET_DB_PORT" \
                -U "$TARGET_DB_USER" \
                -d postgres \
                -f "/backup/$globals_file"
        fi
        
        if [[ -f "$BACKUP_DIR/$schema_file" ]]; then
            print_info "Step 2/3: Restoring schema..."
            docker exec -e PGPASSWORD="$TARGET_DB_PASSWORD" postgres-client \
                pg_restore \
                -h "$TARGET_DB_HOST" \
                -p "$TARGET_DB_PORT" \
                -U "$TARGET_DB_USER" \
                -d "$TARGET_DB_NAME" \
                --verbose \
                --clean \
                --if-exists \
                --create \
                --exit-on-error \
                "/backup/$schema_file"
        fi
        
        if [[ -f "$BACKUP_DIR/$data_file" ]]; then
            print_info "Step 3/3: Restoring data..."
            docker exec -e PGPASSWORD="$TARGET_DB_PASSWORD" postgres-client \
                pg_restore \
                -h "$TARGET_DB_HOST" \
                -p "$TARGET_DB_PORT" \
                -U "$TARGET_DB_USER" \
                -d "$TARGET_DB_NAME" \
                --verbose \
                --disable-triggers \
                --exit-on-error \
                "/backup/$data_file"
        fi
    fi
    
    print_success "Advanced restore completed successfully!"
}

# Show usage
show_usage() {
    echo "Advanced PostgreSQL Backup/Restore Tool"
    echo
    echo "This tool creates comprehensive backups that preserve:"
    echo "  • All data types (dates, UUIDs, etc.)"
    echo "  • All extensions (uuid-ossp, etc.)"
    echo "  • All functions (gen_random_uuid(), etc.)"
    echo "  • All constraints and relationships"
    echo "  • All indexes and triggers"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  backup                   Perform advanced backup"
    echo "  restore <timestamp>      Restore from advanced backup"
    echo
    echo "Examples:"
    echo "  $0 backup"
    echo "  $0 restore 20250714_143022"
}

# Main function
case "${1:-}" in
    "backup")
        if [[ "$MODE" != "backup" ]]; then
            print_error "Environment is not configured for backup mode. Please set MODE=backup in .env"
            exit 1
        fi
        advanced_backup
        ;;
    "restore")
        if [[ "$MODE" != "restore" ]]; then
            print_error "Environment is not configured for restore mode. Please set MODE=restore in .env"
            exit 1
        fi
        advanced_restore "${2:-}"
        ;;
    "help"|"-h"|"--help"|"")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac
