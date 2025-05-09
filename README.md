# RoboticsService Project Structure

## Project Overview
RoboticsService is an enterprise-level assistant application that includes multiple submodules and SDKs, developed using C++/Qt. The project aims to provide one-stop management and control services for VR teleoperated robots, including device management, data recording, demonstration, and control functionalities.

### Main Modules

#### Server
- `RoboticsServiceProcess/`
    - Service process
    - Only one instance can run at a time
    - Cross-platform application based on Qt6 (supports Windows x86, Linux x86, Linux aarch64)
    - Main functional modules:
        - Business: Business logic processing
        - DeviceManagement: Device management
        - PXREAGRPCServer: SDK server logic
        - CommonUtils: Common utility library

- `DeviceConnectionManager/` - Device Connection SDK
    - Device connection management
    - Event handling
- `Business/` - Business Logic Module
    - Device Management (DeviceManage):
      - Device connection status management
      - Real-time message communication
      - Device group management
    - Data Model (Model):
      - Device model definition
      - Device status maintenance
      - Device property management
    - Communication Protocol:
      - TCP/UDP communication protocol definition
      - Server command protocol (device control, data transmission)
      - Client message protocol (connection, status, data transmission)
      - Message encapsulation and parsing mechanism
      - Timestamp and verification mechanism
- `PXREAService/` - Background Service
    Service interfaces defined through Protocol Buffers and gRPC, including:
    - Device management and control (device discovery, status monitoring, parameter configuration)
    - Real-time data stream processing (video stream, sensor data)
    - Device status feedback (connection status)
    - Inter-device communication (device-to-device communication, broadcasting)
    - Server heartbeat detection and status maintenance
- `PXREAGRPCServer/` - Server SDK
    - Server-side core functionality encapsulation
    - Encapsulated GRPC server
- `PXREARobotSDK/` - Robot Control SDK
    - Robot device control interface
    - JSON configuration parsing and processing
    - Device status monitoring and feedback
    - Encapsulated software GRPC client
- `CommonUtils/` - Common Utility Library
    - Logging System:
      - Configurable log output (file/debug output)
      - Support for multiple log levels
    - Network Tools:
      - Local IPv4 address retrieval
      - Network connection status detection

#### SDK and Demo
- `SDK/` - SDK Core Directory
    - `include/` - SDK Header Files Directory
        - Contains all SDK public header files
        - Defines SDK interfaces and data structures
    - Platform-specific library files
        - `win/64/` - Windows x64 platform library files
        - `linux/64/` - Linux x86_64 platform library files
        - `linux_aarch64/64/` - Linux ARM64 platform library files
    - Main Features
        - Provides robot control SDK (PXREARobotSDK)
        - Device connection management
        - JSON configuration parsing and processing
        - Encapsulated gRPC client functionality

- `SDKDemo/` - SDK Demonstration and Example Programs
    - `CppSrc/` - C++ Example Programs
        - `ConsoleDemo/` - Console Example Program
            - Demonstrates basic SDK usage
            - Server connection and communication demonstration
            - Device discovery and status monitoring
        - `RobotDemoQt/` - Qt GUI Demonstration Program
            - 2D demonstration interface based on Qt6
            - SDK callback data visualization
        - `RobotDataRecorder/` - Data Recorder
            - Records robot sensor data
            - Multi-type sensor data classification storage
    - `UnityBin/` - Unity Demonstration Programs
        - `RobotWinDemo/` - Windows platform Unity demonstration
        - `RobotLinuxDemo/` - Linux platform Unity demonstration
        - Provides 3D visualization demonstration interface
    - Demonstration Features
        - Device connection and management
        - Real-time data monitoring
        - Device status feedback
        - Data recording and visualization
        - Cross-platform support (Windows, Linux x86_64, Linux ARM64)

#### Third-party Dependencies
- `Redistributable/` - Third-party Dependencies and Pre-compiled Binaries
  - `win/` - Windows Platform Dependencies
    - Visual C++ Runtime (VC_redist.x86.exe, VC_redist.x64.exe)
    - Robot Demo Program (RobotDemoQt.exe)
    - Console Example Program (ConsoleDemo.exe)
    - Data Recorder (RobotDataRecorder.exe)
    - Launch Scripts (run2D.bat, run3D.bat, runDataRecorder.bat, runService.bat)
    - Configuration File (setting.ini)
  - `linux/` - Linux x86_64 Platform Dependencies
    - Robot Demo Program (RobotDemoQt)
    - Console Example Program (ConsoleDemo)
    - Data Recorder (RobotDataRecorder)
    - Compression Library (libz.so)
    - OpenSSL Library (openssl/)
    - gRPC Directory (grpc/)
    - Configuration File (setting.ini)
  - `linux_aarch64/` - Linux ARM64 Platform Dependencies
    - Robot Demo Program (RobotDemoQt)
    - Console Example Program (ConsoleDemo)
    - Data Recorder (RobotDataRecorder)
    - OpenSSL Library (openssl/)
    - gRPC Directory (grpc/)
    - Configuration File (setting.ini)

## Build Process

### Build Scripts

The project provides build scripts for different platforms to simplify the build process:

#### Windows Platform Build
- `RoboticsService\qt-msvc.bat`
  - Used for building the project with MSVC compiler on Windows platform
  - Automatically sets up Qt and Visual Studio environment variables
  - Uses Ninja as the build system

#### Linux x86_64 Platform Build
- `RoboticsService\qt-gcc.sh`
  - Used for building the project with GCC compiler on Linux x86_64 platform
  - Automatically sets up Qt environment variables

#### Linux ARM64 Platform Build
- `RoboticsService\qt-gcc_aarch64.sh`
  - Used for building the project with GCC compiler on Linux ARM64 (aarch64) platform
  - Automatically sets up Qt environment variables

### Packaging Process

The project provides packaging scripts for different platforms to generate distributable installation packages:

#### Windows Platform Packaging
- `RoboticsService\Package\innosetup\robot.iss`
  - Creates Windows installer using Inno Setup
  - Automatically copies binary files, dependency libraries, and resource files
  - Creates desktop shortcuts and start menu items

#### Linux x86_64 Platform Packaging
- `RoboticsService\Package\debPack\setup.sh`
  - Creates Debian package (.deb) for Linux x86_64 platform
  - Automatically copies binary files, dependency libraries, and resource files
  - Sets up application icons and desktop shortcuts
  - Configures launch scripts:
    - `run2D.sh` - Launches 2D demo program
    - `run3D.sh` - Launches 3D demo program
    - `runRobotDataRecorder.sh` - Launches data recorder
    - `runService.sh` - Launches service process only

#### Linux ARM64 Platform Packaging
- `RoboticsService\Package\debPackAArch64\setup.sh`
  - Creates Debian package (.deb) for Linux ARM64 platform
  - Automatically copies binary files, dependency libraries, and resource files
  - Sets up application icons and desktop shortcuts
  - Configures launch scripts (similar to x86_64, but optimized for ARM64 architecture) 