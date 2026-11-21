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

## Install

Download the EL10 x86_64 RPM from GitHub Releases and install it:

```bash
sudo dnf install ./hercules-*-ZWIEGNET.*.el10.x86_64.rpm
hercules -v
man hercules
```

## Run

Create a Hercules configuration file and start the emulator:

```bash
sudo install -d -m 0755 /etc/hercules
hercules /etc/hercules/my-system.cnf
```

Hercules configuration controls the emulated CPU model, storage, device
addresses, DASD/tape files, consoles and networking. See the upstream
installation guide: https://sdl-hercules-390.github.io/html/hercinst.html

IBM operating system software, licensed guest programs, disk images and
tape images are not included. Obtain and use those materials under their
own licensing terms.

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
