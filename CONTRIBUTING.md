# Contributing to Neovim

Getting started
---------------

If you want to help but don't know where to start, here are some
low-risk/isolated tasks:

- Merge a [Vim patch].
- Try a [complexity:low] issue.
- Fix [clang-scan], [coverity](#coverity), and [PVS](#pvs-studio) warnings.

Developer guidelines
--------------------

- Nvim developers should read `:help dev-help`.
- External UI developers should read `:help dev-ui`.

Reporting problems
------------------

- Check the [**FAQ**][wiki-faq].
- Search [existing issues][github-issues] (including closed!)
- Update Neovim to the latest version to see if your problem persists.
- If you're using a plugin manager, comment out your plugins, then add them back
  in one by one, to narrow down the cause of the issue.
- Crash reports which include a stacktrace are 10x more valuable.
- [Bisecting][git-bisect] to the cause of a regression often leads to an
  immediate fix.

Pull requests ("PRs")
---------------------

- To avoid duplicate work, create a `[WIP]` pull request as soon as possible.
- Avoid cosmetic changes to unrelated files in the same commit: noise makes
  reviews take longer.
- Use a [feature branch][git-feature-branch] instead of the master branch.
- Use a **rebase workflow** for small PRs.
  - After addressing review comments, it's fine to rebase and force-push.
- Use a **merge workflow** for big, high-risk PRs.
  - Merge `master` into your PR when there are conflicts or when master
    introduces breaking changes.
  - Use the `ri` git alias:
    ```
    [alias]
    ri = "!sh -c 't=\"${1:-master}\"; s=\"${2:-HEAD}\"; mb=\"$(git merge-base \"$t\" \"$s\")\"; if test \"x$mb\" = x ; then o=\"$t\"; else lm=\"$(git log -n1 --merges \"$t..$s\" --pretty=%H)\"; if test \"x$lm\" = x ; then o=\"$mb\"; else o=\"$lm\"; fi; fi; test $# -gt 0 && shift; test $# -gt 0 && shift; git rebase --interactive \"$o\" \"$@\"'"
    ```
    This avoids unnecessary rebases yet still allows you to combine related
    commits, separate monolithic commits, etc.
  - Do not edit commits that come before the merge commit.
- During a squash/fixup, use `exec make -C build unittest` between each
  pick/edit/reword.

### Stages: WIP, RFC, RDY

Pull requests have three stages: `[WIP]` (Work In Progress), `[RFC]` (Request
For Comment) and `[RDY]` (Ready).

- Untagged PRs are assumed to be `[RFC]`, i.e. you are requesting a review.
- Prepend `[WIP]` to the PR title if you are _not_ requesting feedback and the
  work is still in flux.
- Prepend `[RDY]` to the PR title if you are _done_ with the PR and are only
  waiting on it to be merged.

For example, a typical workflow is:

1. You open a `[WIP]` PR where the work is _not_ ready for feedback, you just want to
   let others know what you are doing.
2. Once the PR is ready for review, you replace `[WIP]` in the title with `[RFC]`.
   You may add fix up commits to address issues that come up during review.
3. Once the PR is ready for merging, you rebase/squash your work appropriately and
   then replace `[RFC]` in the title with `[RDY]`.

### Commit messages

Follow [commit message hygiene][hygiene] to *make reviews easier* and to make
the VCS/git logs more valuable.

- Try to keep the first line under 72 characters.
- **Prefix the commit subject with a _scope_:** `doc:`, `test:`, `foo.c:`,
  `runtime:`, ...
    - For commits that contain only style/lint changes, a single-word subject
      line is preferred: `style` or `lint`.
- A blank line must separate the subject from the description.
- Use the _imperative voice_: "Fix bug" rather than "Fixed bug" or "Fixes bug."

### Automated builds (CI)

Each pull request must pass the automated builds ([travis CI] and [quickbuild]).

- CI builds are compiled with [`-Werror`][gcc-warnings], so if your PR
  introduces any compiler warnings, the build will fail.
- If any tests fail, the build will fail.
  See [Building Neovim#running-tests][wiki-run-tests] to run tests locally.
  Passing locally doesn't guarantee passing the CI build, because of the
  different compilers and platforms tested against.
- CI runs [ASan] and other analyzers. To run valgrind locally:
  `VALGRIND=1 make test`
- The `lint` build ([#3174][3174]) checks modified lines _and their immediate
  neighbors_. This is to encourage incrementally updating the legacy style to
  meet our style guidelines.
    - A single word (`lint` or `style`) is sufficient as the subject line of
      a commit that contains only style changes.
- [How to investigate QuickBuild failures](https://github.com/neovim/neovim/pull/4718#issuecomment-217631350)

QuickBuild uses this invocation:

    mkdir -p build/${params.get("buildType")} \
    && cd build/${params.get("buildType")} \
    && cmake -G "Unix Makefiles" -DBUSTED_OUTPUT_TYPE=TAP -DCMAKE_BUILD_TYPE=${params.get("buildType")}
    -DTRAVIS_CI_BUILD=ON ../.. && ${node.getAttribute("make", "make")}
    VERBOSE=1 nvim unittest-prereqs functionaltest-prereqs


### Coverity

[Coverity](https://scan.coverity.com/projects/neovim-neovim) runs against the
master build. If you want to view the defects, just request access at the
_Contributor_ level. An Admin will grant you permission.

Use this commit-message format for coverity fixes:

    coverity/<id>: <description of what fixed the defect>

where `<id>` is the Coverity ID (CID). For example see [#804](https://github.com/neovim/neovim/pull/804).

### PVS-Studio

Run `scripts/pvscheck.sh` to check the codebase with [PVS
Studio](https://www.viva64.com/en/pvs-studio/).

Reviewing
---------

To help review pull requests, start with [this checklist][review-checklist].

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [`hub`][hub], you can create a new branch with the contents of a pull
request, e.g. [#1820][1820]:

    hub checkout https://github.com/neovim/neovim/pull/1820

Use [`git log -p master..FETCH_HEAD`][git-history-filtering] to list all
commits in the feature branch which aren't in the `master` branch; `-p`
shows each commit's diff. To show the whole surrounding function of a change
as context, use the `-W` argument as well.

[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[git-bisect]: http://git-scm.com/book/tr/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[git-history-rewriting]: http://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[git-rebasing]: http://git-scm.com/book/en/v2/Git-Branching-Rebasing
[github-issues]: https://github.com/neovim/neovim/issues
[1820]: https://github.com/neovim/neovim/pull/1820
[hub]: https://hub.github.com/
[hygiene]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[style-guide]: http://neovim.io/develop/style-guide.xml
[ASan]: http://clang.llvm.org/docs/AddressSanitizer.html
[wiki-run-tests]: https://github.com/neovim/neovim/wiki/Building-Neovim#running-tests
[wiki-faq]: https://github.com/neovim/neovim/wiki/FAQ
[review-checklist]: https://github.com/neovim/neovim/wiki/Code-review-checklist
[3174]: https://github.com/neovim/neovim/issues/3174
[travis CI]: https://travis-ci.org/neovim/neovim
[quickbuild]: http://neovim-qb.szakmeister.net/dashboard
[Vim patch]: https://github.com/neovim/neovim/wiki/Merging-patches-from-upstream-Vim
[clang-scan]: https://neovim.io/doc/reports/clang/
[complexity:low]: https://github.com/neovim/neovim/issues?q=is%3Aopen+is%3Aissue+label%3Acomplexity%3Alow
