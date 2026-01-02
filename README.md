# loadout (one-line OS setup, in bash)

Pick the tags (apps + setup) you want and install them in one go (starting with Debian-family distros like **Ubuntu**): `--dev`, `--gaming`, etc.

Implementation detail: tags map to folders under `_tags/` (e.g. `_tags/dev/`, `_tags/gaming/`).

## One-liner usage

```bash
curl -fsSL https://loadout.timlind.net | bash -s -- --base --dev --gaming --optional
```

```bash
wget -qO- https://loadout.timlind.net | bash -s -- --base --dev --gaming --optional
```

If you prefer to bypass `loadout.timlind.net`, you can use GitHub directly:

```bash
curl -fsSL https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

```bash
wget -qO- https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

> Note: if you want to pass arguments to a script read from stdin, you need `bash -s -- ...`.

The bootstrap also installs a helper command so you can later run:

```bash
loadout --dev --gaming
```

## Tags

Tags correspond to folders under `_tags/` (e.g. `_tags/base/`, `_tags/dev/`, `_tags/gaming/`) and are installed only when selected.

- **Purpose**: keep installs modular. You choose *what kind of machine* you’re setting up by selecting tags.
- **`base`**: OS-level “foundation” changes meant to improve stability/security (packages, system settings, prerequisites). It should avoid app-specific installs.
- **Naming**: folders prefixed with `_` (e.g. `_lib/`, `_pre/`, `_req/`) are internal and **cannot** be targeted as tags.

- Install every tag folder:

```bash
loadout --all-tags
```

- Install every tag folder + optional scripts:

```bash
loadout --all-tags -o
```

## Optional scripts

Optional scripts live under `_tags/<tag>/optional/`.

- Install optional scripts for the tags you selected:

```bash
loadout --base --gaming -o
```

- Install all optional scripts for a specific tag:

```bash
loadout --base-optional
loadout --gaming-optional
```

- Install only one optional script for a tag (maps to `_tags/<tag>/optional/<script>.sh`):

```bash
loadout --dev--cursor
```

## Explicit scripts

Explicit scripts live under `_tags/<tag>/explicit/` and are installed only when you name them (they are never installed via `-o/--optional`).

```bash
loadout --games--rs3
loadout --dev--aws-cli
```

## Folder execution model

- Always runs:
  - `_req/` (bootstrap tools like a downloader + certs)
  - `_pre/` (e.g. `apt update`, `apt upgrade`)
- Runs tag folders only when selected:
  - `_tags/base/`, `_tags/dev/`, `_tags/gaming/`, etc.

Scripts within a folder run in lexicographic order (use prefixes like `10-...sh`).

### Script boilerplate

To keep scripts small, files under `_req/`, `_pre/`, and `_tags/` are treated as **snippets** and are executed via `lib/run-script.sh`, which applies `set -euo pipefail`, sources `lib/common.sh`, then sources `_lib/os.sh` for the active OS layers and runs `ensure_os` for each script.

## OS layering

The installer auto-detects your OS via `/etc/os-release` and builds a layer chain, e.g. on Ubuntu 24.04:

- `debian/`
- `debian/ubuntu/`
- `debian/ubuntu/24.04/` (optional)

For each folder being run (`_req/`, `_pre/`, `_tags/<tag>/...`), scripts are merged across layers by filename: the most specific layer wins.

