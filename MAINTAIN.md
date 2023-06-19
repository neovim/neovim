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

In general, when a feature is slated to be removed it should:

1. Be marked deprecated in the _next_ release
  - This includes a note in the release notes (include a "Deprecation Warning"
    section just below "Breaking Changes")
  - Lua features can use `vim.deprecate()`
  - Features implemented in Vimscript or in C will need bespoke implementations
    to communicate to users that the feature is deprecated
2. Be removed in a release following the release in which it was marked
   deprecated
  - Usually this will be the next release, but it may be a later release if a
    longer deprecation cycle is desired

Feature removals which may benefit from community input or further discussion
should also have a tracking issue (which should be linked to in the release
notes).

Third-party dependencies
------------------------

These "bundled" dependencies can be updated by bumping their versions in `cmake.deps/CMakeLists.txt`.
Some can be auto-bumped by `scripts/bump_deps.lua`.

* [LuaJIT](https://github.com/LuaJIT/LuaJIT)
* [Lua](https://www.lua.org/download.html)
* [Luv](https://github.com/luvit/luv)
    * When bumping, also sync [our bundled documentation](https://github.com/neovim/neovim/blob/master/runtime/doc/luvref.txt) with [the upstream documentation](https://github.com/luvit/luv/blob/master/docs.md).
* [gettext](https://ftp.gnu.org/pub/gnu/gettext/)
* [libiconv](https://ftp.gnu.org/pub/gnu/libiconv)
* [libtermkey](https://github.com/neovim/libtermkey)
* [libuv](https://github.com/libuv/libuv)
* [libvterm](http://www.leonerd.org.uk/code/libvterm/)
* [lua-compat](https://github.com/keplerproject/lua-compat-5.3)
* [msys2](https://github.com/msys2/MINGW-packages) (for mingw Windows build)
    * Changes to mingw can [break our mingw build](https://github.com/msys2/MINGW-packages/issues/9946).
* [tree-sitter](https://github.com/tree-sitter/tree-sitter)
* [unibilium](https://github.com/neovim/unibilium)

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
* `runtime/lua/vim/lsp/types/protocol.lua`: LSP specification
    * Run `scripts/lsp_types.lua` to update.
* `src/bit.c`: only for PUC lua: port of `require'bit'` from luajit https://bitop.luajit.org/
* [treesitter parsers](https://github.com/neovim/neovim/blob/fcc24e43e0b5f9d801a01ff2b8f78ce8c16dd551/cmake.deps/CMakeLists.txt#L197-L210)

### Forks

We may maintain forks, if we are waiting on upstream changes: https://github.com/neovim/neovim/wiki/Deps

CI
--------------

### General

As our CI is primarily dependent on GitHub Actions at the moment, then so will
our CI strategy be. The following guidelines have worked well for us so far:

* Never use a macOS runner if an Ubuntu or a Windows runner can be used
  instead. This is because macOS runners have a [tighter restrictions on the
  number of concurrent jobs](https://docs.github.com/en/actions/learn-github-actions/usage-limits-billing-and-administration#usage-limits).

### Runner versions

* For special-purpose jobs where the runner version doesn't really matter,
  prefer `-latest` tags so we don't need to manually bump the versions. An
  example of a special-purpose workflow is `labeler.yml`.

* For our testing jobs, which are in `test.yml` and `build.yml`, prefer to use
  the latest stable (i.e. non-beta) version explicitly. Avoid using the
  `-latest` tags here as it makes it difficult to determine from an unrelated
  PR if a failure is due to the PR itself or due to GitHub bumping the
  `-latest` tag without our knowledge. There's also a high risk that automatic
  bumping the CI versions will fail due to manual work being required from
  experience.

* For our release job, which is `release.yml`, prefer to use the oldest stable
  (i.e. non-deprecated) versions available. The reason is that we're trying to
  produce images that work in the broadest number of environments, and
  therefore want to use older releases.

See also
--------

* https://github.com/neovim/neovim/issues/862
* https://github.com/git/git/blob/master/Documentation/howto/maintain-git.txt
