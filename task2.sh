#!/bin/bash

# Configuration and global variables
CONFIG_FILE="config.cfg"
REPORT_FILE="audit_report_$(hostname)_$(date +%F).txt"
EMAIL_ALERT=false

# Load configuration file
if [[ -f $CONFIG_FILE ]]; then
  source $CONFIG_FILE
else
  echo "Configuration file ($CONFIG_FILE) not found!"
  exit 1
fi

# Function to perform user and group audits
audit_users_groups() {
  echo "User and Group Audit" >> $REPORT_FILE
  echo "---------------------" >> $REPORT_FILE
  echo "Listing all users and groups:" >> $REPORT_FILE
  getent passwd >> $REPORT_FILE
  getent group >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Checking for users with UID 0 (root privileges):" >> $REPORT_FILE
  awk -F: '($3 == "0") {print}' /etc/passwd >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Checking for users without passwords or with weak passwords:" >> $REPORT_FILE
  awk -F: '($2 == "" || $2 == "x") {print $1 " has no password set"}' /etc/shadow >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to check file and directory permissions
audit_file_permissions() {
  echo "File and Directory Permissions Audit" >> $REPORT_FILE
  echo "-----------------------------------" >> $REPORT_FILE
  echo "Scanning for world-writable files and directories:" >> $REPORT_FILE
  find / -type f -perm -o+w 2>/dev/null >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Checking .ssh directories for secure permissions:" >> $REPORT_FILE
  find /home/*/.ssh -type d -exec stat -c "%a %n" {} \; 2>/dev/null >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Reporting files with SUID or SGID bits set:" >> $REPORT_FILE
  find / -type f \( -perm -4000 -o -perm -2000 \) -exec ls -l {} \; 2>/dev/null >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to audit services
audit_services() {
  echo "Service Audit" >> $REPORT_FILE
  echo "-------------" >> $REPORT_FILE
  echo "Listing all running services:" >> $REPORT_FILE
  systemctl list-units --type=service --state=running >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Checking for critical services (e.g., sshd, iptables):" >> $REPORT_FILE
  for service in sshd iptables; do
    if systemctl is-active --quiet $service; then
      echo "$service is running" >> $REPORT_FILE
    else
      echo "WARNING: $service is not running" >> $REPORT_FILE
    fi
  done
  echo >> $REPORT_FILE

  echo "Checking for services listening on non-standard or insecure ports:" >> $REPORT_FILE
  netstat -tulnp | grep -v ":22 " >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to check firewall and network security
audit_firewall_network() {
  echo "Firewall and Network Security" >> $REPORT_FILE
  echo "-----------------------------" >> $REPORT_FILE
  if command -v iptables >/dev/null 2>&1; then
    echo "Checking iptables rules:" >> $REPORT_FILE
    iptables -L -n -v >> $REPORT_FILE
  else
    echo "WARNING: iptables is not installed or configured." >> $REPORT_FILE
  fi
  echo >> $REPORT_FILE

  echo "Checking for IP forwarding settings:" >> $REPORT_FILE
  sysctl net.ipv4.ip_forward >> $REPORT_FILE
  sysctl net.ipv6.conf.all.forwarding >> $REPORT_FILE
  echo >> $REPORT_FILE

  echo "Checking open ports and associated services:" >> $REPORT_FILE
  netstat -tuln >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to check IP and network configurations
audit_ip_network() {
  echo "IP and Network Configuration" >> $REPORT_FILE
  echo "----------------------------" >> $REPORT_FILE

  # Check public vs private IP
  echo "Listing all IP addresses and classifying as public or private:" >> $REPORT_FILE
  ip -o -f inet addr show | awk '/scope global/ {print $4, ($4 ~ /^10\./ || $4 ~ /^192\.168\./ || $4 ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./ ? "Private" : "Public")}' >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to check for security updates and patches
audit_security_updates() {
  echo "Security Updates and Patching" >> $REPORT_FILE
  echo "-----------------------------" >> $REPORT_FILE
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update >> $REPORT_FILE 2>&1
    apt-get -s upgrade | grep -i security >> $REPORT_FILE
  elif command -v yum >/dev/null 2>&1; then
    yum check-update --security >> $REPORT_FILE
  else
    echo "Package manager not recognized. Skipping update check." >> $REPORT_FILE
  fi
  echo >> $REPORT_FILE
}

# Function to check log files for suspicious activity
audit_log_monitoring() {
  echo "Log Monitoring" >> $REPORT_FILE
  echo "--------------" >> $REPORT_FILE
  echo "Checking for suspicious SSH login attempts:" >> $REPORT_FILE
  grep "Failed password" /var/log/auth.log | tail -n 10 >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Function to implement hardening steps
harden_server() {
  echo "Server Hardening Steps" >> $REPORT_FILE
  echo "----------------------" >> $REPORT_FILE

  # SSH Hardening
  echo "Implementing SSH hardening:" >> $REPORT_FILE
  sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart sshd
  echo "SSH hardened by disabling root login and password-based authentication." >> $REPORT_FILE
  echo >> $REPORT_FILE

  # Disable IPv6 if not needed
  if [ "$DISABLE_IPV6" = true ]; then
    echo "Disabling IPv6:" >> $REPORT_FILE
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    echo "IPv6 disabled." >> $REPORT_FILE
  fi
  echo >> $REPORT_FILE

  # Securing the bootloader
  echo "Securing GRUB bootloader:" >> $REPORT_FILE
  grub-mkpasswd-pbkdf2
  echo "Add the generated password to /etc/grub.d/40_custom and run update-grub." >> $REPORT_FILE
  echo >> $REPORT_FILE

  # Configuring automatic security updates
  echo "Configuring automatic security updates:" >> $REPORT_FILE
  if command -v apt-get >/dev/null 2>&1; then
    apt-get install -y unattended-upgrades
    dpkg-reconfigure --priority=low unattended-upgrades
  elif command -v yum >/dev/null 2>&1; then
    yum install -y yum-cron
    systemctl enable yum-cron
    systemctl start yum-cron
  fi
  echo "Automatic security updates configured." >> $REPORT_FILE
  echo >> $REPORT_FILE
}

# Custom security checks (defined in config.cfg)
custom_security_checks() {
  echo "Custom Security Checks" >> $REPORT_FILE
  echo "----------------------" >> $REPORT_FILE
  for check in "${CUSTOM_CHECKS[@]}"; do
    echo "Running custom check: $check" >> $REPORT_FILE
    eval "$check" >> $REPORT_FILE 2>&1
  done
  echo >> $REPORT_FILE
}

# Function to send email alerts if critical issues are found
send_email_alert() {
  if [ "$EMAIL_ALERT" = true ]; then
    mail -s "Security Audit Report for $(hostname)" $EMAIL_RECIPIENT < $REPORT_FILE
  fi
}

# Main execution
echo "Security Audit and Hardening Report for $(hostname) - $(date)" > $REPORT_FILE
echo "=============================================================" >> $REPORT_FILE

audit_users_groups
audit
