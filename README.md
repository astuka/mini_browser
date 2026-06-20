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
- 🛡️ **Security epic ("Fortify") — complete:** browser-security primitives built directly on
  content_shell, from scratch (no `//chrome`). A connection-security indicator (lock / "Not
  Secure") derived ourselves from the navigation's TLS state; a certificate viewer (subject /
  issuer / validity / SANs); a real certificate-error interstitial ("Your connection is not
  private" with Back-to-safety / Proceed); HTTPS-First mode (upgrades http→https, with a
  fallback interstitial when a site has no HTTPS); a local URL blocklist (our own miniature
  "Safe Browsing" with a dangerous-site interstitial); a from-scratch permission system
  (Allow/Block prompts for geolocation, notifications, camera, mic, and clipboard, persisted
  per-origin); per-site settings from the lock popover (per-site JavaScript toggle + global
  third-party-cookie blocking); download safety (dangerous file-type warnings); and a
  Security Diagnostics panel (⌘⇧D — process model, sandbox status, site isolation, per-tab
  renderer PIDs).
- 🧩 **Extension epic, Part 1 ("Graft") — complete (loading + install):** an extension runtime built
  directly on content_shell, from scratch (no `//chrome/browser/extensions`). It delivers an
  **extension model +
  unpacked loader + manager** (⌘⇧E) — load an unpacked extension folder, parse its MV3
  `manifest.json`, derive a Chrome-style id from the path, and list/enable/disable/remove it from a
  management window, persisted across restarts; the **`chrome-extension://` scheme + a
  file-serving URLLoaderFactory** — extension pages, icons, and other bundled resources load from
  the extension's on-disk root under a real `chrome-extension://<id>` origin, with path-traversal
  rejected; and **content-script injection** — an extension's `content_scripts` run on matching
  pages, injected into an isolated world (a renderer-side `RenderFrameObserver` matches the page URL
  against the manifest patterns and injects at the right `run_at`); and **extension action icons +
  popups** — an extension's MV3 `action` shows a toolbar icon (from `default_icon`), and clicking it
  opens its `default_popup` page in a small floating panel hosting a real extension-origin
  `WebContents`; a **`chrome.*` API shim** in extension pages — `chrome.runtime` (`id`, `getURL`,
  messaging) and `chrome.storage.local` (persisted per-extension); and a **persistent background
  page** — an extension's MV3 `background.service_worker` runs in a hidden extension-origin
  `WebContents` (a reduced background model), able to react to messages and share `chrome.storage`
  with the popup; **`declarativeNetRequest` block rules** — an ad/content blocker: enabled
  extensions' static DNR rules block matching network requests (subresources included) via a proxying
  `URLLoaderFactory`, toggled live as extensions are enabled/disabled; and **packaged (.crx)
  install** — install a signed `.crx`, verifying its CRX3 signature (and rejecting tampered packages),
  unpacking it to a managed dir, and registering it under its real key-derived id; and **Web Store
  install-by-id** — paste an extension id (or Web Store URL) to fetch the Google-vetted CRX from the
  public update endpoint and install it through the same verify pipeline (tested with the real Obsidian
  Web Clipper). **Boundary:** install + page-loading work for real Web Store extensions, but full
  *functionality* of a complex extension needs a much larger `chrome.*` API surface than this runtime
  implements yet (e.g. `chrome.tabs`/`scripting`, `chrome.*` in content scripts, external protocols) —
  the focus of Part 2.
- 🛠️ **Extension epic, Part 2 ("Wield") — in progress:** making installed extensions actually
  *usable*, not just loadable, with the real Obsidian Web Clipper (clip a page to an Obsidian vault) as
  the end-to-end bar. **W1a — browser-backed `chrome.storage.local`:** an extension's data now lives in
  one browser-persisted store (`content_shell.extension_storage`) **shared across all of its contexts**
  (popup, options, background) and surviving restarts, via a new `chrome.*` transport — a per-frame
  `ExtensionApi` Mojo interface implemented in the browser plus **gin native bindings** in the renderer
  (the v8↔browser binding deferred in Part 1) — that replaces the old per-origin `localStorage` shim.
  **W1b — `chrome.*` in content scripts:** that same native `chrome.*` (and the shared
  `chrome.storage.local`) is now installed into **content scripts' isolated worlds** too, so a content
  script running on any web page reads/writes the same browser-backed store as the extension's
  background/popup (verified: a content script on example.com reads the background's value and writes
  back). **W1c — `chrome.runtime` messaging:** `chrome.runtime.sendMessage`/`onMessage` is now routed by
  the browser across **all** of an extension's contexts (content script ↔ background ↔ popup, across
  origins), via an `ExtensionApiClient` push channel + a per-extension context registry, with the
  `chrome.*` runtime refactored to one bindings object per v8 context (verified: a content script
  messages the background, and a popup broadcast lands in the content script's `onMessage`). This
  completes the **W1 keystone** (storage + content-script `chrome.*` + cross-context messaging).
  **W2 — `chrome.tabs`:** a popup/background can now `query`/`get`/`create`/`update` tabs (e.g.
  `tabs.query({active:true})` to find the active tab), backed by a TabNode↔tabId bridge into the tab
  strip (verified: query active/all, create + activate, and navigate the active tab). **W3 —
  `chrome.scripting.executeScript`:** an extension can now run a function in a tab's frame and get the
  result back — the page-extraction mechanism the Obsidian Clipper uses. The browser routes to the
  target tab's renderer (via a per-frame `ExtensionScriptRunner`), runs the code in the extension's
  isolated world, and returns the JSON-serialized result as chrome's `[{frameId, result}]` (verified: a
  popup extracted `{title, url, h1, textLength}` live from the active page). **W4 — the clip works:** with
  `obsidian://` external-protocol launch (handed to the OS via `NSWorkspace`), page-JS clipboard access,
  request/response `chrome.runtime`/`chrome.tabs` messaging, `chrome.i18n`, and the remaining MV3 API
  stubs, the **real Web-Store-installed Obsidian Web Clipper clips a live page end-to-end** — its popup
  extracts the page to markdown and "Add to Obsidian" writes a real note (YAML frontmatter + body) to the
  vault's `Clippings/` folder. **This is the Wield epic's north star, achieved.** (Other complex
  extensions get progressively more of what they need; some surfaces — ports, sidePanel UI,
  contextMenus/commands actions — remain stubbed.)
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
