Maintaining the Neovim project
==============================

Notes on maintaining the Neovim project.

General guidelines
------------------

* Decide by cost-benefit
* Write down what was decided
* Constraints are good
* Use automation to solve problems
* Never break the API... but sometimes break the UI

Issue triage
------------

In practice we haven't found a way to forecast more precisely than "next" and
"after next". So there are usually one or two (at most) planned milestones:

* Next bugfix-release (1.0.x)
* Next feature-release (1.x.0)

The forecasting problem might be solved with an explicit priority system (like
Bram's todo.txt). Meanwhile the Neovim priority system is defined by:

* PRs nearing completion.
* Issue labels. E.g. the `has:plan` label increases the ticket's priority merely
  for having a plan written down: it is _closer to completion_ than tickets
  without a plan.
* Comment activity or new information.

Anything that isn't in the next milestone, and doesn't have a finished PR—is
just not something you care very much about, by construction. Post-release you
can review open issues, but chances are your next milestone is already getting
full... :)

Release policy
--------------

Release "often", but not "early".

The (unreleased) `master` branch is the "early" channel; it should not be
released if it's not stable. High-risk changes may be merged to `master` if
the next release is not imminent.

For maintenance releases, create a `release-x.y` branch. If the current release
has a major bug:

1. Fix the bug on `master`.
2. Cherry-pick the fix to `release-x.y`.
3. Cut a release from `release-x.y`.
    * Run `./scripts/release.sh`
    * Update (force-push) the remote `stable` tag.
    * The [CI job](https://github.com/neovim/neovim/blob/3d45706478cd030c3ee05b4f336164bb96138095/.github/workflows/release.yml#L11-L13)
      will update the release assets and force-push to the `stable` tag.

### Release automation

Neovim automation includes a [backport bot](https://github.com/zeebe-io/backport-action).
Trigger the action by labeling a PR with `backport release-X.Y`. See `.github/workflows/backport.yml`.

Deprecating and removing features
---------------------------------

Neovim inherits many features and design decisions from Vim, not all of which
align with the goals of this project. It is sometimes desired or necessary to
remove existing features, or refactor parts of the code that would change
user's workflow. In these cases, a deprecation policy is needed to properly
inform users of the change.

When a (non-experimental) feature is slated to be removed it should:

1. Be _soft_ deprecated in the _next_ release
  - Use of the deprecated feature will still work.
  - This means deprecating via documentation and annotation (`@deprecated`).
  - Include a note in `news.txt` under `DEPRECATIONS`.
  - For Lua features, use `vim.deprecate()`. The specified version is the
    current minor version + 2. For example, if the current version is
    `v0.10.0-dev-1957+gd676746c33` then use `0.12`.
  - For Vimscript features, use `v:lua.vim.deprecate()`. Use the same version
    as described for Lua features.
2. Be _hard_ deprecated in a following a release in which it was soft deprecated.
  - Use of the deprecated feature will still work but should issue a warning.
  - Features implemented in C will need bespoke implementations to communicate
    to users that the feature is deprecated.
3. Be removed in a release following the release in which it was hard deprecated
  - Usually this will be the next release, but it may be a later release if a
    longer deprecation cycle is desired
  - If possible, keep the feature as a stub (e.g. function API) and issue an error
    when it is accessed.

Example:

```
                Deprecation                            Removal
                     ┆                 ┆                 ┆
                     ┆      Soft       ┆      Hard       ┆
                     ┆   Deprecation   ┆   Deprecation   ┆
                     ┆     Period      ┆     Period      ┆
         ────────────────────────────────────────────────────────────
Version:            0.10              0.11              0.12
         ────────────────────────────────────────────────────────────
         Old code         Old code          Old code
                             +                 +
                          New code          New code         New code
```

Feature removals which may benefit from community input or further discussion
should also have a tracking issue (which should be linked to in the release
notes).

Exceptions to this policy may be made (for experimental subsystems or when
there is broad consensus among maintainers). The rationale for the exception
should be stated explicitly and publicly.

Third-party dependencies
------------------------

For some dependencies we maintain temporary "forks", which are simply private
branches with a few extra patches, while we wait for the upstream project to
merge the patches. This is done instead of maintaining the patches as (fragile)
CMake `PATCH_COMMAND` steps.

These "bundled" dependencies can be updated by bumping their versions in `cmake.deps/deps.txt`.
Some can be auto-bumped by `scripts/bump_deps.lua`.

* [LuaJIT](https://github.com/LuaJIT/LuaJIT)
* [Lua](https://www.lua.org/download.html)
* [Luv](https://github.com/luvit/luv)
    * When bumping, also sync [our bundled documentation](https://github.com/neovim/neovim/blob/master/runtime/doc/luvref.txt) with [the upstream documentation](https://github.com/luvit/luv/blob/master/docs.md).
* [gettext](https://ftp.gnu.org/pub/gnu/gettext/)
* [libiconv](https://ftp.gnu.org/pub/gnu/libiconv)
* [libuv](https://github.com/libuv/libuv)
* [libvterm](http://www.leonerd.org.uk/code/libvterm/)
  * Downloading from the original source is unreliable, so we use our [mirror](https://github.com/neovim/libvterm) instead.
* [lua-compat](https://github.com/keplerproject/lua-compat-5.3)
* [tree-sitter](https://github.com/tree-sitter/tree-sitter)
* [unibilium](https://github.com/neovim/unibilium)
  * The original project [was abandoned](https://github.com/neovim/neovim/issues/10302), so the [neovim/unibilium](https://github.com/neovim/unibilium) fork is considered "upstream" and is maintained on the `master` branch.
* [treesitter parsers](https://github.com/neovim/neovim/blob/7e97c773e3ba78fcddbb2a0b9b0d572c8210c83e/cmake.deps/deps.txt#L47-L62)

### Vendored dependencies

These dependencies are "vendored" (inlined), we must update the sources manually:

* `src/mpack/`: [libmpack](https://github.com/libmpack/libmpack)
    * send improvements upstream!
* `src/xdiff/`: [xdiff](https://github.com/git/git/tree/master/xdiff)
* `src/cjson/`: [lua-cjson](https://github.com/openresty/lua-cjson)
* `src/klib/`: [Klib](https://github.com/attractivechaos/klib)
* `runtime/lua/vim/inspect.lua`: [inspect.lua](https://github.com/kikito/inspect.lua)
* `src/nvim/tui/terminfo_defs.h`: terminfo definitions
    * Run `scripts/update_terminfo.sh` to update these definitions.
* `runtime/lua/vim/lsp/_meta/protocol.lua`: LSP specification
    * Run `scripts/gen_lsp.lua` to update.
* `runtime/lua/vim/_meta/lpeg.lua`: LPeg definitions.
    * Refer to [`LuaCATS/lpeg`](https://github.com/LuaCATS/lpeg) for updates.
    * Update the git SHA revision from which the documentation was taken.
* `runtime/lua/vim/re.lua`: LPeg regex module.
    * Vendored from LPeg. Needs to be updated when LPeg is updated.
* `runtime/lua/vim/_meta/re.lua`: docs for LPeg regex module.
    * Needs to be updated when LPeg is updated.
* `src/bit.c`: only for PUC lua: port of `require'bit'` from luajit https://bitop.luajit.org/
* `runtime/lua/coxpcall.lua`: coxpcall (only needed for PUC lua, builtin to luajit)
* `src/termkey`: [libtermkey](https://github.com/neovim/libtermkey)

Other dependencies
--------------------------

* GitHub users:
    * https://github.com/marvim
    * https://github.com/nvim-winget
* Org secrets/tokens:
    * `CODECOV_TOKEN`
* Domain names (held in https://namecheap.com):
    * neovim.org
    * neovim.io
    * packspec.org
    * pkgjson.org
* DNS for the above domains is managed in https://cloudflare.com (not the domain registrar)


Refactoring
-----------

### Frozen legacy modules

Refactoring Vim structurally and aesthetically is an important goal of Neovim.
But there are some modules that should not be changed significantly, because
they are maintained Vim, at present. Until someone takes "ownership" of these
modules, the cost of any significant changes (including style or structural
changes that re-arrange the code) to these modules outweighs the benefit. The
modules are:

- `regexp.c`
- `indent_c.c`

Automation (CI)
---------------

### Backup

Discussions from issues and PRs are backed up here:
https://github.com/neovim/neovim-backup

### Development guidelines

* CI and automation jobs are primarily driven by GitHub Actions.
* Avoid macOS if an Ubuntu or a Windows runner can be used instead. This is
  because macOS runners have [tighter restrictions on the number of concurrent
  jobs](https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits).

* Runner versions:
    * For special-purpose jobs where the runner version doesn't really matter,
      prefer `-latest` tags so we don't need to manually bump the versions. An
      example of a special-purpose workflow is `labeler_pr.yml`.
    * For our testing job `test.yml`, prefer to use the latest stable (i.e.
      non-beta) version explicitly. Avoid using the `-latest` tags here as it
      makes it difficult to determine from an unrelated PR if a failure is due
      to the PR itself or due to GitHub bumping the `-latest` tag without our
      knowledge. There's also a high risk that automatically bumping the CI
      versions will fail due to manual work being required from experience.
    * For our release job, which is `release.yml`, prefer to use the oldest
      stable (i.e. non-deprecated) versions available. The reason is that we're
      trying to produce images that work in the broadest number of environments,
      and therefore want to use older releases.

### Special labels

Some github labels are used to trigger certain jobs:

* `ci:backport release-x.y` - backport to branch `release-x.y`
* `ci:s390x` - enable s390x CI
* `ci:skip-news` - skip news.yml workflows
* `ci:windows-asan` - test windows with ASAN enabled
* `needs:response` - close PR after a certain amount of time if author doesn't
  respond

See also
--------

* https://github.com/neovim/neovim/issues/862
* https://github.com/git/git/blob/master/Documentation/howto/maintain-git.txt
