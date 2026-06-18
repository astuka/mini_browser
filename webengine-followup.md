# Web Engine Capstone — Follow-up Project (Out of Scope for the Chromium Build)

> **Status: parked idea / future project.** This is *not* part of the current effort
> (building and modifying a specific Chromium 151 build on 8 GB RAM). It's a separate,
> later capstone captured here so we don't lose the thread. Do not start this until the
> Chromium project has run its course.

## The idea in one sentence

Build a web engine **from scratch**, starting from the bare minimum (a text-mode browser in
the spirit of **Lynx / w3m / Links**) and growing it **one deliberate stage at a time**,
treating each stage as both a capability milestone *and* an optimization exercise — all
under the same self-imposed **8 GB / constrained-hardware** discipline that defines this
whole line of work.

## Why this is a *different* project from the Chromium one

| | **Current project (Chromium)** | **This capstone (from scratch)** |
|---|---|---|
| Question it answers | *How is a production browser assembled and modified?* | *How does a browser engine actually work, from first principles?* |
| Method | Build, trim, and extend an existing 30-year-old engine | Write the core ourselves; lean on libraries only for deep specialized subsystems |
| Codebase | Tens of millions of LOC, hours-long builds | Starts at hundreds of LOC, builds in seconds |
| Risk | Low (it already works) | High (we own every bug) — which is the point |

They're **complementary**: reading Blink/V8 in the Chromium project is the best possible
preparation for building our own, because we'll have seen how the grown-up version solves
each problem before we attempt a minimal version of it.

## Guiding principles

1. **Constraints first.** 8 GB is a feature, not a bug. Every stage must build fast and run
   lean. When something gets expensive, that expense *is the lesson*.
2. **Vertical slices.** Each stage should produce a *working browser*, not a half-finished
   subsystem. Always have something you can point at a URL.
3. **Standards are the spec.** When in doubt, the WHATWG/W3C specs are the source of truth —
   reading them is part of the work.
4. **Measure everything.** Track build time, binary size, memory footprint, and time-to-
   render per stage. The numbers are the deliverable as much as the code.
5. **Build the architecture, borrow the abysses.** We build the *engine core* (parsing, DOM,
   style, layout, paint orchestration). We **do not** rewrite the bottomless specialized
   pits — TLS, font rasterization, image codecs, and (critically) a JS JIT. Those are where
   Blink's size comes from; leaning on libraries there is what keeps this tractable. The
   skill is knowing the boundary.

## What we deliberately DON'T build (and what we use instead)

| Subsystem | Why not build it | Borrow |
|---|---|---|
| TLS / crypto | A correct, secure TLS stack is its own multi-year project | OS APIs or a vetted lib (rustls / BoringSSL / OpenSSL) |
| Font rasterization & shaping | Hinting + complex-script shaping is brutal | FreeType + HarfBuzz, or platform text APIs |
| Image codecs | PNG/JPEG/WebP decoders are deep | stb_image / libpng / platform decoders |
| JavaScript engine | A JIT VM is a *career*, not a stage (see: V8) | **Embed QuickJS** (small, embeddable) — write only the *bindings* |
| Unicode | Endless edge cases | ICU, or the language's stdlib |

This boundary is the single most important scoping decision. Building everything = Chromium
scale. Building the **orchestration** while embedding the deep pieces = a tractable capstone.

## The staged roadmap

Each stage lists: **Goal · Build · Learn · Reference tier** (the real-world engine that lives
at roughly this level of ambition).

### Stage 0 — "curl that understands HTML"
- **Goal:** fetch a URL and dump readable text. The "hello world."
- **Build:** an HTTP(S) GET (start with `file://` and plain HTTP, add TLS via a lib), then
  naively strip tags and print the text content.
- **Learn:** sockets, the HTTP request/response cycle, why even *this* has surprises
  (redirects, encodings, chunked transfer).
- **Reference tier:** `curl` + `lynx -dump`.

### Stage 1 — Real HTML → a DOM tree
- **Goal:** a genuine text-mode browser.
- **Build:** a subset of the HTML5 tokenizer + tree-construction algorithm that produces a
  **DOM tree** and tolerates malformed markup; render the tree as structured text (headings,
  paragraphs, lists, links) to the terminal.
- **Learn:** parsing as a state machine, tree data structures, *why* HTML parsing is
  specified so rigidly (interoperability on broken input).
- **Reference tier:** **Lynx / w3m / Links.**

### Stage 2 — Navigation & an interactive TUI
- **Goal:** something you'd actually use in a terminal.
- **Build:** link following, back/forward history, a URL bar, relative-URL resolution, basic
  GET forms.
- **Learn:** the *browsing model* — the navigation controller, session history, the URL/origin
  model. (This maps directly onto what we'll have seen in Chromium's `content/`.)
- **Reference tier:** w3m's interactive mode.

