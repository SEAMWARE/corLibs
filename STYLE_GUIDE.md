# Coding style — the Cor stack

Governs the **k-libs** (`kbase`, `kalloc`, `khash`, `kjson`, `kargs`, `ktrace`,
`kprom`), the **Cor-Libs** (`corRest`, `corJsonld`, `corNgsild`, `corPlugin`,
`corTest`) and **coraine**. One guide for all of them; where a rule below and
existing code disagree, the rule wins and the code is wrong.

Every rule here is here because something went wrong without it. Where that is
worth knowing, it is written down — a rule whose reason is lost is a rule that
gets argued with.

---

## 1. Includes

### Every file includes what it uses

**A file includes everything it uses, and does not rely on another header having
included it.** If a `.c` calls `memset`, it includes `<string.h>` itself, even if
the header above it already does.

This is not tidiness. Retiring `klog` removed one `#include` from
`kjson/KjTraceLevels.h`, and three files that had never mentioned klog stopped
compiling: `kjBufferCreate.c` lost `NULL`, `malloc`, `calloc` and `memset`,
`kjParse.c` lost `snprintf`, `kalloc/kaAlloc.c` lost `calloc`. None of them was
wrong about klog. They were wrong about `<stdlib.h>`.

The cost is paid at exactly the wrong moment: the file that breaks is not the file
that changed, the error is a `-Werror` implicit-declaration a long way from the
edit, and it makes an unrelated removal look dangerous when it was not.

### Order

Groups separated by one blank line, no blank lines inside a group:

1. C system headers
2. third-party headers
3. project headers, low-level to high-level (`kbase` → `kalloc` → `kjson` →
   `khash` → `corRest` → `corJsonld` → `corNgsild`)
4. **own interface last**, in a `.c`, commented `// Own interface`

### Every include says what it is for

A trailing comment naming what the file takes from it:

```c
#include <string.h>                                       // strcmp

#include "kjson/KjNode.h"                                 // KjNode
#include "kjson/kjBuilder.h"                              // kjChildRemove

#include "corNgsild/ldStripAtContext.h"                    // Own interface
```

That comment is what makes the self-sufficiency rule checkable: an include whose
comment names nothing the file uses is an include the file does not need.

---

## 2. Files

Every file opens with the header block. In a `.h` the include guard comes first,
in a `.c` the block is the very first thing:

```c
//
// FILE            ldStripAtContext.c
//
// AUTHOR          Ken Zangelin
//
// Copyright 2026 Seamware
// SPDX-License-Identifier: Apache-2.0
//
```

Include guards are `<LIB>_<FILE>_H_`, upper snake, and the `#endif` carries the
same name as a comment.

One SPDX line per file — not the eleven-line Apache boilerplate. The header is
machine-readable licensing, not a legal recital.

---

## 3. Layout

- **2 spaces** per indent level, never tabs.
- Braces on their **own line**, at the indent of the statement they belong to.
- A single statement under an `if` needs no braces.
- **Lines up to 150 characters.** Long is not a problem; wrapping a readable
  expression across three lines to satisfy 80 is.
- A banner comment before every function:

```c
// -----------------------------------------------------------------------------
//
// ldStripAtContext - recursively remove every "@context" child from a tree
//
```

In the header, that banner carries the *contract* — what it does, what it assumes,
what it mutates. In the `.c` a bare name is enough; do not maintain the same prose
twice.

---

## 4. Naming

| Thing | Form | Example |
|---|---|---|
| function | `<libPrefix><Verb>` camelCase | `ldStripAtContext`, `kjChildRemove` |
| type | PascalCase, library-prefixed | `KjNode`, `LdRegCacheItem` |
| pointer variable | name ends in `P` | `treeP`, `childP`, `itemP` |
| "next" in a walk | `nextP` | |
| enum member | prefix shared with the enum | `KjObject`, `KatInit` |
| macro | upper snake | `KT_W`, `K_VEC_SIZE` |

An allocation parameter is named for what it allocates *into*, not for the fact
that it allocates.

---

## 5. Memory

