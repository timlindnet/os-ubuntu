# loadout (one-line OS setup, in bash)

Pick the tags (apps + setup) you want and install them in one go (starting with Debian-family distros like **Ubuntu**): `--dev`, `--gaming`, etc.

Implementation detail: tags map to folders under `_tags/` (e.g. `_tags/dev/`, `_tags/gaming/`).

## One-liner usage

```bash
wget -qO- https://loadout.timlind.net | bash -s -- --base --dev --gaming --optional
```

If you already have `curl`:

```bash
curl -fsSL https://loadout.timlind.net | bash -s -- --base --dev --gaming --optional
```

If you prefer to bypass `loadout.timlind.net`, you can use GitHub directly:

```bash
wget -qO- https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

```bash
curl -fsSL https://raw.githubusercontent.com/timlindnet/loadout/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

The bootstrap also installs a helper command so you can later run:

```bash
loadout --dev --gaming
```

## CLI quick reference (matches --help)

Modes:
- `loadout --help` (show help)
- `loadout --list-tags` (list tags and available add-ons)

Notes:
- Default tag: `--base` (when no tags are given)
- See what you can install: `loadout --list-tags`
- Install tags by name: `loadout --base --dev --gaming`
- Install all tags: `loadout --all-tags`
  - Include optional add-ons too: `loadout --all-tags -o`
- Include optional add-ons for selected tags: `loadout --dev -o`
- Install all add-ons for one tag: `loadout --dev-optional`
- Run a single add-on by name: `loadout --dev--cursor`
  - Names for add-ons are shown under `optional/` and `explicit/` in `loadout --list-tags`

## Tags and add-ons

Tags correspond to folders under `_tags/` (e.g. `_tags/base/`, `_tags/dev/`, `_tags/gaming/`) and are installed only when selected.

- **Purpose**: keep installs modular. You choose *what kind of machine* you're setting up by selecting tags.
- **`base`**: OS-level "foundation" changes meant to improve stability/security (packages, system settings, prerequisites). It should avoid app-specific installs.
- **Naming**: folders prefixed with `_` (e.g. `_lib/`, `_pre/`, `_req/`) are internal and **cannot** be targeted as tags.

Add-ons live under `_tags/<tag>/optional/` and `_tags/<tag>/explicit/`.

- **Optional** add-ons run with `-o/--optional` or `--<tag>-optional`.
- **Explicit** add-ons run only when named (`--<tag>--<script>`), and are never installed via `-o/--optional`.
- If both exist for the same name, `explicit/` is preferred over `optional/`.

Examples:

```bash
loadout --dev--cursor
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

