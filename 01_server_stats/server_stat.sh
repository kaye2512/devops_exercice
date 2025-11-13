#!/bin/bash
cpu_usage=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2 + $4}')
memory_usage=$(free -m | grep "Mem:" | awk '{print $3/$2 * 100}')
disk_usage=$(df -h | grep "/dev/sda1" | awk '{print $5}')

echo "CPU Usage: $cpu_usage%"
echo "Memory Usage: $memory_usage%"
echo "Disk Usage: $disk_usage%"

top_5_processes_cpu=$(ps aux --sort=-%cpu | head -n 6)
top_5_processes_memory=$(ps aux --sort=-%mem | head -n 6)

echo "Top 5 Processes by CPU Usage:"
echo "$top_5_processes_cpu"

echo "Top 5 Processes by Memory Usage:"
echo "$top_5_processes_memory"


