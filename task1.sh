#!/bin/bash

# Function to display top 10 applications by CPU and memory usage
show_top_10_apps() {
  echo "Top 10 Applications by CPU and Memory Usage"
  echo "------------------------------------------"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 11
  echo
}

# Function to monitor network statistics
show_network_stats() {
  echo "Network Monitoring"
  echo "------------------"
  
  # Number of concurrent connections
  echo -n "Concurrent Connections: "
  netstat -an | grep ESTABLISHED | wc -l

  # Packet drops
  echo -n "Packet Drops (RX + TX): "
  netstat -i | awk 'NR>2 {rxdrops+=$4; txdrops+=$8} END {print rxdrops + txdrops}'

  # Data traffic in and out (in MB)
  RX_BYTES=$(cat /proc/net/dev | awk '/eth0/ {print $2}')  # Adjust interface if needed
  TX_BYTES=$(cat /proc/net/dev | awk '/eth0/ {print $10}') # Adjust interface if needed
  RX_MB=$(echo "scale=2; $RX_BYTES/1024/1024" | bc)
  TX_MB=$(echo "scale=2; $TX_BYTES/1024/1024" | bc)
  echo "Data In: ${RX_MB} MB"
  echo "Data Out: ${TX_MB} MB"
  echo
}

# Function to monitor disk usage and highlight partitions over 80% usage
show_disk_usage() {
  echo "Disk Usage"
  echo "----------"
  df -h | awk '$5 > 80 {print "WARNING: "$1 " is using " $5 " of space!"} 1'
  echo
}

# Function to display system load and CPU breakdown
show_system_load() {
  echo "System Load"
  echo "-----------"
  echo "Load Average: $(uptime | awk -F'load average: ' '{print $2}')"
  echo "CPU Usage Breakdown:"
  mpstat | grep "all" | awk '{print "User: " $4"% System: " $6"% Idle: " $13"%"}'
  echo
}

# Function to display memory and swap usage
show_memory_usage() {
  echo "Memory Usage"
  echo "------------"
  free -h | awk 'NR==2{printf "Total: %s\nUsed: %s\nFree: %s\n", $2, $3, $4}'
  free -h | awk 'NR==3{printf "Swap Total: %s\nSwap Used: %s\nSwap Free: %s\n", $2, $3, $4}'
  echo
}

# Function to monitor processes
show_process_monitoring() {
  echo "Process Monitoring"
  echo "------------------"
  echo -n "Active Processes: "
  ps aux --no-heading | wc -l

  echo "Top 5 Processes by CPU and Memory Usage:"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
  echo
}

# Function to monitor essential services
show_service_monitoring() {
  echo "Service Monitoring"
  echo "------------------"
  services=("sshd" "nginx" "apache2" "iptables")

  for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
      echo "$service: Active"
    else
      echo "$service: Inactive (or not installed)"
    fi
  done
  echo
}

# Function to display the entire dashboard
show_dashboard() {
  clear
  show_top_10_apps
  show_network_stats
  show_disk_usage
  show_system_load
  show_memory_usage
  show_process_monitoring
  show_service_monitoring
}

# Handle command-line switches
while getopts "antdsmp" option; do
  case $option in
    a) show_dashboard ;;                   # Show entire dashboard
    n) show_network_stats ;;               # Show network monitoring
    t) show_top_10_apps ;;                 # Show top 10 apps by CPU and memory
    d) show_disk_usage ;;                  # Show disk usage
    s) show_system_load ;;                 # Show system load
    m) show_memory_usage ;;                # Show memory usage
    p) show_process_monitoring ;;          # Show process monitoring
    *) echo "Usage: $0 [-a] (All) [-n] (Network) [-t] (Top 10 Apps) [-d] (Disk Usage) [-s] (System Load) [-m] (Memory Usage) [-p] (Process Monitoring)" ;;
  esac
  exit 0
done

# Continuously refresh the dashboard every few seconds
while true; do
  show_dashboard
  sleep 5
done
