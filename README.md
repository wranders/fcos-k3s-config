# Fedora CoreOS + k3S

Fedora CoreOS with packages required to run k3s.

## Usage

Build with [`coreos-assembler`](https://github.com/coreos/coreos-assembler).

The k3s install script is located at `/usr/lib/k3s/install.sh` and will be
automatically run post-ignition: immediately if PXE/Live, or after reboot is
installed to disk

To configure k3s, define a config file at `/etc/rancher/k3s/config.yaml` in your
Ignition file. Configuration options are arguments without the preceding `--`.

* [`server` arguments](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/)
* [`agent` arguments](https://rancher.com/docs/k3s/latest/en/installation/install-options/agent-config/)

A `server` installation is performed if `server: <URL>` is missing from the
`config.yaml` file. Inversely, an `agent` installation is performed if it is
present, though remember to also specify the `token` value.

Install `server` using `butane`:

```yaml
storage:
  files:
  - path: /etc/rancher/k3s/config.yaml
    contents:
      inline: |
        write-kubeconfig-mode: 644
        token: "secrett0ken"
        disable:
        - local-storage
        - traefik
        tls-san:
        - "k3ssrv01.local"
```

Install `agent` using `butane`:

```yaml
storage:
  files:
  - path: /etc/rancher/k3s/config.yaml
    contents:
      inline: |
        server: https://k3ssrv01.local:6443
        token: "secrett0ken"
```

### Air-Gap Install

With just the configuration file, the `k3s` install script will download the
required binary and images. To distribute locally or offline, include the
following in your Ignition file. For convenience, the `download-artifacts.sh`
script will pull these files into the `./downloads`folder for easier
distribution.

Using `butane`:

```yaml
storage:
  files:
  - path: /var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar
    contents:
      compression: gzip
      source: http://10.0.10.1/k3s-airgap-images-amd64.tar.gz
      verification:
        hash: sha256-a901da769286da2f29f4451cae613c452663b0ce343bce37571c677d81533b5d
  - path: /usr/local/bin/k3s
    # Regardless of architecture, binary on system must be called 'k3s'
    contents:
      source: http://10.0.10.1/k3s
      # source: http://10.0.10.1/k3s-arm64
      verification:
        hash: sha256-84bc5241f76d9468c25bb5982624df21ba7f1d6fb142d5986912dca82577d6f7
```

To prevent the install script from attempting to download the files, include the
following `systemd` drop-in to the install service:

```yaml
systemd:
  units:
  - name: k3s-install.service
    dropins:
    - name: skip-download.conf
      contents: |
        [Service]
        Environment=INSTALL_K3S_SKIP_DOWNLOAD=true
```
