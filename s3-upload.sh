#!/bin/bash

# S3 Upload Script for PostgreSQL Backups
# Compresses and uploads backup files/folders to S3

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

# shellcheck source=.env
source "$ENV_FILE"

# Print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if AWS CLI container is running
start_aws_cli() {
    if ! docker ps | grep -q aws-cli; then
        print_info "Starting AWS CLI container..."
        docker compose up -d aws-cli
        sleep 2
    fi
    print_success "AWS CLI container is ready"
}

# Test S3 connection
test_s3_connection() {
    print_info "Testing S3 connection..."
    
    if docker exec -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                  -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
                  aws-cli aws s3 ls "s3://$AWS_BUCKET" >/dev/null 2>&1; then
        print_success "S3 connection successful"
        return 0
    else
        print_error "S3 connection failed"
        print_error "Please check your AWS credentials and bucket name"
        return 1
    fi
}

# Compress backup file or directory
compress_backup() {
    local backup_name="$1"
    local compressed_file="${backup_name}.tar.gz"
    
    print_info "Compressing backup: $backup_name"
    
    if [[ -d "$BACKUP_DIR/$backup_name" ]]; then
        # It's a directory (parallel backup)
        print_info "Compressing directory: $backup_name"
        if docker exec postgres-client tar -czf "/backup/$compressed_file" -C "/backup" "$backup_name" >/dev/null 2>&1; then
            print_success "Directory compressed to: $compressed_file"
            echo "$compressed_file"
            return 0
        else
            print_error "Failed to compress directory"
            return 1
        fi
    elif [[ -f "$BACKUP_DIR/$backup_name" ]]; then
        # It's a file
        print_info "Compressing file: $backup_name"
        if docker exec postgres-client tar -czf "/backup/$compressed_file" -C "/backup" "$backup_name" >/dev/null 2>&1; then
            print_success "File compressed to: $compressed_file"
            echo "$compressed_file"
            return 0
        else
            print_error "Failed to compress file"
            return 1
        fi
    else
        print_error "Backup not found: $BACKUP_DIR/$backup_name"
        return 1
    fi
}

# Upload to S3
upload_to_s3() {
    local file_to_upload="$1"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local s3_key="${S3_BACKUP_PREFIX:-postgres-backups}/${timestamp}_${file_to_upload}"
    local local_path="/backup/$file_to_upload"
    
    print_info "Uploading to S3: s3://$AWS_BUCKET/$s3_key"
    
    if docker exec -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                  -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
                  aws-cli aws s3 cp "$local_path" "s3://$AWS_BUCKET/$s3_key" \
                  --storage-class STANDARD_IA; then
        print_success "Upload successful: s3://$AWS_BUCKET/$s3_key"
        
        # Get file size
        local file_size
        file_size=$(docker exec aws-cli ls -lh "$local_path" | awk '{print $5}')
        print_success "File size: $file_size"
        
        return 0
    else
        print_error "Upload failed"
        return 1
    fi
}

# Upload multiple files (for advanced backup)
upload_advanced_backup() {
    local backup_timestamp="$1"
    local backup_prefix="${BACKUP_PREFIX:-postgres_backup}"
    
    print_info "Uploading advanced backup set for timestamp: $backup_timestamp"
    
    # Create a combined archive with all backup files
    local combined_name="${backup_prefix}_${backup_timestamp}_complete_set.tar.gz"
    local files_to_compress=""
    
    # Find all files for this timestamp
    for file_type in "globals.sql" "schema.dump" "data.dump" "complete.dump"; do
        local file_name="${backup_prefix}_${backup_timestamp}_${file_type}"
        if [[ -f "$BACKUP_DIR/$file_name" ]]; then
            files_to_compress="$files_to_compress $file_name"
        fi
    done
    
    if [[ -n "$files_to_compress" ]]; then
        print_info "Creating combined archive with files:$files_to_compress"
        
        if docker exec postgres-client tar -czf "/backup/$combined_name" -C "/backup" $files_to_compress; then
            print_success "Combined archive created: $combined_name"
            
            # Upload combined archive
            if upload_to_s3 "$combined_name"; then
                print_success "Advanced backup set uploaded successfully"
                
                # Optionally delete local files
                if [[ "${DELETE_LOCAL_AFTER_UPLOAD:-false}" == "true" ]]; then
                    print_info "Cleaning up local files..."
                    for file_name in $files_to_compress; do
                        rm -f "$BACKUP_DIR/$file_name"
                        print_info "Deleted: $file_name"
                    done
                    rm -f "$BACKUP_DIR/$combined_name"
                    print_info "Deleted: $combined_name"
                    print_success "Local cleanup completed"
                fi
                
                return 0
            else
                return 1
            fi
        else
            print_error "Failed to create combined archive"
            return 1
        fi
    else
        print_error "No backup files found for timestamp: $backup_timestamp"
        return 1
    fi
}

