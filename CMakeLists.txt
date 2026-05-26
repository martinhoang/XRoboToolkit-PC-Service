cmake_minimum_required(VERSION 3.8)
project(xrobotoolkit_pc_service)

# find dependencies
find_package(ament_cmake REQUIRED)

file(GLOB UTILS_SCRIPTS Utils/*.sh)

install(
  FILES ${UTILS_SCRIPTS}
  DESTINATION lib/${PROJECT_NAME}/Utils
)

ament_package()
