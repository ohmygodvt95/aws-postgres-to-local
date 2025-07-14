#!/bin/bash

# PostgreSQL Backup/Restore Tool
# Author: AWS PostgreSQL to Local Tool
# Description: Tool for backing up and restoring PostgreSQL databases

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
BACKUP_DIR="${SCRIPT_DIR}/backup"
DOCKER_COMPOSE_CMD=""

# Load environment variables
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Error: .env file not found. Please copy .env.example to .env and configure it.${NC}"
        exit 1
    fi
    
    # shellcheck source=.env
    source "$ENV_FILE"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
}

# Print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_message "$GREEN" "✓ $1"
}

print_error() {
    print_message "$RED" "✗ $1"
}

print_warning() {
    print_message "$YELLOW" "⚠ $1"
}

print_info() {
    print_message "$BLUE" "ℹ $1"
}

# Validate environment configuration
validate_env() {
    if [[ -z "${MODE:-}" ]]; then
        print_error "MODE is not set in .env file. Please set MODE=backup or MODE=restore"
        exit 1
    fi
    
    if [[ "$MODE" != "backup" && "$MODE" != "restore" ]]; then
        print_error "Invalid MODE: $MODE. Must be 'backup' or 'restore'"
        exit 1
    fi
    
    print_info "Running in $MODE mode"
}

# Detect Docker Compose command
get_docker_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        print_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
    
    # Set Docker Compose command
    DOCKER_COMPOSE_CMD=$(get_docker_compose_cmd)
    print_success "Using Docker Compose command: $DOCKER_COMPOSE_CMD"
}

# Start PostgreSQL client container if not running
start_client_container() {
    if ! docker ps | grep -q postgres-client; then
        print_info "Starting PostgreSQL client container..."
        $DOCKER_COMPOSE_CMD up -d postgres-client
        sleep 2
    fi
    print_success "PostgreSQL client container is ready"
}

# Test database connection
test_connection() {
    local host=$1
    local port=$2
    local database=$3
    local username=$4
    local password=$5
    local connection_name=$6
    
    print_info "Testing connection to $connection_name..."
    
    if docker exec -e PGPASSWORD="$password" postgres-client psql -h "$host" -p "$port" -U "$username" -d "$database" -c "SELECT 1;" >/dev/null 2>&1; then
        print_success "Connection to $connection_name successful"
        return 0
    else
        print_error "Connection to $connection_name failed"
        return 1
    fi
}

# Check database connections
check_connections() {
    validate_env
    check_docker
    start_client_container
    
    local success=true
    
    if [[ "$MODE" == "backup" ]]; then
        if ! test_connection "$SOURCE_DB_HOST" "$SOURCE_DB_PORT" "$SOURCE_DB_NAME" "$SOURCE_DB_USER" "$SOURCE_DB_PASSWORD" "Source Database (AWS)"; then
            success=false
        fi
    elif [[ "$MODE" == "restore" ]]; then
        if ! test_connection "$TARGET_DB_HOST" "$TARGET_DB_PORT" "$TARGET_DB_NAME" "$TARGET_DB_USER" "$TARGET_DB_PASSWORD" "Target Database"; then
            success=false
        fi
    fi
    
    if [[ "$success" == true ]]; then
        print_success "All database connections are working"
    else
        print_error "Some database connections failed"
        exit 1
    fi
}

# Generate backup filename
generate_backup_filename() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local prefix="${BACKUP_PREFIX:-postgres_backup}"
    
    if [[ "${USE_CUSTOM_FORMAT:-true}" == "true" ]]; then
        # Use directory format for parallel jobs
        if [[ "${PARALLEL_JOBS:-1}" -gt 1 ]]; then
            echo "${prefix}_${timestamp}_dir"
        else
            echo "${prefix}_${timestamp}.dump"
        fi
    else
        echo "${prefix}_${timestamp}.sql"
    fi
}

