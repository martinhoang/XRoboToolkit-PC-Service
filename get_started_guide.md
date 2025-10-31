Get Started Guide for xRobotoolkit PC Service
===============================

# Quick Start
1. Setup environment & Run the service:
  a. Direct run
   ```bash
    cd (to the Utils folder of this repository)
    chmod +x setup_pxrea_linux.sh
    sudo ./setup_pxrea_linux.sh
   ```
  b. Run as like ros2 node
  - Build this ros2 package:
  ```bash
    colcon build --packages-select xrobotoolkit_pc_service
  ```
  - Run the setup script via ros2 run
   ```bash
    sudo bash -c 'source /opt/ros/{ROS_DISTRO}/setup.bash; source <your_ros2_workspace_install/setup.bash>; ros2 run xrobotoolkit_pc_service setup_pxrea_linux.sh'
   ```
