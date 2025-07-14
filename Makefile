# PostgreSQL Backup + S3 Auto Upload Tool
# Simple one-command operations

.PHONY: help setup check backup backup-complete backup-advanced restore s3-test s3-list s3-upload s3-download clean demo

# Default target
help:
	@echo "🚀 PostgreSQL Backup + S3 Auto Upload Tool"
	@echo "==========================================="
	@echo ""
	@echo "📋 Quick Commands:"
	@echo "  make setup               - Setup environment and test connections"
	@echo "  make backup              - Standard backup (with auto S3 upload)"
	@echo "  make backup-complete     - Complete backup (preserves all metadata)"
	@echo "  make backup-advanced     - Advanced backup (recommended)"
	@echo "  make restore FILE=xxx    - Restore from backup file"
	@echo ""
	@echo "☁️  S3 Commands:"
	@echo "  make s3-test             - Test S3 connection"
	@echo "  make s3-list             - List S3 backups"
	@echo "  make s3-upload FILE=xxx  - Upload backup to S3"
	@echo "  make s3-download FILE=xxx - Download backup from S3"
	@echo ""
	@echo "🛠️  Utility:"
	@echo "  make demo                - Show demo and features"
	@echo "  make clean               - Clean Docker containers"
	@echo ""
	@echo "💡 Examples:"
	@echo "  make setup"
	@echo "  make backup-advanced"
	@echo "  make s3-list"
	@echo "  make restore FILE=backup.dump"

# One-command setup with testing
setup:
	@echo "🔧 Setting up PostgreSQL Backup + S3 Tool..."
	@chmod +x *.sh
	@./postgres-tool.sh check
	@./postgres-tool.sh s3-test
	@echo "✅ Setup complete!"

# Standard backup with S3 upload
backup:
	@echo "💾 Starting standard backup..."
	@./postgres-tool.sh backup

# Complete backup with all metadata
backup-complete:
	@echo "💾 Starting complete backup (preserves all metadata)..."
	@./postgres-tool.sh backup-complete

# Advanced backup (recommended)
backup-advanced:
	@echo "💾 Starting advanced backup (recommended)..."
	@./advanced-backup.sh backup

# Restore (requires FILE parameter)
restore:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Error: FILE parameter required"; \
		echo "Usage: make restore FILE=backup_file.dump"; \
		./postgres-tool.sh list; \
		exit 1; \
	fi
	@echo "📥 Restoring from $(FILE)..."
	@./postgres-tool.sh restore $(FILE)

# S3 test connection
s3-test:
	@echo "🔍 Testing S3 connection..."
	@./postgres-tool.sh s3-test

# List S3 backups
s3-list:
	@echo "📋 Listing S3 backups..."
	@./postgres-tool.sh s3-list

# Upload to S3 (requires FILE parameter)
s3-upload:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Error: FILE parameter required"; \
		echo "Usage: make s3-upload FILE=backup_file.dump"; \
		./postgres-tool.sh list; \
		exit 1; \
	fi
	@echo "☁️ Uploading $(FILE) to S3..."
	@./postgres-tool.sh s3-upload $(FILE)

# Download from S3 (requires FILE parameter)
s3-download:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Error: FILE parameter required"; \
		echo "Usage: make s3-download FILE=s3-key"; \
		./postgres-tool.sh s3-list; \
		exit 1; \
	fi
	@echo "📥 Downloading $(FILE) from S3..."
	@./postgres-tool.sh s3-download $(FILE)

# Show demo
demo:
	@./s3-demo.sh

# Clean environment
clean:
	@echo "🧹 Cleaning Docker environment..."
	@docker compose down -v 2>/dev/null || true
	@docker system prune -f
	@echo "✅ Cleanup complete!"
