# dovy-kernel

Debian's backports kernel for Debian 13, rebuilt with a few changes for
desktops. Installed by dovy's `kernel-dovy` recipe. Not part of Debian.

## Changes

Debian's source, patches and amd64 config, except:

| | Debian | dovy-kernel |
|---|---|---|
| Timer | 250 Hz | 1000 Hz |
| Preemption | lazy | full (`preempt=lazy` switches back) |
| Module compression | xz | zstd |
| `teo` idle governor | not built | built, not default |
| Console takeover | immediate | deferred |
| IRQ time accounting | off | on |
| Module signing | Debian's key | a key made for each build, not kept |

Options and their reasons: [options.config](options.config).

Upstream patches, unchanged, in `patches/<series>/`:

| Series | Patches | For |
|---|---|---|
| 7.2 | resolve_btfids kfunc tagging, from 7.3 | sched_ext schedulers |

## Limits

- Not signed for Secure Boot.
- amd64 only.

## Build

Needs Docker. Builds run in a Debian 13 container (`Dockerfile`, built
once); the source tree stays in this folder.

```sh
MAINTAINER='Name <address>' ./build.sh            # newest series in backports
MAINTAINER='Name <address>' ./build.sh -s 7.2 -r 2
MAINTAINER='Name <address>' ./build.sh --configure  # stop after .config
```

| Path | Contents |
|---|---|
| `cache/` | Debian's source and config packages |
| `build/` | source tree, `build.log`, `config.diff` |
| `output/<tag>/` | `linux-image_amd64.deb`, `linux-headers_amd64.deb`, `SHA256SUMS`, `build-info.txt` |

Kernel release `7.2.12-dovy`. Package version: Debian's plus
`+dovy<revision>`, e.g. `7.2.12-1~bpo13+1+dovy1`. Release tag `v7.2.12`
(`v7.2.12-2` for a rebuild of the same kernel).

## Licence

GPL-2.0-only, matching Linux. Name and logo: [TRADEMARKS.md](TRADEMARKS.md).
