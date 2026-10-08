#!/bin/bash
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"
if [ -f /opt/onnxruntime_vendor/setup.bash ]; then
    source /opt/onnxruntime_vendor/setup.bash
fi
exec "$@"
