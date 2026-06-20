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
- **`0017-security-site-content-settings.patch`** — **per-site content settings + cookie controls**,
  surfaced as interactive checkboxes in the lock/"Not Secure" popover. **Enable JavaScript on this
  site** writes a per-origin `javascript` flag into the `0016` SiteSettings store; `OverrideWebPreferences`
  reads it and sets `prefs->javascript_enabled = false` (applied on the next reload, which the toggle
  triggers). **Block third-party cookies (all sites)** drives the network service directly via
  `StoragePartition::GetCookieManagerForBrowserProcess()->BlockThirdPartyCookies(...)`, persists a
  global flag, and is re-applied at startup. Reuses the `0016` SiteSettings store. Touches
  `shell_content_browser_client.{cc,h}` (JS pref read + store) and `shell_platform_delegate_mac.mm`
  (popover checkboxes + cookie-manager call); stacks on `0016` and the full prior chain.
- **`0018-security-download-safety.patch`** — **download safety**, plus working Mac downloads.
  content_shell's `ChooseDownloadPath` is `NOTIMPLEMENTED()` on Mac (downloads silently fail), so
  `ShellDownloadManagerDelegate::OnDownloadPathGenerated` now auto-saves to the default Downloads
  directory — **but first warns if the file type is dangerous** (`.dmg`/`.pkg`/`.app`/`.exe`/`.msi`/
  `.jar`/`.sh`/…). The warning is a critical sheet with **Keep** (save) / **Discard** (cancel),
  bridged via a new static `ShellPlatformDelegate::RequestDownloadDecision`; Keep/safe both finish
  the download via the same target callback, Discard cancels with an empty target path. Touches
  `shell_download_manager_delegate.cc` (Mac save + dangerous-type check), `shell_platform_delegate.h`
  (bridge decl), and `shell_platform_delegate_mac.mm` (sheet); stacks on the full prior chain.
  (Broader download support — a Save-As dialog, resumable downloads, a downloads UI — is out of
  scope for the security epic and can be added later.)
- **`0019-security-process-diagnostics.patch`** — a **Security Diagnostics** panel (⌘⇧D), the final
  security-epic feature: it makes content_shell's inherited multiprocess/sandbox/site-isolation
  architecture *observable*. Reports the process model (`RenderProcessHost::run_renderer_in_process`),
  renderer sandbox status (`--no-sandbox`), site-per-process and isolated-origins mode
  (`content::SiteIsolationPolicy`), the count of distinct renderer processes, and a per-tab list of
  renderer PIDs (`GetPrimaryMainFrame()->GetProcess()->GetProcess().Pid()`) — so cross-site tabs
  visibly land in separate processes. Shown as an informational sheet; triggered via ⌘⇧D in
  `HandleKeyboardEvent`. Touches `content/shell/browser/shell_platform_delegate_mac.mm` only; stacks
  on the full prior chain. **This completes the "Fortify" security epic (`0011`–`0019`).**

### Extension epic ("Graft") — building an extension runtime on content_shell from scratch

- **`0020-extensions-model-and-loader.patch`** — the **extension model + unpacked loader +
  management UI** (first piece of the extensions epic). content_shell has no extensions layer at
  all, so we start our own: a persistent installed-extensions registry — `content_shell.extensions`
  JSON dict pref + `GetExtensions()/SetExtensions()` on `ShellContentBrowserClient` (mirrors the
  `0003`/`0010` stores) — and an **Extensions manager window (⌘⇧E)** with a **Load Unpacked…**
  button. Loading a folder reads and parses its `manifest.json` (validating MV3 `name`/`version`,
  recording `description`, `manifest_version`, `permissions`, `host_permissions`, and the on-disk
  path), derives the extension **id from the folder path** the way Chrome does for unpacked
  extensions (SHA-256 → first 16 bytes → `a`–`p` letters, via `//crypto`), and persists it. The
  manager lists each extension with an **enable/disable** checkbox (dims when off) and a **Remove**
  button; the list is rebuilt from the store and survives restart. **No execution yet** — this PR
  only models, loads, and persists what an extension *is*; serving `chrome-extension://` resources
  and running content scripts come in later patches. Touches `content/shell/BUILD.gn` (adds the
  `//crypto` dep), `shell_content_browser_client.{cc,h}` (the store), and
  `shell_platform_delegate_mac.mm` (manifest parsing + manager UI + ⌘⇧E hook); stacks on `0003`/
  `0010` for the store accessors and on the full `.mm` chain through `0019`.
