# 🚀 PostgreSQL Backup + S3 Auto Upload Tool

**A complete solution for PostgreSQL backup with automatic upload to S3**

## ❌ Problems Solved:

* Date fields converted to TEXT instead of DATE/TIMESTAMP
* Loss of `gen_random_uuid()` function and `uuid-ossp` extensions
* Loss of constraints, relationships, and indexes
* Backup files stored only locally, no cloud backup

## ✅ Key Features

### 🛡️ **Complete Database Backup**

* ✅ Preserve all data types (DATE, TIMESTAMP, UUID, etc.)
* ✅ Includes all extensions (uuid-ossp, etc.)
* ✅ Preserves functions (gen\_random\_uuid(), etc.)
* ✅ Preserves constraints, relationships, indexes
* ✅ Backup globals (roles, tablespaces)

### ☁️ **S3 Integration**

* ✅ Automatically compress backup files (.tar.gz)
* ✅ Automatically upload to S3 after backup
* ✅ Manage backups in the cloud
* ✅ Download and restore from S3
* ✅ Organized backup structure

### 🎯 **Multiple Backup Strategies**

* **Standard**: Basic backup in custom format
* **Complete**: Backup with all metadata
* **Advanced**: Separate backup (globals + schema + data + complete)

## 🚀 Quick Start (Just 1 Command!)

```bash
# Clone repository
git clone <repository-url>
cd aws-postgres-to-local

# Complete setup with just 1 command
make setup

# Advanced backup (recommended)
make backup-advanced

# View S3 backups
make s3-list
```

## 🔧 Configuration

### 1. Database Settings (Required)

Edit the `.env` file:

```bash
# Operation Mode
MODE=backup                    # or restore

# Source Database (for backup)
SOURCE_DB_HOST=your_aws_host
SOURCE_DB_PORT=5432
SOURCE_DB_NAME=your_database
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_password

# Target Database (for restore)
TARGET_DB_HOST=localhost
TARGET_DB_PORT=5432
TARGET_DB_NAME=your_target_db
TARGET_DB_USER=postgres
TARGET_DB_PASSWORD=your_password
```

### 2. AWS S3 Settings (Required)

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=ap-southeast-1
AWS_BUCKET=your-bucket

# S3 Auto Upload Settings
AUTO_UPLOAD_S3=true                    # Auto-upload after backup
S3_BACKUP_PREFIX=postgres-backups      # S3 folder
DELETE_LOCAL_AFTER_UPLOAD=false        # Keep local files

# Backup Settings
USE_CUSTOM_FORMAT=true                 # Custom format (recommended)
PARALLEL_JOBS=4                        # Parallel backup/restore
COMPRESSION_LEVEL=6                    # Compression (0-9)
```

## 📋 Commands (Just 1 Command!)

### 🎯 **Quick Commands**

```bash
make setup               # Setup environment + test connections
make backup              # Standard backup + S3 upload
make backup-complete     # Complete backup + S3 upload  
make backup-advanced     # Advanced backup + S3 upload (recommended)
make restore FILE=xxx    # Restore from backup file
```

### ☁️ **S3 Commands**

```bash
make s3-test             # Test S3 connection
make s3-list             # List S3 backups
make s3-upload FILE=xxx  # Upload backup to S3
make s3-download FILE=xxx # Download backup from S3
```

### 🛠️ **Utility Commands**

```bash
make demo                # Show demo and features
make clean               # Clean Docker containers
```

## 🔄 Workflows

### 1. **Daily Backup Workflow**

```bash
# Just 1 command for daily backup!
make backup-advanced

# Result:
# ✅ Complete database backup
# ✅ Compressed to .tar.gz  
# ✅ Uploaded to S3
# ✅ Organized by timestamp
```

### 2. **Restore Workflow**

```bash
# View available backups
make s3-list

# Download backup from S3
make s3-download FILE=postgres-backups/20250714_143022_backup.tar.gz

# Switch to restore mode (edit .env: MODE=restore)