# Backup database
backup_database() {
    validate_env
    
    if [[ "$MODE" != "backup" ]]; then
        print_error "Environment is not configured for backup mode. Please set MODE=backup in .env"
        exit 1
    fi
    
    check_docker
    start_client_container
    
    # Test source connection
    if ! test_connection "$SOURCE_DB_HOST" "$SOURCE_DB_PORT" "$SOURCE_DB_NAME" "$SOURCE_DB_USER" "$SOURCE_DB_PASSWORD" "Source Database (AWS)"; then
        exit 1
    fi
    
    local backup_file
    backup_file=$(generate_backup_filename)
    local backup_path="/backup/$backup_file"
    
    print_info "Starting backup of database: $SOURCE_DB_NAME"
    print_info "Backup file: $backup_file"
    
    export PGPASSWORD="$SOURCE_DB_PASSWORD"
    
    local pg_dump_cmd="pg_dump"
    local pg_dump_args=()
    
    # Connection parameters
    pg_dump_args+=("-h" "$SOURCE_DB_HOST")
    pg_dump_args+=("-p" "$SOURCE_DB_PORT")
    pg_dump_args+=("-U" "$SOURCE_DB_USER")
    pg_dump_args+=("-d" "$SOURCE_DB_NAME")
    
    # Output file
    pg_dump_args+=("-f" "$backup_path")
    
    # Backup options for preserving structure and data
    pg_dump_args+=("--verbose")
    pg_dump_args+=("--no-password")
    pg_dump_args+=("--create")
    pg_dump_args+=("--clean")
    pg_dump_args+=("--if-exists")
    
    # Include all database objects and preserve data types
    pg_dump_args+=("--no-owner")
    pg_dump_args+=("--no-privileges")
    
    # Include extensions, functions, and all database objects
    pg_dump_args+=("--schema=public")
    pg_dump_args+=("--blobs")
    
    # Use custom format for large databases
    if [[ "${USE_CUSTOM_FORMAT:-true}" == "true" ]]; then
        # Use parallel jobs for directory format (required for parallel backup)
        if [[ "${PARALLEL_JOBS:-1}" -gt 1 ]]; then
            pg_dump_args+=("--format=directory")
            pg_dump_args+=("--jobs=${PARALLEL_JOBS}")
            # Change backup path to directory for directory format
            backup_path="/backup/${backup_file%.*}"
            # Update the -f argument to point to directory
            for i in "${!pg_dump_args[@]}"; do
                if [[ "${pg_dump_args[$i]}" == "-f" ]]; then
                    pg_dump_args[$((i+1))]="$backup_path"
                    break
                fi
            done
        else
            pg_dump_args+=("--format=custom")
            pg_dump_args+=("--compress=${COMPRESSION_LEVEL:-6}")
        fi
    else
        pg_dump_args+=("--format=plain")
    fi
    
    print_info "Running: $pg_dump_cmd ${pg_dump_args[*]}"
    
    if docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client "$pg_dump_cmd" "${pg_dump_args[@]}"; then
        local file_info
        # Check if it's a directory or file
        if [[ "${PARALLEL_JOBS:-1}" -gt 1 && "${USE_CUSTOM_FORMAT:-true}" == "true" ]]; then
            file_info=$(docker exec postgres-client du -sh "$backup_path" | awk '{print $1}')
            print_success "Backup completed successfully!"
            print_success "Directory: $backup_file (Size: $file_info)"
            print_info "Backup saved to: $BACKUP_DIR/$backup_file"
        else
            file_info=$(docker exec postgres-client ls -lh "$backup_path" | awk '{print $5}')
            print_success "Backup completed successfully!"
            print_success "File: $backup_file (Size: $file_info)"
            print_info "Backup saved to: $BACKUP_DIR/$backup_file"
        fi
    else
        print_error "Backup failed!"
        exit 1
    fi
}

