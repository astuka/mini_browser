# Building minichromium

This documents the real build process for this project, **including the non-obvious gotchas
we hit** building on an 8 GB Apple Silicon MacBook Air. If you're on a beefier machine, most
of the constraints sections won't bite you — but the Metal toolchain and the basic flow still
apply.

## TL;DR

```sh
./setup.sh                                  # one-time: fetch + configure
cd chromium/src
caffeinate autoninja -C out/Shell content_shell -j 2
"out/Shell/Content Shell.app/Contents/MacOS/Content Shell" \
  --use-mock-keychain --disable-features=DialMediaRouteProvider https://example.com
```

## Prerequisites

- macOS on Apple Silicon, an APFS volume, and **Xcode** (we used 26.5).
- ~150 GB free disk for a lean checkout + build.
- `setup.sh` handles `depot_tools` and the Chromium fetch.

### Gotcha #1 — the Metal shader compiler (Xcode 16+/26)

Recent Xcode **no longer bundles** the `metal` shader compiler, but Chromium compiles
`.metal` GPU shaders and needs it. The build fails almost immediately with:

```
error: cannot execute tool 'metal' due to missing Metal Toolchain;
use: xcodebuild -downloadComponent MetalToolchain
```

Fix (a ~688 MB one-time download):

```sh
xcodebuild -downloadComponent MetalToolchain
```

If that command itself fails to load a plugin (a stale Xcode framework mismatch), repair
Xcode's components first, then retry:

```sh
xcodebuild -runFirstLaunch
xcodebuild -downloadComponent MetalToolchain
```

Verify: `xcrun -sdk macosx metal --version`.

## The build configuration

Our `build/args.gn` builds Chromium's minimal **`content_shell`** target (not the full
`chrome`), tuned for low memory:

```gn
is_debug = false           # release: faster linking, less RAM/disk
is_component_build = true   # many small dylibs -> low peak link memory + fast incremental
symbol_level = 1            # function-level backtraces at modest cost
blink_symbol_level = 0      # strip Blink's symbols (Blink is the bulk) — big win
target_cpu = "arm64"
```

`setup.sh` copies this into `out/Shell/args.gn` and runs `gn gen out/Shell`.

## Constraints on 8 GB RAM

### Gotcha #2 — cap parallelism to `-j 2`

`autoninja`/Siso default parallelism to the **CPU core count** (8 here) with **no regard for
RAM**. Each heavy Blink/V8 translation unit needs ~1–2 GB to compile, so 8 concurrent jobs
vastly exceed 8 GB and the kernel thrashes on swap — throughput collapsed to **~30 files/hour**
(53% of CPU was kernel memory-management, ~58 MB RAM free).

**Always cap it:**

```sh
caffeinate autoninja -C out/Shell content_shell -j 2
```

At `-j 2`, the heavy section runs with comfortable headroom and throughput climbed past
**~2,800 files/hour**. `-j 3` works but runs at the memory edge (risky for unattended runs);
`-j 2` is the safe default on 8 GB. On a machine with more RAM, drop the `-j` cap entirely.

### Expected timing

- **First clean build:** hours (most of a day on 8 GB). Blink + V8 are irreducibly large —
  this is the price of a real web engine, and it's a **one-time** cost.
- **Incremental builds:** seconds to a couple of minutes. Editing one `.cc` recompiles that
  file and relinks one small component dylib. Editing a widely-included header can trigger a
  large recompile — so prefer touching implementation files while iterating.

### Monitoring a long build

Siso runs with `--quiet`, so it emits **no progress bar** to a non-terminal. Gauge progress
by counting compiled objects:

```sh
find out/Shell/obj -name '*.o' | wc -l
```

A full `content_shell` build produces ~36k objects, then links ~529 component dylibs.

## Running

```sh
"out/Shell/Content Shell.app/Contents/MacOS/Content Shell" \
  --use-mock-keychain --disable-features=DialMediaRouteProvider <url>
```

The flags suppress the per-launch keychain and media-router dialogs. You may still get a
one-time macOS firewall prompt ("accept incoming network connections") — that's the OS; allow
it. A healthy launch spawns a browser process plus GPU, renderer, and utility child processes
(the multi-process architecture).
