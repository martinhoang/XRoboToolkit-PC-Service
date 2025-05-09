# RoboticsService 项目结构说明

## 项目概述
RoboticsService 是一个企业级助手应用程序，包含多个子模块和 SDK，采用 C++/Qt 开发。该项目旨在为VR遥操作机器人提供一站式的管理和控制服务，包括设备管理、数据记录、演示和控制等功能。

### 主要模块

#### 服务端
- `RoboticsServiceProcess/`
    - 服务进程
    - 一次只能运行一个实例
    - 基于 Qt6 的跨平台应用程序(支持 Windows x86、Linux x86、Linux aarch64)
    - 主要功能模块:
        - Business: 业务逻辑处理
        - DeviceManagement: 设备管理
        - PXREAGRPCServer: SDK服务端逻辑
        - CommonUtils: 通用工具库

- `DeviceConnectionManager/` - 设备连接SDK
    - 设备连接管理
    - 事件处理
- `Business/` - 业务逻辑模块
    - 设备管理（DeviceManage）：
      - 设备连接状态管理
      - 实时消息通信
      - 设备分组管理
    - 数据模型（Model）：
      - 设备模型定义
      - 设备状态维护
      - 设备属性管理
    - 通信协议：
      - TCP/UDP通信协议定义
      - 服务器命令协议（设备控制、数据传输）
      - 客户端消息协议（连接、状态、数据传输）
      - 消息封装和解析机制
      - 时间戳和校验机制
- `PXREAService/` - 后台服务
    通过 Protocol Buffers 和 gRPC 定义的服务接口，包括：
    - 设备管理和控制（设备发现、状态监控、参数配置）
    - 实时数据流处理（视频流、传感器数据）
    - 设备状态反馈（连接状态）
    - 设备间通信（设备点对点通信、广播）
    - 服务器心跳检测和状态维护
- `PXREAGRPCServer/` - 服务器SDK
    - 服务器端核心功能封装
    - 封装了 GRPC 服务端。
- `PXREARobotSDK/` - 机器人控制SDK
    - 机器人设备控制接口
    - JSON配置解析和处理
    - 设备状态监控和反馈
    - 封装软件 GRPC 客户端。
- `CommonUtils/` - 通用工具库
    - 日志系统：
      - 可配置的日志输出（文件/调试输出）
      - 支持多级别日志
    - 网络工具：
      - 本地IPv4地址获取
      - 网络连接状态检测

#### SDK和Demo
- `SDK/` - SDK核心目录
    - `include/` - SDK头文件目录
        - 包含所有SDK的公共头文件
        - 定义SDK接口和数据结构
    - 平台特定库文件
        - `win/64/` - Windows x64平台库文件
        - `linux/64/` - Linux x86_64平台库文件
        - `linux_aarch64/64/` - Linux ARM64平台库文件
    - 主要功能
        - 提供机器人控制SDK（PXREARobotSDK）
        - 设备连接管理
        - JSON配置解析和处理
        - 封装gRPC客户端功能

- `SDKDemo/` - SDK演示和示例程序
    - `CppSrc/` - C++示例程序
        - `ConsoleDemo/` - 控制台示例程序
            - 展示基本SDK使用方式
            - 服务器连接和通信演示
            - 设备发现和状态监控
        - `RobotDemoQt/` - Qt图形界面演示程序
            - 基于Qt6的2D演示界面
            - SDK回调数据可视化
        - `RobotDataRecorder/` - 数据记录器
            - 记录机器人传感器数据
            - 多类型传感器数据分类存储
    - `UnityBin/` - Unity演示程序
        - `RobotWinDemo/` - Windows平台Unity演示
        - `RobotLinuxDemo/` - Linux平台Unity演示
        - 提供3D可视化演示界面
    - 演示功能
        - 设备连接和管理
        - 实时数据监控
        - 设备状态反馈
        - 数据记录和可视化
        - 跨平台支持（Windows、Linux x86_64、Linux ARM64）

#### 第三方依赖
- `Redistributable/` - 第三方依赖及预编译二进制文件
  - `win/` - Windows平台依赖
    - Visual C++ 运行时（VC_redist.x86.exe, VC_redist.x64.exe）
    - 机器人演示程序（RobotDemoQt.exe）
    - 控制台示例程序（ConsoleDemo.exe）
    - 数据记录器（RobotDataRecorder.exe）
    - 启动脚本（run2D.bat, run3D.bat, runDataRecorder.bat, runService.bat）
    - 配置文件（setting.ini）
  - `linux/` - Linux x86_64平台依赖
    - 机器人演示程序（RobotDemoQt）
    - 控制台示例程序（ConsoleDemo）
    - 数据记录器（RobotDataRecorder）
    - 压缩库（libz.so）
    - OpenSSL库（openssl/）
    - gRPC目录（grpc/）
    - 配置文件（setting.ini）
  - `linux_aarch64/` - Linux ARM64平台依赖
    - 机器人演示程序（RobotDemoQt）
    - 控制台示例程序（ConsoleDemo）
    - 数据记录器（RobotDataRecorder）
    - OpenSSL库（openssl/）
    - gRPC目录（grpc/）
    - 配置文件（setting.ini）


## 编译构建流程

### 编译脚本

项目提供了针对不同平台的编译脚本，用于简化构建过程：

#### Windows 平台编译
- `RoboticsService\qt-msvc.bat`
  - 用于 Windows 平台下使用 MSVC 编译器构建项目
  - 自动设置 Qt 和 Visual Studio 环境变量
  - 使用 Ninja 作为构建系统

#### Linux x86_64 平台编译
- `RoboticsService\qt-gcc.sh`
  - 用于 Linux x86_64 平台下使用 GCC 编译器构建项目
  - 自动设置 Qt 环境变量


#### Linux ARM64 平台编译
- `RoboticsService\qt-gcc_aarch64.sh`
  - 用于 Linux ARM64 (aarch64) 平台下使用 GCC 编译器构建项目
  - 自动设置 Qt 环境变量

### 打包流程

项目提供了针对不同平台的打包脚本，用于生成可分发的安装包：

#### Windows 平台打包
- `RoboticsService\Package\innosetup\robot.iss`
  - 使用 Inno Setup 创建 Windows 安装程序
  - 自动复制二进制文件、依赖库和资源文件
  - 创建桌面快捷方式和开始菜单项

#### Linux x86_64 平台打包
- `RoboticsService\Package\debPack\setup.sh`
  - 创建 Debian 包 (.deb) 用于 Linux x86_64 平台
  - 自动复制二进制文件、依赖库和资源文件
  - 设置应用程序图标和桌面快捷方式
  - 配置启动脚本：
    - `run2D.sh` - 启动 2D 演示程序
    - `run3D.sh` - 启动 3D 演示程序
    - `runRobotDataRecorder.sh` - 启动数据记录器
    - `runService.sh` - 仅启动服务进程

#### Linux ARM64 平台打包
- `RoboticsService\Package\debPackAArch64\setup.sh`
  - 创建 Debian 包 (.deb) 用于 Linux ARM64 平台
  - 自动复制二进制文件、依赖库和资源文件
  - 设置应用程序图标和桌面快捷方式
  - 配置启动脚本（与 x86_64 类似，但针对 ARM64 架构优化）