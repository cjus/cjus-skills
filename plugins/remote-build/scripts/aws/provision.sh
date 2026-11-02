#!/bin/bash
# Turn a fresh Ubuntu 24.04 build machine into a remote-build worker image.
#
# bootstrap.py copies this to the build machine and runs it as the default `ubuntu` user with
# stdin from /dev/null, then checks the result as `builder` and makes the image. Run it by hand
# the same way (operator guide, step 6).
#
# Inputs (environment):
#   PUBKEY           the remote-build public key; the only key that may log in to workers
#   RUST_TOOLCHAINS  optional, space-separated extra toolchains to preinstall, for example
#                    "1.85.0 nightly-2026-10-01". Workers never download toolchains.
#   GPU              "nvidia" when every instance type in the profile has NVIDIA GPUs, else
#                    empty. bootstrap reboots the machine afterwards and checks nvidia-smi.
#
# This is the file to change for your own toolchain (Node, Go, a C++ SDK, extra cargo tools).
# Keep the last two sections: the client disables instance metadata at launch, so cloud-init
# must be off, and only `builder` may log in. See "Make it yours" in the operator guide.
set -euo pipefail
: "${PUBKEY:?set PUBKEY to the remote-build public key}"
# SSH answers before first-boot jobs finish, and they hold the dpkg lock: wait for them.
sudo cloud-init status --wait >/dev/null || true
# sudo drops DEBIAN_FRONTEND from the environment, so pass it on each call, keep existing
# config files on upgrade (openssh-server asks otherwise), and wait for any remaining lock.
apt_get() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Lock::Timeout=600 \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}
apt_get update
apt_get upgrade
# python3-venv lets a job make a virtual environment: builder has no sudo, and Ubuntu's own
# Python refuses pip installs outside one.
apt_get install build-essential pkg-config curl python3 python3-venv git

# NVIDIA driver for a GPU profile. A base image whose driver already works (--base-image, for
# example one of AWS's GPU images) keeps its own. The server branch (--gpgpu) is the headless
# compute driver; ubuntu-drivers picks the branch for this GPU and kernel modules prebuilt for
# this kernel flavour, so nothing compiles at boot. nvidia-smi comes in the matching utils
# package. To pin a branch, edit your copy: ubuntu-drivers install --gpgpu nvidia:570-server
if [ "${GPU:-}" = nvidia ] && ! nvidia-smi >/dev/null 2>&1; then
  apt_get install ubuntu-drivers-common
  sudo DEBIAN_FRONTEND=noninteractive ubuntu-drivers install --gpgpu
  branch=$(dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' | awk '$1 == "ii" { print $2 }' \
    | sed -nE 's/^(linux-modules-nvidia|nvidia-dkms|nvidia-headless-no-dkms|nvidia-headless|nvidia-driver)-([0-9]+)-server.*/\2/p' \
    | sort -n | tail -n 1)
  if [ -z "$branch" ]; then
    echo "ubuntu-drivers installed no NVIDIA server driver for this machine" >&2
    exit 1
  fi
  apt_get install "nvidia-utils-$branch-server"
fi

# Unprivileged build user, reachable only with the remote-build key; no sudo.
sudo useradd --create-home --shell /bin/bash builder
sudo install -d -m 700 -o builder -g builder /home/builder/.ssh
printf '%s\n' "$PUBKEY" | sudo tee /home/builder/.ssh/authorized_keys >/dev/null
sudo chown builder:builder /home/builder/.ssh/authorized_keys
sudo chmod 600 /home/builder/.ssh/authorized_keys

# Rust for builder, with rustfmt and clippy, plus cargo-deny and mdbook.
sudo -iu builder bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable -c rustfmt -c clippy'
for toolchain in ${RUST_TOOLCHAINS:-}; do
  sudo -iu builder bash -c "~/.cargo/bin/rustup toolchain install --profile minimal -c rustfmt -c clippy '$toolchain'"
done
sudo -iu builder bash -c '~/.cargo/bin/cargo install --locked cargo-deny mdbook'
# Non-interactive SSH sessions do not read the rustup PATH line in ~/.bashrc; link the tools instead.
for tool in cargo rustc rustdoc rustup rustfmt cargo-fmt cargo-clippy clippy-driver cargo-deny mdbook; do
  sudo ln -sf /home/builder/.cargo/bin/$tool /usr/local/bin/$tool
done

# The client disables the instance metadata service at launch, and cloud-init needs it to set
# up networking and would regenerate host keys. Turn cloud-init off, keep this host key, and
# use DHCP on any ethernet interface rather than this machine's MAC address.
sudo tee /etc/netplan/60-remote-build.yaml >/dev/null <<'NETPLAN'
network:
  version: 2
  ethernets:
    primary:
      match:
        name: "en*"
      dhcp4: true
NETPLAN
sudo chmod 600 /etc/netplan/60-remote-build.yaml
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo touch /etc/cloud/cloud-init.disabled

# Only builder may log in to workers.
sudo rm -f /home/ubuntu/.ssh/authorized_keys
