# mini_browser

A personalized, minimal web browser built on the Chromium engine — a learning project in
understanding how a real browser works by building and modifying one, **under deliberate
hardware constraints** (an 8 GB Apple Silicon MacBook Air).

## What this is (and isn't)

This repo follows the **overlay / patch** pattern used by real Chromium-derived projects
(ungoogled-chromium, Thorium, etc.). It does **not** vendor Chromium's source — that's tens
of millions of lines and tens of gigabytes. Instead, this repo contains **only what's ours**,
and a setup script pulls in a pinned Chromium checkout and wires our code into it.

What lives here:

| Path | What it is |
|---|---|
| `mini_browser/` | Our own browser/embedder source (Stage 2 — currently a placeholder). |
| `build/args.gn` | Our GN build configuration (minimal `content_shell`, tuned for 8 GB RAM). |
| `patches/` | Diffs we apply to upstream Chromium files (`.patch`, not copies). Empty for now. |
| `setup.sh` | Reproducible setup: fetch pinned Chromium → link our code → apply patches → configure. |
| `research.md` | Architecture research: what's the minimum for a working+secure browser, what to keep/cut. |
| `webengine-followup.md` | A separate future capstone idea (from-scratch web engine). Parked. |
| `docs/building.md` | Detailed build instructions and the gotchas we hit. |

## Pinned upstream

| | |
|---|---|
| Chromium version | **151.0.7897.0** |
| Git revision | `cd1d42cba19c64f3386d5dfa1475d620b6efb6a4` |

## Quickstart

```sh
git clone https://github.com/astuka/mini_browser.git
cd mini_browser
./setup.sh          # clones depot_tools, fetches pinned Chromium, links our code, runs gn gen
```

Then build (note the `-j 2` cap — see "Constraints" below):

```sh
cd chromium/src
caffeinate autoninja -C out/Shell content_shell -j 2
```

Run it:

```sh
"out/Shell/Content Shell.app/Contents/MacOS/Content Shell" \
  --use-mock-keychain --disable-features=DialMediaRouteProvider https://example.com
```

> **Already have a Chromium checkout?** Reuse it instead of re-fetching ~50 GB:
> `CHROMIUM_SRC=/path/to/chromium/src ./setup.sh`

## Status

- ✅ **Stage 1 — minimal browser builds & runs.** `content_shell` (Chromium's minimal
  Blink+V8 browser) compiles from our config and runs with the full multi-process,
  sandboxed, site-isolated architecture.
- 🛠️ **Customizations** (as `patches/`): vertical tab strip on the left, with background
  tabs (cmd+click) that flash the strip instead of stealing focus; SF Symbol icons on the
  Back/Forward/Reload/Stop buttons; a horizontal bookmark bar (persisted via the browser's
  PrefService); collapsible **tab folders** — drag one tab onto another to group them,
  click to collapse/expand; **multi-select** (⌘/Shift-click) with a right-click context
  menu (close, move to folder, add to bookmarks); **drag a tab onto the bookmark bar**
  to bookmark it; **renamable folders** (right-click or double-click a folder); and
  **session persistence** — your tabs and folders are restored automatically on
  the next launch (and after a crash). See `patches/README.md`.
- 🛡️ **Security epic (in progress):** building browser-security primitives directly on
  content_shell, from scratch (no `//chrome`). So far: a connection-security indicator
  (lock / "Not Secure") derived ourselves from the navigation's TLS state; a certificate
  viewer (subject / issuer / validity / SANs); a real certificate-error interstitial
  ("Your connection is not private" with Back-to-safety / Proceed); HTTPS-First mode
  (upgrades http→https, with a fallback interstitial when a site has no HTTPS); a
  local URL blocklist (our own miniature "Safe Browsing" with a dangerous-site interstitial);
  a from-scratch permission system (Allow/Block prompts for geolocation, notifications,
  camera, mic, and clipboard, persisted per-origin); and per-site settings from the lock
  popover (per-site JavaScript toggle + global third-party-cookie blocking); and
  download safety (dangerous file-type warnings, with downloads saving to ~/Downloads).
- ⬜ **Stage 2 — our own embedder.** Write a thin browser in `mini_browser/` against
  Chromium's `content` module (our `ContentMain`, window/tab UI, address bar), linking the
  engine rather than copying it. See `research.md` §6.

## Constraints (the whole point)

This project is built on **8 GB of RAM on purpose** — constraints are where first-principles
learning happens. Two consequences worth knowing up front:

- The **first clean build takes hours** (Blink + V8 are irreducibly large). This is a
  one-time cost; **incremental rebuilds are seconds to minutes** thanks to the component
  build.
- The build **must be capped to `-j 2`** on this machine. The default parallelism (one job
  per CPU core) ignores RAM and causes catastrophic swap thrashing. See `docs/building.md`.

## License

Our code here is ours to license (TBD). Chromium itself is BSD-licensed and is fetched
separately by `setup.sh`, not redistributed in this repo.
