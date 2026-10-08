##############
# Base image #
##############
ARG BASE_IMAGE=nvidia/cuda:13.0.1-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base

ARG AMENT_WORKSPACE_DIR="/ament_ws"

LABEL org.opencontainers.image.authors="tobit.flatscher@outlook.com"
LABEL description="ROS 2 Jazzy Docker template"
LABEL version="1.0"

WORKDIR ${AMENT_WORKSPACE_DIR}
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV ROS_DISTRO=jazzy
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute
ENV QT_X11_NO_MITSHM=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    locales \
    tzdata \
    curl \
    git \
    libegl1 \
    libegl-mesa0 \
    libgl1 \
    libgl1-mesa-dri \
    libglvnd0 \
    libglx0 \
    libglx-mesa0 \
    libx11-6 \
    libxext6 \
    software-properties-common \
 && locale-gen en_US.UTF-8 \
 && ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
 && dpkg-reconfigure --frontend noninteractive tzdata \
 && add-apt-repository -y universe \
 && curl -fsSL -o /tmp/ros2-apt-source.deb https://github.com/ros-infrastructure/ros-apt-source/releases/download/1.1.0/ros2-apt-source_1.1.0.noble_all.deb \
 && apt-get install -y /tmp/ros2-apt-source.deb \
 && rm /tmp/ros2-apt-source.deb \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    python3-colcon-clean \
    python3-osrf-pycommon \
    ros-${ROS_DISTRO}-ros-base \
    python3-argcomplete \
    python3-rosdep \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get -y install \
    ros-${ROS_DISTRO}-compressed-image-transport \
    ros-${ROS_DISTRO}-compressed-depth-image-transport \
    ros-${ROS_DISTRO}-image-transport \
    ros-${ROS_DISTRO}-pinocchio \
    ros-${ROS_DISTRO}-point-cloud-transport \
    ros-${ROS_DISTRO}-point-cloud-transport-plugins \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
 && rm -rf /var/lib/apt/lists/*

# Add additional installation instructions here...

COPY docker/ros_entrypoint.sh /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

ENV DEBIAN_FRONTEND=dialog


#####################
# Development image #
#####################
FROM base AS dev

ARG AMENT_WORKSPACE_DIR="/ament_ws"
ARG USERNAME="developer"
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y \
    ack \
    bash-completion \
    bmon \
    build-essential \
    cloc \
    cmake \
    gdb \
    htop \
    iperf3 \
    iputils-ping \
    net-tools \
    openssh-client \
    plocate \
    psmisc \
    python3-pip \
    ros-dev-tools \
    tmux \
    vim \
    xterm \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get install -y \
    python3-vcstool \
    ros-${ROS_DISTRO}-rqt-common-plugins \
    ros-${ROS_DISTRO}-rqt-robot-steering \
    ros-${ROS_DISTRO}-rqt-tf-tree \
    ros-${ROS_DISTRO}-rviz2 \
 && rm -rf /var/lib/apt/lists/*

# Install additional developer tools here...

RUN apt-get update \
 && apt-get install -y sudo \
 && rm -rf /var/lib/apt/lists/* \
 # Remove user blocking UID 1000 on Ubuntu 24.04 and onwards:
 # See https://bugs.launchpad.net/cloud-images/+bug/2005129 and
 # https://github.com/devcontainers/images/issues/1056
 && userdel -r ubuntu || true \
 && addgroup --gid ${GID} ${USERNAME} \
 && adduser --disabled-password --gecos '' --uid ${GID} --gid ${GID} ${USERNAME} \
 && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
 && chown -R ${UID}:${GID} /home/${USERNAME} \
 && chown -R ${UID}:${GID} ${AMENT_WORKSPACE_DIR}

# Build ONNX Runtime's ROS vendor package outside the mounted workspace.
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
 && mkdir -p /tmp/onnxruntime_ws/src \
 && git clone --depth 1 https://github.com/ros-controls/onnxruntime_vendor.git /tmp/onnxruntime_ws/src/onnxruntime_vendor \
 && rosdep init \
 && rosdep update --rosdistro=${ROS_DISTRO} \
 && apt-get update \
 && rosdep install --from-paths /tmp/onnxruntime_ws/src/onnxruntime_vendor --ignore-src -y \
 && cd /tmp/onnxruntime_ws \
 && colcon build --packages-select onnxruntime_vendor --merge-install --install-base /opt/onnxruntime_vendor \
 && source /opt/onnxruntime_vendor/setup.bash \
 && ros2 pkg prefix onnxruntime_vendor \
 && rm -rf /tmp/onnxruntime_ws /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=dialog

RUN echo "alias rsource='source ${AMENT_WORKSPACE_DIR}/install/setup.bash'" >> /home/${USERNAME}/.bash_aliases \
 && echo "alias rbuild='(cd ${AMENT_WORKSPACE_DIR} && colcon build)'" >> /home/${USERNAME}/.bash_aliases \
 && echo "alias rclean='(cd ${AMENT_WORKSPACE_DIR} && colcon clean workspace -y)'" >> /home/${USERNAME}/.bash_aliases \
 && echo "source /opt/onnxruntime_vendor/setup.bash" >> /home/${USERNAME}/.bashrc \
 && echo "rsource || source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/${USERNAME}/.bashrc

USER ${USERNAME}


#####################
# Full image #
#####################
FROM dev AS full

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-desktop \
 && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog
USER ${USERNAME}


#####################
# Gazebo image #
#####################
FROM full AS gazebo

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN curl -fsSL https://packages.osrfoundation.org/gazebo.gpg -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable noble main" > /etc/apt/sources.list.d/gazebo-stable.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-ros-gz \
 && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog
USER ${USERNAME}


#########################
# ROS 2 control image #
#########################
FROM gazebo AS ros2_control

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-ros2-control \
    ros-${ROS_DISTRO}-ros2-controllers \
    ros-${ROS_DISTRO}-control-toolbox \
    ros-${ROS_DISTRO}-plotjuggler-ros \
    ros-${ROS_DISTRO}-joint-state-publisher-gui \
    ros-${ROS_DISTRO}-pinocchio \
    ros-${ROS_DISTRO}-mujoco-ros2-control \
    ros-${ROS_DISTRO}-mujoco-ros2-control-demos\
 && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog
USER ${USERNAME}
