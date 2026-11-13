# busy-bar

Apps and widgets for my [BUSY Bar](https://busy.app), a desk display with a 72×16 RGB LED front screen, a
160×80 OLED back screen and a built-in focus timer.

This repository holds two kinds of project:

- **Apps** are small JavaScript programs that run on the bar itself and can be published to the
  [BUSY Bar app catalog](https://github.com/busy-app/busy-apps-catalog).
- **Widgets** are Python programs that run on a computer and draw on the bar through its HTTP API. They only
  work while that computer is on.

## Layout

```
apps/<slug>/       one JS app per folder (npm, TypeScript)
widgets/<slug>/    one Python widget per folder (uv)
scripts/           scaffolding and lock file tools
```

Every project is standalone, with its own dependencies and lock file. There are no workspaces and no root
`package.json`: the BUSY Bar build tools and the catalog both work on one self-contained folder at a time.

## Requirements

- [Node 24](https://nodejs.org) and npm, for apps. Node 26 is not supported by the BUSY Bar tools.
- [uv](https://docs.astral.sh/uv/), for widgets.
- A BUSY Bar on USB (it answers at `10.0.4.20`) or Wi-Fi, or
  [BUSY Bar Emulator](https://go.busy.app/busy-emulator-docs).

## Apps

Create one:

```sh
scripts/new-app.sh pomodoro "Pomodoro" "A tomato-shaped focus timer"
```

This scaffolds `apps/pomodoro` with the id `io.github.birdcar.pomodoro`. The slug can be up to 14 characters,
because the bar limits ids to 32.

Develop it:

```sh
cd apps/pomodoro
npm run typecheck
npm run build          # writes dist/<id>.tgz
npm run app:install    # uploads to the bar
npm run app:run
npm run app:stop
```

Over Wi-Fi, add the bar's address: `npm run app:install -- --addr 192.168.1.42`.

The app's source is in `src/`, with its manifest in `src/appmeta/manifest.json`. Each app folder also has its
own README from the official template, covering the build, packaging and manifest in detail.

### Changing dependencies

Use npm, not Bun or Yarn: the catalog only accepts `package-lock.json` or a pinned `pnpm-lock.yaml`. After
any install that changes a lock file, run this from the repository root:

```sh
node scripts/normalize-lock.mjs
```

It makes sure every package URL in the lock files points at the public npm registry instead of a local
registry proxy. CI fails if this was skipped.

### Publishing to the catalog

1. Test the app on a bar with the latest release firmware.
2. Add 72×16 PNG screenshots taken from the bar to `apps/<slug>/screenshots/`.
3. Raise `version` in `src/appmeta/manifest.json`, then commit and push.
4. Open a pull request to [busy-apps-catalog](https://github.com/busy-app/busy-apps-catalog) that adds
   `applications/<id>/manifest.yml`, pointing at this repository with the pushed commit's full SHA and
   `subdir: apps/<slug>`.

The catalog's [contribution guide](https://github.com/busy-app/busy-apps-catalog/blob/main/CONTRIBUTING.md)
has the manifest format and every check an app must pass.

## Widgets

Create one:

```sh
scripts/new-widget.sh weather
```

This scaffolds `widgets/weather` as a uv project with [`busylib`](https://pypi.org/project/busylib/), `pytest`
and `ty` installed.

Develop it:

```sh
cd widgets/weather
uv run main.py
uv run ty check
uv run pytest
uv add <package>       # add a dependency
```

## CI

One workflow, `.github/workflows/ci.yml`, runs on every push to `main` and every pull request. It checks the
app lock files, type-checks and builds every app, and type-checks and tests every widget.

## Documentation

- [BUSY Bar developer docs](https://docs.busy.app)
- [JS apps](https://go.busy.app/js-apps)
- [HTTP API](https://docs.busy.app/bar/dev/http-api)
- [Instructions for AI coding agents](https://go.busy.app/agents), with this repository's own conventions in
  [AGENTS.md](AGENTS.md)

## License

[MIT](LICENSE)
