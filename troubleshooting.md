
Troubleshooting
===

## Quick Start — Use `setup.sh`

Instead of manually diagnosing issues, run the bundled setup script which checks all prerequisites, auto-fixes what it can, and then launches the service:

```bash
cd /opt/apps/roboticsservice

# Non-sudo mode: checks and auto-fixes anything writable by your user
./setup.sh

# Sudo mode: additionally installs apt packages and opens firewall ports
./setup.sh y
```

The script covers: Qt bundled libs, XCB platform plugin, `libxcb-cursor0`, QML modules, display/DISPLAY, NVIDIA PRIME setup, binary deps, `setting.ini`, and UFW firewall ports.

Only refer to the sections below if `setup.sh` reports specific errors you need to fix manually.

---

### Segfault / Crash when running `run2D.sh` or `run3D.sh` on Ubuntu 22.04

#### Issue: `RobotDemoQt` or `RobotLinuxDemo.x86_64` segfaults immediately at launch

**Symptoms:**
- Running `./run2D.sh` or `./run3D.sh` results in an immediate segfault
- Error message such as:
  ```
  /opt/apps/roboticsservice/RobotDemoQt: /lib/x86_64-linux-gnu/libQt6Core.so.6: version 'Qt_6.6' not found
  ```
  or a silent crash with no output
- `RoboticsServiceProcess` (the background service) may start fine, but the Qt GUI frontend crashes

**Root Cause:**

The binary was compiled against **Qt 6.6.3** but Ubuntu 22.04 ships **Qt 6.2.4** as the system library. There are two compounding problems in older builds of the deb package:

1. **Qt version mismatch**: Running the binary without the correct `LD_LIBRARY_PATH` causes the system linker to pick up system Qt 6.2.4 (`/lib/x86_64-linux-gnu/libQt6Core.so.6`) instead of the bundled Qt 6.6.3 in `/opt/apps/roboticsservice/lib/`. The binary then fails at startup because it requires the `Qt_6.6` symbol version.

2. **Missing Qt Quick/Qml libs**: The older deb package's `lib/` directory only included core Qt libs (`libQt6Core`, `libQt6Network`, `libQt6DBus`, etc.) but was **missing** the Qt Quick/QML libraries that `RobotDemoQt` requires:
   - `libQt6Qml.so.6`
   - `libQt6QmlModels.so.6`
   - `libQt6QmlWorkerScript.so.6`
   - `libQt6Quick.so.6`
   - `libQt6QuickControls2.so.6`
   - `libQt6QuickTemplates2.so.6`
   - `libQt6Gui.so.6`
   - `libQt6OpenGL.so.6`
   - `libQt6ShaderTools.so.6`
   - `libQt6Multimedia.so.6`
   - `libQt6MultimediaQuick.so.6`
   
   Even with the correct `LD_LIBRARY_PATH`, these fall back to system Qt 6.2.4 (or are not found at all), causing a version mismatch segfault.

---

#### Still crashing after the deb fix? Missing `libQt6XcbQpa`

The previous deb fix added the Qt Quick/QML/Multimedia libs but missed **`libQt6XcbQpa`** — the Qt XCB QPA support library that `plugins/platforms/libqxcb.so` depends on. Without it, the XCB platform plugin falls through to the system Qt 6.2.4 version and crashes.

**Diagnosis** — run this to confirm:
```bash
LD_LIBRARY_PATH=/opt/apps/roboticsservice:/opt/apps/roboticsservice/lib:/opt/apps/roboticsservice/SDK/x64 \
  ldd /opt/apps/roboticsservice/plugins/platforms/libqxcb.so | grep Qt6
# PROBLEM: libQt6XcbQpa.so.6 => /lib/x86_64-linux-gnu/...  (system, not bundled)
# FIXED:   libQt6XcbQpa.so.6 => /opt/apps/roboticsservice/lib/...
```

**Quick fix** (no rebuild needed — requires Qt 6.6.3 at `~/Qt6`):
```bash
sudo cp -P ~/Qt6/6.6.3/gcc_64/lib/libQt6XcbQpa.so* /opt/apps/roboticsservice/lib/
```

The `CMakeLists.txt` in this repo has been updated to include `libQt6XcbQpa` for future builds.

**Verify the fix:**
```bash
LD_LIBRARY_PATH=/opt/apps/roboticsservice:/opt/apps/roboticsservice/lib:/opt/apps/roboticsservice/SDK/x64 \
  ldd /opt/apps/roboticsservice/plugins/platforms/libqxcb.so | grep -E "Qt6.*system|not found"
# Should print nothing
./run2D.sh   # should launch without crash
```

---

#### Fix: Install the Updated Deb Package (Recommended)

The `CMakeLists.txt` has been fixed to bundle all required Qt libs (including `libQt6XcbQpa`). **Build and install the updated deb** from source:

**Step 1 — Install Qt 6.6.3 via aqtinstall** (if not already present):
```bash
pip install aqtinstall
aqt install-qt linux desktop 6.6.3 gcc_64 \
  -m qtmultimedia qtshadertools qt5compat \
  --outputdir ~/Qt6
```

**Step 2 — Build the package:**
```bash
cd /path/to/XRoboToolkit-PC-Service/RoboticsService
# Edit qt-gcc.sh and ensure QT_DIR points to your Qt install, e.g.:
#   QT_DIR=/home/$USER/Qt6/6.6.3/gcc_64
./qt-gcc.sh 1
```
> **Note:** Do not pass `--clean` as an argument to `qt-gcc.sh` — it breaks the build number parsing. Instead, manually remove the build directory and run `./qt-gcc.sh 1` with just the build number.

