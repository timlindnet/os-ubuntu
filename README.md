# os-ubuntu (bash-based Ubuntu setup)

Folder-driven installer for fresh Ubuntu installs, with optional tags (e.g. `--dev`, `--gaming`). Includes an optional **snapshot** system that stores machine state as **commits** in a nested git repo under `state/` (ignored by the main repo).

## One-liner usage

```bash
curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/main/install.sh | bash -s -- --base --dev --gaming
```

```bash
wget -qO- https://raw.githubusercontent.com/<you>/<repo>/main/install.sh | bash -s -- --base --dev --gaming
```

Only one of `curl` or `wget` is required; the bootstrap step installs just one if needed.

## Local usage

```bash
./install.sh --list-tags
./install.sh --base --dev --gaming
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
  - `req/` (bootstrap tools like `git`, `curl`, `wget`)
  - `pre/` (e.g. `apt update`, optional upgrade)
- Runs tag folders only when selected:
  - `base/`, `dev/`, `gaming/`, etc.

Scripts within a folder run in lexicographic order (use prefixes like `10-...sh`).

