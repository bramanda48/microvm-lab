#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

NERDCTL_REPO="containerd/nerdctl"
NERDCTL_VERSION=${NERDCTL_VERSION:-"v1.7.7"}

if [ -z "$NERDCTL_VERSION" ]; then
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

function is_command_exists() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

function download_nerctl() {
  local arch=$(get_architecture "amd64" "arm64")
  local filename="nerdctl-${NERDCTL_VERSION/v/}-linux-$arch.tar.gz"
  local download_url=$(build_download_url $NERDCTL_REPO $NERDCTL_VERSION $filename)
  local download_location="$TEMP_DIR/$filename"

  echo "Download nerdctl binaries..."
  curl -L -o $download_location $download_url

  echo "Extract nerdctl."
  tar  -xvzf $download_location -C /usr/local/bin

  echo "Nerdctl binary installed."
  sudo nerdctl version
}

function main() {
  if is_command_exists "nerdctl"; then
    echo "Nerdctl already installed."
    sudo nerdctl version
    exit 1
  fi

  download_nerctl
}

main "$@"