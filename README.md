# ZWIEGNET Hercules for Enterprise Linux 10

This repository builds SDL Hercules mainframe emulator RPM packages for
AlmaLinux 10 and compatible Enterprise Linux 10 systems.

- Package: `hercules`
- Architecture: x86_64
- Build target: AlmaLinux 10
- Upstream: [SDL Hercules 4.x Hyperion](https://github.com/SDL-Hercules-390/hyperion)
- Project information: https://www.hercules-390.eu/

The package includes the emulator, upstream utility programs, runtime
libraries/modules installed by upstream, and the `hercules(1)` man page.

## ZWIEGNET RPM versioning

This repository uses the same package naming and rebuild convention as
[azwieg103/gnucobol](https://github.com/azwieg103/gnucobol):

```
hercules-<upstream-version>-ZWIEGNET.<build-number>.el10.<architecture>.rpm
```

The RPM release field is `ZWIEGNET.N.el10`. The rebuild number increments
for each published build of the same upstream version. A new upstream
version starts at `ZWIEGNET.1.el10`. GitHub Release tags follow the GnuCOBOL
convention: `hercules-<upstream-version>-ZWIEGNET.N.el10`.

For example, upstream 4.9.1 produces
`hercules-4.9.1-ZWIEGNET.1.el10.x86_64.rpm`.

## Automated build pipeline

GitHub Actions builds on relevant pushes to `main`, daily on a schedule,
and on demand through Actions > Build Hercules RPM.

The workflow installs dependencies in an AlmaLinux 10 container, obtains
the current SDL Hercules Hyperion source, reads its upstream version, and
selects the next ZWIEGNET rebuild number from published GitHub Releases.
Compilation and RPM packaging are retried up to three times. Build logs are
retained as workflow artifacts, including on failure. Successful builds
publish binary and source RPMs as a GitHub Release. Existing releases are
never overwritten.

## Install Hercules

Download the EL10 x86_64 RPM from
[GitHub Releases](https://github.com/azwieg103/hercules/releases) and install
it with DNF:

```bash
sudo dnf install ./hercules-*-ZWIEGNET.*.el10.x86_64.rpm
hercules -v
hercules -h
man hercules
```

The executable is installed as `/usr/bin/hercules`.

## Getting an MVS system running

Hercules emulates the mainframe hardware; it does **not** include MVS, z/OS,
DOS/VS, VM, or any other IBM operating system. You must obtain a bootable
guest distribution and its disk/tape images separately, and you are
responsible for complying with the applicable software licenses. This RPM
does not download or install an operating system or provide IBM system
volumes.

A practical way to get started is to use a complete Hercules-ready MVS
distribution (for example, a legally obtained MVS 3.8j-based distribution
such as TK4-). Such distributions commonly include a tested Hercules
configuration, DASD images, startup scripts, and system-specific operating
instructions. Follow the distribution's own documentation first; do not
substitute an arbitrary sample device layout for its supplied configuration.

### 1. Create a service account and data directories

Run Hercules as an unprivileged dedicated account when the guest does not
need host networking devices:

```bash
sudo useradd --system --home-dir /var/lib/hercules \
  --create-home --shell /sbin/nologin hercules

sudo install -d -o hercules -g hercules -m 0750 \
  /etc/hercules \
  /var/lib/hercules \
  /var/lib/hercules/dasd \
  /var/lib/hercules/tapes \
  /var/lib/hercules/working
```

Keep the operating-system distribution and its DASD/tape images under
`/var/lib/hercules`. Preserve the directory structure expected by its
configuration and startup scripts. For example, if its configuration references a relative path such as
`dasd/vol001.3390`, either retain that directory layout under the configured
working directory or edit the path to its final absolute location.

Copy the distribution's Hercules configuration to:

```text
/etc/hercules/hercules.cnf
```

Then make sure the service account can read the configuration and all
referenced guest files. It must also be able to write to any DASD shadow
files, printer output, card-reader/punch files, tape output, logs, and
working directories that the guest uses:

```bash
sudo chown -R hercules:hercules /var/lib/hercules
sudo chown root:hercules /etc/hercules
sudo chmod 0750 /etc/hercules
sudo chmod 0640 /etc/hercules/hercules.cnf
```

If you keep the original distribution elsewhere, grant the `hercules`
account access to that location instead of making unnecessary copies.

### 2. Review the Hercules configuration

The configuration file describes the emulated CPU, memory, channel devices,
DASD, tape, consoles, and optional network adapters. Review every path in
the supplied `hercules.cnf` and make sure it resolves on this Linux host.
For example, a 3390 device entry points to a guest DASD image; it is not a
physical Linux disk.

At minimum, verify:

- The architecture and CPU/memory settings are appropriate for the guest.
- Every DASD and tape image exists and is readable by the service account.
- Writable images and output directories are writable by the service account.
- Device addresses and device types match the MVS distribution's instructions.
- Any 3270 terminal listener ports are reachable from the workstation running
  your TN3270 client.
- Host networking devices are configured deliberately; do not enable a guest
  network adapter just because a sample configuration contains one.

The configuration file is not an operating-system installer. MVS must already
be installed on, or supplied as, bootable guest volumes. Consult the upstream
[Hercules configuration reference](https://sdl-hercules-390.github.io/html/hercconf.html)
and [installation and operation guide](https://sdl-hercules-390.github.io/html/hercinst.html).

### 3. Test the guest interactively before enabling systemd

First run Hercules in the foreground so startup errors and the operator
console are visible:

```bash
sudo -u hercules sh -c \
  'cd /var/lib/hercules && exec /usr/bin/hercules -f /etc/hercules/hercules.cnf'
```

Use the Hercules operator console and the MVS distribution's documented
startup procedure to load/boot the guest. The exact IPL device, console
commands, and startup sequence depend on the MVS distribution and its
volumes; there is no universal IPL address.

When the guest is running, connect a TN3270 client to the host and the
3270 device/listener port configured in `hercules.cnf` (often port 3270,
but use the actual configured value). A TN3270 client is separate software;
it is not included in this RPM.

Stop the foreground test cleanly before starting the systemd service.

## Run Hercules with systemd

The following unit runs Hercules without an attached panel, leaves it in the
foreground for systemd supervision, and sends its output to the journal.
Hercules 4.x supports `-n` (NoUI) for this non-interactive mode. Do not use
the old `-d` daemon option with this unit: systemd should supervise the
Hercules process itself.

Create `/etc/systemd/system/hercules.service`:

```ini
[Unit]
Description=Hercules IBM Mainframe Emulator
Documentation=https://sdl-hercules-390.github.io/html/hercinst.html
After=network.target

[Service]
Type=simple
User=hercules
Group=hercules
WorkingDirectory=/var/lib/hercules
ExecStart=/usr/bin/hercules -f /etc/hercules/hercules.cnf -n
Restart=on-failure
RestartSec=5
TimeoutStopSec=60
UMask=0027
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Load the unit, enable it at boot, and start it now:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hercules.service
```

Check status and follow the logs:

```bash
systemctl status hercules.service
sudo journalctl -u hercules.service -f
```

Common service operations:

```bash
sudo systemctl stop hercules.service
sudo systemctl start hercules.service
sudo systemctl restart hercules.service
sudo systemctl disable hercules.service
```

After changing `hercules.cnf` or the unit file, restart the service. If you
change the unit file itself, run `sudo systemctl daemon-reload` first.

### Guest networking and Linux permissions

The example service intentionally runs as the unprivileged `hercules`
account. Hercules configurations that attach host networking devices (for
example, TUN/TAP-backed CTCI, LCS, or QETH devices) may require elevated
host privileges and access to `/dev/net/tun`. The upstream operating guide
warns that networking-device initialization can fail without administrative
privileges.

Do not solve this by casually running every guest as root. First decide
which network device the guest needs, configure the host interface/TUN/TAP
and firewall, and then grant only the required access. If the selected
Hercules device genuinely requires root privileges, use a reviewed
systemd override or a dedicated host networking setup and understand the
security implications before enabling it. A guest network adapter can expose
the host to traffic from the emulated operating system.

### Troubleshooting

- **Service exits immediately:** inspect `journalctl -u hercules -b`; check
  the configuration syntax, executable path, and every referenced file.
- **DASD opens read-only or fails to open:** verify ownership, permissions,
  SELinux labels, and whether the image is on a read-only filesystem.
- **3270 client cannot connect:** confirm the configured listener port,
  host firewall rules, and the address on which Hercules is listening.
- **Guest networking fails:** verify the host TUN/TAP setup and the privileges
  required by the configured Hercules network device.
- **Guest does not IPL:** confirm the MVS distribution's documented IPL
  device, boot volumes, and startup procedure. Hercules starting successfully
  does not mean the guest operating system has booted.

## Build locally on AlmaLinux 10

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled crb
sudo dnf install -y gcc gcc-c++ make autoconf automake libtool flex bison perl \
  ncurses-devel zlib-devel bzip2-devel openssl-devel curl-devel \
  rpm-build rpmdevtools git tar gzip findutils sed grep patch diffutils which \
  pkgconf-pkg-config
./scripts/build-rpm.sh
```

To specify the release explicitly:

```bash
RPM_VERSION=4.9.1 RPM_RELEASE=ZWIEGNET.1.el10 ./scripts/build-rpm.sh
```

RPMs are written to `dist/`; build logs are written to `build-logs/`.

## License and support

SDL Hercules is distributed under the Q Public License (QPL); consult the
upstream `COPYRIGHT` and `LICENSES` materials for full license terms.
This repository supplies packaging and build automation, not IBM software.
Packages are supplied as-is, without warranty or commercial support.
