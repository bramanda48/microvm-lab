#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace

VMID="2906f87c-eff1-4ef6-8742-71aa6a2b7189"
CHROOT_PATH="/srv/jailer/firecracker/$VMID/root"
SOCKET_PATH="$CHROOT_PATH/run/firecracker.socket"

if [ ! -f "${CHROOT_PATH}/firecracker.pid" ]; then
  echo "VM $VMID is not running"
  exit 1
fi

echo -n "Stopping $VMID..."
PID=$(cat "${CHROOT_PATH}/firecracker.pid")

# Stop VM
# As per this comment
# https://github.com/firecracker-microvm/firecracker/issues/1095#issuecomment-537529808
# SendCtrlAltDel only works in kernels that have enabled i8042/atkbd configuration.
curl \
  --unix-socket \
  "$SOCKET_PATH" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -X PUT "http://localhost/actions" \
  -d "{ \"action_type\": \"SendCtrlAltDel\" }"

i=1
while :
do
  ps "$PID" > /dev/null || break
  sleep 1
  
  if [ $i -gt 30 ]; then
    echo 
    echo "Force. Killing $VMID..."
    sudo kill -KILL "$PID"
    break
  else
    echo -n "."
    ((i++))
  fi
done

echo
sudo rm -r "${CHROOT_PATH}/firecracker.pid"
sudo rm -r "${CHROOT_PATH}/dev"
sudo rm -r "${CHROOT_PATH}/run"
sudo rm -r "${CHROOT_PATH}/firecracker"