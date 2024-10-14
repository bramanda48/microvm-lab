#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

TEMP_MOUNTING_DIR=`mktemp -d`

# Install prerequisites
command -v skopeo &> /dev/null || { sudo apt update && sudo apt install -y skopeo; }

IMAGES_FILE="./data/ubuntu-22.04.tar"
ROOTFS_FILE="./data/ubuntu-22.04.rootfs.tar"
EXT4_FILE="${ROOTFS_FILE%.*}.ext4"

mkdir -p data
rm -f $IMAGES_FILE $ROOTFS_FILE $EXT4_FILE

skopeo copy docker://ghcr.io/malang-dev/microstack-ubuntu:22.04 docker-archive:$IMAGES_FILE
undocker $IMAGES_FILE $ROOTFS_FILE

get_tar_file_size() {
  tar_file="$1"

  if [[ -f "$tar_file" ]]; then
    file_size_bytes=$(stat -c %s "$tar_file")
    echo $file_size_bytes
  else
    echo "File not found: $tar_file"
    exit 1
  fi
}

function cleanup {   
  if grep -qs "$TEMP_MOUNTING_DIR" /proc/mounts; then
    echo "Unmounting $TEMP_MOUNTING_DIR"
    umount "$TEMP_MOUNTING_DIR"   
  fi

  echo "Deleted temp working directory $TEMP_MOUNTING_DIR"
  rm -rf "$TEMP_MOUNTING_DIR"
}

trap cleanup EXIT

ROOTFS_FILE_SIZE=$(get_tar_file_size $ROOTFS_FILE)
ROOTFS_FILE_SIZE=$(($ROOTFS_FILE_SIZE + 31457280)) # Add more 30MB for reserved space

truncate -s 500M $EXT4_FILE
mkfs.ext4 $EXT4_FILE

mount $EXT4_FILE -o loop $TEMP_MOUNTING_DIR
tar -xf $ROOTFS_FILE -C $TEMP_MOUNTING_DIR
umount $TEMP_MOUNTING_DIR

echo "Image contents extracted into ${EXT4_FILE}."
