#!/usr/bin/env bash
# Runs inside the build container (see build.sh): builds Debian's backports
# kernel with options.config and patches/<series>/ into output/<tag>/.
set -euo pipefail
trap 'printf "error: line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

NAME=dovy
ROOT=/work
OPTIONS="$ROOT/options.config"
CACHE="$ROOT/cache"
BUILD="$ROOT/build"
SRC="$BUILD/linux"
LOG="$BUILD/build.log"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

SERIES=${SERIES:-} REVISION=${REVISION:-1} CONFIGURE_ONLY=${CONFIGURE_ONLY:-no}
[[ $REVISION =~ ^[1-9][0-9]*$ ]] || die "revision must be a positive integer"
: "${MAINTAINER:?set MAINTAINER, e.g. 'Name <address>'}"

# version_in <package> <suite>: the version apt has for it there.
version_in() {
    apt-cache madison "$1" | awk -F'|' -v s=" $2/" 'index($3, s) && !n++ { gsub(/ /, "", $2); print $2 }'
}

resolve() {
    SUITE=trixie-backports
    if [ -z "$SERIES" ]; then
        SERIES="$(apt-cache pkgnames linux-source- | grep -E '^linux-source-[0-9]+\.[0-9]+$' \
            | while read -r p; do [ -z "$(version_in "$p" "$SUITE")" ] || echo "${p#linux-source-}"; done \
            | sort -V | tail -n 1)"
    fi
    [ -n "$SERIES" ] || die "no linux-source package in $SUITE"
    DEBIAN_VERSION="$(version_in "linux-source-$SERIES" "$SUITE")"
    [ -n "$DEBIAN_VERSION" ] || die "linux-source-$SERIES is not in $SUITE"
    UPSTREAM="${DEBIAN_VERSION%%-*}"
    KERNELRELEASE="$UPSTREAM-$NAME"
    VERSION="$DEBIAN_VERSION+$NAME$REVISION"
    TAG="v$UPSTREAM"
    [ "$REVISION" = 1 ] || TAG="$TAG-$REVISION"
    OUT="$ROOT/output/$TAG"
}

# fetch <package> <version>: the .deb in cache/, as apt downloaded and
# checked it against Debian's signed index.
fetch() {
    local file
    file="$(apt-get download --print-uris "$1=$2" | awk 'NR == 1 { print $2 }')"
    [ -n "$file" ] || die "apt cannot locate $1 $2"
    if [ ! -f "$CACHE/$file" ]; then
        log "downloading $file" >&2
        (cd "$CACHE" && apt-get download "$1=$2" >&2) || die "download of $1 failed"
    fi
    printf '%s' "$CACHE/$file"
}

prepare() {
    local source config p
    mkdir -p "$CACHE"
    source="$(fetch "linux-source-$SERIES" "$DEBIAN_VERSION")"
    config="$(fetch "linux-config-$SERIES" "$DEBIAN_VERSION")"

    log "extracting linux-source-$SERIES $DEBIAN_VERSION"
    rm -rf -- "$BUILD"
    mkdir -p "$SRC"
    dpkg-deb --fsys-tarfile "$source" | tar -xO --wildcards '*/linux-source-*.tar.xz' \
        | xz -T0 -dc | tar -x -C "$SRC" --strip-components=1
    [ -f "$SRC/Makefile" ] || die "no kernel source in $source"

    for p in "$ROOT/patches/$SERIES"/*.patch; do
        [ -e "$p" ] || break
        log "applying ${p#"$ROOT"/}"
        patch -d "$SRC" -p1 -N --no-backup-if-mismatch -i "$p" || die "${p##*/} does not apply"
    done
    [ -z "$(find "$SRC" -name '*.rej' -print -quit)" ] || die "a patch left a rejected hunk"

    log "configuring"
    dpkg-deb --fsys-tarfile "$config" | tar -xO --wildcards '*/config.amd64_none_amd64.xz' \
        | xz -dc >"$SRC/.config"
    [ -s "$SRC/.config" ] || die "no amd64 config in $config"
    cp "$SRC/.config" "$BUILD/debian.config"
    (cd "$SRC" && ./scripts/kconfig/merge_config.sh -m .config "$OPTIONS" >/dev/null && make olddefconfig >/dev/null)
    verify_config
}

