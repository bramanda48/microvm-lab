#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Install prerequisites
command -v jq &> /dev/null || { sudo apt update && sudo apt install -y jq; }

function inspect_tap() {
  local interface=$1
  local key=$2
  echo $(ip -json addr show "$interface" | jq -r '.[].addr_info[] | select(.family == "inet").'"$key")
}

function cidr_to_netmask() {  
  local cidr=$1
  local netmask 
  for ((i=0; i<4; i++)); do
    if (( cidr >= 8 )); then
      netmask+="255."
      cidr=$((cidr - 8))
    else
      local octet=$(( 256 - (2 ** (8 - cidr)) ))
      netmask+="${octet}."
      break
    fi
  done
  echo ${netmask%.*}
}

function generate_mac_address() {
  local mac_address=$(printf "%02x:%02x:%02x:%02x:%02x:%02x" \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) \
    $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
  
  # Ensure the MAC address is unicast (bit 0 of the first byte is 0)
  local first_byte=${mac_address:0:2}
  first_byte=$(printf "%02x" $(((0x00 | 0x${first_byte}) & 0xfe)))
  mac_address=${first_byte}${mac_address:2}
  mac_address=${mac_address^^}
  echo "$mac_address"
}

# function generate_ssh_key() {
#   ssh-keygen -t ed25519 -q -N "" -C "root@localhost.localdomain" -f "./data/id_ed25519"
# }

TAP_DEV="microvm0"
TAP_IP_ADDRESS=$(inspect_tap "$TAP_DEV" "local")
TAP_SUBNET_CIDR=$(inspect_tap "$TAP_DEV" "prefixlen")
TAP_SUBNET_MASK=$(cidr_to_netmask "$TAP_SUBNET_CIDR")

VMS_IP_ADDRESS="172.20.0.2"
VMS_MAC=$(generate_mac_address)

# If cannot boot try this boot args
# Based on this https://github.com/firecracker-microvm/firecracker/issues/4816
# KERNEL_BOOT_ARGS="ro console=ttyS0 reboot=k panic=1 pci=off"

KERNEL_BOOT_ARGS="ro console=ttyS0 noapic reboot=k panic=1 pci=off nomodules random.trust_cpu=on"
KERNEL_BOOT_ARGS="${KERNEL_BOOT_ARGS} ip=${VMS_IP_ADDRESS}::${TAP_IP_ADDRESS}:${TAP_SUBNET_MASK}::eth0:off"

cat <<EOF > ./data/vmconfig.json
{
  "boot-source": {
    "kernel_image_path": "./data/vmlinux.bin",
    "boot_args": "$KERNEL_BOOT_ARGS"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "./data/ubuntu-22.04.rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "$VMS_MAC",
      "host_dev_name": "$TAP_DEV"
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
EOF

# VMID=$(uuidgen)
VMID="2906f87c-eff1-4ef6-8742-71aa6a2b7189"
CHROOT_PATH="/srv/jailer/firecracker/$VMID/root"

rm -rf $CHROOT_PATH
mkdir -p $CHROOT_PATH $CHROOT_PATH/data

# Copy deployment file + kernel + fs
cp ./data/vmlinux.bin $CHROOT_PATH/data/vmlinux.bin
cp ./data/vmconfig.json $CHROOT_PATH/vmconfig.json
cp ./data/ubuntu-22.04.rootfs.ext4 $CHROOT_PATH/data/ubuntu-22.04.rootfs.ext4

chmod o+x $CHROOT_PATH/data/vmlinux.bin
chmod o+w $CHROOT_PATH/data/ubuntu-22.04.rootfs.ext4

jailer \
  --id $VMID \
  --exec-file $(which firecracker) \
  --uid 1000 \
  --gid 1000 \
  --chroot-base-dir "/srv/jailer"\
  -- \
  --config-file vmconfig.json