### Stage 3 — The box model & basic layout (text → *visual*)
- **Goal:** the conceptual leap from "flowing text" to a real 2D rendering engine.
- **Build:** parse a CSS subset (a few selectors + properties: `display`, `width`, `margin`,
  `color`, `font-size`); do **style resolution** (cascade + specificity, even a simple
  version); compute a **box-model** layout (block/inline boxes, margin/border/padding/
  content); render boxes + text to an actual **window**, not the terminal.
- **Learn:** the box model, layout as a tree traversal, the cascade — and your first taste of
  *why CSS engines grow without bound*.
- **Reference tier:** **NetSurf**, and Matt Brubeck's `robinson` toy engine.

### Stage 4 — Paint pipeline: fonts & images
- **Goal:** pages that look like pages.
- **Build:** a **display-list / paint phase**; real text rendering (FreeType/HarfBuzz or
  platform); image decoding + display.
- **Learn:** rasterization, font metrics & baselines, separating *layout* from *paint*
  (the distinction every real engine makes).
- **Reference tier:** NetSurf with images.

### Stage 5 — CSS richness (feel the combinatorial explosion)
- **Goal:** handle real-world simple pages (a blog post, a docs page).
- **Build:** inline flow with line-wrapping, lists, maybe a minimal flexbox; full cascade;
  more properties as needed by target pages.
- **Learn:** *first-hand*, why the feature surface is irreducible — each new property
  interacts with all the others. This stage is meant to make Blink's size *felt*, not just
  understood.
- **Reference tier:** early Gecko/WebKit-era layout.

### Stage 6 — JavaScript (the hard leap), via embedding
- **Goal:** dynamic pages.
- **Build:** **embed QuickJS**; expose a *minimal* DOM API to it (`getElementById`,
  `addEventListener`, basic node mutation); implement the **event loop**; trigger
  **re-layout on DOM mutation**.
- **Learn:** the **bindings problem** — wiring a language runtime to the DOM is *exactly*
  what makes Blink huge (its IDL-generated bindings). Doing a tiny version makes that
  concrete. Also: the event loop, and reflow-on-mutation.
- **Reference tier:** any JS-capable engine — and a direct line of sight to *why* V8 + its
  bindings are their own giant.

### Stage 7 — Performance & the constraints thesis (the "optimizing" core)
- **Goal:** make it genuinely fast and small — the heart of what makes this a *capstone*.
- **Build:** profile and optimize: **incremental layout** (only re-lay-out dirty subtrees),
  **dirty-region repaint**, style/measurement caching, a **memory budget**, and possibly
  **parallelism** (parallel style resolution — the Servo idea).
- **Learn:** the actual engineering of speed and footprint under constraint. This is where
  first-principles thinking pays off and where genuinely novel ideas can appear.
- **Reference tier:** **Servo** (parallel, Rust), and the design ethos of **Ladybird**.

### Stage 8 (stretch) — Networking & security maturity
- **Goal:** be a *responsible* browser, not just a renderer.
- **Build:** proper HTTPS, cookies, an HTTP cache, and enforcement of the **same-origin
  policy**; consider process isolation / a sandbox.
- **Learn:** why the security model is woven through everything (the lesson from the Chromium
  project's `content/SECURITY.md`, now built rather than read).

## Language & tooling decision (defer, but framed)

A real choice to make at Stage 0:

- **Rust** — memory safety in a domain *infamous* for use-after-free bugs, plus fearless
  parallelism (the Stage 7 payoff). Precedent: **Servo**. Strong lean for a from-scratch
  engine.
- **C++** — continuity with the Chromium project (same language we're already learning),
  precedent in **Ladybird**. Lower friction if we want to lift ideas straight from Blink.
- **A high-level language (Python/JS) for a *first pass*** — the book *Web Browser
  Engineering* builds a real browser in Python; great for learning the architecture fast
  before a performance-oriented rewrite.

**Tentative lean:** prototype the architecture quickly (even in a high-level language),
then commit to **Rust** for the performance/constraint stages — but this is explicitly a
Stage-0 decision, not now.

## Definition of done (for the capstone)

Render a handful of **real, simple, modern pages** (e.g. a blog post, a Wikipedia article, a
docs page) with correct text layout, links, images, basic CSS, and minimal interactivity —
**while building in seconds and running comfortably inside an 8 GB budget.** The numbers
(build time, binary size, peak RAM, time-to-first-paint) tracked across all stages are part
of the final artifact.

## Reference material

- **Web Browser Engineering** (browser.engineering) — Pavel Panchekha & Chris Harrelson.
  Builds a working browser in Python, step by step. The closest existing thing to this plan.
- **"Let's build a browser engine!"** — Matt Brubeck's `robinson` series (Rust), great for
  Stages 3–4.
- **Ladybird** — a from-scratch independent engine; read its code for "how a small team does
  it today."
- **Servo** — for the parallel-engine architecture and the Stage 7 ideas.
- **NetSurf** — for "usable browser, tiny footprint."
- The **WHATWG HTML** and **W3C/CSSWG CSS** specs — the actual source of truth.

---

*Captured during the Chromium build project on 2026-06-17. When we're ready, Stage 0 is a
weekend's worth of work and immediately rewarding.*
