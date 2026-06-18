# Chromium Architecture Research — Toward a Minimal Learning Browser

**Goal of this document:** understand the Chromium 151 codebase we checked out, so we can
build a browser that *builds and runs functionally on this machine in well under 10 minutes
of iteration time*. Everything below is grounded in our actual checkout at
`/Users/astukari/Desktop/chromium/src` (Chromium 151.0.7897.0), not generic knowledge.

Target hardware reminder: **Apple Silicon MacBook Air, 8 GB RAM, ~145 GB free disk.**

---

## 0. The single most important finding (read this first)

Chromium already contains a minimal browser. It is called **`content_shell`**
(`content/shell/`), and it is built on the **`content` module** (`content/`) — which is
literally "a working browser minus all the *Chrome* features."

`content_shell` already:

- renders real web pages (Blink engine),
- runs JavaScript (V8),
- does real networking with HTTPS (`net` + the network service),
- has a window with an address bar, back/forward buttons, and DevTools,
- runs the full **multi-process sandboxed, site-isolated security architecture**.

What it deliberately *omits*: sync, bookmarks, profiles, the settings UI, the omnibox
suggestion engine, the New Tab Page, extensions, Safe Browsing, autofill, spellcheck,
translate, enterprise policy, and Google-service integration. All of that lives in
`//chrome` (1.3 GB of source), layered *on top of* `content`.

This reframes both of your proposed options (see §6) and is the backbone of the
recommendation.

### A necessary reality check on "under 10 minutes"

We have to split the goal in two, because they have very different answers:

- **Clean/full build under 10 minutes: not achievable for *any* real web browser on this
  hardware.** A browser's irreducible core is the layout engine (Blink) and the JavaScript
  engine (V8). Those two alone are the overwhelming majority of compile time — thousands of
  files plus large amounts of *generated* code (the IDL → C++ bindings). You cannot have a
  functional browser without them, so no amount of trimming gets a *clean* build to 10
  minutes on an 8 GB Air. Expect a first clean build of even the minimal shell to take on
  the order of **1–3 hours** here (mostly bottlenecked by 8 GB RAM forcing swap).

- **Incremental build under 10 minutes: very achievable, and this is the goal that
  actually matters.** Once the engine is compiled, changing the files *you* are learning on
  and rebuilding only recompiles those files plus a relink. With a **component build** (many
  small dylibs, which we already configured in `args.gn`), a typical incremental rebuild is
  seconds to a couple of minutes. That is the fast iteration loop that makes this project
  fun and educational.

So the practical target is: **pay the one-time clean-build cost once, then live in the
sub-10-minute incremental loop.** Trimming features (§3) mostly helps the one-time cost and
disk/RAM headroom; the component build is what gives us the fast loop.

---

## 1. The minimum needed for a working *and secure* browser

These are the non-negotiable subsystems. Every one of them is already present in our tree
and is pulled in automatically when you build `content_shell`.

### 1a. Core engine (rendering + scripting + I/O)

| Subsystem | Path | Primary GN target | Role |
|---|---|---|---|
| **base** | `base/` | `//base` | Foundational C++ runtime: threading, tasks, memory (PartitionAlloc), logging, file I/O. Everything depends on it. |
| **URL** | `url/` | `//url` | `GURL`/`url::Origin` parsing & canonicalization — the basis of every security decision. |
| **Blink (core)** | `third_party/blink/renderer/core/` | `//third_party/blink/renderer/core:core` | The HTML/DOM/CSS/layout/paint engine. The heart of the browser. |
| **Blink (platform)** | `third_party/blink/renderer/platform/` | `//third_party/blink/renderer/platform:platform` | Graphics/font/audio primitives the engine sits on. |
| **Blink (bindings)** | `third_party/blink/renderer/bindings/` | `//third_party/blink/renderer/bindings:bindings` | The V8 ↔ DOM bridge (generated from Web IDL). Large generated-code cost. |
| **V8** | `v8/` | `//v8` | JavaScript engine: parse, JIT, garbage collection. |
| **net** | `net/` | `//net` | HTTP/HTTPS, TLS, sockets, DNS, cookies, cache. |
| **Skia** | `third_party/skia/` | `//third_party/skia:skia` | 2D rasterization — turns the page into pixels (text, shapes, images). |
| **cc** (compositor) | `cc/` | `//cc` | Layer trees, scrolling, animation, frame scheduling. |
| **mojo** | `mojo/` | `//mojo/public` | Type-safe IPC. The glue of the multi-process model. |

