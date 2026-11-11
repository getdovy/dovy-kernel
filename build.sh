#!/usr/bin/env bash
# Builds the kernel in a Debian 13 container (Dockerfile); the work tree is
# this folder, so it compiles at native speed. See README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ./build.sh [-s SERIES] [-r REVISION] [--configure]

  -s SERIES     kernel series, e.g. 7.2 (default: newest in trixie-backports)
  -r REVISION   dovy revision of this kernel version (default 1)
  --configure   stop after the checked .config

MAINTAINER ('Name <address>') goes into the packages.
EOF
}

SERIES="" REVISION=1 CONFIGURE_ONLY=no
while [ $# -gt 0 ]; do
    case $1 in
        -s) [ $# -ge 2 ] || die "-s needs a value"; SERIES=$2; shift ;;
        -r) [ $# -ge 2 ] || die "-r needs a value"; REVISION=$2; shift ;;
        --configure) CONFIGURE_ONLY=yes ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
    shift
done
[ "$(id -u)" != 0 ] || die "run as a normal user"
: "${MAINTAINER:?set MAINTAINER, e.g. MAINTAINER='Name <address>' ./build.sh}"
command -v docker >/dev/null || die "Docker is needed"

# The image is named after the Dockerfile's hash: a change rebuilds it.
IMAGE="dovy-kernel-build:$(sha256sum "$ROOT/Dockerfile" | cut -c1-12)"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker build -t "$IMAGE" "$ROOT"

mkdir -p "$ROOT/cache" "$ROOT/build" "$ROOT/output"
exec 9>"$ROOT/cache/.lock"
flock -n 9 || die "another build is running in $ROOT"

status=0
docker run --rm -v "$ROOT:/work" -w /work \
    -e SERIES="$SERIES" -e REVISION="$REVISION" -e CONFIGURE_ONLY="$CONFIGURE_ONLY" -e MAINTAINER="$MAINTAINER" \
    "$IMAGE" ./kernel.sh || status=$?
# The container ran as root: hand the files back.
docker run --rm -v "$ROOT:/work" "$IMAGE" chown -R "$(id -u):$(id -g)" /work/cache /work/build /work/output
exit "$status"
