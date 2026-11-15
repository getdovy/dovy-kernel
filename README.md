<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/getdovy/dovy-kernel/main/.github/logo/dovy-kernel-wordmark-dark.svg">
    <img alt="dovy-kernel" src="https://raw.githubusercontent.com/getdovy/dovy-kernel/main/.github/logo/dovy-kernel-wordmark.svg" height="64">
  </picture>
</p>

<p align="center">
  Debian's backports kernel for Debian 13, tweaked for performance.<br>
  Not part of Debian.
</p>

<p align="center">
  <a href="https://github.com/getdovy/dovy-kernel/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/getdovy/dovy-kernel"></a>
  <a href="LICENSE"><img alt="Licence" src="https://img.shields.io/github/license/getdovy/dovy-kernel"></a>
</p>

## Overview

dovy-kernel is Debian's kernel from `trixie-backports`, built from
Debian's source package with Debian's patches and amd64 config. A small
set of options and upstream patches change it for desktop and gaming
use. Everything else is Debian's.

It installs next to Debian's kernel, which stays available in the boot
menu.

## Changes

| | Debian | dovy-kernel |
|---|---|---|
| Timer | 250 Hz | 1000 Hz |
| Preemption | lazy | full (`preempt=lazy` on the command line switches back) |
| Module compression | xz | zstd |
| `teo` idle governor | not built | built, not default |
| Console takeover | immediate | deferred |
| IRQ time accounting | off | on |
| Module signing | Debian's key | a key made for each build, then discarded |

Each option and its reason: [options.config](options.config).

Patches, taken from upstream unchanged, in `patches/<series>/`:

| Series | Patches | For |
|---|---|---|
| 7.2 | resolve_btfids kfunc tagging, from 7.3 | sched_ext schedulers |

## Requirements

- Debian 13 (trixie), amd64.
- Secure Boot off: the kernel is not signed for it.

## Install

With dovy:

```sh
dovy install kernel-dovy
```

Or from a [release](https://github.com/getdovy/dovy-kernel/releases/latest):

```sh
sha256sum -c SHA256SUMS
sudo apt install ./linux-image_amd64.deb ./linux-headers_amd64.deb
```

Reboot and choose the new kernel; `uname -r` then ends in `-dovy`.
A kernel installed by hand is not updated; one installed with dovy is
updated by `dovy upgrade`.

## Remove

Boot Debian's kernel first, then:

```sh
sudo apt purge '~n^linux-.*-dovy$'
```

## Versions

| | Example |
|---|---|
| Kernel release | `7.2.12-dovy` |
| Package version | `7.2.12-1~bpo13+1+dovy1`: Debian's, plus `+dovy<revision>` |
| Release tag | `v7.2.12`; `v7.2.12-2` for a rebuild of the same kernel |

Each release lists its build record: source package, options and patch
hashes, compiler versions.

## Build

Needs Docker. The build runs in a Debian 13 container (`Dockerfile`);
the source tree stays in this folder.

```sh
MAINTAINER='Name <address>' ./build.sh              # newest series in backports
MAINTAINER='Name <address>' ./build.sh -s 7.2 -r 2  # series 7.2, revision 2
MAINTAINER='Name <address>' ./build.sh --configure  # stop after .config
```

| Path | Contents |
|---|---|
| `cache/` | Debian's source and config packages |
| `build/` | source tree, `build.log`, `config.diff` |
| `output/<tag>/` | `linux-image_amd64.deb`, `linux-headers_amd64.deb`, `SHA256SUMS`, `build-info.txt` |

## Reporting problems

Open an [issue](https://github.com/getdovy/dovy-kernel/issues) with the
output of `uname -r`, your hardware, and what Debian's kernel does
differently. Problems that also happen on Debian's kernel belong to
[Debian](https://www.debian.org/Bugs/).

## Licence

GPL-2.0-only, the same as Linux: [LICENSE](LICENSE). Name and logo:
[TRADEMARKS.md](TRADEMARKS.md).
