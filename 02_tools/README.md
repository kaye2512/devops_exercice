# project name
https://roadmap.sh/projects/log-archive-tool

# Log Archive Tool

A bash-based command-line tool for archiving and compressing log files on Unix-based systems. This tool helps maintain system cleanliness by compressing old logs while preserving them for future reference.

## Features

- **Flexible Input**: Accept any log directory path as an argument
- **Smart Filtering**: Archive only logs older than a specified number of days (default: 7)
- **Multiple Formats**: Support for tar.gz, zip, or individual file compression
- **Safe Operations**: Dry-run mode to preview what will be archived
- **Customizable**: Configure archive location, compression format, and retention policy
- **Clean Output**: Colored, informative console output with verbose mode
- **Optional Cleanup**: Delete original logs after successful archiving

## Requirements

- Bash 4.0 or higher
- Standard Unix tools: `tar`, `gzip`, `find`, `stat`
- Optional: `zip` (for zip format support)

## Installation

1. Clone or download the script:
```bash
cd 02_tools
chmod +x log-archive.sh
```

2. Optionally, add to your PATH for system-wide access:
```bash
sudo cp log-archive.sh /usr/local/bin/log-archive
```

## Usage

### Basic Syntax

```bash
./log-archive.sh [OPTIONS] <log-directory>
```

### Options

| Option | Description |
|--------|-------------|
| `-a, --archive-dir DIR` | Directory to store archives (default: `<log-directory>/archives`) |
| `-d, --days-old DAYS` | Only archive logs older than DAYS days (default: 7) |
| `-f, --format FORMAT` | Archive format: `tar.gz`, `zip`, or `individual` (default: tar.gz) |
| `-r, --delete` | Delete original log files after successful archiving |
| `-n, --dry-run` | Preview what would be archived without making changes |
| `-v, --verbose` | Enable verbose output for detailed logging |
| `-h, --help` | Display help message |

### Examples

#### 1. Basic Archive (Default Settings)
Archive logs older than 7 days from `/var/log`:
```bash
./log-archive.sh /var/log
```

#### 2. Custom Archive Location
Store archives in a specific backup directory:
```bash
./log-archive.sh -a /backup/logs /var/log
```

#### 3. Dry Run (Preview Mode)
See what would be archived without making changes:
```bash
./log-archive.sh -n -v /var/log
```

#### 4. Archive and Delete Originals
Compress logs and remove originals to save disk space:
```bash
./log-archive.sh -r /var/log
```

#### 5. Custom Retention Period
Archive logs older than 30 days:
```bash
./log-archive.sh -d 30 /var/log
```

#### 6. Individual File Compression
Compress each log file separately instead of creating a single archive:
```bash
./log-archive.sh -f individual /var/log
```

#### 7. ZIP Format
Create a zip archive instead of tar.gz:
```bash
./log-archive.sh -f zip -a /backup /var/log
```

#### 8. Test with Local Directory
Test with a local test_logs directory:
```bash
./log-archive.sh -v ./test_logs
```

## How It Works

### 1. Directory Validation
- Verifies that the log directory exists and is readable
- Creates the archive directory if it doesn't exist

### 2. Log File Discovery
- Searches for files with `.log` or `.txt` extensions
- Filters files older than the specified number of days
- Excludes already compressed files (`.gz`, `.zip`, `.bz2`)

### 3. Compression
Depending on the selected format:
- **tar.gz**: Creates a single compressed archive with timestamp (e.g., `logs_20251113_143022.tar.gz`)
- **zip**: Creates a ZIP archive with timestamp (e.g., `logs_20251113_143022.zip`)
- **individual**: Compresses each log file separately (e.g., `app.log` → `app.log.gz`)

### 4. Optional Cleanup
If `--delete` flag is used, removes original log files after successful compression.

## Common Use Cases

### System Log Maintenance
Archive system logs on Ubuntu/Debian:
```bash
sudo ./log-archive.sh -d 14 -a /var/backups/log-archives /var/log
```

