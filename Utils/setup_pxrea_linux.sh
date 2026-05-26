#!/bin/bash

################################################################################
# PXREA PC Service Quick Start Script for Linux
#
# This script automates the setup process for running the PXREA PC Service
# on Ubuntu/Linux for Meta Quest 3 connections.
#
# Usage: sudo bash setup_pxrea_linux.sh
#
# What it does:
#   1. Configures firewall rules (UFW)
#   2. Verifies setting.ini configuration
#   3. Starts the service
#   4. Performs initial verification
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║         PXREA PC Service Setup for Ubuntu/Linux                            ║"
echo "║                                                                            ║"
echo "║  This script will configure your Ubuntu machine to allow Meta Quest 3      ║"
echo "║  devices to connect to the PXREA PC Service.                              ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ============================================================================
# STEP 1: Check prerequisites
# ============================================================================
echo -e "${BLUE}Step 1: Checking Prerequisites...${NC}"
echo ""

if ! command -v ss &> /dev/null; then
    echo -e "${RED}✗ 'ss' command not found. Please install iproute2:${NC}"
    echo "  sudo apt-get update && sudo apt-get install -y iproute2"
    exit 1
fi

if ! command -v ufw &> /dev/null; then
    echo -e "${YELLOW}⚠ UFW firewall not found. Using sudo iptables instead.${NC}"
    USE_IPTABLES=true
else
    echo -e "${GREEN}✓ UFW firewall found${NC}"
    USE_IPTABLES=false
fi

echo ""

# ============================================================================
# STEP 2: Verify service installation
# ============================================================================
echo -e "${BLUE}Step 2: Verifying Service Installation...${NC}"
echo ""

SERVICE_PATH=""
if [ -f /opt/apps/roboticsservice/RoboticsServiceProcess ]; then
    SERVICE_PATH="/opt/apps/roboticsservice"
    echo -e "${GREEN}✓ Service found at: $SERVICE_PATH${NC}"
elif [ -f ./RoboticsService/Redistributable/linux/RoboticsServiceProcess ]; then
    SERVICE_PATH="./RoboticsService/Redistributable/linux"
    echo -e "${GREEN}✓ Service found at: $SERVICE_PATH${NC}"
else
    echo -e "${RED}✗ RoboticsServiceProcess not found${NC}"
    echo "  Expected location: /opt/apps/roboticsservice/"
    echo "  Or in source directory: ./RoboticsService/Redistributable/linux/"
    exit 1
fi

echo ""

# ============================================================================
# STEP 3: Configure setting.ini
# ============================================================================
echo -e "${BLUE}Step 3: Configuring setting.ini...${NC}"
echo ""

CONFIG_FILE="$SERVICE_PATH/setting.ini"

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ setting.ini not found at: $CONFIG_FILE${NC}"
    exit 1
fi

# Backup original
cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
echo -e "${GREEN}✓ Backup created: ${CONFIG_FILE}.backup${NC}"

# Check and update listenAddr
if grep -q "listenAddr=127.0.0.1" "$CONFIG_FILE"; then
    sed -i 's/listenAddr=127.0.0.1/listenAddr=0.0.0.0/g' "$CONFIG_FILE"
    echo -e "${GREEN}✓ Updated listenAddr to 0.0.0.0${NC}"
elif grep -q "listenAddr=0.0.0.0" "$CONFIG_FILE"; then
    echo -e "${GREEN}✓ listenAddr already set to 0.0.0.0${NC}"
else
    echo -e "${YELLOW}⚠ listenAddr not found, adding it...${NC}"
    # Find [Service] section and add if not present
    if grep -q "^\[Service\]" "$CONFIG_FILE"; then
        sed -i '/^\[Service\]/a listenAddr=0.0.0.0' "$CONFIG_FILE"
    fi
fi

# Verify TCP section
if ! grep -q "^\[TCP\]" "$CONFIG_FILE"; then
    echo -e "${YELLOW}⚠ [TCP] section not found, adding it...${NC}"
    
    # Find a good place to insert [TCP] section (before [Log] if it exists)
    if grep -q "^\[Log\]" "$CONFIG_FILE"; then
        sed -i '/^\[Log\]/i\[TCP]\nBroadCastSendPort=29888\nTcpBindPort=63901' "$CONFIG_FILE"
    else
        echo "[TCP]" >> "$CONFIG_FILE"
        echo "BroadCastSendPort=29888" >> "$CONFIG_FILE"
        echo "TcpBindPort=63901" >> "$CONFIG_FILE"
    fi
    echo -e "${GREEN}✓ Added [TCP] section${NC}"
else
    echo -e "${GREEN}✓ [TCP] section found${NC}"
fi

echo ""

# ============================================================================
# STEP 4: Configure Firewall
# ============================================================================
echo -e "${BLUE}Step 4: Configuring Firewall Rules...${NC}"
echo ""

