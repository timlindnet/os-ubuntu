# loadout (bash-based multi-OS setup)

Folder-driven installer for fresh OS installs (starting with **Ubuntu**), with optional tags (e.g. `--dev`, `--gaming`).

## One-liner usage

```bash
curl -fsSL https://loadout.timlind.net | bash -s -- ubuntu --base --dev --gaming --optional
```

```bash
wget -qO- https://loadout.timlind.net | bash -s -- ubuntu --base --dev --gaming --optional
```

If you prefer to bypass `loadout.timlind.net`, you can use GitHub directly:

```bash
curl -fsSL https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- ubuntu --base --dev --gaming --optional
```

```bash
wget -qO- https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- ubuntu --base --dev --gaming --optional
```

> Note: if you want to pass arguments to a script read from stdin, you need `bash -s -- ...`.

The bootstrap also installs a helper command so you can later run:

```bash
loadout --dev --gaming
```

## Tags

Tags correspond to folders under `<os>/` (e.g. `ubuntu/base/`, `ubuntu/dev/`, `ubuntu/gaming/`) and are installed only when selected.

- **Purpose**: keep installs modular. You choose *what kind of machine* you’re setting up by selecting tags.
- **`base`**: OS-level “foundation” changes meant to improve stability/security (packages, system settings, prerequisites). It should avoid app-specific installs.
- **Naming**: folders prefixed with `_` (e.g. `ubuntu/_lib/`, `ubuntu/_pre/`, `ubuntu/_req/`) are internal and **cannot** be targeted as tags.

- Install every tag folder:

```bash
loadout --all-tags
```

- Install every tag folder + optional scripts:

```bash
loadout --all-tags -o
```

## Optional scripts

Optional scripts live under `<os>/<tag>/optional/`.

- Install optional scripts for the tags you selected:

```bash
loadout --base --gaming -o
```

- Install all optional scripts for a specific tag:

```bash
loadout --base-optional
loadout --gaming-optional
```

- Install only one optional script for a tag (maps to `<tag>/optional/<script>.sh`):

```bash
loadout --dev--cursor
```

## Explicit scripts

Explicit scripts live under `<os>/<tag>/explicit/` and are installed only when you name them (they are never installed via `-o/--optional`).

```bash
loadout --games--rs3
```

## Folder execution model

- Always runs:
  - `<os>/_req/` (bootstrap tools like a downloader + certs)
  - `<os>/_pre/` (e.g. `apt update`, `apt upgrade`)
- Runs tag folders only when selected:
  - `<os>/base/`, `<os>/dev/`, `<os>/gaming/`, etc.

Scripts within a folder run in lexicographic order (use prefixes like `10-...sh`).

### Script boilerplate

To keep scripts small, files under `<os>/_req/`, `<os>/_pre/`, and OS tag folders are treated as **snippets** and are executed via `lib/run-script.sh`, which applies `set -euo pipefail`, sources `lib/common.sh`, then sources `<os>/_lib/os.sh` and runs `ensure_os` for each script.

