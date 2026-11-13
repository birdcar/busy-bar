# AGENTS.md

Instructions for coding agents working in this repository: a monorepo of projects for one
[BUSY Bar](https://busy.app), holding both JavaScript apps that run on the bar and Python widgets that
drive it from a computer.

## Where the BUSY Bar docs are

**Start at <https://go.busy.app/agents>.** It is the official entry point for agents. Read it at the start of
any task here: it describes the device, lists known pitfalls in the tools and docs, and routes to the right
guide for the job. Fetch it with `curl -sL`; it redirects to a Markdown file on GitHub.

| For | Read |
|---|---|
| Anything, first | <https://go.busy.app/agents> |
| JS apps on a real bar | <https://raw.githubusercontent.com/busy-app/busybar-firmware/dev/applications_js/AGENTS.md> |
| JS apps on BUSY Bar Emulator | <https://raw.githubusercontent.com/busy-app/busybar-emulator/main/public-docs/agents.md> |
| Publishing to the app catalog | <https://raw.githubusercontent.com/busy-app/busy-apps-catalog/main/CONTRIBUTING.md> |
| Python widgets (`busylib`) | <https://raw.githubusercontent.com/busy-app/busylib-py/main/AGENTS.md> |
| HTTP API for a firmware version | `https://api.busy.app/busybar/openapi.yaml?Name=<version>` |
| Docs index | <https://docs.busy.app/llms.txt> (any docs.busy.app page reads as Markdown with `.md` added) |

Those documents are the source of truth for how BUSY Bar works. This file only covers what this repository
does differently. Where the two disagree about repository layout or tooling, this file wins; where they
disagree about the device, API or catalog rules, they win.

Inside an app folder, also read that app's own `AGENTS.md`. The generator writes it and it documents the
runtime, entry point and lifecycle rules.

## Layout

```
apps/<slug>/       one JS app per folder, each a complete standalone npm project
widgets/<slug>/    one Python widget per folder, each a complete standalone uv project
scripts/           scaffolding and lock file tools
LICENSE            MIT, covers every project in the repository
```

There is no root `package.json` or `pyproject.toml`, on purpose. See the next section.

## What this repository does differently, and why

The official guides assume one app per repository. These are the adjustments that make a monorepo work.

### 1. Every project is standalone: no workspaces

Do not add npm, pnpm, Bun or uv workspaces, and do not add a root `package.json` or `pyproject.toml`.

- `busy-cli` only looks at the folder it runs in, or that folder's `src/`.
- The catalog builds an app from its `subdir` alone and requires exactly one lock file inside that folder. A
  workspace lock file at the root is ignored.

Run every command from inside the project folder: `cd apps/<slug>` or `cd widgets/<slug>` first.

### 2. Apps use npm, never Bun

The catalog refuses Bun and Yarn lock files. Apps use npm and commit `package-lock.json`. Do not run
`bun install` or `bun add` in an app folder, and do not commit a `bun.lock` anywhere under `apps/`.

Node 24 is required (`.nvmrc`); Node 26 is not supported by the tools.

### 3. Lock files must point at the public npm registry

On a machine whose npm goes through a registry proxy, `npm install` writes the proxy's host into every
`resolved` URL in `package-lock.json`. The catalog build and other contributors cannot reach that host.

After any command that changes an app's dependencies, run:

```sh
node scripts/normalize-lock.mjs
```

It rewrites those URLs to `https://registry.npmjs.org/`. Only the host changes; integrity hashes are
untouched. Local installs still go through the proxy afterwards, because npm swaps the public host for the
configured registry at install time (`replace-registry-host`, on by default). CI runs the same script with
`--check` and fails if a lock file was committed without normalizing.

### 4. Create projects with the scripts, not the generators directly

```sh
scripts/new-app.sh <slug> "<Display Name>" "<one-line description>" [api-version]
scripts/new-widget.sh <slug>
```

`new-app.sh` runs `npm create @busy-app/app` and then applies the adjustments:

- passes `--no-git`, since the app lives in this repository;
- sets the id to `io.github.birdcar.<slug>` and rejects ids over 32 characters, which leaves 14 for the slug;
- deletes the generated `.github/` folder, because GitHub only runs workflows from the repository root;
- creates `screenshots/` inside the app folder, where the catalog needs them;
- normalizes the lock file (adjustment 3).

`api-version` defaults to `27.12.0`. It must not be newer than the HTTP API of the latest release firmware;
a connected bar reports its own as `api_semver` at `http://10.0.4.20/api/version`.

`new-widget.sh` runs `uv init`, adds `busylib`, and adds `pytest` and `ty` as dev dependencies.

### 5. Shared code is copied, not linked

An app cannot import from a sibling folder: the catalog build has no network access and sees only the app
folder. Each app has its own `shared/` from the template. If two apps need the same helper, copy it into
both. The same applies to widgets.

### 6. One CI workflow for everything

`.github/workflows/ci.yml` checks the lock files, then type-checks and builds every folder in `apps/`, and
runs `ty` and `pytest` on every folder in `widgets/`. Add nothing per project. The template's per-app release
workflow is not used here: releases go through the catalog.

### 7. Publishing from a subfolder

A catalog submission is a pull request to
[busy-apps-catalog](https://github.com/busy-app/busy-apps-catalog) adding
`applications/<id>/manifest.yml`. For apps from this repository:

```yaml
sourcecode:
  type: git
  location:
    origin: https://github.com/birdcar/busy-bar.git
    commit_sha: <full 40-character SHA>
    subdir: apps/<slug>
```

- Screenshot paths in the manifest are relative to the app folder, for example `screenshots/1.png`.
- The root `LICENSE` satisfies the license check for every app.
- An app id belongs to the repository it was first published from. Do not rename or move this repository,
  and do not move a published app to a different folder without updating `subdir` in its next version.
- Do not tick the catalog's authorship or device-testing boxes on the user's behalf.

## Working on an app

```sh
cd apps/<slug>
npm run typecheck
npm run build            # dist/<id>.tgz
npm run app:install      # bar on USB at 10.0.4.20; over Wi-Fi add: -- --addr <host>
npm run app:run
```

Before finishing: `npm run typecheck` and `npm run build` succeed, and
`node scripts/normalize-lock.mjs --check` passes from the repository root. Install and run on a bar or the
emulator if one is available; if not, say so.

## Working on a widget

```sh
cd widgets/<slug>
uv run main.py
uv run ty check
uv run pytest
```

Add dependencies with `uv add`, never `pip install`. Type-hint everything. When a widget stops, it clears
what it drew: `DELETE /api/display/draw?application_name=<name>`.
