#!/usr/bin/env bash
# Build the Debian packages (librtlsdr0, librtlsdr-dev, rtl-sdr) from the
# working tree and collect them in ./dist.
#
# The build runs in a Debian container so the result matches Raspberry Pi OS
# and works the same on a Mac, a Linux box and in GitHub Actions.
#
#   scripts/build-deb.sh
#
# Environment:
#   DEB_IMAGE     container image to build in      (default: debian:trixie)
#   DEB_PLATFORM  docker --platform, e.g. linux/arm64 (default: host platform)
#   OUT           output directory                  (default: ./dist)
#
# The package version is derived from `git describe`: tag v0.9.0 -> 0.9.0,
# 12 commits after it -> 0.9.0+git12.<hash>, uncommitted changes add +dirty.
# debian/changelog is not modified, the entry is generated inside the build copy.
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT=${OUT:-$SRC/dist}
IMAGE=${DEB_IMAGE:-debian:trixie}

version() {
    local desc ver n hash
    desc=$(git -C "$SRC" describe --tags --match 'v[0-9]*' --long --always --abbrev=7)
    if [[ $desc =~ ^v(.+)-([0-9]+)-g([0-9a-f]+)$ ]]; then
        ver=${BASH_REMATCH[1]//-/+}
        n=${BASH_REMATCH[2]}
        hash=${BASH_REMATCH[3]}
        [ "$n" -gt 0 ] && ver+="+git$n.$hash"
    else
        ver="0.0.0+git.$desc"
    fi
    git -C "$SRC" diff --quiet HEAD -- || ver+="+dirty"
    echo "$ver"
}

# Runs inside the container.
if [ "${1:-}" = "--inside" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
        build-essential cmake debhelper fakeroot libusb-1.0-0-dev pkgconf >/dev/null

    mkdir -p /build/rtl-sdr
    tar -C /src --exclude=.git --exclude=dist --exclude=build -cf - . | tar -C /build/rtl-sdr -xf -
    cd /build/rtl-sdr

    {
        echo "rtl-sdr ($DEB_VERSION) unstable; urgency=medium"
        echo
        echo "  * Build of the trackIT-Systems/librtlsdr fork ($DEB_VERSION)."
        echo
        echo " -- Jonas Höchst <hoechst@trackit.systems>  $(date -R)"
        echo
        cat debian/changelog
    } > debian/changelog.new
    mv debian/changelog.new debian/changelog

    dpkg-buildpackage -b -us -uc
    cp -v $(ls /build/*.deb | grep -v -- "-dbgsym_") /out/   # debug symbol packages are not published
    exit 0
fi

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
VERSION=$(version)
mkdir -p "$OUT"
rm -f "$OUT"/*.deb
echo "Building rtl-sdr $VERSION in $IMAGE"

docker run --rm ${DEB_PLATFORM:+--platform "$DEB_PLATFORM"} \
    -e DEB_VERSION="$VERSION" \
    -v "$SRC":/src:ro -v "$OUT":/out \
    "$IMAGE" bash /src/scripts/build-deb.sh --inside
