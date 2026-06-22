# swLibs

Umbrella build for the **k-libs** and **sw-libs** that the swBroker (NGSI-LD
context broker) links against. This repo is not a library itself — it is a
thin orchestration layer: a makefile that builds each sibling library in
dependency order and collects the resulting archives, shared objects and test
tooling into `lib/` and `bin/`.

All libraries live as **separate sibling repos under `~/git`**. swLibs drives
them; it does not vendor them.

## Layout

```
~/git/
├── swLibs/        ← this repo (umbrella: makefile + iter.sh, collects into bin/ lib/)
├── kbase  kalloc  klog  khash  kjson  kargs  ktrace  kprom   ← k-libs   (gitlab.com/kzangeli)
├── swRest  swJsonld  swPlugin  swNgsild                      ← sw-libs  (github.com/kzangeli)
├── swTest                                                    ← test runner (github.com/kzangeli)
└── swBroker                                                  ← the broker (links the above)
```

Build order respects dependencies: k-libs first (foundation, no sw-lib deps),
then sw-libs (`swRest swJsonld swPlugin swNgsild`).

## Prerequisites

- The sibling repos listed above, cloned under the same parent dir (`~/git`).
- A C toolchain + `make`. Individual libs may pull system packages (OpenSSL,
  libmicrohttpd, mosquitto, GEOS, the mongo-c v2 driver, …) — see swBroker.

The pinned versions known to build together:

| repo   | branch          | | repo     | branch   |
|--------|-----------------|-|----------|----------|
| kbase  | `release/0.10`  | | kjson    | `release/0.11.1` |
| kalloc | `release/0.10.1`| | kargs    | `release/0.10`   |
| klog   | `release/0.10`  | | ktrace   | `release/0.10`   |
| khash  | `release/0.10`  | | kprom    | `release/0.1.0`  |
| swRest / swJsonld / swPlugin / swNgsild / swTest | `master` | | | |

## Quick start

If you don't have the sibling repos yet, the easiest path is the bootstrap
script (`bootstrap-swlibs.sh`, kept next to the repos under `~/git`): it clones
every dependency at the pinned versions and runs the umbrella build for you.

Otherwise, with the siblings already cloned:

```sh
cd ~/git/swLibs
make di          # debug build + install of every lib, collected into lib/ bin/
```

Then build the broker:

```sh
cd ~/git/swBroker && make di
```

## Targets

| target        | what it does                                            |
|---------------|---------------------------------------------------------|
| `make` / `all`| release build of every library                          |
| `make debug`  | debug build of every library                            |
| `make install`| build + collect `lib*.{a,so}` and swTest tooling into `lib/`, `bin/` |
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
  also copies `swTest`, `swDiff`, `swDiffGui` and `swTestFunctions.sh` from
  `../swTest`, which swBroker's test target (`~/git/swLibs/bin/swTest`) relies
  on.
- The umbrella does not pin versions itself — it builds whatever each sibling
  repo is currently checked out at. Use `make branch` to confirm, or the
  bootstrap script to get the pinned set.
