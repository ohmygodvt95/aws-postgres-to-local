# AWS PostgreSQL Backup/Restore Tool

A comprehensive tool for backing up and restoring PostgreSQL databases between AWS and local databases using Docker and pg_dump/pg_restore.

## Features

- ✅ Backup PostgreSQL database from AWS to SQL/dump files
- ✅ Restore PostgreSQL database from backup files
- ✅ Database connection health checks
- ✅ Support for large databases with compression and parallel jobs
- ✅ Docker containerization for consistent environments
- ✅ Preserves table structure, relationships, constraints and data
- ✅ Custom format support for memory optimization
- ✅ Chunk processing for large databases

## System Requirements

- Docker and Docker Compose (v1 or v2)
- Bash shell
- Git (optional)

**Note:** Tool automatically detects and uses `docker compose` (v2) or `docker-compose` (v1)

## Quick Installation

```bash
# Clone repository
git clone <repository-url>
cd aws-postgres-to-local

# Automatic setup
make setup

# Or manual setup
./setup.sh
```

## Configuration

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Edit `.env` file and configure:
   - **MODE**: Choose `backup` or `restore` (cannot be both)
   - **SOURCE_DB_***: Configure AWS PostgreSQL (for backup)
   - **TARGET_DB_***: Configure target database (for restore)

### Example configuration for backup:
```bash
MODE=backup
SOURCE_DB_HOST=your-aws-postgres.amazonaws.com
SOURCE_DB_PORT=5432
SOURCE_DB_NAME=production_db
SOURCE_DB_USER=postgres
SOURCE_DB_PASSWORD=your_password
```

### Example configuration for restore:
```bash
MODE=restore
TARGET_DB_HOST=localhost
TARGET_DB_PORT=5432
TARGET_DB_NAME=local_db
TARGET_DB_USER=postgres
TARGET_DB_PASSWORD=postgres
```

## Usage

### Using Makefile (Recommended)

```bash
# Check database connections
make check

# Backup database
make backup

# Restore database
make restore FILE=postgres_backup_20250714_143022.dump

# List backup files
make list
```

### Using Script Directly

```bash
# Check database connections
./postgres-tool.sh check

# Backup database
./postgres-tool.sh backup

# Restore database
./postgres-tool.sh restore postgres_backup_20250714_143022.dump

# List backup files
./postgres-tool.sh list
```

## Workflow

### 1. Backup from AWS

```bash
# 1. Configure for backup
echo "MODE=backup" > .env
# ... add SOURCE_DB_* information

# 2. Check connections
make check

# 3. Perform backup
make backup
```

### 2. Restore to Target Database

```bash
# 1. Configure for restore
echo "MODE=restore" > .env
# ... add TARGET_DB_* information

# 2. Check connections
make check

# 3. Restore from backup file
make restore FILE=postgres_backup_20250714_143022.dump
```

## Optimization for Large Databases

The tool supports multiple optimization options:

- **Custom format**: Use PostgreSQL binary format
- **Compression**: Compress backup files (level 0-9)
- **Parallel jobs**: Use multiple threads
- **Chunking**: Process data in chunks

Configure in `.env`:
```bash
USE_CUSTOM_FORMAT=true
COMPRESSION_LEVEL=6
PARALLEL_JOBS=4
```

## File Structure

```
├── postgres-tool.sh      # Main script
├── setup.sh             # Automatic setup script
├── Makefile             # Makefile for easy usage
├── docker-compose.yml   # Docker compose for pg_dump/pg_restore tools
├── .env.example         # Configuration template
├── .env                 # Actual configuration (gitignored)
├── .gitignore          # Git ignore rules
├── backup/             # Backup files directory (gitignored)
│   └── .keep           # Keep directory in git
├── LICENSE             # MIT License
├── CODE_OF_CONDUCT.md  # Code of Conduct
└── README.md           # This documentation
```

## Backup File Formats

- **Custom format** (`.dump`): Binary format, supports compression and parallel processing
- **Plain format** (`.sql`): Text format, easy to read and edit

## Troubleshooting

### Connection Issues
```bash
# Check connections
make check

# View Docker logs
make logs
```

### Permission Issues
```bash
# Ensure scripts are executable
chmod +x postgres-tool.sh setup.sh
```

### Database Does Not Exist
Tool automatically creates database during restore when using `--create` option.

### Large Backup Files
Use custom format with compression:
```bash
USE_CUSTOM_FORMAT=true
COMPRESSION_LEVEL=9
PARALLEL_JOBS=8
```

### Docker Compose Compatibility
Tool automatically detects and uses:
- `docker compose` (Docker Compose v2) - preferred
- `docker-compose` (Docker Compose v1) - fallback

If encountering Docker Compose issues, check:
```bash
docker compose version  # v2
docker-compose version  # v1
```

## Security Notes

- `.env` file contains sensitive information and is gitignored
- Do not commit passwords to source code
- Use environment variables or secrets management in production

## Contributing

We welcome contributions! Please see our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [Issues](../../issues)
3. Create a new issue if needed

## Changelog

### v1.0.0 (2025-07-14)
- Initial release
- AWS PostgreSQL backup/restore functionality
- Docker Compose v1/v2 auto-detection
- Support for large databases with parallel processing
- Custom and plain backup formats
