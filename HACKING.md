# Hacking on fcos-k3s-config

This is derivative of the main
[fedora-coreos-config](https://github.com/coreos/fedora-coreos-config), so it's
built the same way using
[coreos-assembler](https://github.com/coreos/coreos-assembler).

Contributions are welcome. If you notice a bug or missing feature, you're
invited to fix it and submit your work as a
[pull request](https://github.com/wranders/fcos-k3s-config/pull/new).

## Setup coreos-assembler

Instructions come from
[coreos-assembler documentation](https://coreos.github.io/coreos-assembler/building-fcos/).

You will need a modern Linux operating system and `podman`.

Paste the following function into your terminal to create the `coreos-assembler`
alias. This can also be placed in `~/.bashrc.d/` to persist the alias between
sessions.

```sh
cosa() {
    env | grep COREOS_ASSEMBLER
    set -x
    podman run --rm -ti --security-opt label=disable --privileged                            \
        --uidmap=1000:0:1 --uidmap=0:1:1000 --uidmap 1001:1001:64536                         \
        -v ${PWD}:/srv/ --device /dev/kvm --device /dev/fuse                                 \
        --tmpfs /tmp -v /var/tmp:/var/tmp --name cosa                                        \
        ${COREOS_ASSEMBLER_CONFIG_GIT:+-v $COREOS_ASSEMBLER_CONFIG_GIT:/srv/src/config/:ro}  \
        ${COREOS_ASSEMBLER_GIT:+-v $COREOS_ASSEMBLER_GIT/src/:/usr/lib/coreos-assembler/:ro} \
        ${COREOS_ASSEMBLER_CONTAINER_RUNTIME_ARGS}                                           \
        ${COREOS_ASSEMBLER_CONTAINER:-$COREOS_ASSEMBLER_CONTAINER_LATEST} "$@"
    rc=$?; set +x; return $rc
}
```

## Setup and Use Cloned Repository

```sh
git clone https://github.com/wranders/fcos-k3s-config
```

```sh
export COREOS_ASSEMBLER_CONFIG_GIT="${PWD}/fcos-k3s-config"
```

## Building

Create an empty directory to work in.

```sh
mkdir ~/fcos-k3s && cd $_
```

Initialize the assembler and working directory structure.

```sh
cosa init --force $COREOS_ASSEMBLER_CONFIG_GIT
```

Fetch and import the latest packages.

```sh
cosa fetch
```

Build OSTree. This is required to build all other artifacts.

```sh
cosa build ostree
```

### Testing with QEMU

QEMU can be used to run the latest built image.

Build the QEMU image:

```sh
cosa build ostree qemu
```

Once this is done, you can run it using `cosa`.

```sh
cosa run -b fcos -c
```

To exit, press `Ctrl-a` then `x`.

The `-b` flag must be specified with `fcos`. `-c` is used to connect directly to
the serial console.

Butane and Ignition files can also be used:

```sh
cosa run -b fcos -c -B install.bu
```

```sh
cosa run -b fcos -c -i install.ign
```

To see more examples, check out the reference for
[cosa run](https://coreos.github.io/coreos-assembler/cosa/run/).

### Testing with Live ISO

Live artifacts require the `metal` and `metal4k` artifacts, which require `qemu`
and `ostree`.

```sh
cosa build ostree qemu metal metal4k
```

Now build the ISO and PXE artifacts.

```sh
cosa buildextend-live
```

Create a simple Butane file.

```sh
cat << EOF > install.bu && echo
variant: fcos
version: 1.4.0
passwd:
  users:
  - name: core
    password_hash: $(read -sp 'Password: ' pwd && podman run --rm -it quay.io/coreos/mkpasswd -m yescrypt $pwd)
EOF
```

Transpile the Butane file to Ignition.

```sh
podman run -i --rm quay.io/coreos/butane:latest --strict < install.bu > install.ign
```

Create a custom iso with `coreos-installer`. There are different commands for
Live booting and disk installation.

To install to disk:

```sh
podman run --rm -v .:/data:z -w /data \
quay.io/coreos/coreos-installer:latest iso customize \
--dest-device=/dev/sda \
--dest-ignition=install.ign \
--output custom.iso \
$(find ./builds/latest/x86_64 -name "*.iso")
```

To run Live from memory:

```sh
podman run --rm -v .:/data:z -w /data \
quay.io/coreos/coreos-installer:latest iso ignition embed \
--ignition-file=install.ign \
--output=custom.iso \
$(find ./builds/latest/x86_64 -name "*.iso")
```

## Adding to fcos-k3s

If it's related to `k3s`, add it to the `overlay.d/95k3s` directory in the
appropriate root filesystem path.

If it's something unrelated to `k3s`, but not appropriate for the upstream
configuration, then create a new directory in `overlay.d` and add it to the
manifest template (`manifest.yaml.tmpl`) under the `ostree-layers` key.

For example, if you add `overlay.d/50myfeature`:

```yaml
. . .
ostree-layers:
- overlay/50myfeature
. . .
```

Then run the `build-manifest.sh` script to generate the new manifest.

## Updating Upstream Config or k3s

Use the `pin-submodule.sh` script to set new versions of the upstream
`fedora-coreos-config` and `k3s`.

```sh
./pin-submodule.sh [SUBMODULE] [OPTIONS]

Pin a submodule

SUBMODULE:
    config  CoreOS Assembler configuration
    k3s     K3S
```

```sh
./pin-submodule.sh config [OPTIONS]

Pin upstream CoreOS Assembler configuration.
Specify branch and either latest or commit hash.

    ./pin-submodule.sh config -b stable -l
    ./pin-submodule.sh config -b stable -c f1962b5

OPTIONS:
    -l      Latest
    -b      Branch
    -c      Commit Hash / ID
```

```sh
./pin-submodule.sh k3s [OPTIONS]

Pin upstream k3s.

Specify either latest or a release tag.

    ./pin-submodule.sh k3s -l
    ./pin-submodule.sh k3s -t v1.22.4+k3s1

OPTIONS:
    -l      Latest
    -t      Release Tag
```
