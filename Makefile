# Makefile for AWS PostgreSQL Backup/Restore Tool

.PHONY: help setup check backup restore list clean

# Detect Docker Compose command
DOCKER_COMPOSE_CMD := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo ""; fi)

# Default target
help:
	@echo "AWS PostgreSQL Backup/Restore Tool"
	@echo "=================================="
	@echo ""
	@echo "Available commands:"
	@echo "  setup        - Setup the environment (create .env, make scripts executable)"
	@echo "  check        - Check database connections"
	@echo "  backup       - Backup database (requires MODE=backup in .env)"
	@echo "  restore      - Restore database (requires backup file and MODE=restore)"
	@echo "  list         - List available backup files"
	@echo "  clean        - Clean Docker containers and volumes"
	@echo ""
	@echo "Examples:"
	@echo "  make setup"
	@echo "  make check"
	@echo "  make backup"
	@echo "  make restore FILE=backup_file.dump"

# Setup environment
setup:
	@./setup.sh

# Check database connections
check:
	@./postgres-tool.sh check

# Backup database
backup:
	@./postgres-tool.sh backup

# Restore database (requires FILE parameter)
restore:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE parameter is required"; \
		echo "Usage: make restore FILE=backup_file.dump"; \
		exit 1; \
	fi
	@./postgres-tool.sh restore $(FILE)

# List backup files
list:
	@./postgres-tool.sh list

# Clean Docker containers and volumes
clean:
	@if [ -z "$(DOCKER_COMPOSE_CMD)" ]; then \
		echo "Error: Docker Compose not found. Please install Docker Compose."; \
		exit 1; \
	fi
	@echo "Cleaning Docker containers and volumes using: $(DOCKER_COMPOSE_CMD)"
	@$(DOCKER_COMPOSE_CMD) down -v
	@docker system prune -f
