#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Slimming round 1 (dry-run verified: 6 packages, ~294 MiB)
dnf5 remove -y nvidia-gpu-firmware libva-intel-media-driver \
  intel-opencl intel-opencl-clang intel-igc intel-igc-libs

# Slimming round 2: Intel-only firmware (Z13 uses MediaTek Wi-Fi and AMD graphics)
dnf5 remove -y intel-gpu-firmware intel-npu-firmware \
  iwlwifi-mvm-firmware iwlwifi-mld-firmware iwlwifi-dvm-firmware iwlegacy-firmware

### Install packages

# this installs a package from fedora repos
dnf5 install -y tmux powertop podman-compose

### z13ctl-plus (pinned release RPM)
Z13CTL_PLUS_VERSION="2.5.1"
Z13CTL_PLUS_RPM="z13ctl-plus_${Z13CTL_PLUS_VERSION}_linux_amd64.rpm"
Z13CTL_PLUS_SHA256="7bef48550afc74f50357d21f287c49b0ca1751dd86d2f238d602fa8a958f6cd4"

curl -fsSL -o /tmp/z13ctl-plus.rpm \
  "https://github.com/aic0d3r/z13ctl-plus/releases/download/v${Z13CTL_PLUS_VERSION}/${Z13CTL_PLUS_RPM}"
echo "${Z13CTL_PLUS_SHA256}  /tmp/z13ctl-plus.rpm" | sha256sum -c -
dnf5 install -y /tmp/z13ctl-plus.rpm
rm -f /tmp/z13ctl-plus.rpm

### z13gui-plus (pinned release RPM)
Z13GUI_PLUS_VERSION="2.7.0"
Z13GUI_PLUS_RPM="z13gui-plus_${Z13GUI_PLUS_VERSION}_linux_amd64.rpm"
Z13GUI_PLUS_SHA256="2f508ceb112d0fe77babc5f59e569435474e6a5fd916d2bcba4bf8b310c3ac32"

curl -fsSL -o /tmp/z13gui-plus.rpm \
  "https://github.com/aic0d3r/z13gui-plus/releases/download/v${Z13GUI_PLUS_VERSION}/${Z13GUI_PLUS_RPM}"
echo "${Z13GUI_PLUS_SHA256}  /tmp/z13gui-plus.rpm" | sha256sum -c -
dnf5 install -y /tmp/z13gui-plus.rpm
rm -f /tmp/z13gui-plus.rpm

# Show what the packages installed (appears in the build log)
rpm -ql z13ctl-plus z13gui-plus

#### Example for enabling a System Unit File

systemctl enable podman.socket

# NOTE: the z13ctl-plus and z13gui-plus user daemons are intentionally NOT
# enabled here. Test per-user first; once they work, add:
#   systemctl --global enable z13ctl-plus.socket z13ctl-plus.service z13gui-plus.service

### Build-time guard
# Fail the build (instead of silently publishing a broken image) if something this
# image depends on has gone missing, for example if the Bazzite base stops shipping
# the ryzen_smu kernel module or a z13 package fails to install its files.
 
KVER="$(ls /usr/lib/modules | sort -V | tail -1)"
echo "Guard: checking kernel ${KVER}"
 
# 1. ryzen_smu must exist for the kernel in the image
modinfo -k "${KVER}" ryzen_smu > /dev/null
echo "Guard: ryzen_smu module found, signer: $(modinfo -k "${KVER}" -F signer ryzen_smu || true)"
 
# 2. The z13 packages must be installed and have shipped their key files
rpm -q z13ctl-plus z13gui-plus
test -x /usr/bin/z13ctl-plus
test -f /usr/lib/udev/rules.d/99-z13ctl-plus.rules
test -f /usr/lib/systemd/user/z13ctl-plus.service
test -f /usr/lib/systemd/user/z13ctl-plus.socket

# Firmware and apps that must survive slimming
rpm -q mt7xxx-firmware amd-gpu-firmware amd-ucode-firmware linux-firmware \
       realtek-firmware alsa-sof-firmware cirrus-audio-firmware
rpm -q steam tailscale lutris umu-launcher terra-gamescope fish git podman 

echo "Guard: all checks passed"
