# Contributing to Neovim

## Getting started

- Help us review [open pull requests](https://github.com/neovim/neovim/pulls)!
- Look for [**entry-level**][entry] issues to work on.
    - [**documentation**](https://github.com/neovim/neovim/labels/documentation)
      improvements are also very helpful.
- Look at [Waffle][waffle] to see who is working on what issues.
- Refer to the [the wiki][wiki] for detailed guidance.

## Issues

- Search existing issues before raising a new one.
- Include as much detail as possible. In particular, we need to know which
  OS you're using.

## Pull requests

- Make it clear in the issue tracker what you are working on.
- Be descriptive in your PR message: what is it for, why is it needed, etc.
- Don't make cosmetic changes to unrelated files in the same PR.
- If you're a first-time contributor, please sign the
  [Neovim Contributor License Agreement (CLA)][cla] before submitting your PR.

#### Tagging in the issue tracker

When submitting pull requests, include one of the following tokens in the title:

* `[WIP]` - Work In Progress. The pull request will change, and there is no need
  to review it yet.
* `[RFC]` - Request For Comment. The request needs reviewing and/or comments.
* `[RDY]` - The request is ready to be merged. The request must have been
  reviewed by at least one person and have no outstanding issues.
* Default label is assumed to be `[WIP]` if there's no indication otherwise.

#### Branching & history

- Use a feature branch, not master.
- Rebase your feature branch onto (upstream) master before raising the PR.
- Keep up to date with changes in (upstream) master so your PR is easy to merge.
- Try to actively tidy your history: combine related commits with interactive
  rebasing etc. If your PR is still `[WIP]` don't be afraid to force-push to
  your feature branch to tidy your history.

### For code PRs

#### Testing

- We are unlikely to merge your PR if the Travis build fails.
- The Travis build does not currently run the tests under valgrind, but you
  are encouraged to do so locally.

#### Coding style

We have a [style guide][style] that all new code should follow. However, vast
swathes of the existing vim codebase violate it to some degree, and fixing
them would increase merge conflicts and add noise to `git blame`. Please weigh
those costs when making cosmetic changes. As a rule of thumb, avoid pull
requests dominated by style changes. Feel free to fix up lines that you happen
to be modifying anyway, as long as they look consistent with their
surroundings. Fix anything that looks outright
[barbarous](http://www.orwell.ru/library/essays/politics/english/e_polit) --
especially if you can't find any editor settings that make it look ok -- but
otherwise err on the side of leaving things as they are.

For new code, please run [`clint.py`][clint] to detect style errors. It is not
perfect and may have false positives and negatives. To have `clint.py` ignore
certain special cases, put `// NOLINT` at the end of the line.

We also provide a configuration file for [`clang-format` and 
`git-clang-format`][clang-format], which can be used to format code according
to the style guidelines. Be aware this formatting method might need user
supervision.

#### Commit guidelines

The purpose of these guidelines is to *make reviews easier* and make the VCS logs more valuable.

- Try to keep the first line under 70 characters.
- Include further description, if necessary, after a blank line.
    - Don't make it too verbose by including obvious things.
    - But don't spare clarifications for anything that could be not so obvious.
      Some commit messages are pages long, and that's fine if there's no better
      place for those comments to live.
    - **Recommended:** Prefix logically-related commits with a consistent
      identifier at the beginning of each commit message.
      [For example](https://github.com/neovim/neovim/commits?author=elmart),
      the following commits are related by task (*Introduce vim namespace*) and
      scope (*Contrib YCM*).
      <br/> `Introduce vim namespace: Contrib YCM: Fix style issues.`
      <br/> `Introduce vim namespace: Contrib YCM: Fix build dir calculation`
        - Subtasks can be *activity-oriented* (doing different things on the same area)
          or *scope-oriented* (doing the same thing on different areas).
    - Granularity helps, but it's conceptual size that matters, not extent size.
- Use the imperative voice: "Fix bug" rather than "Fixed bug" or "Fixes bug."


[cla]: https://docs.google.com/forms/d/1u54bpbwzneDIRltFx1TGi2evKxY3w0cOV3vlpj8DPbg/viewform
[clint]: clint.py
[clang-format]: http://clang.llvm.org/docs/ClangFormat.html
[entry]: https://github.com/neovim/neovim/issues?labels=entry-level&state=open
[imperative]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[style]: http://neovim.org/develop/style-guide.xml
[waffle]: https://waffle.io/neovim/neovim
[wiki]: https://github.com/neovim/neovim/wiki/Contributing
