#!/bin/bash

set -euo pipefail 

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' 

# Default values
ARCHIVE_DIR=""
LOG_DIR=""
DAYS_OLD=7
DRY_RUN=false
VERBOSE=false
DELETE_ORIGINAL=false
ARCHIVE_FORMAT="tar.gz"


print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <log-directory>

Archive and compress log files from a specified directory.

ARGUMENTS:
    log-directory          Path to the directory containing logs to archive

OPTIONS:
    -a, --archive-dir DIR  Directory to store archives (default: <log-directory>/archives)
    -d, --days-old DAYS    Only archive logs older than DAYS days (default: 7)
    -f, --format FORMAT    Archive format: tar.gz, zip, or individual (default: tar.gz)
    -r, --delete           Delete original log files after archiving
    -n, --dry-run          Show what would be archived without actually doing it
    -v, --verbose          Enable verbose output
    -h, --help             Display this help message

EXAMPLES:
    # Archive logs older than 7 days from /var/log
    $(basename "$0") /var/log

    # Archive to custom location and delete originals
    $(basename "$0") -a /backup/logs -r /var/log

    # Dry run to see what would be archived
    $(basename "$0") -n -v /var/log

    # Archive logs older than 30 days
    $(basename "$0") -d 30 /var/log

EOF
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

validate_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_error "Directory does not exist: $dir"
        exit 1
    fi
    if [[ ! -r "$dir" ]]; then
        log_error "Directory is not readable: $dir"
        exit 1
    fi
}

create_archive_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_verbose "Creating archive directory: $dir"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                log_error "Failed to create archive directory: $dir"
                if [[ "$EUID" -ne 0 ]] && [[ "$dir" == /var/* ]] || [[ "$dir" == /etc/* ]]; then
                    log_error "System directories require root privileges. Try:"
                    echo -e "${YELLOW}  sudo $0 $*${NC}" >&2
                    echo -e "${YELLOW}  OR specify a custom archive location:${NC}" >&2
                    echo -e "${YELLOW}  sudo $0 -a /home/\$USER/archives $*${NC}" >&2
                fi
                exit 1
            }
        fi
    elif [[ ! -w "$dir" ]]; then
        log_error "Archive directory is not writable: $dir"
        if [[ "$EUID" -ne 0 ]]; then
            log_error "You may need root privileges. Try:"
            echo -e "${YELLOW}  sudo $0 $*${NC}" >&2
        fi
        exit 1
    fi
}

find_log_files() {
    local log_dir="$1"
    local days_old="$2"

    log_verbose "Searching for log files older than $days_old days in: $log_dir"

    # Find log files (*.log, *.txt) older than specified days
    # Exclude already compressed files (*.gz, *.zip, *.tar.gz, *.bz2)
    find "$log_dir" -maxdepth 1 -type f \
        \( -name "*.log" -o -name "*.txt" \) \
        ! -name "*.gz" \
        ! -name "*.zip" \
        ! -name "*.bz2" \
        -mtime +"$days_old" 2>/dev/null || true
}

get_file_size_mb() {
    local total_size=0
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
        fi
    done
    echo "$((total_size / 1024 / 1024))"
}

archive_tar_gz() {
    local log_dir="$1"
    local archive_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="logs_${timestamp}.tar.gz"
    local archive_path="${archive_dir}/${archive_name}"
    local temp_file_list=$(mktemp)

    # Get list of files to archive
    local files=()
    while IFS= read -r file; do
        files+=("$file")
        echo "$file" >> "$temp_file_list"
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        rm -f "$temp_file_list"
        return 0
    fi

    log_info "Archiving ${#files[@]} log file(s) to: $archive_name"

    if [[ "$DRY_RUN" == false ]]; then
        # Create tar.gz archive
        tar -czf "$archive_path" -C "$log_dir" --transform='s,.*/,,' "${files[@]}" 2>/dev/null || {
            log_error "Failed to create archive: $archive_path"
            rm -f "$temp_file_list"
            exit 1
        }

        local archive_size=$(du -h "$archive_path" | cut -f1)
        log_success "Archive created: $archive_name ($archive_size)"

        # Delete original files if requested
        if [[ "$DELETE_ORIGINAL" == true ]]; then
            log_info "Deleting original log files..."
            while IFS= read -r file; do
                rm -f "$file"
                log_verbose "Deleted: $file"
            done < "$temp_file_list"
            log_success "Original files deleted"
        fi
    else
        log_info "[DRY RUN] Would create archive: $archive_name"
        log_info "[DRY RUN] Files to be archived:"
        while IFS= read -r file; do
            echo "  - $(basename "$file")"
        done < "$temp_file_list"
    fi

    rm -f "$temp_file_list"
}

