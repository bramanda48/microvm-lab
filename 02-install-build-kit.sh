#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

BUILD_KIT_REPO="moby/buildkit"
BUILD_KIT_VERSION=${BUILD_KIT_VERSION:-"v0.16.0"}

if [ -z "$BUILD_KIT_VERSION" ]; then
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

function download_buildkit() {
  local arch=$(get_architecture "amd64" "arm64")
  local filename="buildkit-$BUILD_KIT_VERSION.linux-$arch.tar.gz"
  local download_url=$(build_download_url $BUILD_KIT_REPO $BUILD_KIT_VERSION $filename)
  local download_location="$TEMP_DIR/$filename"

  echo "Download buildkit binaries..."
  curl -L -o $download_location $download_url

  echo "Extract buildkit."
  tar  -xvzf $download_location -C $TEMP_DIR

  echo "Move buildkit binaries to /usr/local/bin."
  mv $TEMP_DIR/bin/buildctl /usr/local/bin
  mv $TEMP_DIR/bin/buildkitd /usr/local/bin
}

function install_buildkit() {
  local buildkit_service="/etc/systemd/system/buildkit.service"

  echo "Create buildkit config..."
  cat <<EOF >"$buildkit_service"
[Unit]
Description=BuildKit
Documentation=https://github.com/moby/buildkit

[Service]
ExecStart=/usr/local/bin/buildkitd --oci-worker=false --containerd-worker=true

[Install]
WantedBy=multi-user.target
EOF

  # Enable and start firecracker
  sudo systemctl enable buildkit
  sudo systemctl daemon-reload
  sudo systemctl start buildkit

  echo "Buildkit service installed."
  sudo systemctl status buildkit --lines=0
}

function main() {
  if is_service_exists "buildkit.service"; then
    echo "Service buildkit already installed."
    sudo systemctl status buildkit --lines=0
    exit 1
  fi

  download_buildkit
  # install_buildkit
}

main "$@"