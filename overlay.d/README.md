# Overlays

The following overlays are imported from the base `fedora-coreos-config`.

* `05core`
* `08nouveau`
* `09misc`
* `14NetworkManager-plugins`
* `15fcos`
* `20platform-chrony`
* `35coreos-iptables`

Refer to the base `overlay.d` `README.md`.

## Customizations

* `99k3s` - Contains `systemd` units and configuration files for
[k3s](https://k3s.io/)
