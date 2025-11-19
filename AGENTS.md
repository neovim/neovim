# AGENTS

Guidance for coding agents that contribute to the Neovim core repository. Read
this before attempting automated edits or large-scale refactors.

## Fast facts

- **Mission**: modern fork of Vim focused on extensibility, async APIs, and UI
  flexibility (`README.md`).
- **Languages**: C/C99 core (`src/nvim/**`), Lua in `runtime/lua` and tests,
  legacy Vimscript inside `runtime/`.
- **Build system**: CMake wrapped by the project `Makefile`. Ninja is used
  automatically when available.
- **Key docs**: `BUILD.md`, `CONTRIBUTING.md`, `MAINTAIN.md`, and
  `runtime/doc/dev_*.txt` (open them in `:help`, e.g. `:help dev-quickstart`).

## Repository layout quick reference

- `src/nvim/`: editor core broken into API, eval, event loop, RPC, TUI, etc.
- `runtime/`: shipped runtime files, docs, syntax, Lua helpers.
- `cmake*/`: CMake toolchain configuration and dependency builders.
- `test/`: Lua (busted) tests split into `functional`, `unit`, `old`.
- `scripts/`: release automation, tooling helpers.
- `build/`, `.deps/`: generated artifacts (should not be committed).

Use `rg` to explore code quickly (`rg --files`, `rg PATTERN path`).

## Environment & dependencies

1. Install the prerequisites from `BUILD.md` for your platform (e.g. `ninja`,
   `cmake`, `gcc/clang`, `gettext`). On Windows prefer MSVC.
2. `make deps` downloads third-party libraries into `.deps/`. Pass
   `USE_BUNDLED=0` to rely on system packages when needed.
3. Change build parameters (like `CMAKE_BUILD_TYPE`) only after `make distclean`
   or deleting `build/` to avoid stale caches.

## Build workflow

```sh
make CMAKE_BUILD_TYPE=RelWithDebInfo   # default developer build
make CMAKE_BUILD_TYPE=Debug            # slower but easier debugging
make CMAKE_INSTALL_PREFIX=$HOME/nvim install
./build/bin/nvim --version | grep ^Build
cmake --build build --target help      # list targets (after an initial make)
```

- Set `CCACHE_DISABLE=true` to bypass ccache/sccache; install `ninja` for faster
  builds.
- Use `VIMRUNTIME=runtime ./build/bin/nvim` to run from the tree without
  installing.

## Testing

Core targets (see `runtime/doc/dev_test.txt`):

- `make test` – runs unit + functional suites (skips legacy Vim tests).
- `make unittest` – LuaJIT FFI-based C unit tests.
- `make functionaltest` – busted-driven functional specs (supports RPC + UI).
- `make oldtest` – legacy Vimscript regression tests.

Useful knobs:

```sh
TEST_FILE=test/functional/api/buffer_spec.lua make functionaltest
TEST_FILTER='pattern$' make functionaltest
TEST_TAG=mytag make functionaltest
BUSTED_ARGS="--repeat=100" make functionaltest
GDB=1 TEST_FILE=... make functionaltest   # run failing test under gdbserver
VALGRIND=1 make test                      # instrumented run
```

Logs land in `${NVIM_LOG_FILE}` (set automatically during tests). Hang suspects
can attach `Screen` snapshots from `test/functional/ui/screen.lua`.

## Lint, format, and style

- `make lint` – runs clang-tidy, luacheck, etc. (fast fail if formatting breaks).
- `make format`, `make formatc`, `make formatlua` – conform to
  `src/uncrustify.cfg` and `.clang-format`.
- `make lintcommit` – enforces conventional commit metadata.
- Commit messages follow `type(scope): subject` with `Problem:` / `Solution:`
  bodies (see `CONTRIBUTING.md`).
- Prefer small, isolated diffs. Cosmetic changes must stay in their own commit.

## Runtime files & upstream coordination

- Vimscript runtime files in `runtime/` are usually mirrored from Vim. Send
  Vimscript-only fixes upstream first (`CONTRIBUTING.md` explains the process).
- Lua runtime files are Neovim-owned; keep behavior aligned with Vim unless the
  feature is explicitly Neovim-specific.
- Provide ROADMAP notes or doc updates when changing UI, RPC, or API behavior.

## Agent workflow tips

1. **Start with docs**: open `:help dev-quickstart`, `:help dev-test`, or read
   the Markdown files listed above.
2. **Prefer incremental builds/tests**: touch only impacted targets and run the
   narrowest test command that proves your change.
3. **Respect generated content**: avoid editing files under `build/`,
   `.deps/`, or auto-generated headers.
4. **Keep context**: cross-reference nearby C/Lua functions before modifying
   them; review `git blame` for regressions or active owners.
5. **Document behavior changes**: update `runtime/doc/*.txt` and mention test
   coverage for regressions or new APIs.
6. **Verification checklist**: format code, run relevant tests, mention build or
   test commands in your summary, and highlight any skipped validation.

## Handy references

- Development guides: `runtime/doc/dev.txt`, `dev_arch.txt`, `dev_tools.txt`,
  `dev_test.txt`.
- Testing quickstart: `:help dev-quickstart`.
- Maintainer policies: `MAINTAIN.md`.
- User docs: `https://neovim.io/doc/`.

Keep this file updated whenever workflows or tooling change so the next agent
has an accurate starting point.
