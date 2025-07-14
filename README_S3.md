# 🚀 PostgreSQL Backup + S3 Auto Upload Tool

## 🎯 Giải pháp hoàn chỉnh cho vấn đề backup PostgreSQL

### ❌ Vấn đề ban đầu:
- Date fields bị chuyển thành TEXT thay vì DATE/TIMESTAMP
- Mất hàm `gen_random_uuid()` và extensions `uuid-ossp`
- Mất constraints, relationships, và indexes
- Backup files chỉ lưu local, không có backup cloud

### ✅ Giải pháp đã implement:

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

## 📦 Tính năng

### 1. **Complete Database Backup**
- ✅ Bảo toàn tất cả data types (DATE, TIMESTAMP, UUID, etc.)
- ✅ Bao gồm tất cả extensions (uuid-ossp, etc.)
- ✅ Bảo toàn functions (gen_random_uuid(), etc.)
- ✅ Bảo toàn constraints, relationships, indexes
- ✅ Backup globals (roles, tablespaces)

### 2. **S3 Integration**
- ✅ Tự động nén backup files (.tar.gz)
- ✅ Tự động upload lên S3 sau backup
- ✅ Quản lý backup trên cloud
- ✅ Download và restore từ S3
- ✅ Organized backup structure

### 3. **Multiple Backup Strategies**
- **Standard**: Basic backup với custom format
- **Complete**: Backup với tất cả metadata
- **Advanced**: Backup riêng biệt (globals + schema + data + complete)

## 🔧 Setup

### 1. Configure Environment
```bash
# Copy và edit .env file
cp .env.example .env

# Required settings
MODE=backup                    # hoặc restore
USE_CUSTOM_FORMAT=true
AUTO_UPLOAD_S3=true

# AWS S3 Settings
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=ap-southeast-1
AWS_BUCKET=your-bucket
S3_BACKUP_PREFIX=postgres-backups
DELETE_LOCAL_AFTER_UPLOAD=false
```

### 2. Database Settings
```bash
# Source database (for backup)
SOURCE_DB_HOST=your_aws_host
SOURCE_DB_PORT=5432
SOURCE_DB_NAME=your_db
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_password

# Target database (for restore)
TARGET_DB_HOST=localhost
TARGET_DB_PORT=5432
TARGET_DB_NAME=your_target_db
TARGET_DB_USER=postgres
TARGET_DB_PASSWORD=your_password
```

## 🎮 Usage

### Basic Commands

```bash
# Test connections
./postgres-tool.sh check

# Test S3 connection
./postgres-tool.sh s3-test

# Standard backup (with S3 upload)
./postgres-tool.sh backup

# Complete backup (preserves everything)
./postgres-tool.sh backup-complete

# Advanced backup (recommended)
./advanced-backup.sh backup
```

### S3 Management

```bash
# List S3 backups
./postgres-tool.sh s3-list

# Upload specific file to S3
./postgres-tool.sh s3-upload backup_file.dump

# Download from S3
./postgres-tool.sh s3-download postgres-backups/backup.tar.gz

# Advanced S3 operations
./s3-upload.sh list
./s3-upload.sh upload filename.dump
./s3-upload.sh upload-advanced 20250714_143022
./s3-upload.sh download s3-key
```

### Restore

```bash
# Set mode to restore
MODE=restore

# Restore from local file
./postgres-tool.sh restore backup_file.dump

# Restore from S3 (download first)
./postgres-tool.sh s3-download postgres-backups/backup.tar.gz
./postgres-tool.sh restore backup_file.dump

# Advanced restore
./advanced-backup.sh restore 20250714_143022
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

## 🔄 Workflows

### 1. Daily Backup Workflow
```bash
# Automated daily backup với S3
./advanced-backup.sh backup

# Kết quả:
# ✅ Complete database backup
# ✅ Compressed to .tar.gz
# ✅ Uploaded to S3
# ✅ Organized by timestamp
```

### 2. Restore Workflow
```bash
# Download latest backup from S3
./postgres-tool.sh s3-list
./postgres-tool.sh s3-download postgres-backups/latest_backup.tar.gz

# Switch to restore mode
MODE=restore

# Restore database
./postgres-tool.sh restore backup_file.dump
```

### 3. Disaster Recovery
```bash
# Tất cả backup đều có trên S3
# Download bất kỳ backup nào theo timestamp
# Restore hoàn toàn với tất cả metadata
```

## ⚙️ Configuration Options

### Auto Upload Settings
```bash
AUTO_UPLOAD_S3=true              # Tự động upload sau backup
DELETE_LOCAL_AFTER_UPLOAD=false  # Giữ local files sau upload
S3_BACKUP_PREFIX=postgres-backups # Thư mục trên S3
```

### Backup Options
```bash
USE_CUSTOM_FORMAT=true     # Custom format (khuyến nghị)
PARALLEL_JOBS=4           # Parallel backup/restore
COMPRESSION_LEVEL=6       # Compression level (0-9)
```

## 🔍 Verification

### Sau khi restore, kiểm tra:

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
- 100% bảo toàn data types, constraints, relationships
- Không mất extensions, functions, indexes
- Perfect restore với đầy đủ metadata

### ☁️ **Cloud Backup**
- Automatic S3 upload
- Compressed storage (save costs)
- Organized by timestamp
- Easy download/restore

### 🚀 **Automation**
- One-command backup + upload
- No manual steps required
- Perfect for CI/CD pipelines
- Disaster recovery ready

### 💰 **Cost Effective**
- S3 Standard-IA storage class
- Compressed files save bandwidth
- Pay only for what you use

## 🚨 Important Notes

1. **Always test restore** trên database test trước khi production
2. **Verify extensions** sau khi restore
3. **Check data types** để đảm bảo không bị convert
4. **Monitor S3 costs** và setup lifecycle policies
5. **Backup regularly** và test restore process

## 📞 Support

- Standard backup: `./postgres-tool.sh backup`
- Complete backup: `./postgres-tool.sh backup-complete`  
- Advanced backup: `./advanced-backup.sh backup`
- S3 operations: `./s3-upload.sh help`
- Demo: `./s3-demo.sh`

**Giờ đây backup PostgreSQL của bạn sẽ hoàn hảo và an toàn trên cloud! 🎯**
