#!/bin/bash

function fatal() {
    echo '[FATAL] ' "$@" >&2
    exit 1
}

ARCH=$(uname -m)
case "$ARCH" in
    x86_64 | amd64)
        ARCH=amd64
        SUFFIX=
        ;;
    aarch64 | arm64)
        ARCH=arm64
        SUFFIX=-${ARCH}
        ;;
    arm*)
        ARCH=arm
        SUFFIX=-${ARCH}hf
        ;;
    *)
        fatal "Unsupported CPU architecture $ARCH"
esac

STORE=/usr/lib/k3s
IMAGES=/var/lib/rancher/k3s/agent/images

mkdir -p $IMAGES
gzip -dc < $STORE/k3s-airgap-$ARCH.tar.gz > $IMAGES/k3s-airgap-$ARCH.tar
cp $STORE/k3s$SUFFIX /usr/local/bin/k3s