# Complete backup with all database objects and metadata
backup_database_complete() {
    validate_env
    
    if [[ "$MODE" != "backup" ]]; then
        print_error "Environment is not configured for backup mode. Please set MODE=backup in .env"
        exit 1
    fi
    
    check_docker
    start_client_container
    
    # Test source connection
    if ! test_connection "$SOURCE_DB_HOST" "$SOURCE_DB_PORT" "$SOURCE_DB_NAME" "$SOURCE_DB_USER" "$SOURCE_DB_PASSWORD" "Source Database (AWS)"; then
        exit 1
    fi
    
    local backup_file
    backup_file=$(generate_backup_filename)
    local backup_path="/backup/$backup_file"
    
    print_info "Starting COMPLETE backup of database: $SOURCE_DB_NAME"
    print_info "This backup will preserve all data types, extensions, constraints, and relationships"
    print_info "Backup file: $backup_file"
    
    export PGPASSWORD="$SOURCE_DB_PASSWORD"
    
    local pg_dump_cmd="pg_dump"
    local pg_dump_args=()
    
    # Connection parameters
    pg_dump_args+=("-h" "$SOURCE_DB_HOST")
    pg_dump_args+=("-p" "$SOURCE_DB_PORT")
    pg_dump_args+=("-U" "$SOURCE_DB_USER")
    pg_dump_args+=("-d" "$SOURCE_DB_NAME")
    
    # Output file
    pg_dump_args+=("-f" "$backup_path")
    
    # Complete backup options for preserving ALL database objects
    pg_dump_args+=("--verbose")
    pg_dump_args+=("--no-password")
    pg_dump_args+=("--create")
    pg_dump_args+=("--clean")
    pg_dump_args+=("--if-exists")
    
    # Preserve ownership and privileges (comment out if you want to skip)
    # pg_dump_args+=("--no-owner")
    # pg_dump_args+=("--no-privileges")
    
    # Include ALL database objects
    pg_dump_args+=("--blobs")                    # Include large objects
    pg_dump_args+=("--inserts")                 # Use INSERT statements (preserves data types)
    pg_dump_args+=("--column-inserts")          # Use column names in INSERT statements
    pg_dump_args+=("--disable-triggers")        # Disable triggers during restore
    
    # Force custom format to preserve everything properly
    if [[ "${PARALLEL_JOBS:-1}" -gt 1 ]]; then
        pg_dump_args+=("--format=directory")
        pg_dump_args+=("--jobs=${PARALLEL_JOBS}")
        # Change backup path to directory for directory format
        backup_path="/backup/${backup_file%.*}"
        # Update the -f argument to point to directory
        for i in "${!pg_dump_args[@]}"; do
            if [[ "${pg_dump_args[$i]}" == "-f" ]]; then
                pg_dump_args[$((i+1))]="$backup_path"
                break
            fi
        done
    else
        pg_dump_args+=("--format=custom")
        pg_dump_args+=("--compress=${COMPRESSION_LEVEL:-6}")
    fi
    
    print_info "Running COMPLETE backup: $pg_dump_cmd ${pg_dump_args[*]}"
    
    if docker exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" postgres-client "$pg_dump_cmd" "${pg_dump_args[@]}"; then
        local file_info
        # Check if it's a directory or file
        if [[ "${PARALLEL_JOBS:-1}" -gt 1 ]]; then
            file_info=$(docker exec postgres-client du -sh "$backup_path" | awk '{print $1}')
            print_success "COMPLETE backup completed successfully!"
            print_success "Directory: $backup_file (Size: $file_info)"
            print_info "Backup saved to: $BACKUP_DIR/$backup_file"
        else
            file_info=$(docker exec postgres-client ls -lh "$backup_path" | awk '{print $5}')
            print_success "COMPLETE backup completed successfully!"
            print_success "File: $backup_file (Size: $file_info)"
            print_info "Backup saved to: $BACKUP_DIR/$backup_file"
        fi
        
        print_success "This backup preserves:"
        print_success "  ✓ All data types (including dates, UUID, etc.)"
        print_success "  ✓ All constraints and relationships"
        print_success "  ✓ All indexes and triggers"
        print_success "  ✓ All extensions (including uuid-ossp)"
        print_success "  ✓ All functions (including gen_random_uuid())"
        
    else
        print_error "COMPLETE backup failed!"
        exit 1
    fi
}

