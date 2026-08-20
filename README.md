# corLibs

Umbrella build for the **k-libs** and **Cor-Libs** that the coraine (NGSI-LD
context broker) links against. This repo is not a library itself — it is a
thin orchestration layer: a makefile that builds each sibling library in
dependency order and collects the resulting archives, shared objects and test
tooling into `lib/` and `bin/`.

All libraries live as **separate sibling repos under `~/git`**. corLibs drives
them; it does not vendor them.

- **License:** [Apache License 2.0](LICENSE) — Copyright 2026 Seamware

## Layout

```
~/git/
├── corLibs/        ← this repo (umbrella: makefile + iter.sh, collects into bin/ lib/)
├── kbase  kalloc  klog  khash  kjson  kargs  ktrace  kprom   ← k-libs   (gitlab.com/kzangeli)
├── corRest  corJsonld  corPlugin  corNgsild                      ← Cor-Libs  (github.com/SEAMWARE)
├── corTest                                                    ← test runner (github.com/SEAMWARE)
└── coraine                                                  ← the broker (links the above)
```

Build order respects dependencies: k-libs first (foundation, no Cor-Lib deps),
then Cor-Libs (`corRest corJsonld corPlugin corNgsild`).

## Libraries

Each library has its own README (linked below — the repo landing page renders it).

**k-libs** (gitlab.com/kzangeli) — foundation, no Cor-Lib dependencies:

- [kbase](https://gitlab.com/kzangeli/kbase) — core utilities and base types
- [kalloc](https://gitlab.com/kzangeli/kalloc) — arena allocator (`KAlloc`)
- [klog](https://gitlab.com/kzangeli/klog) — logging
- [khash](https://gitlab.com/kzangeli/khash) — hash tables
- [kjson](https://gitlab.com/kzangeli/kjson) — JSON parser + tree (`KjNode`)
- [kargs](https://gitlab.com/kzangeli/kargs) — CLI argument parsing
- [ktrace](https://gitlab.com/kzangeli/ktrace) — trace-level logging
- [kprom](https://gitlab.com/kzangeli/kprom) — Prometheus metrics

**Cor-Libs** (github.com/SEAMWARE) — depend on the k-libs and each other:

- [corRest](https://github.com/SEAMWARE/corRest) — REST server (libmicrohttpd) + HTTP client
- [corJsonld](https://github.com/SEAMWARE/corJsonld) — JSON-LD context expansion / compaction
- [corPlugin](https://github.com/SEAMWARE/corPlugin) — generic plugin loader (`dlopen` wrapper)
- [corNgsild](https://github.com/SEAMWARE/corNgsild) — NGSI-LD validation + format conversion

**Tooling** (github.com/SEAMWARE):

- [corTest](https://github.com/SEAMWARE/corTest) — generic functional-test harness (input → stdout, with `REGEX()` / `#SORT` smart diff); `install` collects its runner into `bin/`

## Prerequisites

- The sibling repos listed above, cloned under the same parent dir (`~/git`).
- A C toolchain + `make`. Individual libs may pull system packages (OpenSSL,
  libmicrohttpd, mosquitto, GEOS, the mongo-c v2 driver, …) — see coraine.

The pinned versions known to build together:

| repo   | branch          | | repo     | branch   |
|--------|-----------------|-|----------|----------|
| kbase  | `release/0.10`  | | kjson    | `release/0.11.1` |
| kalloc | `release/0.10.1`| | kargs    | `release/0.10`   |
| klog   | `release/0.10`  | | ktrace   | `release/0.10`   |
| khash  | `release/0.10`  | | kprom    | `release/0.1.0`  |
| corRest / corJsonld / corPlugin / corNgsild / corTest | `main` | | | |

## Quick start

If you don't have the sibling repos yet, the easiest path is the bootstrap
script (`bootstrap-corlibs.sh`, kept next to the repos under `~/git`): it clones
every dependency at the pinned versions and runs the umbrella build for you.

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
