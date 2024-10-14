#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

CONTAINERD_REPO="containerd/containerd"
CONTAINERD_VERSION=${CONTAINERD_VERSION:-"v1.7.22"}

if [ -z "$CONTAINERD_VERSION" ]; then
  echo "Incorrect versions provided!" >/dev/stderr
  exit 1
fi

TEMP_DIR=`mktemp -d`

if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

function cleanup {      
  rm -rf "$TEMP_DIR"
  echo "Deleted temp working directory $TEMP_DIR"
}

trap cleanup EXIT

function build_download_url() {
	local repo_name="$1"
	local tag="$2"
	local bin="$3"
	echo "https://github.com/$repo_name/releases/download/$tag/$bin"
}

function get_architecture() {
  local arch
  local x86_alias=${1:-"x86_64"}
  local arm_alias=${2:-"aarch64"}

  case $(uname -m) in
    x86_64)  arch=$x86_alias;;
    aarch64) arch=$arm_alias;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1;;
  esac

  echo $arch
}

function is_service_exists() {
  local x=$1
  if systemctl status "${x}" 2> /dev/null | grep -Fq "Active:"; then
    return 0
  else
    return 1
  fi
}

function download_containerd() {
  local arch=$(get_architecture "amd64" "arm64")
  local filename="cri-containerd-cni-${CONTAINERD_VERSION/v/}-linux-$arch.tar.gz"
  local download_url=$(build_download_url $CONTAINERD_REPO $CONTAINERD_VERSION $filename)
  local download_location="$TEMP_DIR/$filename"

  echo "Download Containerd + CNI binaries..."
  curl -L -o $download_location $download_url

  echo "Extract Containerd."
  tar  -xvzf $download_location -C /
}

function install_containerd() {
  local chgrp_path=$(command -v chgrp | tr -d '\n')
  
  sudo groupadd containerd || true
  sudo sed -i -E "s#(ExecStart=/usr/local/bin/containerd)#\1\nExecStartPost=${chgrp_path} containerd /run/containerd/containerd.sock#g" /etc/systemd/system/containerd.service

  # Enable and start firecracker
  sudo systemctl enable containerd
  sudo systemctl daemon-reload
  sudo systemctl start containerd

  echo "Containerd service installed."
  sudo systemctl status containerd --lines=0
}

function create_containerd_config() {
  local containerd_root="/var/lib/containerd"
  local containerd_state="/run/containerd"
  local containerd_config="/etc/containerd/config.toml"

  echo "Create containerd root and state dirs."
  mkdir -p $containerd_root $containerd_state "$(dirname $containerd_config)"

  echo "Create containerd config..."
  cat <<EOF >"$containerd_config"
version = 2
root = "$containerd_root"
state = "$containerd_state"

[grpc]
  address = "$containerd_state/containerd.sock"

[metrics]
  address = "127.0.0.1:1338"

[plugins]
  [plugins."io.containerd.grpc.v1.cri".cni]
    bin_dir = "/opt/cni/bin"
    conf_dir = "/etc/cni/net.d"
EOF
}

function main() {
  if is_service_exists "containerd.service"; then
    echo "Service containerd already installed."
    sudo systemctl status containerd --lines=0
    exit 1
  fi

  download_containerd
  create_containerd_config
  install_containerd
}

main "$@"