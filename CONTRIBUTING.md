# Contributing guidelines (KISS)

This repo is intentionally **simple bash**. Prefer the simplest stable mechanism available on Ubuntu.

## Core rules

- **KISS**: if `apt-get install -y <pkg>` or `snap install <pkg>` is sufficient, do that. Avoid manual keyrings/repos/PPAs unless there is a strong, stable reason.
- **Idempotent-ish**: scripts should be safe to re-run (avoid failing when something is already installed).
- **Minimal dependencies**: don’t install extra tools “just in case”.
- **No interactive prompts**: use noninteractive apt where needed.

## Script style

- Files under `<os>/_req/`, `<os>/_pre/`, and OS tag folders are **snippets** (not standalone programs).
  - They run via `lib/run-script.sh` which applies strict mode and sources `lib/common.sh`.
  - Do **not** add shebangs or duplicate `set -euo pipefail`/`ensure_os` in these scripts.
- Use helpers from `lib/common.sh`:
  - `sudo_run ...`, `log ...`, `die ...`, `fetch_url ...` (curl/wget agnostic).

## Folder conventions

- Always run: `<os>/_req/`, `<os>/_pre/`
- Tags: `<os>/<tag>/`
- Optional scripts: `<os>/<tag>/optional/`
  - `-o/--optional` installs optional scripts for selected tags
  - `--<tag>-optional` installs all optional scripts for that tag
  - `--<tag>--<script>` installs only `<tag>/optional/<script>.sh`

