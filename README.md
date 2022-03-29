# Fedora CoreOS + k3S

Fedora CoreOS with packages required to run k3s.

## Usage

Build with [`coreos-assembler`](https://github.com/coreos/coreos-assembler).

The k3s install script is located at `/usr/libexec/k3s-install` and will be
automatically run post-ignition: immediately if PXE/Live, or after reboot if
installed to disk

To configure the k3s `server`, define a configuration file at
`/etc/rancher/k3s/config.yaml` in your Butane/Ignition file. Configuration
options are `server` arguments without the preceding `--`.

A `server` installation is only performed if `/etc/rancher/k3s/config.yaml`
exists.

* [`server` arguments](https://rancher.com/docs/k3s/latest/en/installation/install-options/server-config/)

Install `server` using Butane:

```yaml
storage:
  files:
  - path: /etc/rancher/k3s/config.yaml
    contents:
      inline: |
        write-kubeconfig-mode: 644
        token: secrett0ken
        disable:
        - local-storage
        - traefik
        tls-san:
        - "k3ssrv01.local"
```

Since the `/etc/rancher/k3s/config.yaml` file is unused by the k3s `agent`,
the `agent` needs to be configured with environment variables, where `K3S_URL`
is required with either `K3S_TOKEN` or `K3S_CLUSTER_SECRET`. If both `K3S_TOKEN`
and `K3S_CLUSTER_SECRET` are missing, the `agent` installation will fail.

* [`agent` arguments](https://rancher.com/docs/k3s/latest/en/installation/install-options/agent-config/)

Configuration options that do not have a corresponding environment variable must
be defined using the `INSTALL_K3S_EXEC` environment variable.

Install `agent` using Butane:

```yaml
systemd:
  units:
  - name: install-k3s.service
    dropins:
    - name: agent.conf
      contents: |
        [Service]
        Environment=K3S_URL=https://k3ssrv01.local:6443
        Environment=K3S_TOKEN=secrett0ken
        Environment=INSTALL_K3S_EXEC="--node-label foo=bar --node-taint key1=value:NoExecute"
```

### Air-Gap Install

With just the above configurations, the k3s install script will download the
required binary and images. To distribute locally or offline, include the
following in your Butane/Ignition file. For convenience, the
`download-artifacts.sh` script will pull these files into the `./downloads`
folder in the repository for easier distribution.

Using Butane:

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
    # Regardless of architecture, the binary on system must be called 'k3s'
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
  - name: install-k3s.service
    dropins:
    - name: skip-download.conf
      contents: |
        [Service]
        Environment=INSTALL_K3S_SKIP_DOWNLOAD=true
```

## Uninstall

To uninstall k3s, use the `k3s-uninstall.sh` script installed by k3s. If you
want to k3s to be automatically reinstalled, you must manually delete the
`/etc/rancher/k3s-installed` file created by the installer service, or else
the installer service will silently fail.

The uninstall script removes the `/etc/rancher/k3s` directory, so `config.yaml`
is deleted as a result. To restart `install-k3s.service` or re-run the
`/usr/libexec/k3s-install` script, `/etc/rancher/k3s/config.yaml` will have to
be recreated or arguments will have to be provided to `/usr/libexec/k3s-install`
directly.

In most cases, it is recommended to reprovision with your Butane configuration.