if [ "$USE_IPTABLES" = false ]; then
    # Use UFW
    ufw allow 60061/tcp comment "PXREA gRPC Server" 2>&1 | grep -E "(added|updated|Rules updated)" && \
        echo -e "${GREEN}✓ UFW rule for port 60061/tcp configured${NC}"
    
    ufw allow 63901/tcp comment "PXREA TCP Device Connection" 2>&1 | grep -E "(added|updated|Rules updated)" && \
        echo -e "${GREEN}✓ UFW rule for port 63901/tcp configured${NC}"
    
    ufw allow 29888/udp comment "PXREA UDP Broadcast" 2>&1 | grep -E "(added|updated|Rules updated)" && \
        echo -e "${GREEN}✓ UFW rule for port 29888/udp configured${NC}"
    
    if ! ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}⚠ UFW is inactive. Enabling it...${NC}"
        echo "y" | ufw enable 2>&1 > /dev/null
        echo -e "${GREEN}✓ UFW enabled${NC}"
    fi
else
    # Use iptables
    iptables -I INPUT -p tcp --dport 60061 -j ACCEPT
    iptables -I INPUT -p tcp --dport 63901 -j ACCEPT
    iptables -I INPUT -p udp --dport 29888 -j ACCEPT
    echo -e "${GREEN}✓ iptables rules configured${NC}"
    
    # Try to save if iptables-persistent is available
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
        echo -e "${GREEN}✓ iptables rules saved${NC}"
    fi
fi

echo ""

# ============================================================================
# STEP 5: Kill existing processes
# ============================================================================
echo -e "${BLUE}Step 5: Cleaning up existing processes...${NC}"
echo ""

if pgrep -f "RoboticsServiceProcess" > /dev/null; then
    echo -e "${YELLOW}⚠ Existing RoboticsServiceProcess found, stopping...${NC}"
    pkill -9 RoboticsServiceProcess
    sleep 2
    echo -e "${GREEN}✓ Service stopped${NC}"
else
    echo -e "${GREEN}✓ No existing process found${NC}"
fi

echo ""

# ============================================================================
# STEP 6: Start the service
# ============================================================================
echo -e "${BLUE}Step 6: Starting Service...${NC}"
echo ""

cd "$SERVICE_PATH"

if [ -f runService.sh ]; then
    echo "Launching: bash runService.sh"
    nohup bash runService.sh > roboticsservice.log 2>&1 &
    SERVICE_PID=$!
    echo -e "${GREEN}✓ Service started (PID: $SERVICE_PID)${NC}"
    sleep 3
else
    echo -e "${YELLOW}⚠ runService.sh not found, attempting direct launch...${NC}"
    nohup ./RoboticsServiceProcess > roboticsservice.log 2>&1 &
    SERVICE_PID=$!
    echo -e "${GREEN}✓ Service started (PID: $SERVICE_PID)${NC}"
    sleep 3
fi

echo ""

# ============================================================================
# STEP 7: Verification
# ============================================================================
echo -e "${BLUE}Step 7: Verifying Setup...${NC}"
echo ""

if ! pgrep -f "RoboticsServiceProcess" > /dev/null; then
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check the log: tail -f $SERVICE_PATH/roboticsservice.log"
    exit 1
fi
echo -e "${GREEN}✓ Service is running${NC}"

if ss -tulpn 2>/dev/null | grep -q ":63901"; then
    echo -e "${GREEN}✓ TCP port 63901 is listening${NC}"
else
    echo -e "${RED}✗ TCP port 63901 is NOT listening${NC}"
fi

if ss -tulpn 2>/dev/null | grep -q ":60061"; then
    echo -e "${GREEN}✓ TCP port 60061 is listening${NC}"
else
    echo -e "${RED}✗ TCP port 60061 is NOT listening${NC}"
fi

echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════════════════════╗"
echo "║                        Setup Complete! ✓                                   ║"
echo "╚════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Your PXREA PC Service is now configured and running!"
echo ""
echo "Next steps:"
echo "  1. Ensure your Meta Quest 3 is on the SAME WiFi network"
echo "  2. Your Ubuntu machine IP(s):"
hostname -I | xargs -I {} echo "     {}"
echo "  3. Close the PXREA app completely on Meta Quest 3"
echo "  4. Relaunch the app - the PC service should appear in the device list"
echo ""
echo "To verify the setup at any time, run:"
echo "  bash $(dirname $0)/verify_pxrea_setup.sh"
echo ""
echo "For detailed diagnostics, run:"
echo "  bash $(dirname $0)/diagnose_pxrea.sh"
echo ""
echo "To view the service log:"
echo "  tail -f $SERVICE_PATH/roboticsservice.log"
echo ""
