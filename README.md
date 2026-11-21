# ZWIEGNET Hercules for Enterprise Linux 10

This repository builds and publishes the SDL Hercules mainframe emulator as
native RPM packages for AlmaLinux 10 and compatible Enterprise Linux 10
systems.

- **Package:** `hercules`
- **Architecture:** x86_64
- **Target:** AlmaLinux 10 (EL10)
- **Upstream:** [SDL Hercules 4.x Hyperion](https://github.com/SDL-Hercules-390/hyperion)
- **Project information:** https://www.hercules-390.eu/

The package includes the emulator, upstream utility programs, runtime
libraries/modules installed by upstream, and the `hercules(1)` man page.

## ZWIEGNET RPM versioning

The RPM uses the same naming and rebuild convention as
[azwieg103/gnucobol](https://github.com/azwieg103/gnucobol):

```
hercules-<upstream-version>-ZWIEGNET.<build-number>.el10.<architecture>.rpm
```

The RPM release field is `ZWIEGNET.N.el10`. The rebuild number increments
for each published build of the same upstream version. A new upstream
version starts at `ZWIEGNET.1.el10`. GitHub Release tags follow the same
pattern used by the GnuCOBOL project:

```
hercules-<upstream-version>-ZWIEGNET.N.el10
```

For example, upstream version 4.9.1 produces
`hercules-4.9.1-ZWIEGNET.1.el10.x86_64.rpm`.

## Automated build pipeline

GitHub Actions runs the RPM build:

- On relevant pushes to `main`.
- On a daily schedule to pick up upstream changes.
- On demand through the Actions tab (`workflow_dispatch`).

The workflow installs build dependencies in an AlmaLinux 10 container,
checks out this packaging repository, obtains the current SDL Hercules
Hyperion source, determines its upstream version, and selects the next
ZWIEGNET rebuild number from existing GitHub Releases.

The build script retries failed compilation/package attempts up to three
times. Build logs are uploaded as workflow artifacts even when a build
fails. Successful builds produce binary and source RPM artifacts and publish
them as a GitHub Release. Existing releases are never overwritten.

## Install

Download the current EL10 x86_64 RPM from the repository's GitHub Releases,
then install it with DNF:

```bash
sudo dnf install ./hercules-*-ZWIEGNET.*.el10.x86_64.rpm
```

Confirm installation:

```bash
hercules -v
man hercules
```

## Run

Create a Hercules configuration file, for example
`/etc/hercules/my-system.cnf`, and start the emulator:

```bash
sudo install -d -m 0755 /etc/hercules
hercules /etc/hercules/my-system.cnf
```

Hercules configuration controls the emulated CPU model, storage, device
addresses, DASD/tape files, consoles and networking. Consult the upstream
installation and operation guide before configuring a guest:

https://sdl-hercules-390.github.io/html/hercinst.html

The package does not include IBM operating system software, licensed guest
programs, DASD images or tape images. Obtain and use those materials under
their own licensing terms.

## Build locally on AlmaLinux 10

Install the build toolchain and libraries:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled crb
sudo dnf install -y gcc gcc-c++ make autoconf automake libtool flex bison perl \
  ncurses-devel zlib-devel bzip2-devel openssl-devel curl-devel \
  rpm-build rpmdevtools git tar gzip findutils sed grep patch diffutils which \
  pkgconf-pkg-config
```

Then run:

```bash
./scripts/build-rpm.sh
```

To specify the ZWIEGNET release explicitly:

```bash
RPM_VERSION=4.9.1 RPM_RELEASE=ZWIEGNET.1.el10 ./scripts/build-rpm.sh
```

RPMs are written to `dist/`; build logs are written to `build-logs/`.

## License and support

SDL Hercules is distributed under the Q Public License (QPL); see the
upstream `COPYRIGHT` and `LICENSES` materials for license details.
This repository supplies packaging and build automation, not IBM software.

Packages are supplied as-is, without warranty or commercial support.