**Step 3 — Package into a deb:**
```bash
cd Package/debPack
chmod +x setup.sh
./setup.sh
# Output: Package/output/XRoboToolkit-PC-Service_1.0.0.0_amd64.deb
```

**Step 4 — Install:**
```bash
sudo dpkg -i Package/output/XRoboToolkit-PC-Service_1.0.0.0_amd64.deb
# Fix any dependency issues if needed:
sudo apt-get install -f
```

**Step 5 — Verify:**
```bash
LD_LIBRARY_PATH=/opt/apps/roboticsservice:/opt/apps/roboticsservice/lib:/opt/apps/roboticsservice/SDK/x64 \
  ldd /opt/apps/roboticsservice/RobotDemoQt | grep "not found"
# Should print nothing (all libs resolved)
```

---

#### Quick Fix: Manually copy missing Qt libs (without rebuilding)

If you have Qt 6.6.x installed via aqtinstall at `~/Qt6/6.6.3/gcc_64/`, you can copy the missing libs directly:

```bash
QT_LIB=~/Qt6/6.6.3/gcc_64/lib
INSTALL_LIB=/opt/apps/roboticsservice/lib

# Copy missing Qt Quick/Qml/Multimedia libs
sudo cp -P \
  $QT_LIB/libQt6Gui.so* \
  $QT_LIB/libQt6OpenGL.so* \
  $QT_LIB/libQt6ShaderTools.so* \
  $QT_LIB/libQt6Qml.so* \
  $QT_LIB/libQt6QmlModels.so* \
  $QT_LIB/libQt6QmlWorkerScript.so* \
  $QT_LIB/libQt6QmlCompiler.so* \
  $QT_LIB/libQt6QmlCore.so* \
  $QT_LIB/libQt6Quick.so* \
  $QT_LIB/libQt6QuickControls2.so* \
  $QT_LIB/libQt6QuickTemplates2.so* \
  $QT_LIB/libQt6Multimedia.so* \
  $QT_LIB/libQt6MultimediaQuick.so* \
  $INSTALL_LIB/

# Copy required QML modules
QT_QML=~/Qt6/6.6.3/gcc_64/qml
INSTALL_QML=/opt/apps/roboticsservice/qml
sudo cp -rP $QT_QML/QtQml $INSTALL_QML/
sudo cp -rP $QT_QML/QtQuick $INSTALL_QML/
sudo cp -rP $QT_QML/QtMultimedia $INSTALL_QML/

# Copy required plugins
QT_PLUGINS=~/Qt6/6.6.3/gcc_64/plugins
INSTALL_PLUGINS=/opt/apps/roboticsservice/plugins
sudo cp -rP $QT_PLUGINS/imageformats $INSTALL_PLUGINS/
sudo cp -rP $QT_PLUGINS/multimedia   $INSTALL_PLUGINS/
```

Then verify:
```bash
LD_LIBRARY_PATH=/opt/apps/roboticsservice:/opt/apps/roboticsservice/lib:/opt/apps/roboticsservice/SDK/x64 \
  ldd /opt/apps/roboticsservice/RobotDemoQt | grep "not found"
```

---

#### Why `run2D.sh` / `run3D.sh` must always be used (never run binaries directly)

The scripts set three critical environment variables before launching any binary:

```bash
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DIR:$DIR/lib:$DIR/SDK/x64
export QT_PLUGIN_PATH=$DIR/plugins/
export QT_QML_PATH=$DIR/qml/
```

| Variable | Purpose |
|----------|---------|
| `LD_LIBRARY_PATH` | Points the dynamic linker at the bundled Qt 6.6.3 libs **before** system Qt 6.2.4 |
| `QT_PLUGIN_PATH` | Tells Qt where to find platform, image, multimedia, and input plugins |
| `QT_QML_PATH` | Tells the QML engine where to find QML module files (`.qmltypes`, `.so`) |

**Running `./RobotDemoQt` directly** (without the script) means none of these are set, so:
- The system linker picks up `/lib/x86_64-linux-gnu/libQt6Core.so.6` (Qt 6.2.4) first
- The binary requires `Qt_6.6` symbol version → immediate crash

**Always launch via the scripts:**
```bash
cd /opt/apps/roboticsservice
./run2D.sh    # runs RoboticsServiceProcess + RobotDemoQt (2D Qt GUI frontend)
./run3D.sh    # runs RoboticsServiceProcess + RobotLinuxDemo.x86_64 (Unity 3D frontend)
./runService.sh  # runs RoboticsServiceProcess only (headless, for SDK use)
```

---

#### Diagnosing library issues

```bash
# Check which Qt version the binary requires
objdump -p /opt/apps/roboticsservice/RobotDemoQt | grep Qt_6

# Check which libs are missing (with correct LD path)
LD_LIBRARY_PATH=/opt/apps/roboticsservice:/opt/apps/roboticsservice/lib:/opt/apps/roboticsservice/SDK/x64 \
  ldd /opt/apps/roboticsservice/RobotDemoQt | grep "not found"

# Check which Qt version is bundled
strings /opt/apps/roboticsservice/lib/libQt6Core.so.6 | grep "^6\." | head -3

# Check system Qt version
dpkg -l libqt6core6 | tail -1
```

Expected healthy output from the `ldd` check: **(no output / empty)** — all libs resolved.

---



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


