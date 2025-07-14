#!/bin/bash

# Setup script for AWS PostgreSQL Backup/Restore Tool

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "AWS PostgreSQL Backup/Restore Tool - Setup"
echo "=========================================="
echo

# Check if .env exists
if [[ ! -f ".env" ]]; then
    print_info "Creating .env file from .env.example..."
    cp .env.example .env
    print_success ".env file created"
    print_warning "Please edit .env file to configure your database connections"
else
    print_info ".env file already exists"
fi

# Check if Docker is installed
if command -v docker >/dev/null 2>&1; then
    print_success "Docker is installed"
else
    print_warning "Docker is not installed. Please install Docker first."
    echo "Installation guide: https://docs.docker.com/get-docker/"
fi

# Check if Docker Compose is available
if docker compose version >/dev/null 2>&1; then
    print_success "Docker Compose v2 is available (docker compose)"
elif command -v docker-compose >/dev/null 2>&1; then
    print_success "Docker Compose v1 is available (docker-compose)"
else
    print_warning "Docker Compose is not available. Please install Docker Compose."
fi

# Make script executable
chmod +x postgres-tool.sh
print_success "Made postgres-tool.sh executable"

# Create backup directory
mkdir -p backup
print_success "Backup directory created"

echo
print_info "Setup completed! Next steps:"
echo "1. Edit .env file with your database configurations"
echo "2. Set MODE=backup or MODE=restore in .env"
echo "3. Run './postgres-tool.sh check' to test connections"
echo "4. Use './postgres-tool.sh backup' or './postgres-tool.sh restore <file>'"
