
## Debian packages (Raspberry Pi OS)

This fork tracks upstream and only adds a package build: `scripts/build-deb.sh`
builds `librtlsdr0`, `librtlsdr-dev` and `rtl-sdr` from the upstream `debian/`
packaging in a `debian:trixie` container (Docker is the only requirement) and
puts them in `./dist`. `DEB_IMAGE`, `DEB_PLATFORM` (e.g. `linux/arm64`) and `OUT`
change the target. The version is derived from `git describe`: `v2.0.3` -> `2.0.3`,
later commits -> `2.0.3+gitN.<hash>`, uncommitted changes add `+dirty`.

`.github/workflows/deb.yml` runs the same script on an arm64 runner for every push
and pull request; pushing a `v*` tag attaches the packages to the release.

For a quick local build without packaging: `cmake -S . -B build && cmake --build build`.
