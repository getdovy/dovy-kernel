# Build environment: Debian 13 with backports and the kernel's build
# packages. Built once, reused by build.sh.
FROM debian:13
RUN printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: trixie-backports\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' \
        >/etc/apt/sources.list.d/backports.sources \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bc bindgen bison build-essential ca-certificates cpio debhelper dpkg-dev dwarves \
        flex kmod libdw-dev libelf-dev libssl-dev patch python3 rsync rust-src rustc \
        rustfmt xz-utils zstd \
 && rm -rf /var/lib/apt/lists/*