# List available backup files
list_backups() {
    print_info "Available backup files:"
    if [[ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        ls -lh "$BACKUP_DIR"
    else
        print_warning "No backup files found in $BACKUP_DIR"
    fi
}

# Restore database
restore_database() {
    validate_env
    
    if [[ "$MODE" != "restore" ]]; then
        print_error "Environment is not configured for restore mode. Please set MODE=restore in .env"
        exit 1
    fi
    
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        print_error "Backup file not specified"
        list_backups
        echo
        print_info "Usage: $0 restore <backup_file>"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_file"
    
    # Check if backup is a directory or file
    if [[ -d "$backup_path" ]]; then
        print_info "Backup is a directory (parallel backup format)"
    elif [[ -f "$backup_path" ]]; then
        print_info "Backup is a file"
    else
        print_error "Backup file/directory not found: $backup_path"
        list_backups
        exit 1
    fi
    
    check_docker
    start_client_container
    
    # Test target connection
    if ! test_connection "$TARGET_DB_HOST" "$TARGET_DB_PORT" "$TARGET_DB_NAME" "$TARGET_DB_USER" "$TARGET_DB_PASSWORD" "Target Database"; then
        exit 1
    fi
    
    print_info "Starting restore of database: $TARGET_DB_NAME"
    print_info "From backup file: $backup_file"
    
    export PGPASSWORD="$TARGET_DB_PASSWORD"
    
    local pg_restore_cmd
    local restore_args=()
    
    # Determine file format and use appropriate tool
    if [[ "$backup_file" == *.dump ]] || [[ -d "$backup_path" ]]; then
        pg_restore_cmd="pg_restore"
        
        # Connection parameters
        restore_args+=("-h" "$TARGET_DB_HOST")
        restore_args+=("-p" "$TARGET_DB_PORT")
        restore_args+=("-U" "$TARGET_DB_USER")
        restore_args+=("-d" "$TARGET_DB_NAME")
        
        # Restore options
        restore_args+=("--verbose")
        restore_args+=("--no-password")
        restore_args+=("--clean")
        restore_args+=("--if-exists")
        restore_args+=("--create")
        restore_args+=("--exit-on-error")
        
        # Use parallel jobs for directory format
        if [[ -d "$backup_path" && "${PARALLEL_JOBS:-1}" -gt 1 ]]; then
            restore_args+=("--jobs=${PARALLEL_JOBS}")
        fi
        
        restore_args+=("/backup/$backup_file")
        
    else
        # Plain SQL file
        pg_restore_cmd="psql"
        
        # Connection parameters
        restore_args+=("-h" "$TARGET_DB_HOST")
        restore_args+=("-p" "$TARGET_DB_PORT")
        restore_args+=("-U" "$TARGET_DB_USER")
        restore_args+=("-d" "$TARGET_DB_NAME")
        
        # Restore options
        restore_args+=("-v" "ON_ERROR_STOP=1")
        restore_args+=("-f" "/backup/$backup_file")
    fi
    
    print_info "Running: $pg_restore_cmd ${restore_args[*]}"
    
    if docker exec -e PGPASSWORD="$TARGET_DB_PASSWORD" postgres-client "$pg_restore_cmd" "${restore_args[@]}"; then
        print_success "Restore completed successfully!"
        print_success "Database $TARGET_DB_NAME has been restored from $backup_file"
    else
        print_error "Restore failed!"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "AWS PostgreSQL Backup/Restore Tool"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  check                    Check database connections"
    echo "  backup                   Backup database (requires MODE=backup in .env)"
    echo "  backup-complete          Complete backup preserving all metadata, extensions, and data types"
    echo "  restore <backup_file>    Restore database from backup file (requires MODE=restore in .env)"
    echo "  list                     List available backup files"
    echo
    echo "Examples:"
    echo "  $0 check"
    echo "  $0 backup"
    echo "  $0 backup-complete"
    echo "  $0 restore postgres_backup_20250714_143022.dump"
    echo "  $0 list"
    echo
    echo "Configuration:"
    echo "  Copy .env.example to .env and configure database connections"
    echo "  Set MODE=backup for backup operations"
    echo "  Set MODE=restore for restore operations"
}

# Main function
main() {
    case "${1:-}" in
        "check")
            load_env
            check_connections
            ;;
        "backup")
            load_env
            backup_database
            ;;
        "backup-complete")
            load_env
            backup_database_complete
            ;;
        "restore")
            load_env
            restore_database "${2:-}"
            ;;
        "list")
            list_backups
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
}

# Run main function with all arguments
main "$@"
