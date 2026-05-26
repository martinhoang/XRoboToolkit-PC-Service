# PXREA PC Service Utilities

This directory contains helper scripts for setting up, verifying, and diagnosing the PXREA PC Service on Ubuntu/Linux systems.

## Quick Start

### For First-Time Setup:
```bash
cd Utils
sudo bash setup_pxrea_linux.sh
```

### To Verify Current Setup:
```bash
bash verify_pxrea_setup.sh
```

### To Diagnose Issues:
```bash
bash diagnose_pxrea.sh --verbose
bash diagnose_pxrea.sh --export diagnostics.txt
```

## Scripts

### 1. `setup_pxrea_linux.sh` - Initial Setup (Recommended for first-time setup)

Automated setup script that configures the service for Linux/Ubuntu.

**What it does:**
- Verifies PXREA service installation
- Configures firewall rules (UFW/iptables)
- Updates `setting.ini` with correct network parameters
- Stops any existing service instances
- Starts the service
- Performs verification

**Requirements:**
- Run with `sudo`
- Ubuntu 22.04 or later (or compatible Linux)
- Service installed at `/opt/apps/roboticsservice/` or in source directory

**Features:**
- Automatic firewall configuration
- Creates backup of original `setting.ini`
- Detailed progress output with color coding
- Handles both UFW and iptables firewalls

**Usage:**
```bash
sudo bash setup_pxrea_linux.sh
```

---

### 2. `verify_pxrea_setup.sh` - Quick Verification

Verifies that the PXREA PC Service is properly configured and running.

**What it checks:**
- ✓ Service process status
- ✓ Required ports (60061, 63901) are listening
- ✓ Firewall rules are configured
- ✓ Configuration file settings
- ✓ Network interfaces

**Usage:**
```bash
bash verify_pxrea_setup.sh
```

**Output:**
- Color-coded results (green for pass, red for fail)
- Detailed port information
- Configuration verification
- Overall readiness status

**Exit codes:**
- `0` - All checks passed, setup is complete
- `1` - Some checks failed, see output for details

---

### 3. `diagnose_pxrea.sh` - Detailed Diagnostics

Comprehensive diagnostic tool for troubleshooting connection issues.

**What it reports:**
- System information (OS, kernel, architecture)
- Service process details
- Listening ports and network status
- All network interfaces and IP addresses
- Firewall configuration (UFW and iptables)
- Configuration file settings
- Library dependencies
- Recent system logs
- Network connectivity tests
- Recommendations for troubleshooting

**Usage:**
```bash
# Standard diagnosis
bash diagnose_pxrea.sh

# Verbose output with full file contents
bash diagnose_pxrea.sh --verbose

# Export diagnosis to file
bash diagnose_pxrea.sh --export /tmp/pxrea_diagnosis.txt
```

**Options:**
- `--verbose` - Include full file contents and detailed analysis
- `--export FILE` - Save output to specified file

---

## Common Tasks

### First-time Setup
```bash
# 1. Run the automated setup
sudo bash setup_pxrea_linux.sh

# 2. Verify it worked
bash verify_pxrea_setup.sh
```

### Daily Verification
```bash
# Check if service is running and ready
bash verify_pxrea_setup.sh
```

### Troubleshooting Connection Issues
```bash
# Get detailed diagnostic information
bash diagnose_pxrea.sh --verbose

# Export for sharing with support
bash diagnose_pxrea.sh --export /tmp/pxrea_diag.txt
```

### Manual Firewall Configuration (if needed)
```bash
# Allow firewall rules manually
sudo ufw allow 60061/tcp comment "PXREA gRPC Server"
sudo ufw allow 63901/tcp comment "PXREA TCP Device Connection"
sudo ufw allow 29888/udp comment "PXREA UDP Broadcast"
```

### Start Service Manually
```bash
# If service is not running
/opt/apps/roboticsservice/runService.sh

# Or from source
cd RoboticsService/Redistributable/linux
bash runService.sh
```

### Check Service Logs
```bash
# Real-time log viewing
tail -f /opt/apps/roboticsservice/roboticsservice.log

# Or if running in background
tail -f log.txt
```

---

## Troubleshooting

### Service won't start
```bash
# Check logs
tail -f /opt/apps/roboticsservice/roboticsservice.log

# Verify binary exists
ls -la /opt/apps/roboticsservice/RoboticsServiceProcess

# Check for port conflicts
sudo ss -tulpn | grep -E "(60061|63901)"
```

### Firewall issues
```bash
# Check UFW status
sudo ufw status numbered

# If UFW is not active
sudo ufw enable

# Verify rules
sudo ufw status | grep PXREA
```

### Meta Quest 3 can't find service
1. Verify on same WiFi network: `hostname -I`
2. Ensure service is running: `bash verify_pxrea_setup.sh`
3. Check ports are listening: `sudo ss -tulpn | grep -E "(60061|63901)"`
4. Close and relaunch app on Quest 3
5. Run diagnostics: `bash diagnose_pxrea.sh --verbose`

### Configuration issues
```bash
# Check current configuration
cat /opt/apps/roboticsservice/setting.ini

# Restore backup if needed
sudo cp /opt/apps/roboticsservice/setting.ini.backup /opt/apps/roboticsservice/setting.ini
```

---

## File Locations

- **Service binary:** `/opt/apps/roboticsservice/RoboticsServiceProcess`
- **Configuration:** `/opt/apps/roboticsservice/setting.ini`
- **Logs:** `/opt/apps/roboticsservice/roboticsservice.log` or `log.txt` in working directory
- **Launch script:** `/opt/apps/roboticsservice/runService.sh`

---

## Key Ports

- **60061/TCP** - gRPC Server (client communication)
- **63901/TCP** - Device Connection (TCP/IP communication)
- **29888/UDP** - Device Discovery (broadcast announcements)

All ports must be:
1. Opened in the firewall
2. Accessible from the Meta Quest 3 device
3. On the same network subnet

---

## Network Requirements

For Meta Quest 3 to discover and connect to the PC Service:

1. **Same Network:** Both devices must be on the same WiFi network
2. **Same Subnet:** Preferably same network subnet (e.g., 192.168.1.x)
3. **No VPN/Proxy:** Direct network connection required
4. **Firewall:** Required ports must be open

---

## Support

If you encounter issues:

1. Run `verify_pxrea_setup.sh` to check basic configuration
2. Run `diagnose_pxrea.sh --verbose` for detailed information
3. Export diagnostics: `diagnose_pxrea.sh --export diag.txt`
4. Check the README in the main repository for additional help
5. Review the troubleshooting section in the main README.md

---

## Version History

- **v1.0** (Oct 26, 2025) - Initial release
  - Added setup_pxrea_linux.sh for automated configuration
  - Added verify_pxrea_setup.sh for quick verification
  - Added diagnose_pxrea.sh for comprehensive diagnostics
  - Added this README

---

## License

These utility scripts are part of the XRoboToolkit-PC-Service project.
See the main repository LICENSE for terms.