> Note on the GPU path (`gpu/`, `components/viz`): hardware acceleration is *performance*,
> not *correctness*. Software rasterization through Skia can render pages without it. But on
> macOS the native GPU path is well-trodden and cheap to keep, so we will keep it.

### 1b. Security architecture — and the good news

The security model is the part people most underestimate when they imagine "writing a
browser from scratch." A genuinely secure browser needs *all* of the following, and
**you get ~85% of it for free by building on the `content` module** (verified against
`content/SECURITY.md` and `docs/process_model_and_site_isolation.md`):

| Security mechanism | Where | Free with content_shell? |
|---|---|---|
| **OS sandbox** (renderer/GPU/utility confined; macOS Seatbelt) | `sandbox/`, `sandbox/policy/` | ✅ Yes — linked & enforced |
| **Multi-process isolation** (untrusted renderer vs trusted browser) | `content/browser`, `content/renderer` | ✅ Yes |
| **Site Isolation** (process-per-site; on by default on desktop) | `content/browser/site_instance_impl.*`, `process_lock.h` | ✅ Yes |
| **IPC validation / capability brokering** (renderers only get granted capabilities) | `mojo/`, `child_process_security_policy_impl.*` | ✅ Yes |
| **TLS / certificate verification** | `net/cert/`, `net/ssl/`, `services/network` | ✅ Yes |
| **Same-Origin Policy, CORS, CSP, CORB/ORB** | `third_party/blink/.../security`, `services/network` | ✅ Yes |

The security pieces you would *lose* by not building `//chrome` are **add-on features, not
core boundaries**: Safe Browsing (phishing/malware blocklists, needs Google infra),
the extension system, and Chrome's advanced permission UI. For a learning MVP, their
absence does not make the browser "insecure" in the architectural sense — the sandbox,
process isolation, and web-platform boundaries are all intact.

**Conclusion for §1:** the minimum *is* essentially the `content` module. That is both the
minimum for *function* and the minimum for *security*, and it already exists in our tree.

---

## 2. Reasonable add-ons with only marginal cost

These sit just above the MVP and are worth keeping/adding because they materially improve
the browser (or the learning experience) without meaningfully blowing up build time, RAM,
or disk. Roughly ordered by value-for-cost:

1. **DevTools (the in-shell debugger)** — `content_shell` already supports it. Invaluable
   for understanding what the engine is doing. The DevTools *frontend* assets
   (`third_party/devtools-frontend`, 933 MB) ship prebuilt and are not a big *compile* cost.
2. **GPU-accelerated rendering** (`gpu/`, `components/viz`) — on by default; on macOS it
   uses the native path and is cheap to keep. Keeps scrolling/animation smooth.
3. **Software video/audio via FFmpeg** (`media/`, `media_use_ffmpeg`) — keep the open
   codecs (VP8/VP9/Opus) so most of the web's media works. This is modest.
4. **A real address bar / multi-tab UI** — `content_shell`'s UI is intentionally bare.
   Adding tabs and a nicer omnibox is *our own code* on top of `content::WebContents`; it's
   cheap to build and is exactly the kind of "how does a browser work" learning we want.
5. **Persistent cookies / disk cache / a simple profile dir** — `net` already implements
   these; wiring a persistent storage path is a small amount of embedder code.

The theme: the cheap, high-value add-ons are mostly **our own thin code against the
content API**, plus a couple of default-on engine features. They do not require pulling in
the `//chrome` layer.

---

## 3. What to exclude (and how easy each is)

Two kinds of exclusion: (a) things macOS **already excludes automatically**, so there's
nothing to do, and (b) things we **turn off with a GN arg**.

### 3a. Already excluded on a Mac build — *do nothing*

When `target_os = "mac"`, GN simply does not compile these (asserts/conditionals prevent
it). They take disk in the checkout but **cost zero build time**, so manually deleting them
is wasted effort and risks breaking `gclient sync`:

