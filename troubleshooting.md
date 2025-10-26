
Troubleshooting
===

### Connection Issues on Ubuntu/Linux

If the PC Service fails to connect to your Meta Quest 3 device on Ubuntu 22.04 (while it works on Windows), follow these troubleshooting steps:

#### Issue: Service Not Discoverable on Network

**Symptoms:**
- The Android remote app cannot find or connect to the PC service
- Connection works on Windows but not on Linux

**Root Cause:**
The Linux `setting.ini` files were missing critical TCP configuration and the gRPC server was bound to localhost only (127.0.0.1).

**Solution:**

1. **Verify `setting.ini` Configuration**
   
   Check your `setting.ini` file (typically located in the application directory) and ensure it contains:
   
   ```ini
   [TCP]
   BroadCastSendPort=29888
   TcpBindPort=63901
   
   [Service]
   listenAddr=0.0.0.0
   listenPort=60061
   ```
   
   **Key Points:**
   - `listenAddr=0.0.0.0` ensures the service listens on all network interfaces (not just localhost)
   - `listenPort=60061` is the gRPC server port
   - `TcpBindPort=63901` is the TCP device connection port
   - `BroadCastSendPort=29888` is the UDP broadcast port for device discovery

2. **Check Firewall Rules**
   
   Ensure the required ports are open on your Ubuntu machine:
   
   ```bash
   # Check current firewall status
   sudo ufw status
   
   # If UFW is enabled, allow the required ports:
   sudo ufw allow 29888/udp comment "PXREA UDP Broadcast"
   sudo ufw allow 63901/tcp comment "PXREA TCP Device Connection"
   sudo ufw allow 60061/tcp comment "PXREA gRPC Server"
   
   # Verify the rules were added:
   sudo ufw status numbered
   ```
   
   **If using iptables instead of UFW:**
   
   ```bash
   # Check listening ports
   sudo ss -tulpn | grep -E '(29888|63901|60061)'
   
   # Add iptables rules if needed
   sudo iptables -I INPUT -p tcp --dport 60061 -j ACCEPT
   sudo iptables -I INPUT -p tcp --dport 63901 -j ACCEPT
   sudo iptables -I INPUT -p udp --dport 29888 -j ACCEPT
   
   # Make rules persistent (if using iptables-persistent)
   sudo iptables-save | sudo tee /etc/iptables/rules.v4
   ```

3. **Verify Network Connectivity**
   
   Check your Ubuntu machine's network configuration:
   
   ```bash
   # Get your machine's IP address
   hostname -I
   
   # Verify the service is listening on the correct interface
   sudo ss -tulpn | grep -E 'LISTEN.*:(60061|63901)'
   ```
   
   Expected output should show listening on `0.0.0.0` or your specific IP address, NOT just `127.0.0.1`.

4. **Enable Service Debugging**
   
   Check the application logs to diagnose connection issues:
   
   ```bash
   # If logs are being written to file (logToFile=1 in setting.ini):
   tail -f log.txt
   
   # Look for error messages related to:
   # - "tcp server listen failed"
   # - "udp socket error"
   # - "grpc server bind failed"
   ```

#### Debugging Network Issues

If connection still fails, perform these diagnostic checks:

```bash
# 1. Check if ports are in TIME_WAIT state (might need to wait or restart service)
sudo netstat -tulpn | grep -E '(29888|63901|60061)'

# 2. Verify UDP broadcast is working
# From Ubuntu machine, check if broadcasts are being sent:
sudo tcpdump -i any -n udp port 29888

# 3. Check network interface state
ip link show
ip addr show

# 4. Check firewall logs (if using UFW)
sudo tail -f /var/log/ufw.log

# 5. Verify hostname resolution
hostname -I
nslookup localhost
```

#### Network Interface Considerations

If you have multiple network interfaces, the application automatically detects and broadcasts from all non-loopback interfaces. However:

- **Ensure your Meta Quest 3 is on the same network subnet** as your Ubuntu machine
- If using VPN or multiple networks, ensure both devices are on the same subnet
- Some corporate networks block UDP broadcasts on port 29888—check with your IT

#### Ubuntu 22.04 Specific Notes

**Netplan (default networking)**
If using netplan on Ubuntu 22.04, ensure your network configuration is correct:

```bash
# Check netplan configuration
cat /etc/netplan/*.yaml

# To apply changes:
sudo netplan apply
```

**AppArmor/SELinux**
If AppArmor is blocking the application:

```bash
# Check AppArmor status
sudo aa-status

# View AppArmor denials
sudo tail -f /var/log/syslog | grep apparmor
```

#### After Making Changes

1. **Restart the service:**
   ```bash
   # Kill existing process
   pkill -f "RoboticsServiceProcess" || pkill -f "RobotDemoQt" || true
   
   # Wait a few seconds
   sleep 3
   
   # Restart the service
   ./runService.sh  # or your launch script
   ```

2. **Restart the Meta Quest 3 app:**
   - Close the Android remote app completely
   - Wait 5 seconds
   - Relaunch the remote app

3. **Verify connectivity:**
   - The device should appear in the device list
   - Check the application logs for confirmation

#### Windows vs Linux Differences

| Feature | Windows | Linux |
| --- | --- | --- |
| Default `listenAddr` | Works with both 127.0.0.1 and 0.0.0.0 | Requires 0.0.0.0 for network access |
| TCP Configuration | Fully specified in setting.ini | Was missing [TCP] section (now fixed) |
| Firewall | Windows Defender manages rules | UFW/iptables must be configured manually |
| Network Discovery | More permissive defaults | Requires explicit configuration |


