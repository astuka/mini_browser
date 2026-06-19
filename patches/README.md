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
- **`0003-bookmark-store.patch`** — persistent **bookmark store** (no UI yet): registers a
  `content_shell.bookmarks` JSON dict pref in `CreateLocalState()` and exposes
  `GetBookmarks()/SetBookmarks()` on `ShellContentBrowserClient` (backed by the existing
  `PrefService`/`Local State`, avoiding `//components/bookmarks`). Touches
  `content/shell/browser/shell_content_browser_client.{cc,h}` — an *independent* patch (different
  files from `0001`/`0002`). Backing store for the upcoming bookmark bar.
- **`0004-bookmark-bar.patch`** — a **horizontal bookmark bar** between the toolbar and the
  content area: renders a button per stored bookmark (click loads it in the active tab) plus a
  "+" button that bookmarks the current page (title + URL) and persists it via the `0003` store.
  Adds a `layoutChrome`-style band (`kBookmarkBarHeight`) and updates `ResizeWebContent`. Touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`/`0002`**; it
  also depends on `0003`'s `GetBookmarks/SetBookmarks` accessor at runtime.
- **`0005-tab-tree-refactor.patch`** — internal refactor with **no user-visible change**:
  renames `TabInfo`→`TabNode` and adds (dormant) folder fields (`kind`, `children`, `expanded`,
  `parent`), introduces a derived `_flatRows` render order via `rebuildFlatRows` (a DFS that
  `layoutTabRows` now iterates), makes `tabForShell:` recursive, and switches the last-tab
  teardown to a recursive `tabNodeCount`. Foundation so tab folders and multi-select can be added
  without reworking the model. Stacks on the other `.mm` patches.
- **`0006-tab-folders.patch`** — **collapsible tab folders** in the vertical strip. Drag one tab
  row onto another to create a folder containing both; drag more rows onto a folder (or onto a tab
  already inside one) to add them; click a folder row to collapse/expand it (disclosure triangle
  ▸/▾, with a live tab count). Children render indented; closing tabs auto-prunes — a folder that
  drops to one child dissolves and lifts the survivor back up. Implemented by making each row a
  `TabRowView` (an `NSDraggingSource`/`NSDraggingDestination`) and the title a `TabTitleButton`
  that distinguishes a click from a drag by tracking the mouse; the tree mutation, pruning, and
  indented layout all live in `TabbedShellController`. The drag uses a shared
  `kTabRowPasteboardType` so a later "drag a tab onto the bookmark bar" feature can reuse it from a
  different destination with no source-side change. Touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`/`0002`/`0004`/
  `0005`** (it builds on the `0005` tree model).
