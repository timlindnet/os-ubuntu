# os-ubuntu (bash-based Ubuntu setup)

Folder-driven installer for fresh Ubuntu installs, with optional tags (e.g. `--dev`, `--gaming`). Includes an optional **snapshot** system that stores machine state as **commits** in a nested git repo under `state/` (ignored by the main repo).

## One-liner usage

```bash
curl -fsSL https://raw.githubusercontent.com/timlindnet/os-ubuntu/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

```bash
wget -qO- https://raw.githubusercontent.com/timlindnet/os-ubuntu/main/bootstrap.sh | bash -s -- --base --dev --gaming --optional
```

Only one of `curl` or `wget` is required; the bootstrap step installs just one if needed.

## Local usage

```bash
./install.sh --list-tags
./install.sh --base --dev --gaming
```

## Optional scripts

Optional scripts live under `<tag>/optional/`.

- Install optional scripts for the tags you selected:

```bash
./install.sh --base --gaming -o
```

- Install all optional scripts for a specific tag:

```bash
./install.sh --base-optional
./install.sh --gaming-optional
```

- Install only one optional script for a tag (maps to `<tag>/optional/<script>.sh`):

```bash
./install.sh --base--spotify
./install.sh --dev--cursor
```

- Explicit scripts live under `<tag>/explicit/` and are installed only when you name them:

```bash
./install.sh --games--rs3
```

- Install everything (all tags + all optional scripts):

```bash
./install.sh --all
```

## Snapshots (commits in `state/`)

- Create a snapshot commit (default name is UTC timestamp):

```bash
./install.sh --snapshot
```

- Create a snapshot with a friendly name (also creates a tag `snapshot/<name>`):

```bash
./install.sh --snapshot "after-clean-install"
```

- Add extra user tags (creates annotated git tags like `label/work-laptop`):

```bash
./install.sh --snapshot --snapshot-tag work-laptop --snapshot-tag pre-gaming
```

- List snapshot commits:

```bash
./install.sh --list-snapshots
```

- Apply a snapshot (additive install; uses the snapshot commit content):

```bash
./install.sh --apply-snapshot snapshot/after-clean-install
./install.sh --apply-snapshot <commit-sha>
```

> Note: apply is intentionally conservative (installs missing items). It does not remove extra packages by default.

## Folder execution model

- Always runs:
  - `req/` (bootstrap tools like a downloader + certs)
  - `pre/` (e.g. `apt update`, `apt upgrade`)
- Runs tag folders only when selected:
  - `base/`, `dev/`, `gaming/`, etc.

Scripts within a folder run in lexicographic order (use prefixes like `10-...sh`).

### Script boilerplate

To keep scripts small, files under `req/`, `pre/`, and tag folders are treated as **snippets** and are executed via `lib/run-script.sh`, which applies `set -euo pipefail`, sources `lib/common.sh`, and runs `ensure_ubuntu` for each script.

