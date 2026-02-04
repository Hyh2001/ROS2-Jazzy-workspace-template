# ROS 2 Jazzy Docker Template

Author: [Tobit Flatscher](https://github.com/2b-t) (2021 - 2025)

Modify: [Yuhao Huang](huangyuhaowork@outlook.com)


## 0. Overview

This repository contains a Docker workspace template for [**ROS 2 Jazzy**](https://docs.ros.org/en/jazzy/index.html). The idea is that a Docker is created for each project at Ament workspace level. Dependencies that are not expected to change during the course of a project are installed from Debian packages inside the Dockerfile, while proprietary dependencies that are expected to change during a project are mounted into the container and version controlled with [**`vcstool`**](https://github.com/dirk-thomas/vcstool). Only selected folders such as `dds/` and `src/` are mounted into the container so that the workspace can be compiled on the host system as well as inside the container without them interfering.

Here is an overview of the structure of this repository:

```bash
ros/
├── dds/                              # DDS middleware configuration
├── docker/                           # Docker and Docker-Compose configuration
│   ├── docker-compose.yml              # Base Docker-Compose file containing all the basic Docker set-up
│   ├── docker-compose-gui.yml          # Extends the base Docker-Compose file by X11-forwarding for graphic user interfaces
│   ├── docker-compose-gui-nvidia.yml   # Extends the graphic user interface Docker-Compose file with the Nvidia runtime
│   ├── docker-compose-nvidia.yml       # Extends the base Docker-Compose file with the Nvidia runtime for graphic acceleration
│   ├── docker-compose-vscode.yml       # Extends one of the other configurations with Visual Studio Code relevant settings
│   ├── Dockerfile                      # Dockerfile containing ROS 2 and the base dependencies
│   └── .env                            # Environment variables to be considered by Docker Compose
├── src/                              # Source folder mounted inside the Docker container
│   └── .repos                          # VCS tool configuration file for version control
├── .devcontainer/                    # Configuration files for containers in Visual Studio Code
└── .vscode/                          # Configuration files for Visual Studio Code
```



## 1. Set-up

### Quick Setup with Interactive Script (Recommended)

The easiest way to configure your workspace is using the **interactive setup script**:

```bash
$ ./setup-workspace.sh
```

This script will guide you through:
- Selecting a Docker Compose configuration (base, gui, nvidia, gui-nvidia, or vscode)
- Configuring environment variables with auto-detection
- Creating the necessary configuration files

The script supports several modes:

**Interactive Mode** (default):
```bash
$ ./setup-workspace.sh
```

**Configuration File Mode** (for automation):
```bash
$ ./setup-workspace.sh -c setup.yaml
```

**Dry-run Mode** (preview changes without applying):
```bash
$ ./setup-workspace.sh --dry-run
```

**Help**:
```bash
$ ./setup-workspace.sh --help
```

#### Configuration File Format

For automated setup, you can create a `setup.yaml` file (see `setup.example.yaml` for a template):

```yaml
docker_compose:
  variant: "gui"  # Options: base, gui, nvidia, gui-nvidia, vscode
  
environment:
  ament_workspace_dir: "/ros2_ws"
  ros_domain_id: 0
  your_ip: "auto"  # or specific IP like "192.168.1.100"
  robot_ip: "127.0.0.1"
  robot_hostname: "P500"
  uid: "auto"  # or specific UID
  gid: "auto"  # or specific GID
```

Then run:
```bash
$ ./setup-workspace.sh -c setup.yaml
```

### Manual Setup

After cloning this repository you will have to update the packages inside the workspace. For version control we use [`vcstool`](http://wiki.ros.org/vcstool) instead of Git submodules. In order to **pull the repositories** please import them with the following command (either inside the Docker or on the host):

```
$ cd src/
$ vcs import < .repos   
```

This should clone the desired repositories given inside `.repos` into your workspace. They are excluded in the [`.gitignore`](./.gitignore) file so that they will not be part of your commits.

If you prefer manual configuration, edit the [`docker/.env`](./docker/.env) file:

```bash
AMENT_WORKSPACE_DIR=/ros2_ws
ROS_DOMAIN_ID=0
YOUR_IP=127.0.0.1
ROBOT_IP=127.0.0.1
ROBOT_HOSTNAME=P500
UID=1000
GID=1000
```

Here you can change the workspace name, network settings as well as user and group IDs.

**Network set-up**: The `ROS_DOMAIN_ID` is used for the ROS 2 DDS middleware configuration. The parameter `YOUR_IP` corresponds to the IP that you are using, in case you are running a simulation set it to `127.0.0.1` while for working with a physical robot you will have to set it to the IP assigned to the network interface used for connecting to the robot shown by `$ ifconfig` from the `net-tools` package on your computer. We use it for the DDS middleware configuration. The `ROBOT_IP` as well as the `ROBOT_HOSTNAME` are used to configure the `/etc/hosts` file as well as configuring the DDS middleware by IP. They should correspond to the IP shown by `$ ifconfig` on the robot as well as to its `$ hostname` and can be set to `127.0.0.1` and an arbitrary hostname in case of the simulation.

**User and group id**: These should be set identical to the user and group ID of the user running the container (see the output of `$ id`). On Debian system [anything below 1000 is generally reserved for system accounts](https://www.redhat.com/sysadmin/user-account-gid-uid) and the first UID `1000` is assigned to the first user of the system, which are the default  values in our set-up. In case your user and group IDs differ, adjust them.



## 2. Running

### Using the Setup Script

If you used the setup script, you can start your configured Docker container with:

```bash
$ docker compose -f docker-compose.active.yml up -d
```

Then connect to the running container:

```bash
$ docker exec -it ros2_docker bash
```

The `docker-compose.active.yml` symlink points to your selected configuration (created by the setup script).

### Manual Method

Alternatively, **run the Docker** manually with a specific compose file:

```bash
$ docker compose -f docker/docker-compose-gui.yml up
```

and then connect to the running Docker

```bash
$ docker exec -it ros2_docker bash
```

Available compose files:
- `docker/docker-compose.yml` - Base configuration
- `docker/docker-compose-gui.yml` - With GUI support
- `docker/docker-compose-nvidia.yml` - With NVIDIA GPU support
- `docker/docker-compose-gui-nvidia.yml` - With GUI and NVIDIA GPU support
- `docker/docker-compose-vscode.yml` - For VSCode development

### VSCode Integration

For [**Visual Studio Code Dev Containers integration**](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers), see the guide [here](https://github.com/2b-t/docker-for-robotics/blob/main/doc/VisualStudioCodeSetup.md). The configuration can be adjusted in `docker/docker-compose-vscode.yml`. Using Docker through Visual Studio Code is much easier and is therefore recommended!

### GUI Applications

In order to be able to run **graphical user interfaces** from inside the Docker you might have to type

```bash
$ xhost +
```

on the **host system**. When using a user with the same name, user and group id as the host system this should not be necessary.
