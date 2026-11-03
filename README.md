# fedora-z13

A custom [bootc](https://github.com/bootc-dev/bootc) image for the **ASUS ROG Flow Z13 (2025, Ryzen AI Max+ 395)**, built from the [Universal Blue image template](https://github.com/ublue-os/image-template).

- **Base:** `ghcr.io/ublue-os/bazzite:stable` (KDE Plasma, Bazzite kernel)
- **Registry:** `ghcr.io/jstnclmn/fedora-z13`
- **Rebuilds:** daily at 10:05 UTC, and on every push to `main`

## What this adds on top of Bazzite

| Addition | Source | Notes |
|---|---|---|
| `z13ctl-plus` | [aic0d3r/z13ctl-plus](https://github.com/aic0d3r/z13ctl-plus) release RPM | Pinned version + SHA-256 in `build_files/build.sh` |
| `z13gui-plus` | [aic0d3r/z13gui-plus](https://github.com/aic0d3r/z13gui-plus) release RPM | Pinned version + SHA-256 in `build_files/build.sh` |
| `powertop`, `tmux` | Fedora repos | |
| `ryzen_smu` module | Already shipped by Bazzite | Not installed here; the build **fails** if it disappears (see "Build guard") |

Not in the image on purpose: VS Code (runs in a distrobox), Brave Origin (Flatpak, switched to Origin mode in its settings), the GRUB theme and Windows boot entry (machine-local, see below), and `z13-tablet-kit`.

## Installing

1. Install stock **Bazzite (KDE, AMD/Intel graphics)** from the official ISO.
2. Enroll the Universal Blue Secure Boot key if you use Secure Boot:
   `ujust enroll-secure-boot-key`, reboot, choose "Enroll MOK", and enter the password
   (`universalblue`; some older Bazzite docs say `ublue-os`).
3. Switch to this image (the GHCR package must be public, or run `sudo podman login ghcr.io` with a token that has `read:packages`):

   ```
   sudo bootc switch ghcr.io/jstnclmn/fedora-z13
   systemctl reboot
   ```

Rollback: `sudo bootc rollback` then reboot.

## First-boot checklist (one time per machine)

These live in `/etc`, `/boot` or your home directory, so they survive image updates but are **not** part of the image.

- [ ] Add yourself to the `users` group (needed so the z13ctl-plus daemon can write hardware interfaces):

  ```
  getent group users                      # should print users:x:100:
  sudo usermod -aG users "$USER"
  ```

  If `usermod` complains the group does not exist, copy it from `/usr/lib/group` first:
  `grep '^users:' /usr/lib/group | sudo tee -a /etc/group`.
  **Reboot**, then confirm `id` lists `users`.
- [ ] Start the controller (and optionally the GUI) for your user:

  ```
  systemctl --user enable --now z13ctl-plus.socket z13ctl-plus.service
  systemctl --user enable --now z13gui-plus.service      # optional
  ```

- [ ] Verify the stack:

  ```
  lsmod | grep ryzen_smu
  ls -l /sys/kernel/ryzen_smu_drv/
  z13ctl-plus status
  z13ctl-plus undervolt --get
  journalctl --user -u z13ctl-plus.service -b --no-pager | tail -20
  ```

## Machine-local settings

### GRUB theme
Theme files go in `/boot/grub2/themes/<name>/` (GRUB cannot read the image's `/usr`). Settings in `/etc/default/grub`:

```
GRUB_THEME="/boot/grub2/themes/<name>/theme.txt"
GRUB_GFXMODE=<resolution>,auto
GRUB_TERMINAL_OUTPUT="gfxterm"
```

Then regenerate with `ujust regenerate-grub`. Back up first: `sudo cp /etc/default/grub /etc/default/grub.bak`.
My notes: theme = [Modern Design Theme - Tela](https://github.com/vinceliuice/grub2-themes).

### Windows boot entry
Either enable os-prober (`GRUB_DISABLE_OS_PROBER=false` in `/etc/default/grub`, then `ujust regenerate-grub`), or add a `chainloader /EFI/Microsoft/Boot/bootmgfw.efi` entry in `/etc/grub.d/40_custom` using the UUID of the EFI partition:
`ESP UUID: fill in from lsblk -f`.
Keep the BitLocker recovery key handy before changing boot settings.

### Tablet kit (optional)
`z13-tablet-kit` is installed per user from its own repo (`./install.sh`). It needs `qdbus6`, `gdbus` and `kscreen-doctor` on the PATH.
#### Install notes: 

```
ln -s /usr/bin/qdbus-qt6 ~/.local/bin/qdbus6
command -v qdbus6 gdbus kscreen-doctor     # all three must print a path
python3 -c 'import evdev' && echo evdev ok
    - If import evdev fails, install it with pip install --user evdev, or check whether the image offers python3-evdev
git clone https://github.com/aic0d3r/z13-tablet-kit
cd z13-tablet-kit && ./install.sh
```

## Updating pinned packages

The z13 RPMs are pinned on purpose. A weekly workflow (`.github/workflows/check-releases.yml`) opens an issue when a newer release exists. To update:

1. Read the release notes of the new version.
2. In `build_files/build.sh`, change `Z13CTL_PLUS_VERSION` (or `Z13GUI_PLUS_VERSION`) and the matching `*_SHA256`.
   Get the checksum from the release page, or with:
   `curl -fsSL <rpm url> | sha256sum`
3. Commit to `main`. The build verifies the checksum and runs the guard checks.
4. `sudo bootc upgrade`, reboot, and test.

## Build guard

At the end of `build_files/build.sh`, the build fails if:

- `modinfo -k <kernel> ryzen_smu` finds no module in the image,
- `z13ctl-plus` or `z13gui-plus` is not installed, or
- the `z13ctl-plus` binary, udev rule, or user units are missing.

A failed scheduled build means the base image changed in a way that matters; check the Actions log before updating.

## Repository layout

| Path | Purpose |
|---|---|
| `Containerfile` | Base image and build step |
| `build_files/build.sh` | Packages, pinned RPMs, build guard |
| `system_files/` | Files copied into `/` in the image (e.g. `etc/modules-load.d/ryzen_smu.conf`) |
| `.github/workflows/build.yml` | Builds, rechunks, pushes and signs the image |
| `.github/workflows/check-releases.yml` | Weekly check for new z13 package releases |
| `disk_config/` | Installer ISO configuration (`build-disk.yml`) |

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Curve Optimizer not available` | User is not in the `users` group, or the session predates the change; reboot and check `id` |
| `permission denied` on `/dev/input/event*` in the z13ctl-plus journal | Armoury Crate button device is held by Bazzite's InputPlumber; unrelated to undervolt |
| Build fails at the guard step | Bazzite dropped `ryzen_smu` or a z13 package changed its files |
| `bootc switch` is very slow | Large first pull; use wired networking. Later updates are deltas |
| Pull is denied | Package is private; make it public or `podman login ghcr.io` |

## Credits and licence

Built from [ublue-os/image-template](https://github.com/ublue-os/image-template) and [Bazzite](https://github.com/ublue-os/bazzite). `z13ctl-plus`, `z13gui-plus` and `z13-tablet-kit` are by [aic0d3r](https://github.com/aic0d3r). This repository is licensed under Apache-2.0.