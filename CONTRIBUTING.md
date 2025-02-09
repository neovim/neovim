Contributing to Neovim
======================

Getting started
---------------

If you want to help but don't know where to start, here are some
low-risk/isolated tasks:

- Try a [complexity:low] issue.
- Fix bugs found by [Coverity](#coverity).
- [Merge a Vim patch] (requires strong familiarity with Vim)
  - NOTE: read the above link before sending improvements to "runtime files" (anything in `runtime/`).
    - Vimscript and documentation files are (mostly) maintained by [Vim], not Nvim.
    - Nvim's [filetype detection](https://github.com/neovim/neovim/blob/master/runtime/lua/vim/filetype.lua) behavior matches Vim, so changes to filetype detection should be submitted to [Vim] first.
    - Lua files are maintained by Nvim.

Reporting problems
------------------

- [Check the FAQ][wiki-faq].
- [Search existing issues][github-issues] (including closed!)
- Update Neovim to the latest version to see if your problem persists.
- Try to reproduce with `nvim --clean` ("factory defaults").
- If a specific configuration or plugin is necessary to recreate the problem, use the minimal template in `contrib/minimal.lua` with `nvim --clean -u contrib/minimal.lua` after making the necessary changes.
- [Bisect](https://neovim.io/doc/user/starting.html#bisect) your config: disable plugins incrementally, to narrow down the cause of the issue.
- [Bisect][git-bisect] Neovim's source code to find the cause of a regression, if you can. This is _extremely_ helpful.
- When reporting a crash, [include a stacktrace](https://neovim.io/doc/user/dev_tools.html#dev-tools-backtrace).
- Use [ASAN/UBSAN](#sanitizers-asan-and-ubsan) to get detailed errors for segfaults and undefined behavior.
- Check the logs. `:edit $NVIM_LOG_FILE`
- Include `cmake --system-information` for build-related issues.

Developer guidelines
--------------------

- Read [:help dev](https://neovim.io/doc/user/develop.html#dev) and [:help dev-doc][dev-doc-guide] if you are working on Nvim core.
- Read [:help dev-ui](https://neovim.io/doc/user/develop.html#dev-ui) if you are developing a UI.
- Read [:help dev-api-client](https://neovim.io/doc/user/develop.html#dev-api-client) if you are developing an API client.
- Install `ninja` for faster builds of Nvim.
  ```bash
  sudo apt-get install ninja-build
  make distclean
  make  # Nvim build system uses ninja automatically, if available.
  ```
- Install `ccache` or `sccache` for faster rebuilds of Nvim. Nvim will use one
  of these automatically if it's found. To disable caching use:
  ```bash
  cmake -B build -D CACHE_PRG=OFF
  ```

Pull requests (PRs)
---------------------

- To avoid duplicate work, create a draft pull request.
- Your PR must include [test coverage][run-tests].
- Avoid cosmetic changes to unrelated files in the same commit.
- Use a [feature branch][git-feature-branch] instead of the master branch.
- Use a _rebase workflow_ for all PRs.
  - After addressing review comments, it's fine to force-push.

### Merging to master

For maintainers: when a PR is ready to merge to master,

- prefer _Squash Merge_ for "single-commit PRs" (when the PR has only one meaningful commit).
- prefer _Merge_ for "multi-commit PRs" (when the PR has multiple meaningful commits).

### Stages: Draft and Ready for review

Pull requests have two stages: Draft and Ready for review.

1. [Create a Draft PR][pr-draft] while you are _not_ requesting feedback as
  you are still working on the PR.
    - You can skip this if your PR is ready for review.
2. [Change your PR to ready][pr-ready] when the PR is ready for review.
    - You can convert back to Draft at any time.

Do __not__ add labels like `[RFC]` or `[WIP]` in the title to indicate the
state of your PR: this just adds noise. Non-Draft PRs are assumed to be open
for comments; if you want feedback from specific people, `@`-mention them in
a comment.

### Commit messages

Follow the [conventional commits guidelines][conventional_commits] to *make reviews easier* and to make
the VCS/git logs more valuable (try `make lintcommit`). The structure of a commit message is:

    type(scope): subject

    Problem:
    ...

    Solution:
    ...

- Commit message **subject** (you can **ignore this for "fixup" commits** or any commits you expect to be squashed):
    - Prefix with a [_type_](https://github.com/commitizen/conventional-commit-types/blob/master/index.json):
        - `build ci docs feat fix perf refactor revert test vim-patch`
    - Append an optional `(scope)` such as `(lsp)`, `(treesitter)`, `(float)`, …
    - Use the _imperative voice_: "Fix bug" rather than "Fixed bug" or "Fixes bug."
    - Keep it short (under 72 characters).
- Commit message **body** (detail):
    - Concisely describe the Problem/Solution in the commit **body**. [Describing the problem](https://lamport.azurewebsites.net/pubs/state-the-problem.pdf)
      _independently of the solution_ often leads to a better understanding for you, reviewers, and future readers.
      ```
      Problem:

      Solution:
      ```
- Indicate breaking API changes with "!" after the type, and a "BREAKING CHANGE" footer. Example:
  ```
  refactor(provider)!: drop support for Python 2

  BREAKING CHANGE: refactor to use Python 3 features since Python 2 is no longer supported.
  ```

### Automated builds (CI)

Each pull request must pass the automated builds on [Cirrus CI] and [GitHub Actions].

- CI builds are compiled with [`-Werror`][gcc-warnings], so compiler warnings
  will fail the build.
- If any tests fail, the build will fail. See [test/README.md#running-tests][run-tests] to run tests locally.
- CI runs [ASan] and other analyzers.
    - To run valgrind locally: `VALGRIND=1 make test`
    - To run ASan/UBSan locally: `CC=clang make CMAKE_FLAGS="-DENABLE_ASAN_UBSAN=ON"`.
      Note that MSVC requires Release or RelWithDebInfo build type to work properly.
- The [lint](#lint) build checks that the code is formatted correctly and
  passes various linter checks.
- CI for FreeBSD runs on [Cirrus CI].
- To see CI results faster in your PR, you can temporarily set `TEST_FILE` in
  [test.yml](https://github.com/neovim/neovim/blob/ad8e0cfc1dfd937c2577dc032e524c799a772693/.github/workflows/test.yml#L26).

### Coverity

Coverity runs against the master build. To view the defects you must
[request access](https://scan.coverity.com/projects/neovim-neovim) (Coverity
does not have a "public" view), then you will be approved as soon as
a maintainer sees the email.

- Use this format for commit messages (where `{id}` is the CID (Coverity ID);
  ([example](https://github.com/neovim/neovim/pull/804))):
  ```
  fix(coverity/{id}): {description}
  ```
- Search the Neovim commit history to find examples:
  ```bash
  git log --oneline --no-merges --grep coverity
  ```

### Sanitizers (ASAN and UBSAN)

  ASAN/UBSAN can be used to detect memory errors and other common forms of undefined behavior at runtime in debug builds.

- To build Neovim with sanitizers enabled, use
  ```
  rm -rf build && CMAKE_EXTRA_FLAGS="-DCMAKE_C_COMPILER=clang -DENABLE_ASAN_UBSAN=1" make
  ```
- When running Neovim, use
  ```
  ASAN_OPTIONS=log_path=/tmp/nvim_asan nvim args...
  ```
- If Neovim exits unexpectedly, check `/tmp/nvim_asan.{PID}` (or your preferred `log_path`) for log files with error messages.


Coding
------

### Lint

You can run the linter locally by:

```bash
make lint
```

### Style

- You can format files by using:
  ```bash
  make format  # or formatc, formatlua
  ```
  This will format changed Lua and C files with all appropriate flags set.
- Style rules are (mostly) defined by `src/uncrustify.cfg` which tries to match
  the [style-guide]. To use the Nvim `gq` command with `uncrustify`:
  ```vim
  if !empty(findfile('src/uncrustify.cfg', ';'))
    setlocal formatprg=uncrustify\ -q\ -l\ C\ -c\ src/uncrustify.cfg\ --no-backup
  endif
  ```
- There is also `.clang-format` which has drifted from the [style-guide], but
  is available for reference. To use the Nvim `gq` command with `clang-format`:
  ```vim
  if !empty(findfile('.clang-format', ';'))
    setlocal formatprg=clang-format\ -style=file
  endif
  ```

### Navigate

- Set `blame.ignoreRevsFile` to ignore [noisy commits](https://github.com/neovim/neovim/commit/2d240024acbd68c2d3f82bc72cb12b1a4928c6bf) in git blame:
  ```bash
  git config blame.ignoreRevsFile .git-blame-ignore-revs
  ```

- Recommendation is to use **[clangd]**.
  Can use the maintained config in [nvim-lspconfig/clangd].
- Explore the source code [on the web](https://sourcegraph.com/github.com/neovim/neovim).

### Includes

For managing includes in C files, use [include-what-you-use].

- [Install include-what-you-use][include-what-you-use-install]
- To see which includes needs fixing use the cmake preset `iwyu`:
  ```bash
  cmake --preset iwyu
  cmake --build build
  ```
- There's also a make target that automatically fixes the suggestions from
  IWYU:
  ```bash
  make iwyu
  ```

See [#549][549] for more details.

### Lua runtime files

Most of the Lua core [`runtime/`](./runtime) modules are precompiled to
bytecode, so changes to those files won't get used unless you rebuild Nvim or
by passing `--luamod-dev` and `$VIMRUNTIME`. For example, try adding a function
to `runtime/lua/vim/_editor.lua` then:

```bash
VIMRUNTIME=./runtime ./build/bin/nvim --luamod-dev
```

Documentation
-------------

Read [:help dev-doc][dev-doc-guide] to understand the expected documentation style and conventions.

### Generating :help

Many `:help` docs are autogenerated from (C or Lua) docstrings. To generate the documentation run:

```bash
make doc
```

To validate the documentation files, run:

```bash
make lintdoc
```

If you need to modify or debug the documentation flow, these are the main files:
- `./scripts/gen_vimdoc.lua`:
  Main doc generator. Parses C and Lua files to render vimdoc files.
- `./scripts/luacats_parser.lua`:
  Documentation parser for Lua files.
- `./scripts/cdoc_parser.lua`:
  Documentation parser for C files.
- `./scripts/luacats_grammar.lua`:
  Lpeg grammar for LuaCATS
- `./scripts/cdoc_grammar.lua`:
  Lpeg grammar for C doc comments
- `./scripts/gen_eval_files.lua`:
  Generates documentation and Lua type files from metadata files:
  ```
  runtime/lua/vim/*     =>  runtime/doc/lua.txt
  runtime/lua/vim/*     =>  runtime/doc/lua.txt
  runtime/lua/vim/lsp/  =>  runtime/doc/lsp.txt
  src/nvim/api/*        =>  runtime/doc/api.txt
  src/nvim/eval.lua     =>  runtime/doc/builtin.txt
  src/nvim/options.lua  =>  runtime/doc/options.txt
  ```

- `./scripts/lintdoc.lua`: Validation and linting of documentation files.

### Lua docstrings

Use [LuaLS] annotations in Lua docstrings to annotate parameter types, return
types, etc. See [:help dev-lua-doc][dev-lua-doc].

- The template for function documentation is:
  ```lua
  --- {Brief}
  ---
  --- {Long explanation}
  ---
  --- @param arg1 type {description}
  --- @param arg2 type {description}
  --- ...
  ---
  --- @return type {description}
  ```
- If possible, add type information (`table`, `string`, `number`, ...). Multiple valid types are separated by a bar (`string|table`). Indicate optional parameters via `type|nil`.
- If a function in your Lua module should _not_ be documented, add `@nodoc`.
- If the function is internal or otherwise non-public add `@private`.
      - Private functions usually should be underscore-prefixed (named "_foo", not "foo").
- Mark deprecated functions with `@deprecated`.

Third-party dependencies
------------------------

To build Nvim using a different commit of a dependency change the appropriate
URL in `cmake.deps/deps.txt`. For example, to use a different version of luajit
replace the value in `LUAJIT_URL` with the wanted commit hash:

```bash
LUAJIT_URL https://github.com/LuaJIT/LuaJIT/archive/<sha>.tar.gz
```

Set `DEPS_IGNORE_SHA` to `TRUE` in `cmake.deps/CMakeLists.txt` to skip hash
check from cmake.

Alternatively, you may point the URL as a local path where the repository is.
This is convenient when bisecting a problem in a dependency with `git bisect`.
This may require running `make distclean` between each build. Hash checking is
always skipped in this case regardless of `DEPS_IGNORE_SHA`.

```bash
LUAJIT_URL /home/user/luajit
```

Reviewing
---------

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [GitHub CLI][gh], you can create a new branch with the contents of a pull
request, e.g. [#1820][1820]:

```bash
gh pr checkout https://github.com/neovim/neovim/pull/1820
```

Use [`git log -p master..FETCH_HEAD`][git-history-filtering] to list all
commits in the feature branch which aren't in the `master` branch; `-p`
shows each commit's diff. To show the whole surrounding function of a change
as context, use the `-W` argument as well.

[549]: https://github.com/neovim/neovim/issues/549
[1820]: https://github.com/neovim/neovim/pull/1820
[3174]: https://github.com/neovim/neovim/issues/3174
[ASan]: http://clang.llvm.org/docs/AddressSanitizer.html
[Cirrus CI]: https://cirrus-ci.com/github/neovim/neovim
[Clang report]: https://neovim.io/doc/reports/clang/
[GitHub Actions]: https://github.com/neovim/neovim/actions
[Vim]: https://github.com/vim/vim
[clangd]: https://clangd.llvm.org
[Merge a Vim patch]: https://neovim.io/doc/user/dev_vimpatch.html
[complexity:low]: https://github.com/neovim/neovim/issues?q=is%3Aopen+is%3Aissue+label%3Acomplexity%3Alow
[conventional_commits]: https://www.conventionalcommits.org
[dev-doc-guide]: https://neovim.io/doc/user/develop.html#dev-doc
[dev-lua-doc]: https://neovim.io/doc/user/develop.html#dev-lua-doc
[LuaLS]: https://luals.github.io/wiki/annotations/
[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[gh]: https://cli.github.com/
[git-bisect]: http://git-scm.com/book/en/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[github-issues]: https://github.com/neovim/neovim/issues
[include-what-you-use-install]: https://github.com/include-what-you-use/include-what-you-use#how-to-install
[include-what-you-use]: https://github.com/include-what-you-use/include-what-you-use#using-with-cmake
[lua-language-server]: https://github.com/sumneko/lua-language-server/
[nvim-lspconfig/clangd]: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
[pr-draft]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
[pr-ready]: https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/changing-the-stage-of-a-pull-request
[run-tests]: https://github.com/neovim/neovim/blob/master/test/README.md#running-tests
[style-guide]: https://neovim.io/doc/user/dev_style.html#dev-style
[wiki-faq]: https://neovim.io/doc/user/faq.html
