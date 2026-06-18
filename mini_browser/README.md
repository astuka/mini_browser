# mini_browser/ — our embedder (Stage 2)

This directory will hold **our own browser source** — the "build your own shell" part of the
project. It is currently a **placeholder**; Stage 1 (getting Chromium's stock `content_shell`
to build and run) is done, and this is where Stage 2 begins.

## The idea

Rather than copying Chromium's engine code (impossible — it's millions of interdependent
lines), we **link against** Chromium's `content` module and write a thin embedder on top, the
same way `content/shell/` does. See `../research.md` §6.

When populated, this will contain roughly:

- A `ContentMain` entry point and a `ContentMainDelegate`.
- Implementations of `ContentBrowserClient` / `ContentRendererClient`.
- Our own window, tab strip, and address-bar UI built on `content::WebContents`.
- A `BUILD.gn` defining a `mini_browser` executable target.

## How it attaches to the Chromium tree

`setup.sh` symlinks this directory into the checkout as `chromium/src/mini_browser`, so GN can
see it. Adding the build target to Chromium's graph (e.g. referencing `//mini_browser` from a
top-level `BUILD.gn`) will be done via a file in `../patches/` so the change is tracked
without committing upstream files.

Build target (once it exists):

```sh
caffeinate autoninja -C out/Shell mini_browser -j 2
```
