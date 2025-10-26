#!/bin/bash

################################################################################
# PXREA PC Service Verification Script
# 
# This script verifies that the PXREA PC Service is properly configured and
# ready to accept connections from Meta Quest 3 devices on Ubuntu/Linux.
#
# Usage: bash verify_pxrea_setup.sh
# 
# Requirements:
#   - Service installed at /opt/apps/roboticsservice/ (for Ubuntu binary)
#   - Or compiled and running in build directory
#   - UFW firewall (or manual port forwarding configured)
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0

# Helper functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((CHECKS_PASSED++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((CHECKS_FAILED++))
}

print_info() {
    echo -e "  $1"
}

echo ""
print_header "PXREA PC Service Verification"
echo ""

# ============================================================================
# 1. SERVICE STATUS CHECK
# ============================================================================
print_header "1. Service Status"

if pgrep -x "RoboticsServiceProcess" > /dev/null; then
    PID=$(pgrep -x RoboticsServiceProcess)
    UPTIME=$(ps -p $PID -o etime= 2>/dev/null || echo "unknown")
    print_success "RoboticsServiceProcess is RUNNING"
    print_info "PID: $PID"
    print_info "Uptime: $UPTIME"
else
    print_error "RoboticsServiceProcess is NOT running"
    print_info "Start the service with: /opt/apps/roboticsservice/runService.sh"
fi
echo ""

# ============================================================================
# 2. PORT LISTENING CHECK
# ============================================================================
print_header "2. Port Listening Status"

# Check TCP 60061 (gRPC Server)
if sudo ss -tulpn 2>/dev/null | grep -q ":60061"; then
    print_success "TCP 60061 (gRPC Server) is LISTENING"
    print_info "$(sudo ss -tulpn 2>/dev/null | grep 60061 | head -1)"
else
    print_error "TCP 60061 (gRPC Server) is NOT listening"
fi

# Check TCP 63901 (Device Connection)
if sudo ss -tulpn 2>/dev/null | grep -q ":63901"; then
    print_success "TCP 63901 (Device Connection) is LISTENING"
    print_info "$(sudo ss -tulpn 2>/dev/null | grep 63901 | head -1)"
else
    print_error "TCP 63901 (Device Connection) is NOT listening"
fi

# Check UDP 29888 (Device Discovery)
# Note: UDP sockets may not appear in ss output if not in LISTEN state
# This is normal - the service broadcasts on this port
print_info "UDP 29888 (Device Discovery) - Broadcasting (no LISTEN required)"

echo ""

# ============================================================================
# 3. FIREWALL CONFIGURATION CHECK
# ============================================================================
print_header "3. Firewall Configuration"

FIREWALL_ACTIVE=$(sudo ufw status 2>/dev/null | grep -q "Status: active" && echo "yes" || echo "no")

if [ "$FIREWALL_ACTIVE" = "yes" ]; then
    print_success "UFW Firewall is ACTIVE"
    
    if sudo ufw status 2>/dev/null | grep -q "60061/tcp"; then
        print_success "TCP 60061 rule found"
    else
        print_warning "TCP 60061 rule NOT found - Run: sudo ufw allow 60061/tcp"
    fi
    
    if sudo ufw status 2>/dev/null | grep -q "63901/tcp"; then
        print_success "TCP 63901 rule found"
    else
        print_warning "TCP 63901 rule NOT found - Run: sudo ufw allow 63901/tcp"
    fi
    
    if sudo ufw status 2>/dev/null | grep -q "29888/udp"; then
        print_success "UDP 29888 rule found"
    else
        print_warning "UDP 29888 rule NOT found - Run: sudo ufw allow 29888/udp"
    fi
else
    print_warning "UFW Firewall is NOT active"
    print_info "If firewall is disabled, ensure other rules don't block these ports:"
    print_info "  - TCP 60061 (gRPC Server)"
    print_info "  - TCP 63901 (Device Connection)"
    print_info "  - UDP 29888 (Device Discovery)"
fi
echo ""

# ============================================================================
# 4. CONFIGURATION FILE CHECK
# ============================================================================
print_header "4. Configuration File"

