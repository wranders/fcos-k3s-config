# Fedora CoreOS + k3S

Fedora CoreOS with packages required to run k3s.

## Usage

Build with [`coreos-assembler`](https://github.com/coreos/coreos-assembler).

The k3s install script is located at `/usr/lib/k3s/install.sh` and will be
automatically run post-ignition. ***(Not true at the moment. Still a WIP, but
will be the intent)***

To configure k3s, define a config file at `/etc/rancher/k3s/config.yaml` in your
Ignition file. Configuration options are `k3s server` options without the
preceding `--`.

Using `butane`:

```yaml
storage:
  files:
    - path: /etc/rancher/k3s/config.yaml
      contents:
        inline: |
          write-kubeconfig-mode: 644
          token: "secret"
          node-ip: 10.0.10.22,2a05:d012:c6f:4655:d73c:c825:a184:1b75 
          cluster-cidr: 10.42.0.0/16,2001:cafe:42:0::/56
          service-cidr: 10.43.0.0/16,2001:cafe:42:1::/112
          disable-network-policy: true
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
