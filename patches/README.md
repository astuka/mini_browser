# patches/ — diffs we apply to upstream Chromium

This directory holds changes we make to **upstream Chromium files**, stored as `.patch` files
rather than copies of the files themselves. This keeps the repo small, makes our changes
reviewable in isolation, and keeps them cleanly separated from the engine.

## Current patches

- **`0001-vertical-tabs-mac.patch`** — rewrites `content/shell/browser/shell_platform_delegate_mac.mm`
  to give content_shell a **vertical tab strip on the left** of a single shared window
  (content_shell normally opens one native window per page). Each `Shell`/`WebContents`
  becomes a tab whose web view swaps into a shared content area, with the toolbar retargeting
  to the active tab. Also: tabs opened in the background (cmd+click, middle-click,
  `target=_blank`, `window.open`) appear at the bottom without stealing focus and trigger a
  subtle accent flash across the whole strip; the `+ New Tab` button opens a foreground blank
  tab. Contained entirely to that one file (no `Shell` core or header changes).
- **`0002-nav-icons.patch`** — replaces the Back/Forward/Reload/Stop toolbar button *text*
  with **SF Symbol icons** (`chevron.backward/forward`, `arrow.clockwise`, `xmark`), guarded by
  `@available(macOS 11.0, *)` with a text fallback. Also touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`** (it edits
  a method that `0001` introduced).

## Workflow

`setup.sh` applies every `*.patch` here (in filename order) to the Chromium checkout with
`git apply`. **Patches that touch the same upstream file stack** — each is a delta on top of the
previous one (in numeric order), so they must be applied in sequence (which `setup.sh` does).

### Creating a patch

After editing a file inside the Chromium checkout (`chromium/src`):

```sh
cd chromium/src
git diff path/to/changed_file > /path/to/minichromium/patches/0001-short-description.patch
```

Use a numeric prefix (`0001-`, `0002-`, …) so patches apply in a deterministic order.

### Conventions

- One logical change per patch, with a descriptive name.
- Keep patches minimal — prefer adding our own files in `../mini_browser/` over editing
  upstream files. Reserve patches for things that *must* touch the tree (e.g. registering our
  build target in a top-level `BUILD.gn`).
- If a patch stops applying after a Chromium version bump, regenerate it against the new tree.