- **`0007-multi-select-context-menu.patch`** — **multi-select tabs + a right-click context menu**.
  ⌘-click toggles a tab in/out of the selection; Shift-click selects a contiguous range from the
  anchor (over the visible flat order); a plain click activates a tab and collapses the selection
  onto it. Selected (but not active) rows get a translucent accent highlight, a third row state
  added to `restyleRow:`. Right-clicking a tab row shows a menu acting on the whole selection —
  **Close N Tabs**, **Move to New Folder** (created at the topmost selected tab's slot), **Move to
  Folder ▸** (submenu of existing folders), **Add N Tabs to Bookmarks** (reuses the `0003` store +
  bookmark bar); right-clicking a folder row shows **Close Folder** (closes all tabs within).
  Right-clicking an unselected row first makes it the selection (Finder-style). Touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`/`0002`/`0004`/
  `0005`/`0006`** (uses the `0006` tree mutation/`makeFolderNode` and the `0003` bookmark store).
- **`0008-drag-tab-to-bookmark-bar.patch`** — **drag a tab onto the bookmark bar to bookmark it**.
  The bookmark bar is now a `BookmarkBarView` (an `NSDraggingDestination`) that registers the same
  `kTabRowPasteboardType` the strip rows already publish; dropping a tab row on it appends the tab's
  title+URL to the `0003` store (op = **Copy**, so the tab stays put) and rebuilds the bar. The bar
  highlights while a valid drag is over it; dragging a *folder* is rejected (no single URL). The
  only source-side change is widening the row's drag op to `Move | Copy` so the destination can
  request a copy — tab→tab stays a Move (the row destination still returns Move). Touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`/`0002`/`0004`/
  `0005`/`0006`/`0007`** (uses the `0003` store; reuses the `0006` row-drag pasteboard type).
- **`0009-rename-folders.patch`** — **rename tab folders**. Adds a "Rename Folder…" item to the
  `0007` folder context menu (and double-click on a folder row) that overlays an inline
  `NSTextField` editor on the folder's row, seeded with the current name. Return / clicking away
  commits (empty falls back to "Folder"); Esc cancels. The disclosure triangle and live tab count
  are preserved (only the name is editable, stored in `TabNode.folderTitle`). The editor's commit
  delegate is wired one runloop tick after it takes focus, to skip a spurious end-editing AppKit
  emits while the field is *becoming* first responder. Closes out the tab-structure epic. Touches
  `content/shell/browser/shell_platform_delegate_mac.mm`, so it **stacks on `0001`/`0002`/`0004`/
  `0005`/`0006`/`0007`/`0008`** (extends the `0007` context menu).
- **`0010-session-persistence.patch`** — **tabs survive quit and crash**. The whole tab tree (tabs +
  their URLs/titles, folder grouping, each folder's name + expanded state, and which tab was active)
  is serialized to a `content_shell.session` JSON pref and re-read on launch. Adds
  `GetSession()/SetSession()` on `ShellContentBrowserClient` (mirrors the `0003` bookmark store;
  pref registered outside the `IS_IOS` guard) in `shell_content_browser_client.{cc,h}`, and the
  serialize/restore + save-on-change logic in `shell_platform_delegate_mac.mm`. On the first window,
  a one-shot deferred pass restores the saved tree and (on a bare launch) closes the default startup
  placeholder; an explicitly launched URL is kept as an extra tab. Persist-on-change gives free
  crash recovery; a clean quit deliberately does **not** clear the store. So it **stacks on every
  prior `.mm` patch (`0001`/`0002`/`0004`/`0005`/`0006`/`0007`/`0008`/`0009`) and on `0003` for the
  `shell_content_browser_client.{cc,h}` store accessors.**

### Security epic ("Fortify") — building browser security on content_shell from scratch

- **`0011-security-connection-indicator.patch`** — a **connection-security indicator** in the
  toolbar (first piece of the security epic). We derive the security level *ourselves* from the
  navigation's URL scheme + `SSLStatus` (content_shell has no `//components/security_state`): a green
  `lock.fill` for valid HTTPS, a grey "Not Secure" badge for HTTP, a yellow open-lock for HTTPS with
  mixed content, a red warning for certificate errors, and nothing for internal pages (`data:`,
  `about:`, …). Stored per-tab on `TabNode`, recomputed in `DidNavigatePrimaryMainFramePostCommit`
  and re-shown on tab switch. The indicator is a (currently no-op) button so the upcoming certificate
  viewer can hang off it. Touches `content/shell/browser/shell_platform_delegate_mac.mm`; stacks on
  the full `.mm` chain (`0001`/`0002`/`0004`/`0005`/`0006`/`0007`/`0008`/`0009`/`0010`).
- **`0012-security-certificate-viewer.patch`** — clicking the `0011` indicator opens a **certificate
  / connection popover**. For HTTPS it reads the server cert straight from the navigation's
  `SSLStatus` (`net::X509Certificate`) and shows subject CN, organization, issuer, validity window
  (UTC), and Subject Alternative Names; for HTTP it explains the connection is unencrypted with no
  certificate; for internal pages it notes there's no network connection. An `NSPopover` anchored to
  the indicator, toggled on click. Touches `content/shell/browser/shell_platform_delegate_mac.mm`;
  stacks on the full `.mm` chain through `0011`.
- **`0013-security-cert-error-interstitial.patch`** — a real **certificate-error interstitial**.
  content_shell's default blocks bad-cert navigations outright; we override
  `ShellContentBrowserClient::AllowCertificateError` and, for a top-level navigation, hand the
  decision to a native **"Your connection is not private"** page (host + reason + net error code)
  with **Back to safety** (cancel) and **Proceed anyway (unsafe)** (continue). The C++ client bridges
  to the Mac UI via a new static `ShellPlatformDelegate::RequestCertificateErrorDecision` (the
  move-only `OnceCallback` is wrapped in a block and run once). Introduces a **reusable interstitial
  primitive** (`presentInterstitialInTab:…` — a centered card overlay with title/message/detail and
  one or two block-backed buttons) that S4 (HTTPS-First) and S5 (blocklist) will reuse; the overlay
  is per-tab (shown only for the active tab, above the web view) and cleared on resolve/close.
  Touches `shell_content_browser_client.{cc,h}` (override), `shell_platform_delegate.h` (static
  bridge decl), and `shell_platform_delegate_mac.mm` (UI). Stacks on the full `.mm` chain through
  `0012`, plus `0003`/`0010` for the `shell_content_browser_client.{cc,h}` edits.
- **`0014-security-https-first.patch`** — **HTTPS-First mode**, built from scratch (no `//chrome`
  HttpsUpgrades). A `NavigationThrottle` (added in `CreateThrottlesForNavigation`) upgrades top-level
  `http://` navigations to `https://` (`WillStartRequest` cancels the http nav and re-navigates to
  https; skips IP/localhost and a session allowlist). If the https attempt fails (`WillFailRequest`
  for a connection/protocol error — cert errors are handled separately by `0013`), it reuses the
  `0013` interstitial primitive to show **"This site doesn't support HTTPS"** with **Continue to
  HTTP site** (allowlists the host for the session, then loads the original http URL) / **Back to
  safety** (cancel). Bridged to the Mac UI via a new static
  `ShellPlatformDelegate::RequestHttpFallbackDecision`. Touches `shell_content_browser_client.cc`
  (throttle), `shell_platform_delegate.h` (bridge decl), and `shell_platform_delegate_mac.mm` (UI);
  stacks on `0013` (interstitial primitive) and the full prior chain.
- **`0015-security-url-blocklist.patch`** — a **local URL-reputation blocklist** (our own miniature
  "Safe Browsing", no Google SB). A second `NavigationThrottle` (registered *before* the HTTPS-First
  one) checks each top-level navigation's host against a built-in blocklist (O(1) `flat_set` match,
  done before the network request — a blocked host needn't even resolve). On a match it reuses the
  `0013` interstitial to show **"Dangerous site blocked"** with **Visit anyway (dangerous)**
  (allowlists the host for the session and `Resume()`s the navigation) / **Back to safety** (cancel).
  Seeded with a few test hosts (incl. Google's real `testsafebrowsing.appspot.com`); a real
  deployment would load a hosts-style list. Bridged via a new static
  `ShellPlatformDelegate::RequestBlocklistDecision`. Touches `shell_content_browser_client.cc`
  (throttle), `shell_platform_delegate.h` (bridge decl), and `shell_platform_delegate_mac.mm` (UI);
  stacks on `0013`/`0014` and the full prior chain. (This is the same request-interception groundwork
  the planned extensions ad-blocker will reuse.)
- **`0016-security-permission-prompts.patch`** — a **permission system from scratch**, replacing
  content_shell's auto-grant/deny test behavior. `ShellPermissionManager::RequestPermissionsFromCurrentDocument`
  now resolves each promptable permission (**geolocation, notifications, camera, microphone,
  clipboard**) using a saved per-origin decision, or — if undecided — a real **Allow / Block prompt**
  (an `NSAlert` sheet), persisting the answer; `GetPermissionStatus` reflects the saved decision (or
  `ASK`). Decisions live in a new persistent **per-origin SiteSettings store** —
  `content_shell.site_settings` pref + `GetSitePermission`/`SetSitePermission` on
  `ShellContentBrowserClient` (the foundational store the per-site content-settings PR will reuse).
  A self-owned flow resolves multi-permission requests one prompt at a time; the prompt is bridged to
  the Mac UI via a new static `ShellPlatformDelegate::RequestPermissionDecision`. Non-promptable
  permissions keep the previous allowlist behavior. Touches `shell_permission_manager.cc` (the logic),
  `shell_content_browser_client.{cc,h}` (store), `shell_platform_delegate.h` (bridge decl), and
  `shell_platform_delegate_mac.mm` (sheet); stacks on `0003`/`0010` and the full prior chain.

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
