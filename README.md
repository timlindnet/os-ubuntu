# loadout (bash-based multi-OS setup)

Folder-driven installer for fresh OS installs (starting with **Ubuntu**), with optional tags (e.g. `--dev`, `--gaming`). Includes an optional **snapshot** system that stores machine state as **commits** in a nested git repo under `state/<os>/` (ignored by the main repo).

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

## Local usage

```bash
./install.sh ubuntu --list-tags
./install.sh ubuntu --base --dev --gaming
```

Or run the OS installer directly:

```bash
./ubuntu/install.sh --list-tags
./ubuntu/install.sh --base --dev --gaming
```

## Optional scripts

Optional scripts live under `<os>/<tag>/optional/`.

- Install optional scripts for the tags you selected:

```bash
./install.sh ubuntu --base --gaming -o
```

- Install all optional scripts for a specific tag:

```bash
./install.sh ubuntu --base-optional
./install.sh ubuntu --gaming-optional
```

- Install only one optional script for a tag (maps to `<tag>/optional/<script>.sh`):

```bash
./install.sh ubuntu --base--spotify
./install.sh ubuntu --dev--cursor
```

## Explicit scripts

Explicit scripts live under `<os>/<tag>/explicit/` and are installed only when you name them (they are never installed via `-o/--optional`).

```bash
./install.sh ubuntu --games--rs3
```

- Install everything (all tags + all optional scripts):

```bash
./install.sh ubuntu --all
```

## Snapshots (commits in `state/<os>/`)

- Create a snapshot commit (default name is UTC timestamp):

```bash
./install.sh ubuntu --snapshot
```

- Create a snapshot with a friendly name (also creates a tag `snapshot/<name>`):

```bash
./install.sh ubuntu --snapshot "after-clean-install"
```

- Add extra user tags (creates annotated git tags like `label/work-laptop`):

```bash
./install.sh ubuntu --snapshot --snapshot-tag work-laptop --snapshot-tag pre-gaming
```

- List snapshot commits:

```bash
./install.sh ubuntu --list-snapshots
```

- Apply a snapshot (additive install; uses the snapshot commit content):

```bash
./install.sh ubuntu --apply-snapshot snapshot/after-clean-install
./install.sh ubuntu --apply-snapshot <commit-sha>
```

> Note: apply is intentionally conservative (installs missing items). It does not remove extra packages by default.

## Folder execution model

- Always runs:
  - `<os>/req/` (bootstrap tools like a downloader + certs)
  - `<os>/pre/` (e.g. `apt update`, `apt upgrade`)
- Runs tag folders only when selected:
  - `<os>/base/`, `<os>/dev/`, `<os>/gaming/`, etc.

Scripts within a folder run in lexicographic order (use prefixes like `10-...sh`).

### Script boilerplate

To keep scripts small, files under `<os>/req/`, `<os>/pre/`, and OS tag folders are treated as **snippets** and are executed via `lib/run-script.sh`, which applies `set -euo pipefail`, sources `lib/common.sh`, then sources `<os>/lib/os.sh` and runs `ensure_os` for each script.

