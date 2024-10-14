#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

IMAGES_FILE="./data/kenel-5.10.199.tar"
KERNEL_FILE="./data/kenel-5.10.199.kernel.tar"
BIN_FILE="./data/vmlinux.bin"

mkdir -p data
rm -f $IMAGES_FILE $KERNEL_FILE $BIN_FILE

skopeo copy docker://ghcr.io/malang-dev/microstack-kernel:5.10.199 docker-archive:$IMAGES_FILE
undocker $IMAGES_FILE $KERNEL_FILE

TEMP_DIR=`mktemp -d`
tar -xf $KERNEL_FILE -C $TEMP_DIR
mv $TEMP_DIR/boot/vmlinux $BIN_FILE