# Upload single backup file
upload_single_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        print_error "Backup file not specified"
        return 1
    fi
    
    # Check if backup file exists
    if [[ ! -f "$BACKUP_DIR/$backup_file" ]] && [[ ! -d "$BACKUP_DIR/$backup_file" ]]; then
        print_error "Backup file not found: $BACKUP_DIR/$backup_file"
        return 1
    fi
    
    print_info "Uploading single backup: $backup_file"
    
    # Create compressed filename
    local compressed_file="${backup_file}.tar.gz"
    
    # Compress the backup
    print_info "Compressing backup: $backup_file"
    if [[ -d "$BACKUP_DIR/$backup_file" ]]; then
        # It's a directory
        print_info "Compressing directory: $backup_file"
        if docker exec postgres-client tar -czf "/backup/$compressed_file" -C "/backup" "$backup_file"; then
            print_success "Directory compressed to: $compressed_file"
        else
            print_error "Failed to compress directory"
            return 1
        fi
    elif [[ -f "$BACKUP_DIR/$backup_file" ]]; then
        # It's a file
        print_info "Compressing file: $backup_file"
        if docker exec postgres-client tar -czf "/backup/$compressed_file" -C "/backup" "$backup_file"; then
            print_success "File compressed to: $compressed_file"
        else
            print_error "Failed to compress file"
            return 1
        fi
    fi
    
    # Verify compressed file exists
    if [[ ! -f "$BACKUP_DIR/$compressed_file" ]]; then
        print_error "Compressed file not found: $BACKUP_DIR/$compressed_file"
        return 1
    fi
    
    # Upload to S3
    if upload_to_s3 "$compressed_file"; then
        print_success "Single backup uploaded successfully"
        
        # Optionally delete local files
        if [[ "${DELETE_LOCAL_AFTER_UPLOAD:-false}" == "true" ]]; then
            print_info "Cleaning up local files..."
            rm -f "$BACKUP_DIR/$backup_file"
            rm -f "$BACKUP_DIR/$compressed_file"
            print_success "Local cleanup completed"
        fi
        
        return 0
    else
        return 1
    fi
}

# List S3 backups
list_s3_backups() {
    print_info "Listing S3 backups in bucket: $AWS_BUCKET"
    
    start_aws_cli
    
    if test_s3_connection; then
        print_info "S3 backups in s3://$AWS_BUCKET/${S3_BACKUP_PREFIX:-postgres-backups}/"
        
        docker exec -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                   -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                   -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
                   aws-cli aws s3 ls "s3://$AWS_BUCKET/${S3_BACKUP_PREFIX:-postgres-backups}/" \
                   --human-readable --summarize
    else
        exit 1
    fi
}

# Download backup from S3
download_from_s3() {
    local s3_key="$1"
    
    if [[ -z "$s3_key" ]]; then
        print_error "S3 key not specified"
        print_info "Usage: $0 download <s3_key>"
        list_s3_backups
        return 1
    fi
    
    print_info "Downloading from S3: s3://$AWS_BUCKET/$s3_key"
    
    start_aws_cli
    
    if test_s3_connection; then
        local local_file="${s3_key##*/}"  # Get filename from S3 key
        
        if docker exec -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                      -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                      -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
                      aws-cli aws s3 cp "s3://$AWS_BUCKET/$s3_key" "/backup/$local_file"; then
            print_success "Download successful: $local_file"
            
            # Extract if it's a compressed file
            if [[ "$local_file" == *.tar.gz ]]; then
                print_info "Extracting compressed backup..."
                if docker exec postgres-client tar -xzf "/backup/$local_file" -C "/backup"; then
                    print_success "Extraction completed"
                else
                    print_warning "Failed to extract, but file downloaded successfully"
                fi
            fi
        else
            print_error "Download failed"
            return 1
        fi
    else
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "PostgreSQL S3 Backup Upload Tool"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  test                     Test S3 connection"
    echo "  upload <backup_file>     Upload single backup file to S3"
    echo "  upload-advanced <timestamp>  Upload advanced backup set to S3"
    echo "  list                     List S3 backups"
    echo "  download <s3_key>        Download backup from S3"
    echo
    echo "Examples:"
    echo "  $0 test"
    echo "  $0 upload postgres_backup_20250714_143022.dump"
    echo "  $0 upload-advanced 20250714_143022"
    echo "  $0 list"
    echo "  $0 download postgres-backups/20250714_143022_backup.tar.gz"
    echo
    echo "Configuration:"
    echo "  Configure AWS credentials in .env file"
    echo "  Set AUTO_UPLOAD_S3=true for automatic upload after backup"
}

# Main function
case "${1:-}" in
    "test")
        start_aws_cli
        test_s3_connection
        ;;
    "upload")
        start_aws_cli
        if test_s3_connection; then
            upload_single_backup "${2:-}"
        fi
        ;;
    "upload-advanced")
        start_aws_cli
        if test_s3_connection; then
            upload_advanced_backup "${2:-}"
        fi
        ;;
    "list")
        list_s3_backups
        ;;
    "download")
        download_from_s3 "${2:-}"
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
