# corLibs

Umbrella build for the **Cor-Libs** that the coraine (NGSI-LD
context broker) links against. **This repo contains no library.** What it holds is
everything one needs to know to assemble the stack:

- **which repositories make it up**, and in which order they build — `bootstrap.sh`
  and the makefile, which collect the archives, shared objects and test tooling
  into `lib/` and `bin/`
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
├── corBase  corLog  corAlloc  corArgs  corHash  corTree  corJson  corProm  ← Cor-Libs  (github.com/SEAMWARE)
├── corHttp  corRest  corJsonld  corPlugin  corNgsild
├── corTools                                                   ← corRequest, corTestClient (github.com/SEAMWARE)
├── corTest                                                    ← test runner (github.com/SEAMWARE)
└── coraine                                                  ← the broker (links the above)
```

Build order respects dependencies (`corBase corLog corAlloc corArgs corHash corTree corJson corProm corHttp corRest corJsonld corPlugin corNgsild corTools`) -
corBase first, since it needs nothing; then the log, allocator, command-line, hash, tree, JSON and metrics libraries; then
corHttp, because corRest links it on a `COR_HTTP_SERVER=builtin` build; corTools last, since its tools link the whole stack.

## Libraries

Each library has its own README (linked below — the repo landing page renders it).

**Cor-Libs** (github.com/SEAMWARE):

- [corBase](https://github.com/SEAMWARE/corBase) — core utilities and the library log (was the k-lib `kbase`)
- [corLog](https://github.com/SEAMWARE/corLog) — logging and trace levels (was the k-lib `ktrace`)
- [corAlloc](https://github.com/SEAMWARE/corAlloc) — arena allocator (`CorAlloc`) (was the k-lib `kalloc`)
- [corArgs](https://github.com/SEAMWARE/corArgs) — CLI argument parsing (was the k-lib `kargs`)
- [corHash](https://github.com/SEAMWARE/corHash) — hash tables (was the k-lib `khash`)
- [corTree](https://github.com/SEAMWARE/corTree) — the tree (`CorNode`): build, edit, look up, clone, sort
- [corJson](https://github.com/SEAMWARE/corJson) — JSON parser and renderers over a corTree, and the `corJson` tool
- [corProm](https://github.com/SEAMWARE/corProm) — Prometheus metrics
- [corHttp](https://github.com/SEAMWARE/corHttp) — HTTP server (the builtin backend: `SO_REUSEPORT` event loops)
- [corRest](https://github.com/SEAMWARE/corRest) — REST server (libmicrohttpd or corHttp) + HTTP client
- [corJsonld](https://github.com/SEAMWARE/corJsonld) — JSON-LD context expansion / compaction
- [corPlugin](https://github.com/SEAMWARE/corPlugin) — generic plugin loader (`dlopen` wrapper)
- [corNgsild](https://github.com/SEAMWARE/corNgsild) — NGSI-LD validation + format conversion

**Tooling** (github.com/SEAMWARE):

- [corTest](https://github.com/SEAMWARE/corTest) — generic functional-test harness (input → stdout, with `REGEX()` / `#SORT` smart diff); `install` collects its runner into `bin/`
- [corTools](https://github.com/SEAMWARE/corTools) — `corRequest` (a cor:// client: one request like `curl -i`, or load like `wrk`) and `corTestClient` (notification receiver, mock context source, bridge-plugin host); `install` collects both into `bin/`

## Prerequisites

- The sibling repos listed above, cloned under the same parent dir (`~/git`).
- A C toolchain + `make`. Individual libs may pull system packages (OpenSSL,
  libmicrohttpd, mosquitto, GEOS, the mongo-c v2 driver, …) — see coraine.

Every library tracks `main` by design: they move together, and a pin between
them would only ever be stale. (The k-libs they grew out of were pinned to
release branches in a `klib-pins` file; with corBase the last of them left the
stack, and the file with them.)

## Quick start

If you don't have the sibling repos yet, the easiest path is
[`bootstrap.sh`](bootstrap.sh) **in this repo**: it clones every dependency
as a sibling of corLibs, then runs the umbrella build.

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
  `../corTest`, and `corRequest` and `corTestClient` from `../corTools`, which
  coraine's test target (`~/git/corLibs/bin/corTest`) relies on.
- The umbrella does not pin versions itself — it builds whatever each sibling
  repo is currently checked out at. Use `make branch` to confirm, or the
  bootstrap script to get the pinned set.
