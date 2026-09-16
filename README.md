# corLibs

Umbrella build for the **k-libs** and **Cor-Libs** that the coraine (NGSI-LD
context broker) links against. **This repo contains no library.** What it holds is
everything one needs to know to assemble the stack:

- **which repositories make it up**, and in which order they build — `bootstrap.sh`
  and the makefile, which collect the archives, shared objects and test tooling
  into `lib/` and `bin/`
- **at which versions** — `klib-pins`, the single source of truth for the k-lib
  refs, read by `bootstrap.sh` and by the broker's own Dockerfile
- **what environment that build needs** — `docker/Dockerfile.ci`, published as
  **`quay.io/seamware/coraine-ci`** and used by every cor repo's CI

That last one lives here for the same reason as the first two: the image exists to
satisfy exactly the dependencies `bootstrap.sh` assumes. Kept in a repo of its own,
the two would have to agree about mongo-c v2 forever — and the day they disagree is
the day CI passes against a toolchain nobody ships.

All libraries live as **separate sibling repos under `~/git`**. corLibs drives
them; it does not vendor them.

- **License:** [Apache License 2.0](LICENSE) — Copyright 2026 Seamware

## Layout

```
~/git/
├── corLibs/        ← this repo (umbrella: makefile + iter.sh, collects into bin/ lib/)
├── kbase  kalloc  khash  kjson  kargs  ktrace  kprom          ← k-libs   (gitlab.com/kzangeli)
├── corHttp  corRest  corJsonld  corPlugin  corNgsild           ← Cor-Libs  (github.com/SEAMWARE)
├── corTest                                                    ← test runner (github.com/SEAMWARE)
└── coraine                                                  ← the broker (links the above)
```

Build order respects dependencies: k-libs first (foundation, no Cor-Lib deps),
then Cor-Libs (`corHttp corRest corJsonld corPlugin corNgsild`) - corHttp first,
because corRest links it on a `COR_HTTP_SERVER=builtin` build.

## Libraries

Each library has its own README (linked below — the repo landing page renders it).

**k-libs** (gitlab.com/kzangeli) — foundation, no Cor-Lib dependencies:

- [kbase](https://gitlab.com/kzangeli/kbase) — core utilities and base types
- [kalloc](https://gitlab.com/kzangeli/kalloc) — arena allocator (`KAlloc`)
- [khash](https://gitlab.com/kzangeli/khash) — hash tables
- [kjson](https://gitlab.com/kzangeli/kjson) — JSON parser + tree (`KjNode`)
- [kargs](https://gitlab.com/kzangeli/kargs) — CLI argument parsing
- [ktrace](https://gitlab.com/kzangeli/ktrace) — trace-level logging
- [kprom](https://gitlab.com/kzangeli/kprom) — Prometheus metrics

**Cor-Libs** (github.com/SEAMWARE) — depend on the k-libs and each other:

- [corHttp](https://github.com/SEAMWARE/corHttp) — HTTP server (the builtin backend: `SO_REUSEPORT` event loops)
- [corRest](https://github.com/SEAMWARE/corRest) — REST server (libmicrohttpd or corHttp) + HTTP client
- [corJsonld](https://github.com/SEAMWARE/corJsonld) — JSON-LD context expansion / compaction
- [corPlugin](https://github.com/SEAMWARE/corPlugin) — generic plugin loader (`dlopen` wrapper)
- [corNgsild](https://github.com/SEAMWARE/corNgsild) — NGSI-LD validation + format conversion

**Tooling** (github.com/SEAMWARE):

- [corTest](https://github.com/SEAMWARE/corTest) — generic functional-test harness (input → stdout, with `REGEX()` / `#SORT` smart diff); `install` collects its runner into `bin/`

## Prerequisites

- The sibling repos listed above, cloned under the same parent dir (`~/git`).
- A C toolchain + `make`. Individual libs may pull system packages (OpenSSL,
  libmicrohttpd, mosquitto, GEOS, the mongo-c v2 driver, …) — see coraine.

The pinned versions known to build together live in [`klib-pins`](klib-pins),
and **only** there - `bootstrap.sh`, this repo's umbrella makefile and the
broker's `docker/Dockerfile` all read that one file.

This README used to restate them as a table. It drifted, in five entries at
once: it still named `klog`, which has left the stack entirely, and it claimed
kjson `release/0.11.1` when the pin had reached `release/0.14.0`. That is the
precise failure `klib-pins` exists to prevent, so there is no table here any
more.

The Cor-Libs - corHttp, corRest, corJsonld, corPlugin, corNgsild, corTest -
track `main` by design.

## Quick start

If you don't have the sibling repos yet, the easiest path is
[`bootstrap.sh`](bootstrap.sh) **in this repo**: it clones every dependency at
the refs `klib-pins` names, as siblings of corLibs, then runs the umbrella build.

```sh
git clone https://github.com/SEAMWARE/corLibs.git && cd corLibs
./bootstrap.sh                  # PROTO=ssh for SSH URLs, NOBUILD=1 to clone only
```

(It used to be a loose `bootstrap-corlibs.sh` in the parent directory, outside
version control — which is why CI could not run it and it drifted. It lives next
to the makefile it drives now.)

Otherwise, with the siblings already cloned:

```sh
cd ~/git/corLibs
make di          # debug build + install of every lib, collected into lib/ bin/
```

Then build the broker:

```sh
cd ~/git/coraine && make di
```

## Targets

| target        | what it does                                            |
|---------------|---------------------------------------------------------|
| `make` / `all`| release build of every library                          |
| `make debug`  | debug build of every library                            |
| `make install`| build + collect `lib*.{a,so}` and corTest tooling into `lib/`, `bin/` |
| `make di`     | debug + install (the usual dev cycle)                   |
| `make i`      | release + install                                       |
| `make ci`     | clean + install                                         |
| `make cdi`    | clean + debug + install                                 |
| `make clean`  | clean every library                                     |
| `make branch` | print the current git branch of each library            |
| `make gs`     | `git status -s` across every library                    |
| `make pull`   | `git pull` in every library                             |
| `make help`   | list targets                                            |

`./iter.sh '<cmd>'` runs an arbitrary command in each library directory, e.g.
`./iter.sh 'git log --oneline -1'`.

## Notes

- `install` collects into this repo's `bin/` and `lib/` (both git-ignored). It
  also copies `corTest`, `corDiff`, `corDiffGui` and `corTestFunctions.sh` from
  `../corTest`, which coraine's test target (`~/git/corLibs/bin/corTest`) relies
  on.
- The umbrella does not pin versions itself — it builds whatever each sibling
  repo is currently checked out at. Use `make branch` to confirm, or the
  bootstrap script to get the pinned set.
