# Contributing to Neovim

## Getting started

- Help us review [open pull requests](https://github.com/neovim/neovim/pulls)!
- Look for [entry-level issues][entry-level] to work on.
    - [Documentation](https://github.com/neovim/neovim/labels/documentation)
      improvements are also much appreciated.
- Look at [Waffle][waffle] to see who is working on what issues.
- If needed, refer to [the wiki][wiki-contributing] for guidance.

## Reporting problems

Before reporting an issue, see the following wiki articles:

- [Troubleshooting][wiki-troubleshooting]
- [Frequently asked questions][wiki-faq]

If your issue isn't mentioned there:

- Verify that it hasn't already been reported.
- If not already running the latest version of Neovim, update to it to see if
  your problem persists.
- If you're experiencing compile or runtime warnings/failures, try searching for
  the error message(s) you received (if any) on [Neovim's issue tracker][github-issues].
    - For build issues, see
      [Troubleshooting#build-issues][wiki-troubleshooting-build-issues].
    - For runtime issues, see
      [Troubleshooting#runtime-issues][wiki-troubleshooting-runtime-issues].
      If your issue isn't mentioned there, try to reproduce your it using
      `nvim` with the smallest possible `vimrc` (or none at all via `nvim -u
      NONE`), to rule out bugs in plugins you're using.
      If you're using a plugin manager, comment out your plugins, then add
      them back in one by one.

Include as much detail as possible; we generally need to know:

- What operating system you're using.
- Which version of Neovim you're using. To get this, run `nvim --version` from
  a shell, or run `:version` from inside `nvim`.
- Whether the bug is present in Vim (not Neovim), and if so which version of
  Vim. It's fine to report Vim bugs on the Neovim bug tracker, but it saves
  everyone time if we know from the start that the bug is not a regression
  caused by Neovim.
- This isn't required, but what commit introduced the issue for you. You can
  use [`git bisect`][git-bisect] for this.

## Submitting contributions

- Make it clear in the issue tracker what you are working on.
- Be descriptive in your pull request description: what is it for, why is it
  needed, etc.
- Do ***not*** make cosmetic changes to unrelated files in the same pull
  request. This creates noise, making reviews harder to do. If your text
  editor strips all trailing whitespace in a file when you edit it, disable
  it.

### Tagging in the issue tracker

When submitting pull requests (commonly referred to as "PRs"), include one of
the following tags prepended to the title:

- `[WIP]` - Work In Progress: the PR will change, so while there is no
  immediate need for review, the submitter still might appreciate it.
- `[RFC]` - Request For Comment: the PR needs reviewing and/or comments.
- `[RDY]` - Ready: the PR has been reviewed by at least one other person and
  has no outstanding issues.

Assuming the above criteria has been met, feel free to change your PR's tag
yourself, as opposed to waiting for a contributor to do it for you.

### Branching & history

- Do ***not*** work on your PR on the master branch, [use a feature branch
  instead][git-feature-branch].
- [Rebase your feature branch onto][git-rebasing] (upstream) master before
  opening the PR.
- Keep up to date with changes in (upstream) master so your PR is easy to
  merge.
- [Try to actively tidy your history][git-history-rewriting]: combine related
  commits with interactive rebasing, separate monolithic commits, etc. If your
  PR is still `[WIP]`, feel free to force-push to your feature branch to tidy
  your history.

### For code pull requests

#### Testing

We are unlikely to merge your PR if the Travis build fails:

- Travis builds are compiled with the [`-Werror`][gcc-warnings] flag, so if
  your PR introduces any compiler warnings then the Travis build will fail.
- If any tests fail, the Travis build will fail.
  See [Building Neovim#running-tests][wiki-building-running-tests] for
  information on running tests locally.
  Tests passing locally doesn't guarantee they'll pass in the Travis
  build, as different compilers and platforms will be used.
- Travis runs [Valgrind][valgrind] for the GCC/Linux build, but you may also
  do so locally by running the following from a shell: `VALGRIND=1 make test`

#### Coding style

We have a [style guide][style-guide] that all new code should follow.
However, large portions of the existing Vim codebase violate it to some
degree, and fixing them would increase merge conflicts and add noise to `git
blame`.

Weigh those costs when making cosmetic changes. In general, avoid pull
requests dominated by style changes, but feel free to fix up lines that you
happen to be modifying anyway. Fix anything that looks outright
[barbarous](http://www.orwell.ru/library/essays/politics/english/e_polit), but
otherwise prefer to leave things as they are.

For new code, run `make lint` (which runs [clint.py][clint]) to detect style
errors. Make sure that the file(s) you intend to be linted are not in
`clint-ignored-files.txt`. It's not perfect, so some warnings may be false
positives/negatives. To have `clint.py` ignore certain cases, put `// NOLINT`
at the end of the line.

We also provide a configuration file for [`clang-format`][clang-format], which
can be used to format code according to the style guidelines. Be aware that
this formatting method might need user supervision. To have `clang-format`
ignore certain line ranges, use the following special comments:

```c
int formatted_code;
// clang-format off
    void    unformatted_code  ;
// clang-format on
    void formatted_code_again;
```

### Commit guidelines

The purpose of these guidelines is to *make reviews easier* and make the
[VCS][vcs] logs more valuable.

- Try to keep the first line under 72 characters.
- If necessary, include further description after a blank line.
    - Don't make the description too verbose by including obvious things, but
      don't spare clarifications for anything that may be not so obvious.
      Some commit messages are pages long, and that's fine if there's no
      better place for those comments to live.
    - **Recommended:** Prefix logically-related commits with a consistent
      identifier in each commit message. For already used identifiers, see the
      commit history for the respective file(s) you're editing.
      [For example](https://github.com/neovim/neovim/commits?author=elmart),
      the following commits are related by task (*Introduce nvim namespace*) and
      sub-task (*Contrib YCM*).
      <br/> `Introduce nvim namespace: Contrib YCM: Fix style issues`
      <br/> `Introduce nvim namespace: Contrib YCM: Fix build dir calculation`
        - Sub-tasks can be *activity-oriented* (doing different things on the same area)
          or *scope-oriented* (doing the same thing in different areas).
    - Granularity helps, but it's conceptual size that matters, not extent size.
- Use the [imperative voice][imperative]: "Fix bug" rather than "Fixed bug" or "Fixes bug."

### Reviewing pull requests

Using a checklist during reviews is highly recommended, so we [provide one at
the wiki][wiki-review-checklist]. If you think it could be improved, feel free
to edit it.

Reviewing can be done on GitHub, but you may find it easier to do locally.
Using [`hub`][hub], you can do the following to create a new branch with the
contents of a pull request, such as [#1820][github-pr-1820]:

    hub checkout https://github.com/neovim/neovim/pull/1820

Use [`git log -p master..FETCH_HEAD`][git-history-filtering] to list all
commits in the feature branch which aren't in the `master` branch; `-p`
shows each commit's diff. To show the whole surrounding function of a change
as context, use the `-W` argument as well.

You may find it easier to instead use an interactive program for code reviews,
such as [`tig`][tig].

[clang-format]: http://clang.llvm.org/docs/ClangFormat.html
[clint]: clint.py
[entry-level]: https://github.com/neovim/neovim/issues?labels=entry-level&state=open
[gcc-warnings]: https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
[git-bisect]: http://git-scm.com/book/tr/v2/Git-Tools-Debugging-with-Git
[git-feature-branch]: https://www.atlassian.com/git/tutorials/comparing-workflows
[git-history-filtering]: https://www.atlassian.com/git/tutorials/git-log/filtering-the-commit-history
[git-history-rewriting]: http://git-scm.com/book/en/v2/Git-Tools-Rewriting-History
[git-rebasing]: http://git-scm.com/book/en/v2/Git-Branching-Rebasing
[github-issues]: https://github.com/neovim/neovim/issues
[github-pr-1820]: https://github.com/neovim/neovim/pull/1820
[hub]: https://hub.github.com/
[imperative]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[style-guide]: http://neovim.io/develop/style-guide.xml
[tig]: https://github.com/jonas/tig
[valgrind]: http://valgrind.org/
[vcs]: https://en.wikipedia.org/wiki/Revision_control
[waffle]: https://waffle.io/neovim/neovim
[wiki-building-running-tests]: https://github.com/neovim/neovim/wiki/Building-Neovim#running-tests
[wiki-contributing]: https://github.com/neovim/neovim/wiki/Contributing
[wiki-faq]: https://github.com/neovim/neovim/wiki/FAQ
[wiki-review-checklist]: https://github.com/neovim/neovim/wiki/Code-review-checklist
[wiki-troubleshooting-build-issues]: https://github.com/neovim/neovim/wiki/Troubleshooting#build-issues
[wiki-troubleshooting-runtime-issues]: https://github.com/neovim/neovim/wiki/Troubleshooting#runtime-issues
[wiki-troubleshooting]: https://github.com/neovim/neovim/wiki/Troubleshooting
