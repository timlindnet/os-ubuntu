# Agent guide (AGENTS.md)

This repo is **loadout**: simple, tag-based **bash automation** for one-line machine setup (starting with **Ubuntu 24+** and Debian-family layering).

If you are an automated coding agent, follow this guide to make changes that match the repo’s conventions and stay low-maintenance.

## What this repo is (and isn’t)

- **Goal**: minimal, stable OS setup via tags (e.g. `--base`, `--dev`, `--gaming`), with optional/explicit scripts.
- **Not a framework**: avoid adding complexity (custom apt repos, PPAs, bespoke key management) unless there’s a clear, Ubuntu-supported reason.

## Key entrypoints

- `install.sh`: main entrypoint when running from a checked-out repo.
- `bootstrap.sh`: “curl | bash” entrypoint that downloads the repo tarball and runs `install.sh`.

## Execution model (important)

The installer detects the OS via `/etc/os-release` and builds a **layer chain** (from base → most specific). Example on Ubuntu 24.04:

- `debian/`
- `debian/ubuntu/`
- `debian/ubuntu/24.04/` (optional)

When running a folder (e.g. `_pre/` or `_tags/dev/`), scripts are **merged across layers by filename**:

- More specific layers **override** earlier layers by basename.
- Execution order is **lexicographic by basename** (use numeric prefixes like `10-...sh`).

## Folder layout + selectors

- **Always-run folders**: `_req/`, `_pre/`
- **Tags**: `_tags/<tag>/` (only runs when tag is selected)
- **Optional scripts**: `_tags/<tag>/optional/`
  - `-o/--optional`: run optional scripts for selected tags
  - `--<tag>-optional`: run all optional scripts for that tag
- **Explicit scripts**: `_tags/<tag>/explicit/`
  - Only runs via `--<tag>--<script>` (never via `-o/--optional`)
  - If both exist, selection prefers `explicit/` over `optional/`

Examples:

```bash
# Help / discovery
bash install.sh --help
bash install.sh --list-tags

# Install tags
bash install.sh --base --dev

# Run optional scripts for selected tags
bash install.sh --base --dev -o

# Run a single optional/explicit script selector
bash install.sh --dev--cursor
```

## Script conventions (snippets vs standalone)

Scripts in these locations are **snippets** (sourced in-process), not standalone executables:

- `_req/`
- `_pre/`
- `_tags/<tag>/`
- `_tags/<tag>/optional/`
- `_tags/<tag>/explicit/`

Because they run via `lib/run-script.sh`, snippet scripts **MUST NOT** include:

- a shebang (e.g. `#!/usr/bin/env bash`)
- `set -euo pipefail`
- `source lib/common.sh`
- calls to `ensure_os` (the runner calls it for you)

Standalone scripts like `install.sh`/`bootstrap.sh` **do** include their own strict mode and helpers.

## Bash style + safety expectations

- **KISS**:
  - Prefer `apt-get install -y <pkg>` / `snap install <pkg>` over custom repo/key/ppa setup.
  - Avoid PPAs and manual keyrings unless there’s a strong, stable reason.
- **Idempotent-ish**: scripts should be safe to re-run (don’t fail if something is already installed).
- **Noninteractive**: avoid prompts (use noninteractive apt patterns when needed).
- **Minimal dependencies**: don’t install extra tools “just in case”.

## Prefer shared helpers

Use helpers from `lib/common.sh` inside snippet scripts:

- `sudo_run ...` (runs with sudo if needed)
- `log ...`, `warn ...`, `die ...`
- `fetch_url ...` (curl/wget agnostic)

## How to validate changes (agent-friendly)

This repo’s scripts can perform real system changes, so prefer lightweight validation:

- **Static checks**:
  - `bash -n <changed-file>` for syntax
  - If available: `shellcheck <changed-file>`
- **CLI sanity** (safe):
  - `bash install.sh --help`
  - `bash install.sh --list-tags`

Only run actual installs in an environment where it’s safe to modify the OS.