# Every options.config line must hold in the final .config.
verify_config() {
    local line sym failed=0
    while IFS= read -r line; do
        if [[ $line =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
            sym=${BASH_REMATCH[1]}
            ! grep -q "^$sym=" "$SRC/.config" || { printf '  %s: want off, got %s\n' "$sym" "$(grep "^$sym=" "$SRC/.config")" >&2; failed=1; }
        elif [[ $line =~ ^(CONFIG_[A-Za-z0-9_]+)= ]]; then
            sym=${BASH_REMATCH[1]}
            grep -qxF "$line" "$SRC/.config" || { printf '  %s: want %s, got %s\n' "$sym" "$line" \
                "$(grep -E "^(# )?$sym[= ]" "$SRC/.config" || echo none)" >&2; failed=1; }
        elif [[ -n $line && $line != \#* ]]; then
            die "invalid line in options.config: $line"
        fi
    done <"$OPTIONS"
    [ "$failed" = 0 ] || die "options.config did not survive olddefconfig"
    diff "$BUILD/debian.config" "$SRC/.config" | grep -E '^[<>] (# )?CONFIG' >"$BUILD/config.diff" || true
    log ".config verified; changes from Debian's in build/config.diff"
}

compile() {
    log "building $KERNELRELEASE $VERSION with $(nproc) jobs"
    if ! (cd "$SRC" && DEB_BUILD_PROFILES=pkg.linux-upstream.nokerneldbg \
            DEBFULLNAME="${MAINTAINER% <*}" DEBEMAIL="$(sed 's/.*<\(.*\)>.*/\1/' <<<"$MAINTAINER")" \
            KBUILD_BUILD_USER="$NAME" KBUILD_BUILD_HOST="$NAME" \
            make -j"$(nproc)" bindeb-pkg LOCALVERSION="-$NAME" KDEB_PKGVERSION="$VERSION") >"$LOG" 2>&1; then
        grep -E 'error|Error [0-9]' "$LOG" | tail -n 20 >&2 || true
        die "build failed, see build/build.log"
    fi
}

collect() {
    local f pkg
    rm -rf -- "$OUT"
    mkdir -p "$OUT"
    for f in "$BUILD"/*.deb; do
        pkg="$(dpkg-deb -f "$f" Package)"
        case $pkg in
            linux-image-"$KERNELRELEASE") mv -- "$f" "$OUT/linux-image_amd64.deb" ;;
            linux-headers-"$KERNELRELEASE") mv -- "$f" "$OUT/linux-headers_amd64.deb" ;;
            *) rm -f -- "$f"; continue ;; # linux-libc-dev would replace Debian's
        esac
    done
    for f in "$OUT"/*.deb; do
        [ "$(dpkg-deb -f "$f" Version)" = "$VERSION" ] || die "${f##*/} has version $(dpkg-deb -f "$f" Version)"
        ! dpkg-deb -c "$f" | grep -q 'signing_key\.pem' || die "${f##*/} contains the module signing key"
    done
    [ -f "$OUT/linux-image_amd64.deb" ] && [ -f "$OUT/linux-headers_amd64.deb" ] || die "image or headers missing"
    cat >"$OUT/build-info.txt" <<EOF
kernel=$KERNELRELEASE
version=$VERSION
source=linux-source-$SERIES $DEBIAN_VERSION ($SUITE)
options_sha256=$(sha256sum "$OPTIONS" | cut -d' ' -f1)
patches_sha256=$(cd "$ROOT" && find "patches/$SERIES" -name '*.patch' -print0 2>/dev/null | sort -z | xargs -0r sha256sum | sha256sum | cut -d' ' -f1)
gcc=$(gcc --version | head -n 1)
rustc=$(rustc --version)
pahole=$(pahole --version)
EOF
    (cd "$OUT" && sha256sum -- *.deb >SHA256SUMS)
}

apt-get update -qq
resolve
log "linux-source-$SERIES $DEBIAN_VERSION -> $KERNELRELEASE $VERSION, tag $TAG"
prepare
[ "$CONFIGURE_ONLY" = no ] || exit 0
compile
collect
log "release files in output/$TAG:"
ls -1 "$OUT"
