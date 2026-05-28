#!/bin/bash
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$DIR:$DIR/lib:$DIR/SDK/x64
export QT_PLUGIN_PATH=$DIR/plugins/:$QT_PLUGIN_PATH
export QT_QML_PATH=$DIR/qml/:$QT_QML_PATH
export SDL_VIDEODRIVER=x11
cd $DIR
./RoboticsServiceProcess &
cd $DIR/SDKDemo/RobotUnityDemo
./RobotLinuxDemo.x86_64 -screen-fullscreen 0