- **`0021-extension-resource-serving.patch`** — the **`chrome-extension://` scheme + a file-serving
  `URLLoaderFactory`** (E2). Registers `chrome-extension` as a **standard + secure** scheme in
  `ShellContentClient::AddAdditionalSchemes` (so extension pages get a real, trustworthy origin) and
  adds it to `IsHandledURL`. A new **`ShellExtensionURLLoaderFactory`** (a
  `network::SelfDeletingURLLoaderFactory`, new file `shell_extension_url_loader_factory.{cc,h}`)
  serves `chrome-extension://<id>/<path>` by looking up the extension's on-disk root in the `0020`
  store, resolving the path **off-thread** (`ThreadPool` + `MayBlock`), reading the file, guessing
  its MIME type (`net::GetMimeTypeFromFile`), and streaming it back over a mojo data pipe — modeled
  on content's `DataURLLoaderFactory`. **Path traversal is rejected**: the resolved file must live
  inside the extension root (`MakeAbsoluteFilePath` + `IsParent`), so `..`/percent-encoded escapes
  return `ERR_ACCESS_DENIED`; unknown id / missing file return `ERR_FILE_NOT_FOUND`. Wired in via
  `ShellContentBrowserClient::CreateNonNetworkNavigationURLLoaderFactory` (extension-page
  navigations) and `RegisterNonNetworkSubresourceURLLoaderFactories` (the page's own bundled
  icons/scripts/etc.). Touches `content/shell/BUILD.gn` (new sources), `shell_content_client.cc`
  (scheme), `shell_content_browser_client.{cc,h}` (the two factory hooks + `IsHandledURL`), and adds
  the factory files; stacks on `0020` (reads its extension store). Everything (extension pages,
  popups, icons, content-script files) will ride on this scheme.
- **`0022-content-script-injection.patch`** — **content-script injection into isolated worlds** (E3),
  the first feature with **renderer-side** code. Extensions' `content_scripts` now run on matching
  pages. A new browser→renderer-queried Mojo interface **`mojom::ShellExtensionScripts`** (new file
  `common/shell_extension_scripts.mojom`) returns each enabled extension's content scripts (match
  patterns, `run_at`, an isolated-world id, and the JS already read from disk). The browser impl
  **`ShellExtensionScriptsImpl`** (new files `shell_extension_scripts_impl.{cc,h}`) re-reads each
  enabled extension's `manifest.json` + JS files **off-thread** (`ThreadPool`/`MayBlock`) and is
  registered per-frame in `RegisterBrowserInterfaceBindersForFrame`. The renderer side lives in
  **`ShellRenderFrameObserver`**: it fetches the scripts once per frame via the
  `BrowserInterfaceBroker`, caches them, and on each navigation's `DidCreateDocumentElement` /
  `DidDispatchDOMContentLoadedEvent` / `DidFinishLoad` (mapped to `document_start`/`end`/`idle`)
  matches the frame URL against the patterns and injects matching scripts with
  `WebLocalFrame::ExecuteScriptInIsolatedWorld` (a stable world id per extension, so content scripts
  can't see page JS globals). Includes a from-scratch match-pattern matcher (`<all_urls>`, `*`
  scheme, `*.host` suffixes, `*` path globs) + `exclude_matches`, and a late-arrival catch-up so
  scripts still inject for stages that already fired. Touches `content/shell/BUILD.gn` (mojom + new
  sources), `shell_content_browser_client.cc` (the binder), and rewrites
  `renderer/shell_render_frame_observer.{cc,h}`; adds the mojom + browser-impl files. Stacks on `0020`
  (reads its extension store). Default MV3 `run_at` is `document_idle`.
