#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# this installs a package from fedora repos
dnf5 install -y tmux

### z13ctl-plus (pinned release RPM)
Z13CTL_PLUS_VERSION="2.5.1"
Z13CTL_PLUS_RPM="z13ctl-plus_${Z13CTL_PLUS_VERSION}_linux_amd64.rpm"
Z13CTL_PLUS_SHA256="7bef48550afc74f50357d21f287c49b0ca1751dd86d2f238d602fa8a958f6cd4"

curl -fsSL -o /tmp/z13ctl-plus.rpm \
  "https://github.com/aic0d3r/z13ctl-plus/releases/download/v${Z13CTL_PLUS_VERSION}/${Z13CTL_PLUS_RPM}"
echo "${Z13CTL_PLUS_SHA256}  /tmp/z13ctl-plus.rpm" | sha256sum -c -
dnf5 install -y /tmp/z13ctl-plus.rpm
rm -f /tmp/z13ctl-plus.rpm

# Inspect what the package installed (shows up in the build log)
rpm -ql z13ctl-plus

#### Example for enabling a System Unit File

systemctl enable podman.socket

# NOTE: z13ctl-plus's user daemon is intentionally NOT enabled here.
# Test it per-user first; once it works, add:
#   systemctl --global enable z13ctl-plus.socket z13ctl-plus.service