CONFIG_FILE=""
if [ -f /opt/apps/roboticsservice/setting.ini ]; then
    CONFIG_FILE="/opt/apps/roboticsservice/setting.ini"
elif [ -f "$(pwd)/setting.ini" ]; then
    CONFIG_FILE="$(pwd)/setting.ini"
elif [ -f "./RoboticsService/Redistributable/linux/setting.ini" ]; then
    CONFIG_FILE="./RoboticsService/Redistributable/linux/setting.ini"
fi

if [ -z "$CONFIG_FILE" ]; then
    print_error "setting.ini NOT found"
    print_info "Expected locations:"
    print_info "  - /opt/apps/roboticsservice/setting.ini"
    print_info "  - ./setting.ini"
else
    print_success "setting.ini found at: $CONFIG_FILE"
    
    # Check [Service] section
    if grep -q "^\[Service\]" "$CONFIG_FILE"; then
        LISTEN_ADDR=$(grep "listenAddr" "$CONFIG_FILE" | cut -d= -f2)
        LISTEN_PORT=$(grep "listenPort" "$CONFIG_FILE" | cut -d= -f2)
        
        if [ "$LISTEN_ADDR" = "0.0.0.0" ]; then
            print_success "listenAddr is correctly set to 0.0.0.0"
        else
            print_warning "listenAddr is set to: $LISTEN_ADDR (should be 0.0.0.0)"
        fi
        
        print_info "[Service] listenPort: $LISTEN_PORT"
    else
        print_error "[Service] section NOT found in setting.ini"
    fi
    
    # Check [TCP] section
    if grep -q "^\[TCP\]" "$CONFIG_FILE"; then
        print_success "[TCP] section found"
        BROADCAST_PORT=$(grep "BroadCastSendPort" "$CONFIG_FILE" | cut -d= -f2)
        TCP_BIND_PORT=$(grep "TcpBindPort" "$CONFIG_FILE" | cut -d= -f2)
        print_info "  BroadCastSendPort: $BROADCAST_PORT"
        print_info "  TcpBindPort: $TCP_BIND_PORT"
    else
        print_warning "[TCP] section NOT found (Linux typically doesn't have this)"
    fi
fi
echo ""

# ============================================================================
# 5. NETWORK INTERFACE CHECK
# ============================================================================
print_header "5. Network Configuration"

if command -v hostname &> /dev/null; then
    IPS=$(hostname -I)
    if [ -z "$IPS" ]; then
        print_warning "No IP addresses detected"
    else
        print_success "Network interfaces detected:"
        for ip in $IPS; do
            print_info "  - $ip"
        done
    fi
else
    print_warning "hostname command not found"
fi
echo ""

# ============================================================================
# 6. COMPILATION CHECK (for development environments)
# ============================================================================
print_header "6. Build Status (Development)"

if [ -f "./RoboticsService/Redistributable/linux/RoboticsServiceProcess" ] || \
   [ -f "./build/RoboticsService/Redistributable/linux/RoboticsServiceProcess" ]; then
    print_success "RoboticsServiceProcess binary found"
elif [ ! -f /opt/apps/roboticsservice/RoboticsServiceProcess ]; then
    print_warning "RoboticsServiceProcess binary not found in expected locations"
    print_info "For binary installation: /opt/apps/roboticsservice/RoboticsServiceProcess"
    print_info "For development build: ./build/RoboticsService/Redistributable/linux/RoboticsServiceProcess"
fi
echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print_header "Summary"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo ""
    print_success "All checks PASSED - Service is ready for testing!"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure Meta Quest 3 is on the SAME WiFi network"
    echo "  2. Close the PXREA remote app completely"
    echo "  3. Relaunch the app on Meta Quest 3"
    echo "  4. The PC Service should appear in the device list"
    echo ""
else
    echo ""
    print_warning "Some checks need attention - see above for details"
    echo ""
fi

# Summary statistics
echo "Results: ${GREEN}$CHECKS_PASSED passed${NC}, ${RED}$CHECKS_FAILED failed${NC}"
echo ""

# Return appropriate exit code
[ $CHECKS_FAILED -eq 0 ] && exit 0 || exit 1