- **`0023-extension-action-popup.patch`** — **extension `action` toolbar icons + popups** (E4). Each
  enabled extension that declares an MV3 `action` now gets an icon on the right of the bookmark bar
  (`rebuildExtensionActions`): the icon is loaded from `action.default_icon` (string or `{size: path}`
  dict) off the extension's on-disk root, the tooltip is `action.default_title`, with a
  `puzzlepiece.extension.fill` SF-Symbol fallback. Clicking an icon opens its `action.default_popup`
  page (`extensionActionClicked:` → `showExtensionPopupForURL:anchor:`) in a small floating `NSPanel`
  anchored under the button, hosting a **standalone `content::WebContents`** loaded at
  `chrome-extension://<id>/<popup>` (the E2 scheme + factory serve it) — so the popup is a real,
  interactive extension page at the extension's privileged origin. The popup's `WebContents` is owned
  by the controller and torn down when the panel closes (via an `NSWindowWillCloseNotification`
  observer, to avoid the main window's `windowShouldClose:` teardown path). The action's `action`
  block isn't kept in the `0020` store, so it's re-read live from `manifest.json`
  (`readManifestForExtensionId:`, `ScopedAllowBlockingForTesting`). The action bar is rebuilt on
  startup and whenever the manager loads/enables/disables/removes an extension; `rebuildBookmarkBar`
  preserves the action buttons. Touches `content/shell/browser/shell_platform_delegate_mac.mm` only;
  stacks on the full `.mm` chain and on `0020`/`0021` (store + chrome-extension:// serving). A popup
  with no `default_popup` is a no-op for now (it would fire `chrome.action.onClicked`, which needs the
  `chrome.*` API bridge in E5).
- **`0024-chrome-api-bridge.patch`** — a **`chrome.*` API shim** injected into extension pages (E5).
  `ShellRenderFrameObserver::DidCreateScriptContext` detects an extension page's main world (a
  `chrome-extension://` document, `world_id == 0`) and compiles + runs a small JS shim in that v8
  context (before the page's own scripts), giving extension pages a `chrome` object:
  **`chrome.runtime`** (`id`, `getURL(path)`, and `sendMessage`/`onMessage` delivered across
  same-origin extension contexts via a `localStorage` mailbox + the cross-document `storage` event);
  **`chrome.storage.local`** (`get`/`set`/`remove`/`clear`, callback + Promise styles), backed by the
  extension origin's `localStorage` so values persist per-extension with no browser plumbing; and
  minimal **`chrome.action`** stubs. The shim is pure JS (the extension id is substituted in), so
  there's no native/Mojo transport yet. Touches only
  `content/shell/renderer/shell_render_frame_observer.{cc,h}`; stacks on the full chain and on `0020`/
  `0021` (extension store + `chrome-extension://` origin). Scope note: this covers **extension pages**;
  giving content scripts (which run in an isolated world at the *page's* origin) the same APIs needs a
  browser-backed transport, which arrives with a later PR (alongside the background worker).
- **`0025-background-service-worker.patch`** — a **persistent background page** for MV3 extensions
  (E6), our reduced "background service worker" model. content_shell has no extension service-worker
  registration machinery, so instead of a true SW we host each enabled extension's
  `background.service_worker` script as a long-lived **hidden `WebContents`** at the extension origin
  (so it gets the `0024` `chrome.*` shim). The `0021` factory gains a synthetic resource at
  `chrome-extension://<id>/__shell_background.html` (`BuildBackgroundPage`) — generated HTML that
  `<script>`-loads the manifest's `background.service_worker` (honoring `background.type: "module"`).
  The controller (`rebuildBackgroundPages`) diffs enabled-with-background extensions against the live
  `_backgroundPages` map, creating a hidden `WebContents` (`WebContents::Create` + `LoadURL`) for new
  ones and destroying those no longer wanted; it runs once a browser context exists (first tab attach)
  and after every manager load/enable/disable/remove, and is cleared on window close. Because the
  background page and the popup share the extension origin, they message each other and share
  `chrome.storage` via the `0024` shim with no extra plumbing. Touches
  `shell_extension_url_loader_factory.cc` (the synthetic page) and `shell_platform_delegate_mac.mm`
  (hosting); stacks on `0020`/`0021`/`0024`. Reduced-model caveats: it's a persistent page, not a real
  ephemeral SW (no `onInstalled`/SW-only events; runs while the browser is open), and cross-context
  messaging is same-origin-only (extension pages, not content scripts).
- **`0026-declarative-net-request.patch`** — **`declarativeNetRequest` block rules** (E7), the
  ad/content-blocker milestone. Enabled extensions' static DNR rules now block network requests
  (subresources included), so a real ad-blocker runs. `ReloadExtensionNetRules` (on the
  `ShellContentBrowserClient`) compiles a flat list of `block`-rule `urlFilter`s from each enabled
  extension's manifest `declarative_net_request.rule_resources` + their JSON rule files (UI thread,
  on startup and every manager change). Enforcement is a **proxying `URLLoaderFactory`** inserted via
  `WillCreateURLLoaderFactory` (`network::URLLoaderFactoryBuilder::Append`) — a `DNRProxyFactory`
  (subclass of `0021`'s `SelfDeletingURLLoaderFactory`) that cancels matching requests with
  `ERR_BLOCKED_BY_CLIENT` and forwards the rest to the real factory. This catches **subresources**
  (the actual ads), unlike a browser-side `URLLoaderThrottle` which only sees navigations. The
  `urlFilter` matcher (`MatchesUrlFilter`) is a pragmatic subset: `*` wildcards, `^` as a wildcard
  separator, `|`/`||` anchors stripped (domain anchors approximated as ordered substrings),
  case-insensitive. Touches `shell_content_browser_client.{cc,h}` (rules + proxy + hook) and
  `shell_platform_delegate_mac.mm` (calls `ReloadExtensionNetRules` at startup + on changes); stacks
  on `0020`/`0021`. Note: this is the same request-interception seam the Security epic's S5 blocklist
  would use; supports `block` rules only for now (no `redirect`/`modifyHeaders`).
- **`0027-crx-install.patch`** — **packaged (.crx) install with signature verification** (E8). The
  Extensions manager gains a **Load Packaged (.crx)…** button. Installing a CRX verifies its CRX3
  signature with `//components/crx_file` (`crx_file::Verify(..., VerifierFormat::CRX3, ...)`) — which
  also returns the authoritative extension id derived from the signing public key — then locates the
  ZIP archive after the CRX3 header (12-byte prefix + `CrxFileHeader`), unpacks it with
  `//third_party/zlib/google:zip` (`zip::Unzip`) into a managed dir under the profile
  (`<profile>/CRXExtensions/<id>/`), and registers it under the **signature-derived id** (so packaged
  extensions get their real Chrome id, unlike unpacked ones which use a path hash). A
  tampered/corrupt package fails verification and is rejected with an error. Refactors the
  unpacked-install path to share a `registerExtensionAtPath:withId:` helper + a
  `refreshExtensionSurfaces` helper (rebuild list/actions/background + reload net rules). Touches
  `content/shell/BUILD.gn` (adds `//components/crx_file` + `//third_party/zlib/google:zip`) and
  `shell_platform_delegate_mac.mm`; stacks on `0020`. Once installed, a packaged extension runs
  through the same machinery as unpacked (`0021`–`0026`). Sets up Web-Store install-by-id next.
- **`0028-webstore-install-by-id.patch`** — **install a Chrome Web Store extension by id** (E9, the
  Graft finale). The Extensions manager gains a **Web Store id or URL** field + **Install from Web
  Store** button. On submit it extracts the 32-char id (from a bare id or a `.../detail/<slug>/<id>`
  URL), fetches the Google-vetted CRX from the public update endpoint
  (`https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx3&prodversion=…&x=id%3D<ID>%26installsource%3Dondemand%26uc`)
  with a `network::SimpleURLLoader` `DownloadToTempFile` (follows the redirect to the CDN), then runs
  the downloaded CRX through the `0027` verify + unpack + register pipeline. This realizes the epic's
  north star — discoverability + Google's vetting — by installing the exact same signed CRX the Web
  Store serves, using only the legitimate public update flow. Touches
  `shell_platform_delegate_mac.mm` only; stacks on `0027`. **Honest boundary (verified with the real
  Obsidian Web Clipper, id `cnjifjpddelmedmihgijeibhnjfabmlf`):** install-by-id works end-to-end — it
  downloads, verifies, unpacks, registers, and the popup page even loads with our `chrome.*` shim. But
  the Clipper can't actually *clip*, because it needs APIs this runtime doesn't implement —
  `chrome.scripting`/`activeTab`/`tabs` (to read the active page), `chrome.*` **in content scripts**
  (its `browser-polyfill` content script), `contextMenus`/`sidePanel`/`commands`, and the `obsidian://`
  external-protocol hand-off. Full real-extension *functionality* is a much larger `chrome.*` surface
  than E1–E9 (a future epic); install + page-loading is what E9 proves.
- **`0029-chrome-storage-browser-backed.patch`** — **browser-backed `chrome.storage.local`** (Wield
  epic, **W1a** — the first step toward making installed extensions actually *usable*, not just
  loadable). Replaces E5's per-origin `localStorage` shim with a real transport: a new per-frame Mojo
  interface `content.mojom.ExtensionApi` (`StorageGet`/`StorageSet`/`StorageRemove`/`StorageClear`,
  JSON payloads keyed by extension id) implemented browser-side by `ShellExtensionApiImpl`, backed by
  a new `content_shell.extension_storage` pref (a dict keyed by extension id) with
  `Get/SetExtensionStorageDict` accessors. Renderer-side, `chrome.storage.local` is now backed by
  **gin native functions** (the v8↔browser binding deliberately deferred in E5) installed into each
  extension page's main world: they issue the async Mojo request and resolve a JS `Promise` (wrapped
  in a `v8::MicrotasksScope`, which Blink's scoped-microtask policy requires). So an extension's data
  now lives in **one browser-persisted store shared across all its contexts** (popup, options,
  background) instead of separate per-origin localStorage. Also adds `chrome.storage.sync` (aliased to
  local), a `chrome.storage.onChanged` listener, and the legacy `get(callback)` form. Touches
  `content/shell/BUILD.gn` (new mojom + impl sources, `//gin` dep),
  `shell_content_browser_client.{cc,h}`, `shell_render_frame_observer.{cc,h}`, and adds
  `shell_extension_api.mojom` + `shell_extension_api_impl.{cc,h}`; stacks on `0028`. **Verified** with
  a two-context test extension: the background context writes `chrome.storage.local`, the popup context
  reads back the same values, a write from the popup merges into the same store, and the data persists
  across a restart in Local State under `content_shell.extension_storage` (count incremented 1→2 on the
  background's next launch) — proving it's genuinely browser-backed, not localStorage. **Scope:**
  extension *pages* only (main world); installing the native `chrome.*` into content-script isolated
  worlds, plus browser-routed `chrome.runtime` messaging across contexts, is **W1b** (next).
- **`0030-chrome-api-in-content-scripts.patch`** — **`chrome.*` (incl. browser-backed
  `chrome.storage.local`) inside content scripts** (Wield epic, **W1b**). W1a wired the native
  `chrome.*` only into extension *pages*' main world; content scripts (which run in isolated worlds on
  arbitrary web pages) still got nothing. This adds an `extension_id` field to the `ContentScript`
  mojom struct (set by the browser from the owning extension), so the renderer builds a
  `world_id → extension_id` map when content scripts arrive; `DidCreateScriptContext` then installs that
  extension's `chrome.*` into the isolated world when it's created (reusing W1a's `InstallChromeApi` +
  gin storage bindings). `chrome.runtime` messaging is gated by a `messaging_enabled` flag baked into
  the shim: extension pages keep the same-origin localStorage messaging (E5), while content-script
  worlds get **no-op messaging stubs** (the page's localStorage is the wrong origin) until
  browser-routed messaging lands in **W1c** — listeners are still accepted so extensions that register
  handlers load cleanly. Touches `shell_extension_scripts.mojom`, `shell_extension_scripts_impl.cc`,
  `shell_render_frame_observer.{cc,h}`; stacks on `0029`. **Verified** with a content-script test
  extension on a normal web page (example.com): the content script's `chrome.runtime.id` resolves, and
  `chrome.storage.local.get` **reads the value the background wrote** (shown in an on-page banner:
  `count=1, lastWriter=background`) and **writes back** to the same store (`contentScriptSaw`,
  `lastWriter:"content_script"` confirmed in Local State, keyed under the extension's id and isolated
  from other extensions' stores). So a content script now shares one browser-backed `chrome.storage`
  with the extension's background/popup/options. **Next (W1c):** browser-routed `chrome.runtime`
  messaging across all contexts (the `ExtensionApiClient` browser→renderer push + a per-extension
  context registry).
- **`0031-chrome-runtime-messaging.patch`** — **browser-routed `chrome.runtime` messaging across all
  of an extension's contexts** (Wield epic, **W1c** — completes the W1 keystone). Replaces W1a/W1b's
  localStorage/stub messaging with a real browser path so `chrome.runtime.sendMessage` from any context
  (content script, popup, background) reaches `chrome.runtime.onMessage` in the extension's *other*
  contexts — including content scripts on arbitrary web pages. Adds a Mojo `ExtensionApiClient`
  interface (browser→renderer `OnMessage` push) plus `RegisterContext` + `SendMessage` on `ExtensionApi`;
  the browser keeps a process-global registry `map<extension_id, set<context>>`, stamps the sender id
  itself (anti-spoof), and fans a message out to every other registered context of the extension. The
  `chrome.*` runtime is **refactored to one bindings object per v8 context** (new
  `ShellExtensionContextBindings`): each context binds its own ExtensionApi pipe, registers with the
  browser, hosts the storage + messaging gin functions, and receives pushed messages on its
  ExtensionApiClient receiver to dispatch into that context's `onMessage` listeners. The observer now
  just creates one per context in `DidCreateScriptContext` and destroys it in
  `WillReleaseScriptContext` (which drops the pipes and de-registers). `ShellExtensionApiImpl` becomes
  per-context/stateful and self-cleans from the registry on disconnect. The shim's old localStorage
  messaging + the W1b `messaging_enabled` gate are removed (all contexts now use the native path).
  Touches `shell_extension_api.mojom`, `shell_extension_api_impl.{cc,h}`,
  `shell_render_frame_observer.{cc,h}`, `content/shell/BUILD.gn`, and adds
  `shell_extension_context_bindings.{cc,h}`; stacks on `0030`. **Verified** with a messaging test
  extension: a content script on example.com `sendMessage`s the background (recorded in Local State with
  the browser-stamped `sender.id`), and a popup broadcast is delivered to that content script's
  `onMessage` (shown live in an on-page banner) — messaging works content↔background↔popup, across
  origins, excluding the sender. **W1 (the `chrome.*` transport keystone) is now complete:** storage +
  content-script `chrome.*` + cross-context runtime messaging. (`sendResponse`/response routing is not
  yet implemented; that and `chrome.tabs`/`scripting` come next.)
- **`0032-chrome-tabs.patch`** — **`chrome.tabs` core subset** (Wield epic, **W2**), backed by a
  TabNode↔tabId bridge into the tabbed UI. The mac `TabbedShellController` gains a stable per-tab `tabId`
  (assigned in `addTabForShell`) and C++ bridge functions (`ShellGetTabs`/`ShellCreateTab`/
  `ShellUpdateTab`, declared in new `shell_extension_tabs.h`) that walk the tab tree, report the active
  tab, and create/navigate/activate tabs. `ExtensionApi` gains `TabsQuery`/`TabsGet`/`TabsCreate`/
  `TabsUpdate` (JSON request/reply); `ShellExtensionApiImpl` answers them (IS_MAC-guarded), serializing
  tabs as `{id,url,title,active,windowId,index}`. The renderer adds `chrome.tabs.{query,get,create,
  update}` to the shim (with the `update(props)` / `update(tabId,props)` overloads) backed by new gin
  functions. So an extension popup/background can enumerate tabs, find the active one, open tabs, and
  navigate them. Touches `shell_extension_api.mojom`, `shell_extension_api_impl.{cc,h}`,
  `shell_extension_context_bindings.{cc,h}`, `shell_platform_delegate_mac.mm`,
  `content/shell/BUILD.gn`, and adds `shell_extension_tabs.h`; stacks on `0031`. **Verified** with a
  tabs test extension: `tabs.query({active:true})` reports the active tab, `tabs.query({})` returns the
  full tab array with well-formed objects, `tabs.create({url})` opens + activates a new tab and returns
  it, and `tabs.update({url})` navigates the active tab (URL bar followed to example.org). This gives W3
  (`chrome.scripting.executeScript`) the active-tab id it targets. **Next (W3):** `chrome.scripting`/
  `activeTab` to run code in a tab and read its content (plus `sendResponse` so request/reply messaging
  works), toward the Obsidian clip.

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
