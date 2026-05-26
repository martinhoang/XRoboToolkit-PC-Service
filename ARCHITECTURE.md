# XRoboToolkit PC Service — Architecture

## Overview

The PC Service is a Linux/Windows background daemon that bridges VR headsets (PICO/Quest) to robot control software. It discovers headsets on the local network, relays tracking/control JSON, and exposes a C SDK for downstream consumers.

## Components

```
┌─────────────────────────────────────────────────────────┐
│                  RoboticsServiceProcess                  │
│  ┌────────────┐  ┌───────────────┐  ┌────────────────┐  │
│  │  Business  │  │DeviceManagement│  │ PXREAServerAPI │  │
│  │ (app logic)│  │(device list,  │  │  (C SDK entry) │  │
│  └─────┬──────┘  │ state)        │  └───────┬────────┘  │
│        │         └───────┬───────┘          │           │
│  ┌─────▼──────────────────▼──────────────────▼────────┐ │
│  │         libPXREAGRPCServer.so  (internal gRPC)     │ │
│  │         libBusiness.so  (protocol/device logic)    │ │
│  │         libCommonUtils.so  (utilities)             │ │
│  └──────────────────────────┬─────────────────────────┘ │
└─────────────────────────────┼───────────────────────────┘
                              │
        ┌─────────────────────┼──────────────────┐
        │ TCP :63901          │ UDP :29888        │
        │ (device data/cmds)  │ (broadcast disco) │
        └──────────┬──────────┴──────────────────┘
                   │
           VR Headset (PICO / Quest)
```

**Ports:**
| Port  | Protocol | Purpose                        |
|-------|----------|--------------------------------|
| 29888 | UDP      | Broadcast device discovery     |
| 63901 | TCP      | Bidirectional data/command channel |
| 60061 | TCP      | Internal gRPC (SDK → service) |

**Public C SDK** (`SDK/include/PXREARobotSDK.h`):
```c
PXREAInit(context, callback, mask)     // connect + register callback
PXREADeinit()                          // disconnect
PXREADeviceControlJson(devID, json)    // send JSON command to headset
// Tracking data arrives via PXREADeviceStateJson callback as JSON string
```

## Demo Applications

| Binary           | Source                       | Description                          |
|------------------|------------------------------|--------------------------------------|
| `RobotDemoQt`    | `SDKDemo/CppSrc/RobotDemoQt` | Qt Quick GUI — uses SDK, shows pose  |
| `RobotLinuxDemo` | *No source (Unity build)*    | 3D Unity viewer launched by run3D.sh |
| `RobotDataRecorder` | `SDKDemo/CppSrc/`        | Records tracking sessions to disk    |

## Data Flow

1. Headset discovered via UDP broadcast → TCP connection established on port 63901
2. Headset pushes JSON tracking frames (head/controller/hand/body) at configured FPS
3. `Business` layer parses and forwards to registered SDK clients via internal gRPC (port 60061)
4. SDK client receives `PXREADeviceStateJson` callback with JSON payload
5. SDK client sends commands back with `PXREADeviceControlJson`

## Tracking Data (JSON)
All tracking delivered as a single JSON envelope with optional fields:
- **Head** — position + quaternion (7 floats), handMode flag
- **Controller** — left/right: pose, trigger, grip, axes, buttons
- **Hand** — left/right: 26 joints × (pose, status, radius)
- **Body** — 24 joints (requires PICO Swift trackers)
- **Motion** — raw tracker IMU (up to 3 trackers)

## Deployment

Installed to `/opt/apps/roboticsservice/`. Must be launched via `runService.sh` which sets `LD_LIBRARY_PATH` to the bundled Qt 6.6.3 libs. Running the binary directly uses system Qt (6.2.4) → segfault.

---

## Recommendations / Overhaul Suggestions

1. **Drop Qt from the headless service.** `RoboticsServiceProcess` uses `QCoreApplication` (Qt Core) only for event loop and networking. Replace with `libuv`, `boost::asio`, or plain `epoll` + `std::thread`. This eliminates the 100 MB Qt dependency from the deb and the `LD_LIBRARY_PATH` fragility.

2. **Replace internal gRPC with direct callbacks or shared memory.** The single-process internal gRPC (loopback port 60061) adds latency and complexity for no inter-process benefit. A direct callback or shared ring buffer would be simpler and faster.

3. **Expose a ROS 2 node wrapper.** The C SDK (`PXREAInit`/callback) is ideal for a thin `rclcpp` node that publishes tracking data as standard ROS messages (`geometry_msgs/PoseStamped`, `sensor_msgs/JointState`). This would eliminate custom client code for robot control.

4. **Fix `LD_LIBRARY_PATH` prepend order** in `runService.sh` — it appends to the env variable, so any earlier Qt on the path wins. Prepend instead: `export LD_LIBRARY_PATH=$LIB_PATH:$LD_LIBRARY_PATH`.

5. **Fix `RobotDemoQt` install permissions** in `setup.sh` — binary is installed without execute bit. Add `chmod +x` for all executables in the deb post-install script.

6. **Versioned SDK ABI.** The `.so` files have no versioned SONAME, making it impossible for downstream packages to handle SDK upgrades without full recompilation.

7. **Protocol modernization.** Replace the bespoke JSON-over-TCP framing with protobuf + gRPC (or ROS 2 DDS) to get schema evolution, multi-language codegen, and built-in flow control.
