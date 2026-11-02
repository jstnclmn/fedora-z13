#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Universal Blue signing key + ryzen-smu kmod
# The addons package installs the signing cert (for Secure Boot MOK enrollment).
dnf5 install -y /akmods/ublue-os/ublue-os-akmods-addons*.rpm
dnf5 install -y /akmods/kmods/kmod-ryzen-smu*.rpm

### Install packages

# this installs a package from fedora repos
dnf5 install -y tmux

#### Example for enabling a System Unit File

systemctl enable podman.socket