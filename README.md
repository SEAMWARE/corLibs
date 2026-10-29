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
├── corHttp  corBridge  corRest  corJsonld  corPlugin  corNgsild
├── corDB                                                      ← the in-process database (plugins)
├── corTools                                                   ← corRequest, corTestClient, corMongoDrop (github.com/SEAMWARE)
├── corDdsBridge  corModbusBridge  corMqttBridge               ← bridge plugins built by the umbrella
├── corCkanBridge  corOpcuaBridge                              ← bridge plugins cloned, not built by the umbrella
├── corTest                                                    ← test runner (github.com/SEAMWARE)
└── coraine                                                  ← the broker (links the above)
```

Build order respects dependencies (`COR_DIRS` in the makefile: `corBase corLog corAlloc corArgs corHash corTree corJson corProm corHttp corBridge corRest corJsonld corPlugin corNgsild corDB corTools corDdsBridge corModbusBridge corMqttBridge`) -
corBase first, since it needs nothing; then the log, allocator, command-line, hash, tree, JSON and metrics libraries; then
corHttp, because corRest links it on a `COR_HTTP_SERVER=builtin` build; corDB after corNgsild (it is skipped, with the reason,
where no coraine checkout sits beside it); corTools after the libraries, since its tools link the whole stack; the bridge
plugins last - corDdsBridge is skipped, with the reason, where the DDS Enabler is not installed. corCkanBridge and
corOpcuaBridge are cloned by `bootstrap.sh` but not built here: coraine's `coraine-build` builds them when asked (`--bridges ckan`, `--bridges opcua`).

## Libraries

Each library has its own README (linked below — the repo landing page renders it).

**Cor-Libs** (github.com/SEAMWARE):

- [corBase](https://github.com/SEAMWARE/corBase) — core utilities, coroutines and the library log
- [corLog](https://github.com/SEAMWARE/corLog) — logging and trace levels
- [corAlloc](https://github.com/SEAMWARE/corAlloc) — arena allocator (`CorAlloc`)
- [corArgs](https://github.com/SEAMWARE/corArgs) — CLI argument parsing
- [corHash](https://github.com/SEAMWARE/corHash) — hash tables
- [corTree](https://github.com/SEAMWARE/corTree) — the tree (`CorNode`): build, edit, look up, clone, sort
- [corJson](https://github.com/SEAMWARE/corJson) — JSON parser and renderers over a corTree, and the `corJson` tool
- [corProm](https://github.com/SEAMWARE/corProm) — Prometheus metrics
- [corHttp](https://github.com/SEAMWARE/corHttp) — HTTP server (the builtin backend: `SO_REUSEPORT` event loops)
- [corBridge](https://github.com/SEAMWARE/corBridge) — the contract a bridge plugin satisfies
- [corRest](https://github.com/SEAMWARE/corRest) — REST server (libmicrohttpd or corHttp) + HTTP client
- [corJsonld](https://github.com/SEAMWARE/corJsonld) — JSON-LD context expansion / compaction
- [corPlugin](https://github.com/SEAMWARE/corPlugin) — generic plugin loader (`dlopen` wrapper)
- [corNgsild](https://github.com/SEAMWARE/corNgsild) — NGSI-LD validation + format conversion

**Plugins** (github.com/SEAMWARE):

- [corDB](https://github.com/SEAMWARE/corDB) — the in-process database: current state and TRoE (`corDB.so`, `troe/corDB.so`)
- [corDdsBridge](https://github.com/SEAMWARE/corDdsBridge) — DDS (and ROS 2) bridge, `dds.so`
- [corModbusBridge](https://github.com/SEAMWARE/corModbusBridge) — Modbus bridge, `modbus.so`
- [corMqttBridge](https://github.com/SEAMWARE/corMqttBridge) — MQTT bridge, `mqtt.so`
- [corCkanBridge](https://github.com/SEAMWARE/corCkanBridge) — CKAN open-data bridge (not built by the umbrella)
- [corOpcuaBridge](https://github.com/SEAMWARE/corOpcuaBridge) — OPC UA bridge, open62541 (not built by the umbrella)

**Tooling** (github.com/SEAMWARE):

- [corTest](https://github.com/SEAMWARE/corTest) — generic functional-test harness (input → stdout, with `REGEX()` / `#SORT` smart diff); `install` collects its runner into `bin/`
- [corTools](https://github.com/SEAMWARE/corTools) — `corRequest` (a cor:// client: one request like `curl -i`, or load like `wrk`), `corTestClient` (notification receiver, mock context source, bridge-plugin host) and `corMongoDrop` (drops MongoDB databases fast, where libmongoc is); `install` collects them into `bin/`

## Prerequisites

- The sibling repos listed above, cloned under the same parent dir (`~/git`).
- A C toolchain + `make`. Individual libs may pull system packages (OpenSSL,
  libmicrohttpd, mosquitto, GEOS, the mongo-c v2 driver, …) — see coraine.

Every library tracks `main` by design: they move together, and a pin between
them would only ever be stale. `bootstrap.sh` clones each one at `main`.

One exception: a release. coraine's pre-release campaign records the commit of every repository it
tested (`RESOLVE=1 ./bootstrap.sh` prints them, `<repo> <sha>` per line, corLibs first), and the
release is built from that record (`COR_LIBS_PIN="<those lines>" ./bootstrap.sh`: every repository,
corLibs too, at its recorded commit; one the record does not name is an error).

## Quick start

If you don't have the sibling repos yet, the easiest path is
[`bootstrap.sh`](bootstrap.sh) **in this repo**: it clones every dependency
as a sibling of corLibs, then runs the umbrella build.

```sh
git clone https://github.com/SEAMWARE/corLibs.git && cd corLibs
./bootstrap.sh                  # PROTO=ssh for SSH URLs, NOBUILD=1 to clone only
```

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
  also copies `corTest`, `corDiff`, `corDiffGui`, `corRegenExpect` and `corTestFunctions.sh` from
  `../corTest`, `corJson` from `../corJson`, and `corRequest`, `corTestClient` and `corMongoDrop` (where
  built) from `../corTools`, which
  coraine's test target (`~/git/corLibs/bin/corTest`) relies on.
- The umbrella does not pin versions — it builds whatever each sibling repo is
  currently checked out at. `make branch` shows which branch that is.
