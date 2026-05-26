#!/bin/bash

################################################################################
# PXREA PC Service Diagnostic Script
# 
# This script provides detailed diagnostic information for troubleshooting
# connection issues between the PC Service and Meta Quest 3 devices.
#
# Usage: bash diagnose_pxrea.sh [--verbose] [--export FILE]
# 
# Examples:
#   bash diagnose_pxrea.sh                    # Standard diagnosis
#   bash diagnose_pxrea.sh --verbose          # With detailed output
#   bash diagnose_pxrea.sh --export /tmp/diag.txt  # Save to file
################################################################################

VERBOSE=false
EXPORT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --export)
            EXPORT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--verbose] [--export FILE]"
            exit 1
            ;;
    esac
done

# Setup output redirection
if [ -n "$EXPORT_FILE" ]; then
    exec > >(tee "$EXPORT_FILE")
    exec 2>&1
fi

echo "================================================================================"
echo "PXREA PC Service Diagnostic Report"
echo "Generated: $(date)"
echo "================================================================================"
echo ""

# ============================================================================
# SYSTEM INFORMATION
# ============================================================================
echo "--- System Information ---"
echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo ""

# ============================================================================
# PROCESS INFORMATION
# ============================================================================
echo "--- Service Process Information ---"
if pgrep -f "RoboticsServiceProcess" > /dev/null; then
    PID=$(pgrep -x RoboticsServiceProcess)
    echo "Status: RUNNING (PID: $PID)"
    echo ""
    
    echo "Process details:"
    ps -p $PID -o pid,ppid,cmd,etime,rss,vsz 2>/dev/null | tail -1
    echo ""
    
    echo "File descriptors:"
    if [ -d "/proc/$PID/fd" ]; then
        echo "  Total: $(ls /proc/$PID/fd 2>/dev/null | wc -l)"
        echo "  Network connections:"
        ls -la /proc/$PID/fd 2>/dev/null | grep socket | head -5
    fi
else
    echo "Status: NOT RUNNING"
fi
echo ""

# ============================================================================
# PORT AND NETWORK INFORMATION
# ============================================================================
echo "--- Port and Network Status ---"
echo ""
echo "Listening ports for PXREA service:"
sudo ss -tulpn 2>/dev/null | grep -E "(60061|63901)" || echo "  (No ports found - service may not be running)"
echo ""

echo "UDP port 29888 (Broadcast):"
sudo ss -tulpn 2>/dev/null | grep 29888 || echo "  (UDP broadcast ports don't typically appear in listening list)"
echo ""

echo "All network interfaces:"
ip link show 2>/dev/null || ifconfig
echo ""

echo "IP addresses:"
hostname -I 2>/dev/null || ifconfig | grep "inet " | awk '{print $2}'
echo ""

# ============================================================================
# FIREWALL INFORMATION
# ============================================================================
echo "--- Firewall Configuration ---"
echo ""
echo "UFW Status:"
sudo ufw status 2>/dev/null || echo "  UFW not available or not running"
echo ""

echo "UFW Rules for PXREA ports:"
sudo ufw status numbered 2>/dev/null | grep -E "(60061|63901|29888)" || echo "  (No PXREA-specific rules found)"
echo ""

if command -v iptables &> /dev/null; then
    echo "iptables rules (INPUT chain):"
    sudo iptables -L INPUT -n 2>/dev/null | grep -E "(60061|63901|29888)" || echo "  (No iptables rules for PXREA ports)"
fi
echo ""

# ============================================================================
# CONFIGURATION INFORMATION
# ============================================================================
echo "--- Configuration Files ---"
echo ""

CONFIG_FILES=(
    "/opt/apps/roboticsservice/setting.ini"
    "./setting.ini"
    "RoboticsService/Redistributable/linux/setting.ini"
)

CONFIG_FOUND=false
for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        CONFIG_FOUND=true
        echo "Found: $config"
        echo "Last modified: $(stat -c %y "$config" 2>/dev/null || stat -f %Sm "$config" 2>/dev/null)"
        echo ""
        echo "--- Content (relevant sections) ---"
        
        if grep -q "^\[Service\]" "$config"; then
            echo "[Service] Section:"
            sed -n '/^\[Service\]/,/^\[/p' "$config" | head -n -1
            echo ""
        fi
        
        if grep -q "^\[TCP\]" "$config"; then
            echo "[TCP] Section:"
            sed -n '/^\[TCP\]/,/^\[/p' "$config" | head -n -1
            echo ""
        fi
        
        if [ "$VERBOSE" = true ]; then
            echo "--- Full File Content ---"
            cat "$config"
            echo ""
        fi
        break
    fi