`ios/` (197 MB), `android_webview/` (16 MB), `ash/` (129 MB, ChromeOS UI),
`chromeos/` (76 MB), `chromecast/` (9 MB), plus Fuchsia/Windows/Linux-specific code.

Likewise, test/benchmark harnesses are `testonly` and are **never** part of a
`content_shell` (or `chrome`) build: `testing/` (230 MB), most of `tools/` (380 MB),
`third_party/catapult`, `jetstream`, `speedometer`, `webpagereplay`.

### 3b. Turn off with GN args — the real wins

Building `content_shell` instead of `chrome` is the **biggest single exclusion** (drops the
entire 1.3 GB `//chrome` layer: sync, profiles, settings UI, NTP, omnibox engine, etc.).
On top of that, these flags (each found in the `.gni` file listed) trim further. Treat the
defaults as "what we'd be overriding"; exact behavior should be confirmed with
`gn args out/<dir> --list` when we configure, since some interact.

| GN arg | Defined in | What it removes |
|---|---|---|
| `enable_extensions = false` | `extensions/buildflags/buildflags.gni` | The entire extension platform (`extensions/` + much of `chrome/browser/extensions`). |
| `enable_pdf = false` | `pdf/features.gni` | Built-in PDF viewer. |
| `enable_printing = false` | `printing/buildflags/buildflags.gni` | Printing + print preview. |
| `enable_plugins = false` | `content/public/common/features.gni` | Legacy plugin support. |
| `safe_browsing_mode = 0` | `components/safe_browsing/buildflags.gni` | Safe Browsing (a `//chrome` feature anyway). |
| `enable_nacl = false` | `build/config/features.gni` | Native Client (large, deprecated). |
| `enable_remoting = false` | `remoting/remoting_enable.gni` | Chrome Remote Desktop. |
| `enable_supervised_users = false` | `components/supervised_user/buildflags.gni` | Family Link controls. |
| `use_dawn = false` | `ui/gl/features.gni` | WebGPU/Dawn (1.5 GB source). *Cut only if we don't want WebGPU.* |
| `enable_swiftshader = false` | `ui/gl/features.gni` | Software-GPU emulator fallback (1.4 GB source). |
| `proprietary_codecs = false` | `build/config/features.gni` | H.264/AAC/MP3/MP4 (licensed codecs). *Trade-off: some media won't play.* |
| `blink_symbol_level = 0` | `build/config/compiler/` | Strips debug symbols *from Blink specifically* — a big RAM/disk/link win, since Blink is the bulk. |

> ⚠️ **Caveat on aggressiveness:** turning off too much at once invites confusing build
> breaks (some code assumes a feature is present). The disciplined approach is incremental:
> get `content_shell` building first, then disable flags a few at a time and re-verify.

### 3c. The "hard to exclude" category

A few large items are *not* worth fighting:

- **devtools-frontend** (933 MB) is embedded with no clean off-switch — and we want
  DevTools anyway, so leave it.
- **Blink and V8 themselves** are the irreducible core. There is no "lite mode." This is
  precisely why the *clean* build can't hit 10 minutes (see §0).
- **swift-toolchain (3.8 GB) / rust-toolchain (1.5 GB)** are *toolchain downloads*, not
  things we compile every build. They cost disk, not build time. Leave them.

---

## 4. Where the cost actually goes (measured in our checkout)

Top-level disk (checkout, ~30 GB in `src/` excluding `out/`):

```
24G  third_party/   ← dominated by toolchains + engine deps (see below)
1.3G chrome/         ← the whole Chrome feature layer (we skip building this)
781M content/        ← the module our MVP IS
474M components/
247M v8/
117M net/   108M ui/   100M base/   129M media/
```

Inside `third_party/` (the 24 GB):

```
3.8G swift-toolchain   1.9G angle        1.7G blink      1.5G rust-toolchain
1.5G dawn              1.4G swiftshader   933M devtools-frontend
761M node              690M catapult      601M tflite     311M boringssl
292M icu               264M skia          222M rust       211M sqlite
```