archive_individual() {
    local archive_dir="$1"
    local file_count=0

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        local filename=$(basename "$file")
        local archive_name="${filename}.gz"
        local archive_path="${archive_dir}/${archive_name}"

        file_count=$((file_count + 1))
        log_info "Compressing: $filename"

        if [[ "$DRY_RUN" == false ]]; then
            gzip -c "$file" > "$archive_path" 2>/dev/null || {
                log_warning "Failed to compress: $filename"
                continue
            }

            local archive_size=$(du -h "$archive_path" | cut -f1)
            log_verbose "Created: $archive_name ($archive_size)"

            if [[ "$DELETE_ORIGINAL" == true ]]; then
                rm -f "$file"
                log_verbose "Deleted: $filename"
            fi
        else
            log_info "[DRY RUN] Would compress: $filename -> $archive_name"
        fi
    done

    if [[ $file_count -eq 0 ]]; then
        log_info "No log files found to archive"
    else
        log_success "Compressed $file_count file(s)"
    fi
}

archive_zip() {
    local log_dir="$1"
    local archive_dir="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_name="logs_${timestamp}.zip"
    local archive_path="${archive_dir}/${archive_name}"

    # Check if zip is available
    if ! command -v zip &> /dev/null; then
        log_error "zip command not found. Please install zip or use a different format."
        exit 1
    fi

    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Archiving ${#files[@]} log file(s) to: $archive_name"

    if [[ "$DRY_RUN" == false ]]; then
        cd "$log_dir"
        local basenames=()
        for file in "${files[@]}"; do
            basenames+=("$(basename "$file")")
        done

        zip -q -j "$archive_path" "${basenames[@]}" 2>/dev/null || {
            log_error "Failed to create zip archive: $archive_path"
            exit 1
        }

        local archive_size=$(du -h "$archive_path" | cut -f1)
        log_success "Archive created: $archive_name ($archive_size)"

        if [[ "$DELETE_ORIGINAL" == true ]]; then
            log_info "Deleting original log files..."
            for file in "${files[@]}"; do
                rm -f "$file"
                log_verbose "Deleted: $(basename "$file")"
            done
            log_success "Original files deleted"
        fi
    else
        log_info "[DRY RUN] Would create zip archive: $archive_name"
        log_info "[DRY RUN] Files to be archived:"
        for file in "${files[@]}"; do
            echo "  - $(basename "$file")"
        done
    fi
}

#############################################
# Main Script
#############################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -a|--archive-dir)
                ARCHIVE_DIR="$2"
                shift 2
                ;;
            -d|--days-old)
                DAYS_OLD="$2"
                shift 2
                ;;
            -f|--format)
                ARCHIVE_FORMAT="$2"
                shift 2
                ;;
            -r|--delete)
                DELETE_ORIGINAL=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                LOG_DIR="$1"
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$LOG_DIR" ]]; then
        log_error "Log directory is required"
        print_usage
        exit 1
    fi

    # Validate log directory
    validate_directory "$LOG_DIR"

    # Set default archive directory if not specified
    if [[ -z "$ARCHIVE_DIR" ]]; then
        ARCHIVE_DIR="${LOG_DIR}/archives"
    fi

    # Validate archive format
    if [[ ! "$ARCHIVE_FORMAT" =~ ^(tar.gz|zip|individual)$ ]]; then
        log_error "Invalid format: $ARCHIVE_FORMAT. Must be tar.gz, zip, or individual"
        exit 1
    fi

    # Print configuration
    log_info "Log Archive Tool"
    log_info "=================="
    log_info "Log directory: $LOG_DIR"
    log_info "Archive directory: $ARCHIVE_DIR"
    log_info "Archive format: $ARCHIVE_FORMAT"
    log_info "Days old: $DAYS_OLD"
    log_info "Delete original: $DELETE_ORIGINAL"
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    echo ""

    # Create archive directory
    create_archive_dir "$ARCHIVE_DIR"

    # Find log files
    mapfile -t log_files < <(find_log_files "$LOG_DIR" "$DAYS_OLD")

    if [[ ${#log_files[@]} -eq 0 ]]; then
        log_info "No log files found older than $DAYS_OLD days"
        exit 0
    fi

    log_info "Found ${#log_files[@]} log file(s) to archive"

    # Calculate total size
    if [[ "$VERBOSE" == true ]]; then
        local total_size_mb=$(printf '%s\n' "${log_files[@]}" | get_file_size_mb)
        log_verbose "Total size: ${total_size_mb}MB"
    fi

    # Archive files based on format
    case $ARCHIVE_FORMAT in
        tar.gz)
            printf '%s\n' "${log_files[@]}" | archive_tar_gz "$LOG_DIR" "$ARCHIVE_DIR"
            ;;
        zip)
            printf '%s\n' "${log_files[@]}" | archive_zip "$LOG_DIR" "$ARCHIVE_DIR"
            ;;
        individual)
            printf '%s\n' "${log_files[@]}" | archive_individual "$ARCHIVE_DIR"
            ;;
    esac

    echo ""
    log_success "Archive operation completed successfully!"
}

main "$@"