- Request-scoped memory comes from a **kalloc arena**, not `malloc`. It is freed by
  resetting the arena, so nothing in the request path frees individually.
- `kaBufferReset(kaP, KFALSE)` is **teardown, not reuse** — it frees the blocks and
  leaves the list pointing at them. A reset inside a loop must pass `KTRUE`, or the
  second pass double-frees.
- Free explicitly and only when non-NULL; do not lean on `free(NULL)` being legal to
  paper over an unclear ownership story.
- Anything long-lived is allocated at init time, not lazily on a request thread.

---

## 6. Trees (kjson)

- **`kjChildAdd` re-points the added node's `->next`.** There is no `kjChildMove`.
  Adding a node that still belongs to another container does not move it — it
  splices the two lists together and silently drops whatever sat between.
- So: **clone it, or unlink it first.** `kjChildRemove` then `kjChildAdd` is a
  *move* and is correct when a move is what you want. When the source tree is the
  caller's and must survive, clone.
- A function handed a tree **reads** it unless its contract says otherwise. If it
  mutates, the banner comment says so in the first line.

---

## 7. Concurrency

- **One thread per connection.** That invariant is what makes per-request state
  simple; do not introduce a work queue that breaks it without saying so.
- **Per-request state lives in the per-connection struct** (`CorNgsild`), never in a
  stray `thread_local`. A thread-local is invisible at the call site and outlives
  the request.
- A newly created pthread **initialises its own thread-locals**. Inheriting them is
  not a thing.
- Globals are written at init time and read afterwards. A global written on a
  request thread is a race waiting for load.

---

## 8. Judgement

- **Never express a new concept through an existing mechanism.** Two concepts
  sharing a code path, a counter and a status word stay tangled, and renaming does
  not fix it. Give the new thing its own.
- **No wrapper functions** that add nothing but a name.
- Do not `strcmp` in a hot path when a length check or a first-character test
  settles it, and never take `strlen` of a literal.
- Group related flags as a **bitmask enum** rather than a row of booleans.
- Correctness before speed. A measurement decides a performance question; taste
  does not.

---

## 9. Tests

A behaviour change carries a test that **fails before the fix and passes after**.
Verify that by reverting the fix and watching it go red — a test written after the
fix and never seen to fail is asserting nothing.

### Never assert the rendering of a builtin timestamp

`createdAt`, `modifiedAt`, `deletedAt` and friends are generated by the broker, and
their *rendering* is not a promise.

`ldSysTimestampToIso` trims trailing zeros from the fraction, so the number of
decimals varies **with the value**: the same code rendered `.6994Z` in CI and
`.532982Z` on a workstation, and a whole second renders as `…:57Z` with no fraction
at all. It also varies **with a runtime flag** — § 5.2.2.4 caps DateTime at six
digits by default, and `-hp` keeps all nine. So the count is anywhere from 0 to 9,
and it is not a property of the DB plugin: the renderer is in `corNgsild`, shared by
all of them. The representation is not guaranteed to be a string either.

So a test may assert that such a field is **there and plausible**, never how many
digits it has. A digit-count assertion is a coin flip that fails about once in a
thousand runs, and when it does it looks exactly like a real bug.

But `REGEX(.*)` is barely an assertion either: it accepts an empty string, a missing
`Z`, a number, anything. Pin the parts that ARE stable and leave free only the part
that is not:

```
"createdAt": "REGEX(20[23]\d-.*Z)"
```

That accepts `2026-08-25T13:35:57.951209Z`, `…57.6994Z` and `…57Z`, and rejects an
empty value, a malformed one, and a wildly wrong year from an uninitialised field.

⏳ It stops accepting timestamps in 2040. That is deliberate — the alternative,
`20\d\d-`, buys sixty more years and gives up the wrong-year check — but it is a
date on which the suite goes red, so it is written down here rather than left to be
discovered.

The same reasoning applies in reverse to a **user-supplied** timestamp such as
`observedAt`: the client chose it, the broker must return it, so the expect carries
it **literally**. A REGEX there hides exactly the bug worth catching.