# Restore database
make restore FILE=backup_file.dump
```

### 3. **Disaster Recovery**

```bash
# All backups are on S3
# Download any backup by timestamp
# Full restore with all metadata
```

## 📁 File Structure

### Local Backup Files

```
backup/
├── postgres_backup_20250714_143022.dump              # Standard backup
├── postgres_backup_20250714_143022_complete.dump     # Complete backup
├── postgres_backup_20250714_143022_globals.sql       # Advanced: globals
├── postgres_backup_20250714_143022_schema.dump       # Advanced: schema
├── postgres_backup_20250714_143022_data.dump         # Advanced: data
└── postgres_backup_20250714_143022_complete_set.tar.gz # Compressed for S3
```

### S3 Structure

```
s3://your-bucket/postgres-backups/
├── 20250714_143022_postgres_backup_20250714_143022.dump.tar.gz
├── 20250714_144500_postgres_backup_20250714_144500_complete_set.tar.gz
└── 20250714_145000_postgres_backup_20250714_145000_complete.dump.tar.gz
```

## 🔍 Verification

### After restore, check:

```sql
-- Check extensions
SELECT extname FROM pg_extension;

-- Check gen_random_uuid() function
SELECT gen_random_uuid();

-- Check data types
\d your_table_name

-- Check constraints
SELECT conname, contype FROM pg_constraint 
WHERE conrelid = 'your_table_name'::regclass;

-- Verify date fields
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'your_table_name';
```

## 🎉 Benefits

### ✅ **Data Integrity**

* 100% preserves data types, constraints, relationships
* No loss of extensions, functions, indexes
* Perfect restore with full metadata

### ☁️ **Cloud Backup**

* Automatic S3 upload
* Compressed storage (save costs)
* Organized by timestamp
* Easy download/restore

### 🚀 **Automation**

* One-command backup + upload
* No manual steps required
* Perfect for CI/CD pipelines
* Disaster recovery ready

### 💰 **Cost Effective**

* S3 Standard-IA storage class
* Compressed files save bandwidth
* Pay only for what you use

## 🚨 Important Notes

1. **Always test restore** on a test database before production
2. **Verify extensions** after restore
3. **Check data types** to ensure no conversion
4. **Monitor S3 costs** and set up lifecycle policies
5. **Backup regularly** and test the restore process

## 💡 Examples

### Backup Examples

```bash
# Standard backup
make backup

# Complete backup (preserves everything)
make backup-complete

# Advanced backup (recommended - preserves all metadata)
make backup-advanced
```

### Restore Examples

```bash
# List available backups
make s3-list

# Download and restore
make s3-download FILE=postgres-backups/backup.tar.gz
make restore FILE=postgres_backup_20250714_143022.dump
```

### S3 Management Examples

```bash
# Test S3 connection
make s3-test

# Upload existing backup
make s3-upload FILE=my_backup.dump

# List all S3 backups
make s3-list
```

## 🏗️ Architecture

```
PostgreSQL Database
        ↓
   [Backup Process]
        ↓
  Local Backup Files
        ↓
   [Auto Compress]
        ↓
   [Auto Upload S3]
        ↓
   Cloud Storage ☁️
```

## 📞 Support & Troubleshooting

### Common Commands

* Demo features: `make demo`
* Test connections: `make setup`
* Clean environment: `make clean`

### Manual Scripts (if needed)

* `./postgres-tool.sh help` - Main tool help
* `./advanced-backup.sh help` - Advanced backup help
* `./s3-upload.sh help` - S3 operations help

### System Requirements

* Docker and Docker Compose
* Bash shell
* AWS CLI (containerized)

### Troubleshooting

#### Connection Issues

```bash
# Test all connections
make setup

# Check specific issues
./postgres-tool.sh check
./postgres-tool.sh s3-test
```

#### Permission Issues

```bash
# Fix permissions
chmod +x *.sh

# Check Docker permissions
docker ps
```

#### S3 Issues

```bash
# Test S3 connection
make s3-test

# Check AWS credentials in .env
# Verify bucket permissions
```

#### Common Restore Errors

**"schema public already exists" error:**
```bash
# This happens with .sql files (plain text format)
# Solution 1: Use custom format backups instead (recommended)
make backup-complete    # Creates .dump files

# Solution 2: If you must use .sql files, the tool now handles this automatically
# The error is harmless and restore will continue
```

**File format issues:**
```bash
# Use custom format (.dump) for best results
USE_CUSTOM_FORMAT=true  # in .env file

# Custom format preserves all metadata and handles restore better
```

## 🏃‍♂️ Quick Reference

### Daily Operations

```bash
make backup-advanced     # Backup + upload to S3
make s3-list            # Check backup status
```

### Recovery Operations

```bash
make s3-download FILE=backup.tar.gz  # Download from S3
make restore FILE=backup.dump        # Restore database
```

### Maintenance

```bash
make clean              # Clean Docker environment
make demo               # Show features
```

**🎯 Now your PostgreSQL backup will be perfect, automated, and safe on the cloud with just 1 command!**
