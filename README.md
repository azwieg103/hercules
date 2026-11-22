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

### TK4-: run MVS 3.8j with this Hercules RPM

[TK4- (The MVS 3.8j Tur(n)key System)](https://wotho.ethz.ch/tk4-/) is a
ready-to-run MVS 3.8j environment. It supplies the guest DASD images,
Hercules configuration, startup scripts, and MVS customization. The
Hercules RPM in this repository supplies the **emulator executable**; use
that executable instead of the older Hercules binary bundled with some
TK4- archives.

#### 1. Download and extract TK4-

Install the archive tools and create a dedicated location. The following
uses the published current archive URL; if the TK4- download page publishes
a newer archive name, use that archive instead.

```bash
sudo dnf install -y curl unzip

# Create the dedicated account if it does not already exist.
getent passwd hercules >/dev/null || sudo useradd --system \
  --home-dir /var/lib/hercules --create-home \
  --shell /sbin/nologin hercules

sudo install -d -o hercules -g hercules -m 0750 /var/lib/hercules/tk4

sudo -u hercules curl -fL \
  https://wotho.ethz.ch/tk4-/tk4-_v1.00_current.zip \
  -o /var/lib/hercules/tk4-current.zip

sudo -u hercules unzip -q \
  /var/lib/hercules/tk4-current.zip \
  -d /var/lib/hercules/tk4
```

The extracted TK4- directory must have these paths directly beneath it:

```text
/var/lib/hercules/tk4/
  conf/tk4-.cnf
  scripts/ipl.rc
  scripts/tk4-.rc
  start_herc
  mvs
  local_conf/
  dasd/
  log/
  unattended/
```

Some archive revisions or repackaged downloads may add a top-level directory.
If so, move that directory's **contents** into
`/var/lib/hercules/tk4/`; do not leave the configuration nested an extra
level down. Check before proceeding:

```bash
test -f /var/lib/hercules/tk4/conf/tk4-.cnf
test -f /var/lib/hercules/tk4/scripts/ipl.rc
test -d /var/lib/hercules/tk4/dasd
```

Set ownership so MVS can update its DASD, logs, printer output, and other
working files:

```bash
sudo chown -R hercules:hercules /var/lib/hercules/tk4
sudo chmod 0750 /var/lib/hercules/tk4
```

Keep a backup of the original TK4- archive and guest DASD images before
applying updates or making system changes. Do not run an update against the
only copy of your system volumes.

#### 2. Use the installed Hercules binary, not TK4-'s bundled one

The stock TK4- Linux launch scripts prepend TK4-'s own
`hercules/linux/<architecture>/bin` directory to `PATH` and set
`LD_LIBRARY_PATH` to its bundled libraries. That can cause the old bundled
emulator to run even when the ZWIEGNET RPM is installed.

The ZWIEGNET RPM now installs a TK4-specific launcher at
`/usr/libexec/hercules/tk4-hercules` and a systemd unit at
`/usr/lib/systemd/system/hercules-tk4.service`. The launcher explicitly
executes `/usr/bin/hercules`, loads optional
`local_conf/tk4-.parm` settings, and selects TK4-'s automatic IPL script
(`scripts/ipl.rc`). It does not use TK4-'s bundled emulator or its bundled
library path.

#### 3. Enable the packaged TK4 systemd service

If you previously enabled the generic `hercules.service` from the section
below, disable it so it does not compete for the same emulator ports:

```bash
sudo systemctl disable --now hercules.service 2>/dev/null || true
```

The TK4 service is installed with the RPM but is **not enabled automatically**.
After extracting TK4- and verifying that
`/var/lib/hercules/tk4/conf/tk4-.cnf` exists, enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now hercules-tk4.service
```

Check startup and logs:

```bash
systemctl status hercules-tk4.service
sudo journalctl -u hercules-tk4.service -f
sudo tail -f /var/lib/hercules/tk4/log/3033.log
```

The unit runs Hercules in the foreground, allowing systemd to supervise the
actual emulator process. It only starts when the TK4- configuration file is
present. TK4- performs its automatic IPL through `scripts/ipl.rc`, which
issues `ipl 148` and drives the supplied MVS startup sequence.

#### 4. Connect a TN3270 terminal

The standard TK4- configuration provides a TN3270 console listener, normally
on TCP port 3270. Confirm the actual listener on your host:

```bash
sudo ss -ltnp | grep -E ':(3270|8038)\b'
```

Connect a TN3270 client to the Linux host's address on port `3270`. If
connecting from another machine, allow TCP/3270 through the host firewall
only from the client networks that should have access. For example, to open
the port generally with firewalld:

```bash
sudo firewall-cmd --permanent --add-port=3270/tcp
sudo firewall-cmd --reload
```

The Hercules HTTP command interface commonly listens on TCP/8038 in TK4-
configurations. Treat that as an administrative interface: do not expose it
to untrusted networks or the public Internet. If remote access is required,
restrict it with host firewall rules or use a secure tunnel.

Once the guest finishes IPL, the TN3270 console should display the MVS
system. TK4- includes its own sample users, jobs, and operational setup;
consult the distribution's manual for login credentials, commands, and
customization.

#### 5. Stop and restart TK4- safely

Use the TK4-/MVS shutdown procedure from its operator console before
stopping the emulator service. Do not use `systemctl stop` as a substitute
for an orderly guest shutdown while MVS is running jobs or writing DASD.

After the guest has shut down, manage the emulator with:

```bash
sudo systemctl stop hercules-tk4.service
sudo systemctl start hercules-tk4.service
sudo systemctl restart hercules-tk4.service
sudo systemctl disable hercules-tk4.service
```

For diagnostics:

```bash
sudo journalctl -u hercules-tk4.service -b
sudo ss -ltnp | grep -E ':(3270|8038)\b'
```

If the service starts but MVS does not IPL, check that
`/var/lib/hercules/tk4/scripts/ipl.rc` exists, the configured DASD images
are present and writable, and the service's working directory is
`/var/lib/hercules/tk4`. Also inspect the TK4- `log/` directory and the
system journal.

For more detail, see the [TK4- project and downloads](https://wotho.ethz.ch/tk4-/),
the [TK4- source scripts](https://github.com/actualquak/tk4), and the
[TK4- user manual](https://peppe8o.com/download/python/mainframe/mvs_tk4-_v1.00_users_manual.pdf).
The manual documents both the automatic IPL sequence and the manual
procedure (start Hercules, connect the configured consoles, then issue
`ipl 148`).

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

The packaged TK4 launcher uses Hercules `-n` (NoUI) mode and writes the emulator panel log to `/var/lib/hercules/tk4/log/3033.log`; systemd still captures launcher/service messages in the journal. The service intentionally runs as the unprivileged `hercules`
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