### Application Log Cleanup
Archive application logs and delete originals:
```bash
./log-archive.sh -r -d 7 /var/www/myapp/logs
```

### Scheduled Archiving with Cron
Add to crontab for automatic weekly archiving:
```bash
# Archive logs every Sunday at 2 AM
0 2 * * 0 /usr/local/bin/log-archive -r -d 7 /var/log
```

### Testing Before Production
Always test first with dry-run:
```bash
./log-archive.sh -n -v -d 30 /var/log
```

## File Structure

After running the tool, your directory structure will look like:

```
/var/log/
├── archives/
│   ├── logs_20251113_120000.tar.gz
│   ├── logs_20251106_120000.tar.gz
│   └── logs_20251030_120000.tar.gz
├── syslog                    # Current logs (recent)
├── auth.log
└── apache2.log
```

Or with individual compression:

```
/var/log/
├── archives/
│   ├── old-app.log.gz
│   ├── old-error.log.gz
│   └── old-access.log.gz
├── current-app.log           # Current logs
└── current-error.log
```

## Understanding `/var/log`

On Unix-based systems, `/var/log` is the standard location for system and application logs:

- **System Logs**: `syslog`, `messages`, `kern.log`
- **Authentication**: `auth.log`, `secure`
- **Web Servers**: `apache2/`, `nginx/`
- **Databases**: `mysql/`, `postgresql/`
- **Applications**: Custom app logs

### Why Archive Logs?

1. **Disk Space**: Old logs can consume significant disk space
2. **Performance**: Large log directories slow down file operations
3. **Compliance**: Retain logs for audit/compliance requirements
4. **Organization**: Keep historical data accessible but compressed

## Permissions

To archive system logs in `/var/log`, you need root privileges:

```bash
sudo ./log-archive.sh /var/log
```

Or use sudo with specific options:
```bash
sudo ./log-archive.sh -a /backup/logs -r -d 14 /var/log
```

## Error Handling

The script includes comprehensive error handling:

- **Missing directories**: Validates paths before operations
- **Permission issues**: Clear error messages for access problems
- **Compression failures**: Individual file errors don't stop the entire process
- **Missing dependencies**: Checks for required tools (e.g., zip)

## Best Practices

1. **Always test first**: Use `--dry-run` before actual archiving
2. **Backup important logs**: Keep copies before using `--delete`
3. **Monitor disk space**: Ensure archive destination has enough space
4. **Schedule wisely**: Run during off-peak hours for system logs
5. **Set appropriate retention**: Balance storage costs vs. compliance needs
6. **Use verbose mode**: For troubleshooting and audit trails

## Automation with Cron

Create a cron job for automatic archiving:

```bash
# Edit crontab
crontab -e

# Add entry (example: archive weekly on Sunday at 2 AM)
0 2 * * 0 /usr/local/bin/log-archive -r -d 7 -a /backup/logs /var/log >> /var/log/archive-tool.log 2>&1
```

## Troubleshooting

### Permission Denied
```bash
# Solution: Run with sudo
sudo ./log-archive.sh /var/log
```

### No Files Found
```bash
# Check if logs exist and meet age criteria
ls -lt /var/log/*.log
# Try with different days-old value
./log-archive.sh -d 1 /var/log
```

### Archive Directory Creation Failed
```bash
# Ensure parent directory exists and is writable
mkdir -p /backup/logs
sudo chown $USER:$USER /backup/logs
```

## Contributing

Improvements welcome! Consider adding:
- Support for more compression formats (bzip2, xz)
- Email notifications on completion
- Log rotation integration
- Archive retention policies (auto-delete old archives)
- Configuration file support

## License

MIT License - Feel free to use and modify for your needs.

## Related Resources

- [Linux Log Files](https://www.linux.com/training-tutorials/linux-log-files/)
- [Log Rotation](https://www.digitalocean.com/community/tutorials/how-to-manage-logfiles-with-logrotate-on-ubuntu-16-04)
- [Cron Jobs](https://crontab.guru/)
