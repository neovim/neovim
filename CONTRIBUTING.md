Contributing to Neovim
======================

Getting started
---------------

If you want to help but don't know where to start, here are some
low-risk/isolated tasks:

- Try a [complexity:low] issue.
- Fix bugs found by [Clang](#clang-scan-build), [PVS](#pvs-studio) or
  [Coverity](#coverity).
- [Improve documentation](#documenting)
- [Merge a Vim patch] (requires strong familiarity with Vim)
  - NOTE: read the above link before sending improvements to "runtime files" (anything in `runtime/`).
    - Vimscript and documentation files are (mostly) maintained by [Vim](https://github.com/vim/vim), not Nvim.
    - Lua files are maintained by Nvim.

Reporting problems
------------------

- [Check the FAQ][wiki-faq].
- [Search existing issues][github-issues] (including closed!)
- Update Neovim to the latest version to see if your problem persists.
- Try to reproduce with `nvim --clean` ("factory defaults").
- [Bisect](https://neovim.io/doc/user/starting.html#bisect) your config: disable plugins incrementally, to narrow down the cause of the issue.
- [Bisect][git-bisect] Neovim's source code to find the cause of a regression, if you can. This is _extremely_ helpful.
- When reporting a crash, [include a stacktrace](https://github.com/neovim/neovim/wiki/FAQ#backtrace-linux).
- Use [ASAN/UBSAN](#clang-sanitizers-asan-and-ubsan) to get detailed errors for segfaults and undefined behavior.
- Check the logs. `:edit $NVIM_LOG_FILE`
- Include `cmake --system-information` for build-related issues.

Developer guidelines
--------------------

- Read [:help dev](https://neovim.io/doc/user/develop.html#dev) and [:help dev-doc][dev-doc-guide] if you are working on Nvim core.
- Read [:help dev-ui](https://neovim.io/doc/user/develop.html#dev-ui) if you are developing a UI.
- Read [:help dev-api-client](https://neovim.io/doc/user/develop.html#dev-api-client) if you are developing an API client.
- Install `ninja` for faster builds of Nvim.
  ```
  sudo apt-get install ninja-build
  make distclean
  make  # Nvim build system uses ninja automatically, if available.
  ```
- Install `ccache` for faster rebuilds of Nvim. Nvim will use it automatically
  if it's found. To disable caching use:
  ```
  CCACHE_DISABLE=true make
  ```

Pull requests (PRs)
---------------------

- To avoid duplicate work, create a draft pull request.
- Your PR must include [test coverage][run-tests].
- Avoid cosmetic changes to unrelated files in the same commit.
- Use a [feature branch][git-feature-branch] instead of the master branch.
- Use a _rebase workflow_ for small PRs.
  - After addressing review comments, it's fine to force-push.
- Use a _merge workflow_ (as opposed to "rebase") for big, high-risk PRs.
  - Merge `master` into your PR when there are conflicts or when master
    introduces breaking changes.
  - Do not edit commits that come before the merge commit.

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
the VCS/git logs more valuable. The general structure of a commit message is:

```
<type>([optional scope]): <description>

[optional body]

[optional footer(s)]
```

- Prefix the commit subject with one of these [_types_](https://github.com/commitizen/conventional-commit-types/blob/master/index.json):
    - `build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `test`, `vim-patch`
    - You can **ignore this for "fixup" commits** or any commits you expect to be squashed.
- Append optional scope to _type_ such as `(lsp)`, `(treesitter)`, `(float)`, …
- _Description_ shouldn't start with a capital letter or end in a period.
- Use the _imperative voice_: "Fix bug" rather than "Fixed bug" or "Fixes bug."
- Try to keep the first line under 72 characters.
- A blank line must follow the subject.
- Breaking API changes must be indicated by
    1. "!" after the type/scope, and
    2. a "BREAKING CHANGE" footer describing the change.
       Example:
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
    - To run Clang ASan/UBSan locally: `CC=clang make CMAKE_FLAGS="-DENABLE_ASAN_UBSAN=ON"`
- The [lint](#lint) build checks modified lines _and their immediate
  neighbors_, to encourage incrementally updating the legacy style to meet our
  [style](#style). (See [#3174][3174] for background.)
- CI for FreeBSD runs on [Cirrus CI].
- To see CI results faster in your PR, you can temporarily set `TEST_FILE` in
  [test.yml](https://github.com/neovim/neovim/blob/e35b9020b16985eee26e942f9a3f6b045bc3809b/.github/workflows/test.yml#L29).

### Clang scan-build

View the [Clang report] to see potential bugs found by the Clang
[scan-build](https://clang-analyzer.llvm.org/scan-build.html) analyzer.

- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep clang
  ```
- To verify a fix locally, run `scan-build` like this:
  ```
  rm -rf build/
  scan-build --use-analyzer=/usr/bin/clang make
  ```

### PVS-Studio

View the [PVS report](https://neovim.io/doc/reports/pvs/PVS-studio.html.d/) to
see potential bugs found by [PVS Studio](https://www.viva64.com/en/pvs-studio/).

- Use this format for commit messages (where `{id}` is the PVS warning-id)):
  ```
  fix(PVS/V{id}): {description}
  ```
- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep PVS
  ```
- Try `./scripts/pvscheck.sh` to run PVS locally.

### Coverity

[Coverity](https://scan.coverity.com/projects/neovim-neovim) runs against the
master build. To view the defects, just request access; you will be approved.

- Use this format for commit messages (where `{id}` is the CID (Coverity ID);
  ([example](https://github.com/neovim/neovim/pull/804))):
  ```
  fix(coverity/{id}): {description}
  ```
- Search the Neovim commit history to find examples:
  ```
  git log --oneline --no-merges --grep coverity
  ```

### Clang sanitizers (ASAN and UBSAN)

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

    make lint

The lint step downloads the [master error list] and excludes them, so only lint
errors related to the local changes are reported.

You can lint a single file (but this will _not_ exclude legacy errors):

    ./src/clint.py src/nvim/ops.c

### Style

- You can format files by using:
  ```
    make format
  ```
  This will format changed Lua and C files with all appropriate flags set.
- Style rules are (mostly) defined by `src/uncrustify.cfg` which tries to match
  the [style-guide]. To use the Nvim `gq` command with `uncrustify`:
  ```
  if !empty(findfile('src/uncrustify.cfg', ';'))
    setlocal formatprg=uncrustify\ -q\ -l\ C\ -c\ src/uncrustify.cfg\ --no-backup
  endif
  ```
  The required version of `uncrustify` is specified in `uncrustify.cfg`.
- There is also `.clang-format` which has drifted from the [style-guide], but
  is available for reference. To use the Nvim `gq` command with `clang-format`:
  ```
  if !empty(findfile('.clang-format', ';'))
    setlocal formatprg=clang-format\ -style=file
  endif
  ```

### Navigate

- Set `blame.ignoreRevsFile` to ignore [noise commits](https://github.com/neovim/neovim/commit/2d240024acbd68c2d3f82bc72cb12b1a4928c6bf) in git blame:
  ```
  git config blame.ignoreRevsFile .git-blame-ignore-revs
  ```

- Recommendation is to use **[clangd]**.
  Can use the maintained config in [nvim-lspconfig/clangd].
- Explore the source code [on the web](https://sourcegraph.com/github.com/neovim/neovim).
- If using [lua-language-server], symlink `contrib/luarc.json` into the
  project root:

      $ ln -s contrib/luarc.json .luarc.json

### Includes

For managing includes in C files, use [include-what-you-use].

- [Install include-what-you-use][include-what-you-use-install]
- To see which includes needs fixing use the cmake preset `iwyu`:
  ```
  cmake --preset iwyu
  cmake --build build iwyu
  ```
- There's also a make target that automatically fixes the suggestions from
  IWYU:
  ```
  make iwyu
  ```

See [#549][549] for more details.

### Lua runtime files

Most of the Lua core [`runtime/`](./runtime) modules are precompiled to
bytecode, so changes to those files won't get used unless you rebuild Nvim or
by passing `--luamod-dev` and `$VIMRUNTIME`. For example, try adding a function
to `runtime/lua/vim/_editor.lua` then:

    VIMRUNTIME=./runtime ./build/bin/nvim --luamod-dev

Documenting
-----------

Read [:help dev-doc][dev-doc-guide] to understand the expected documentation style and conventions.

### Generating :help

Many `:help` docs are autogenerated from (C or Lua) docstrings by the `./scripts/gen_vimdoc.py` script.
For convenience you can filter the regeneration by target (api, lua, lsp) using the `-t` option, for example:

    ./scripts/gen_vimdoc.py -t lua

### Lua docstrings

Lua documentation uses a subset of [EmmyLua] annotations. See [:help dev-doc-lua][dev-doc-lua].

- The template for function documentation is:
  ```lua
  --- {Brief}
  ---
  --- {Long explanation}
  ---
  ---@param arg1 type {description}
  ---@param arg2 type {description}
  --- ...
  ---
  ---@return type {description}
  ```
- If possible, add type information (`table`, `string`, `number`, ...). Multiple valid types are separated by a bar (`string|table`). Indicate optional parameters via `type|nil`.
- If a function in your Lua module should _not_ be documented (e.g. internal or local function), set the doc comment to:
  ```
  ---@private
  ```
- Mark deprecated functions with:
  ```
  ---@deprecated
  ```

Reviewing
---------

To help review pull requests, start with [this checklist][review-checklist].

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [GitHub CLI][gh], you can create a new branch with the contents of a pull
request, e.g. [#1820][1820]:

    gh pr checkout https://github.com/neovim/neovim/pull/1820

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
[clangd]: https://clangd.llvm.org
[Merge a Vim patch]: https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-Vim
[complexity:low]: https://github.com/neovim/neovim/issues?q=is%3Aopen+is%3Aissue+label%3Acomplexity%3Alow
[conventional_commits]: https://www.conventionalcommits.org
[dev-doc-guide]: https://neovim.io/doc/user/develop.html#dev-doc
[dev-doc-lua]: https://neovim.io/doc/user/develop.html#dev-lua-doc
[EmmyLua]: https://github.com/sumneko/lua-language-server/wiki/Annotations
[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[gh]: https://cli.github.com/
[git-bisect]: http://git-scm.com/book/en/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[git-history-rewriting]: http://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[git-rebasing]: http://git-scm.com/book/en/v2/Git-Branching-Rebasing
[github-issues]: https://github.com/neovim/neovim/issues
[include-what-you-use-install]: https://github.com/include-what-you-use/include-what-you-use#how-to-install
[include-what-you-use]: https://github.com/include-what-you-use/include-what-you-use#using-with-cmake
[lua-language-server]: https://github.com/sumneko/lua-language-server/
[master error list]: https://raw.githubusercontent.com/neovim/doc/gh-pages/reports/clint/errors.json
[nvim-lspconfig/clangd]: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
[pr-draft]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
[pr-ready]: https://docs.github.com/en/github/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/changing-the-stage-of-a-pull-request
[review-checklist]: https://github.com/neovim/neovim/wiki/Code-review-checklist
[run-tests]: https://github.com/neovim/neovim/blob/master/test/README.md#running-tests
[style-guide]: https://neovim.io/doc/user/dev_style.html#dev-style
[uncrustify]: http://uncrustify.sourceforge.net/
[wiki-contribute-help]: https://github.com/neovim/neovim/wiki/contribute-%3Ahelp
[wiki-faq]: https://github.com/neovim/neovim/wiki/FAQ
