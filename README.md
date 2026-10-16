# librtlsdr (trackIT Systems fork): RTL2832U SDR driver and tools with Debian packages for Raspberry Pi OS

[![Latest release](https://img.shields.io/github/v/release/trackIT-Systems/librtlsdr?label=release)](https://github.com/trackIT-Systems/librtlsdr/releases)
[![Debian packages](https://github.com/trackIT-Systems/librtlsdr/actions/workflows/deb.yml/badge.svg)](https://github.com/trackIT-Systems/librtlsdr/actions/workflows/deb.yml)
[![GPLv2 License](https://img.shields.io/badge/license-GPLv2-brightgreen.svg)](https://tldrlegal.com/license/gnu-general-public-license-v2)

rtl-sdr turns your Realtek RTL2832 based DVB dongle into a SDR receiver. This repository contains the driver library
`librtlsdr` and command line tools (`rtl_test`, `rtl_sdr`, `rtl_fm`, `rtl_tcp`, `rtl_power`, ...).

This is the librtlsdr used by [tsOS-vhf](https://github.com/trackIT-Systems/tsOS-vhf). It adds individual gain stage
control for R820T/R828D tuners, an extended tuner bandwidth handling and more compared to the original osmocom/steve-m
sources, see [README_improvements.md](README_improvements.md) for the list of improvements,
[README.rtlfm_cmdfile](README.rtlfm_cmdfile) for scanning with `rtl_fm` and [README.rtlsdr_rpc](README.rtlsdr_rpc)
for using a dongle from a remote host.

# trackIT Systems fork

This fork continues the community fork [librtlsdr/librtlsdr](https://github.com/librtlsdr/librtlsdr)
(v0.9.0, last commit 2024-03-22; that fork itself is a hard fork of
[steve-m/librtlsdr](https://github.com/steve-m/librtlsdr) and appears to be inactive), because
our software depends on its additions, e.g. `rtlsdr_set_tuner_gain_ext()` for the individual
R820T/R828D gain stages, the extended tuner bandwidth handling and the GPIO/dithering API used by pyrtlsdr.

**Policy:** we maintain this fork ourselves and selectively port changes, either from
steve-m/librtlsdr (e.g. stability fixes) or from the community fork. We do not merge wholesale.
Ported commits are cherry-picked with `-x` so the origin stays visible in the log.

**Versions:** semantic versioning that continues the community lineage (`v0.9.0` -> `v0.9.1` -> ...).
The Debian package version is derived from `git describe`, see below. (The tag `v2.1.0` and the
`v2.0.x` tags in this repository belong to other lineages and are not releases of this fork.)

## Changes compared to the community fork

| change | origin |
|---|---|
| fall back to userspace buffers if the Linux usbfs mmap() bug is present (zero-copy stays enabled) | steve-m `f68bb2f` |
| fix application hang on USB transfer errors: `rtlsdr_read_async()` returns -1 if the device is lost, `rtl_fm` terminates | steve-m `65f0658` |
| add the missing 48.3 dB step to the tuner gain list (steve-m/librtlsdr#110) | own |
| Debian packaging fixes, `scripts/build-deb.sh` and GitHub Actions build for Raspberry Pi OS | own |

## Reviewed steve-m/librtlsdr commits that are not ported

Reviewed up to steve-m `v2.0.3` (2026-08-12).

| commit | reason |
|---|---|
| `81833a1` zero-copy disabled by default | we run with zero-copy (tsOS-vhf lifts the usbfs memory limit for it) |
| `2659e2d`, `5e73f90`, `142325a` | Windows-only sleep, libusb < 1.0.9 workaround, SIGPIPE in the command line tools; not needed |
| `d81ef9a`, `e04c42c` | FC0012 tuner only |
| `d794155`, `f5978e8`, `2acb75c`, `0b64f07` | tuner_r82xx.c was rewritten in the community fork (own PLL and shadow register handling); these do not apply |
| `138cd05`, `0204c9c` RTL-SDR Blog V4 upconverter switch / V4L | only relevant for Blog V4 dongles; port when needed |
| CMake, Windows, macOS, OpenBSD, Debian metadata, rtl_tcp IPv6 | not relevant for this fork |

## Reviewing upstream changes

```
git remote add upstream https://github.com/steve-m/librtlsdr.git
git fetch upstream
git cherry community-fork upstream/master   # '+' = commit not (yet) in the community fork
git cherry-pick -x <commit>
```

The branch `community-fork` is the unmodified state of the community fork this fork started from.
The branch `upstream-based` holds an earlier experiment with this fork based on steve-m 2.0.3 (not maintained).

# Install on Raspberry Pi OS / Debian (arm64)

Packages are built for Debian 13 (trixie), which Raspberry Pi OS is based on. Download the `.deb` files
from the [latest release](https://github.com/trackIT-Systems/librtlsdr/releases/latest) and install them:

```
sudo apt install ./librtlsdr0_*.deb ./rtl-sdr_*.deb              # library and tools
sudo apt install ./librtlsdr-dev_*.deb                           # additionally, for development
```

- `librtlsdr0` contains the library and the udev rules (`/usr/lib/udev/rules.d/60-librtlsdr0.rules`),
  `rtl-sdr` the command line tools, `librtlsdr-dev` headers, static library and pkg-config file.
- `rtl-sdr` and `librtlsdr-dev` replace the packages of the same name from Debian (2.0.x). The library has the
  soname `librtlsdr.so.0` and therefore does not clash with Debian's `librtlsdr2`. Debian's version numbers
  are higher, so hold our packages if the system has access to the Debian repositories:
  `sudo apt-mark hold librtlsdr0 rtl-sdr librtlsdr-dev`.
- If the kernel DVB driver claims the dongle (`rtl_test` reports `usb_claim_interface error -6`), blacklist it,
  see [Setup for SDR only use](#setup-for-sdr-only-use---without-dvb-compatibility) below.

Check the installation with a dongle plugged in:

```
rtl_test -t
```

# Build from source

## prerequisites
development tools have to be installed:
```
sudo apt-get install build-essential cmake git
```

install the libusb-1.0 development package:
```
sudo apt-get install libusb-1.0-0-dev
```

## retrieve the sources

```
git clone https://github.com/trackIT-Systems/librtlsdr.git
cd librtlsdr
```

The *master* branch is the maintained one. Releases are tags `vX.Y.Z`.

## build
run cmake and start compilation. cmake will accept some options, e.g.
* `-DINSTALL_UDEV_RULES=ON`, default is `OFF`
* `-DDETACH_KERNEL_DRIVER=ON`, default is `OFF`
* `-DPROVIDE_UDP_SERVER=ON`, default is `OFF`
* `-DWITH_RPC=ON`, default is `OFF`
* `-DLINK_RTLTOOLS_AGAINST_STATIC_LIB=ON`, default is `OFF`
* `-DRTL_STATIC_BUILD=OFF`, default is `ON`: for MINGW on WIN32

all cmake options are optional

```
mkdir build && cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
```

## install
setup into prefix, usually will require `sudo`:
```
sudo make install
sudo ldconfig
```

## quick local build for testing (no install, no package)

```
cmake -S . -B build && cmake --build build
build/src/rtl_test -t
```

(needs libusb: `brew install libusb` or `apt install libusb-1.0-0-dev`)

# Build the Debian packages

The packages are built with the packaging in `debian/` inside a `debian:trixie` container, so Docker is the
only requirement, on macOS, Linux and in CI:

```
scripts/build-deb.sh          # packages end up in ./dist
```

`DEB_IMAGE` (default `debian:trixie`), `DEB_PLATFORM` (e.g. `linux/arm64`) and `OUT` can be set to change the
target. The package version is derived from `git describe`: tag `v0.9.1` -> `0.9.1`, later commits ->
`0.9.1+gitN.<hash>`, uncommitted changes add `+dirty`.

# Continuous integration and releases

[GitHub Actions](https://github.com/trackIT-Systems/librtlsdr/actions) (`.github/workflows/deb.yml`) runs
`scripts/build-deb.sh` on an arm64 runner for every push and pull request and uploads the packages as an artifact.
Pushing a tag `vX.Y.Z` additionally creates a GitHub release with the `.deb` files attached.

Only the Debian packages are built and tested. The scripts for cross-building for Windows
([cross_build_mingw32.sh](cross_build_mingw32.sh), [cross_build_mingw64.sh](cross_build_mingw64.sh)) and the
macOS/Windows build files are inherited from the community fork and are not tested by us.

# For more information see:

http://superkuh.com/rtlsdr.html

https://osmocom.org/projects/rtl-sdr/wiki/Rtl-sdr


# Setup for SDR only use - without DVB compatibility:

- a special USB vendor/product id got reserved at http://pid.codes/ : 0x1209/0x2832
- for such devices the linux kernel's DVB modules are not loaded automatically,
 thus can be used without blacklisting *dvb_usb_rtl28xxu* below /etc/modprobe.d/
- this allows to use a second RTL dongle for use with DVB in parallel
- the IDs can be programmed with '`rtl_eeprom -n`' or '`rtl_eeprom -g realtek_sdr`'
- for permanent blacklisting you might check/call following from the clone git directory
    ```./install-blacklist.sh```


# Contributing

Pull requests are welcome, please open them against `master`.

- Changes that originate from steve-m/librtlsdr or the community fork are ported with `git cherry-pick -x <commit>`
  (see [Reviewing upstream changes](#reviewing-upstream-changes)); add new reviewed-but-skipped commits to the table above.
- Check a change locally with `scripts/build-deb.sh`; CI runs the same script.
- A release is a tag `vX.Y.Z` on `master`; CI builds the packages and attaches them to the release.
