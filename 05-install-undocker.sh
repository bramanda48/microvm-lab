#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

UNDOCKER_VERSION=${UNDOCKER_VERSION:-"v1.2.3"}

# Install prerequisites
command -v make &> /dev/null || { sudo apt update && sudo apt install -y make; }
command -v git  &> /dev/null || { sudo apt update  && sudo apt install -y git; }

if [ -z "$UNDOCKER_VERSION" ]; then
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

function is_command_exists() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

function install_golang() {
  if ! is_command_exists "go"; then
    sudo add-apt-repository ppa:longsleep/golang-backports -y
    sudo apt update
    sudo apt install -y golang-go
  fi
}

function install_undocker() {
  echo "Downloading undocker..."
  cd $TEMP_DIR && git clone https://git.jakstys.lt/motiejus/undocker.git .
  git checkout $UNDOCKER_VERSION

  echo "Builing undocker..."
  make undocker

  echo "Move undocker binaries to /usr/local/bin."
  sudo mv undocker /usr/local/bin
  sudo undocker
}

function main() {
  if is_command_exists "undocker"; then
    echo "Undocker already installed."
    sudo undocker
    exit 1
  fi

  install_golang
  install_undocker
}

main "$@"