done

if [ "$CONFIG_FOUND" = false ]; then
    echo "No setting.ini found in standard locations"
fi
echo ""

# ============================================================================
# LIBRARY AND DEPENDENCY INFORMATION
# ============================================================================
echo "--- Library Dependencies ---"
echo ""

if command -v ldd &> /dev/null && [ -f /opt/apps/roboticsservice/RoboticsServiceProcess ]; then
    echo "Checking /opt/apps/roboticsservice/RoboticsServiceProcess dependencies:"
    ldd /opt/apps/roboticsservice/RoboticsServiceProcess 2>/dev/null | grep -E "(grpc|ssl|crypto|qt)" || echo "  (Could not analyze dependencies)"
elif [ -f ./build/RoboticsService/Redistributable/linux/RoboticsServiceProcess ]; then
    echo "Checking build output binary dependencies:"
    ldd ./build/RoboticsService/Redistributable/linux/RoboticsServiceProcess 2>/dev/null | grep -E "(grpc|ssl|crypto|qt)" || echo "  (Could not analyze dependencies)"
else
    echo "RoboticsServiceProcess binary not found"
fi
echo ""

# ============================================================================
# RECENT ERRORS AND LOGS
# ============================================================================
echo "--- Recent System Logs ---"
echo ""

if command -v journalctl &> /dev/null; then
    echo "Recent systemd journal entries for RoboticsServiceProcess:"
    journalctl -u roboticsservice -n 10 2>/dev/null || echo "  (No journal entries for roboticsservice service)"
    echo ""
fi

if [ -f /var/log/syslog ]; then
    echo "Recent syslog entries mentioning robotics:"
    tail -20 /var/log/syslog 2>/dev/null | grep -i robotics || echo "  (No recent robotics-related syslog entries)"
elif [ -f /var/log/system.log ]; then
    echo "Recent system log entries mentioning robotics:"
    tail -20 /var/log/system.log 2>/dev/null | grep -i robotics || echo "  (No recent robotics-related log entries)"
fi
echo ""

# ============================================================================
# CONNECTIVITY TEST
# ============================================================================
echo "--- Network Connectivity Tests ---"
echo ""

echo "DNS resolution test:"
if command -v nslookup &> /dev/null; then
    nslookup localhost 2>/dev/null | head -5 || echo "  (DNS test failed)"
fi
echo ""

echo "Loopback connectivity:"
ping -c 1 127.0.0.1 &>/dev/null && echo "  ✓ Loopback (127.0.0.1) is reachable" || echo "  ✗ Loopback test failed"
echo ""

echo "Port connectivity test (localhost):"
for port in 60061 63901; do
    if timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        echo "  ✓ TCP port $port is accessible on localhost"
    else
        echo "  ✗ TCP port $port is NOT accessible on localhost"
    fi
done
echo ""

# ============================================================================
# RECOMMENDATIONS
# ============================================================================
echo "================================================================================"
echo "Diagnostic Complete"
echo "================================================================================"
echo ""
echo "Recommendations for troubleshooting:"
echo ""
echo "1. If service is NOT running:"
echo "   - Start it with: /opt/apps/roboticsservice/runService.sh"
echo "   - Or check build directory: ./build/RoboticsService/Redistributable/linux/"
echo ""
echo "2. If ports are NOT listening:"
echo "   - Verify service started successfully"
echo "   - Check for error messages in stdout/stderr"
echo "   - Ensure no other process is using these ports:"
echo "     sudo lsof -i :60061"
echo "     sudo lsof -i :63901"
echo ""
echo "3. If firewall rules are missing:"
echo "   - Add UFW rules:"
echo "     sudo ufw allow 60061/tcp"
echo "     sudo ufw allow 63901/tcp"
echo "     sudo ufw allow 29888/udp"
echo ""
echo "4. Configuration issues:"
echo "   - Verify setting.ini has:"
echo "     [Service]"
echo "     listenAddr=0.0.0.0"
echo "     listenPort=60061"
echo ""
echo "     [TCP]"
echo "     BroadCastSendPort=29888"
echo "     TcpBindPort=63901"
echo ""
echo "5. Meta Quest 3 connection:"
echo "   - Ensure Quest is on SAME WiFi network"
echo "   - Close and relaunch the remote app"
echo "   - Check that your Ubuntu IP is in the same subnet"
echo ""

if [ -n "$EXPORT_FILE" ]; then
    echo ""
    echo "Diagnostic report saved to: $EXPORT_FILE"
fi