Read this way: most of the *disk* is toolchains and engine source we either don't compile
(toolchains, tests) or must keep (Blink, Skia, ICU, BoringSSL, V8). The *build cost* we can
actually influence is: **skip `//chrome`, disable feature flags, and reduce symbol level** —
all of which we control via target choice + `args.gn`.

---

## 5. A concrete starting configuration

A proposed `args.gn` for the minimal shell, building on what we already have. (We'd build
the `content_shell` target rather than `chrome`.)

```gn
# Base: release + component build = fast incremental builds, low peak link RAM.
is_debug = false
is_component_build = true

# Symbols: strip aggressively to save the most RAM/disk on an 8 GB machine.
symbol_level = 1
blink_symbol_level = 0      # Blink is the bulk; this is a big win.

target_cpu = "arm64"

# Feature trims (apply incrementally; verify the build after each batch).
enable_extensions = false
enable_pdf = false
enable_printing = false
enable_plugins = false
safe_browsing_mode = 0
enable_nacl = false
enable_remoting = false
enable_supervised_users = false

# Optional, more aggressive (only if we accept the trade-offs):
# use_dawn = false           # drops WebGPU
# enable_swiftshader = false # drops software-GPU fallback
# proprietary_codecs = false # some media stops playing
```

Build command (once configured):

```sh
caffeinate autoninja -C out/Shell content_shell
```

Run it:

```sh
out/Shell/Content\ Shell.app/Contents/MacOS/Content\ Shell --use-mock-keychain https://example.com
```

---

## 6. Recommendation: the path forward

You framed two options. Here's how they actually shake out against the code:

**Option A — "gut Chromium 151 down."** In practice, the *right* version of this is not
hand-deleting directories (which fights `gclient` and breaks builds for little gain). It is:
**switch the build target from `chrome` to `content_shell` and disable feature flags.** That
single move "removes" the entire 1.3 GB Chrome layer instantly and cleanly, and the flags
trim the rest. This is low-risk and uses exactly what we have.

**Option B — "new browser from scratch, copying snippets from Chromium."** The instinct is
right but the literal version isn't viable: you can't copy *snippets* of Blink/V8/net into a
new repo — they're millions of lines of deeply interdependent code with their own build
system. Nobody, including Google, vendors the engine by copy-paste. The realistic form of
"from scratch" is: **write your own small embedder** — a few hundred lines that call
`content::ContentMain()` and implement the `ContentBrowserClient` / `ContentRendererClient`
delegates — that *links against* the content module. And that is, almost exactly,
**what `content_shell` already is.**

So the two options converge. My recommendation is a **staged hybrid**, which gets you a
working browser fastest *and* gives you the "I built this" learning payoff:

1. **Stage 1 — Get a minimal browser running (use what we have).** Configure a second build
   dir with the `args.gn` above and build the `content_shell` target. Outcome: a real,
   secure, multi-process browser that renders the live web, with fast incremental rebuilds.
   This is the "gut it down" option done the smart way, and it's the prerequisite for
   everything else regardless of path. *(One-time clean build is the slow part on 8 GB;
   after that, iteration is in the sub-10-minute loop.)*

2. **Stage 2 — Author our own embedder (the "from scratch" learning).** Once the shell
   builds, create our own thin browser target modeled on `content/shell/` — our own
   `ContentMain` entry point, our own window/tab UI on top of `content::WebContents`, our own
   address bar and storage wiring. This is where you actually *learn how a browser is
   assembled*, while correctly **reusing** Chromium's engine by linking, not copying. We can
   grow it feature by feature (tabs → history → settings) entirely in our own code.

This sequencing means Stage 1 is never wasted: it's the foundation Stage 2 builds on, and it
gives us a guaranteed-working reference (`content_shell`) to compare against while we build
our own.

**Net recommendation: do Option A's *technique* (content_shell + flags) as Stage 1, then
pursue Option B's *spirit* (our own embedder) as Stage 2 — not by copying engine code, but
by writing our own shell against the content module.**

### Suggested immediate next step

Set up an `out/Shell` build directory with the minimal `args.gn` and kick off the one-time
`content_shell` build (overnight, given the hardware). When it's green, we'll have a working
minimal browser to study — and a launchpad for writing our own.
