#!/bin/bash

get_top_ips() {
    local log_file="$1"
    local count="${2:-5}"

    awk '{print $1}' "$log_file" | sort | uniq -c | sort -nr | head -n "$count"
}

get_top_paths() {
    local log_file="$1"
    local count="${2:-5}"

    awk '{
        # Find the request field (enclosed in quotes)
        match($0, /"[A-Z]+ [^ ]+ HTTP/)
        if (RSTART > 0) {
            request = substr($0, RSTART, RLENGTH)
            # Extract just the path (second word in the request)
            split(request, parts, " ")
            print parts[2]
        }
    }' "$log_file" | sort | uniq -c | sort -nr | head -n "$count"
}

get_top_status_codes() {
    local log_file="$1"
    local count="${2:-5}"

    awk '{print $9}' "$log_file" | sort | uniq -c | sort -nr | head -n "$count"
}

# Main script - use command line argument
LOG_FILE="${1:-nginx_log/nginx-access.log}"


echo "Top 5 IP Addresses with Most Requests:"
echo "======================================"
get_top_ips "$LOG_FILE" 5 | awk '{printf "%6d requests - %s\n", $1, $2}'

echo ""
echo ""

echo "Top 5 Most Requested Paths:"
echo "======================================"
get_top_paths "$LOG_FILE" 5 | awk '{printf "%6d requests - %s\n", $1, $2}'

echo ""
echo ""

echo "Top 5 HTTP Status Codes:"
echo "======================================"
get_top_status_codes "$LOG_FILE" 5 | awk '{printf "%6d requests - %s\n", $1, $2}'

