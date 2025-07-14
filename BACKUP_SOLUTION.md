# Giải quyết vấn đề Backup PostgreSQL mất Data Types và Extensions

## Vấn đề bạn gặp phải:

Khi backup PostgreSQL bằng định dạng SQL plain text, bạn sẽ gặp các vấn đề sau:

1. **Date fields bị chuyển thành TEXT** thay vì DATE/TIMESTAMP
2. **Mất các Extensions** như `uuid-ossp`
3. **Mất hàm `gen_random_uuid()`** và các functions khác
4. **Mất constraints, relationships và indexes**
5. **UUID fields không có default values**

## Nguyên nhân:

- Định dạng SQL plain text (`--format=plain`) không bảo toàn đầy đủ metadata
- Thiếu backup extensions và global objects
- Không backup schema và data riêng biệt

## Giải pháp:

### 1. Sử dụng Custom Format (Đã sửa trong .env)

```env
USE_CUSTOM_FORMAT=true
```

### 2. Sử dụng Advanced Backup Script

Tool mới `advanced-backup.sh` sẽ tạo 4 loại backup:

1. **Globals**: Roles, tablespaces
2. **Schema**: Structure, extensions, functions 
3. **Data**: Dữ liệu với preserved data types
4. **Complete**: Backup hoàn chỉnh (fallback)

### 3. Cách sử dụng:

#### Backup Advanced:
```bash
# Sử dụng script mới (khuyến nghị)
./advanced-backup.sh backup

# Hoặc sử dụng tool gốc với options mới
./postgres-tool.sh backup-complete
```

#### Restore Advanced:
```bash
# Restore từ advanced backup
./advanced-backup.sh restore 20250714_143022

# Hoặc restore từ complete backup
./postgres-tool.sh restore postgres_backup_20250714_143022_complete.dump
```

### 4. Kiểm tra sau khi restore:

```sql
-- Kiểm tra extensions đã được restore
SELECT * FROM pg_extension;

-- Kiểm tra hàm gen_random_uuid()
SELECT gen_random_uuid();

-- Kiểm tra data types
\d your_table_name

-- Kiểm tra constraints
SELECT conname, contype FROM pg_constraint WHERE conrelid = 'your_table_name'::regclass;
```

## Tại sao giải pháp này hiệu quả:

### 1. Custom Format bảo toàn metadata:
- Lưu trữ binary format giữ nguyên data types
- Bao gồm tất cả database objects
- Hỗ trợ parallel backup/restore

### 2. Backup riêng biệt đảm bảo đầy đủ:
- **Globals**: Backup roles và tablespaces
- **Schema**: Backup cấu trúc, extensions, functions
- **Data**: Backup dữ liệu với đúng data types

### 3. Options quan trọng được thêm:
- `--blobs`: Include large objects
- `--disable-triggers`: Tắt triggers khi restore
- `--clean --if-exists`: Dọn dẹp trước khi restore
- `--create`: Tạo database nếu chưa có

## Commands mới:

```bash
# Kiểm tra kết nối
./postgres-tool.sh check

# Backup thông thường (đã cải thiện)
./postgres-tool.sh backup

# Backup hoàn chỉnh với tất cả metadata
./postgres-tool.sh backup-complete

# Backup advanced (khuyến nghị nhất)
./advanced-backup.sh backup

# Restore
./postgres-tool.sh restore filename.dump
./advanced-backup.sh restore 20250714_143022
```

## Lưu ý quan trọng:

1. **Luôn dùng Custom Format** cho production
2. **Test restore** trên database test trước
3. **Backup theo steps** để debug dễ dàng
4. **Kiểm tra extensions** sau khi restore
5. **Verify data types** bằng `\d table_name`

Bây giờ backup của bạn sẽ bảo toàn đầy đủ:
- ✅ Date/timestamp fields
- ✅ UUID fields với gen_random_uuid()
- ✅ Extensions (uuid-ossp, etc.)
- ✅ Constraints và relationships
- ✅ Indexes và triggers
- ✅ Functions và procedures
