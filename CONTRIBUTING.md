# Contributing to Neovim

If you need additional support see [the wiki][wiki].

## Getting started contributing

- Look for the [`entry-level`][entry] Issue Label. It marks easier issues.
- Take a look at [Waffle][waffle]. It'll show who is working on what isssues.

### What not to do

Please avoid broad cosmetic/style changes which increase merge conflicts and add
excessive noise to `git blame`.

## Issues

- Search existing issues before raising a new one.
- Include as much detail as possible. In particular, we need to know which
  OS you're using.

## Pull requests

### For all PRs

- Make it clear in the issue tracker what you are working on.
- Be descriptive in your PR message: what is it for, why is it needed, etc.
- Don't make cosmetic changes to unrelated files in the same PR.

#### Tagging in the issue tracker

When submitting pull requests, include one of the following 'tags' in the title:

* `[WIP]` - Work In Progress. The pull request will change, and there is no need
  to review it yet.
* `[RFC]` - Request For Comment. The request needs reviewing and/or comments.
* `[RDY]` - The request is ready to be merged. The request must have been
  reviewed by at least one person and have no outstanding issues.
* Default label is assumed to be `[WIP]` as long as there's no indication
  otherwise.

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
- The Travis build does not currently run the tests under valgrind, but we would
  strongly encourage you to do so locally.

#### Coding style

All code changes should follow the [Neovim style guide][style].

Please run [`clint.py`][clint] to detect style errors. It is not perfect and may
have false positives and negatives. To have `clint.py` ignore certain special
cases, put `// NOLINT` at the end of the line.

#### Commit messages

Follow the [Tim Pope Convention][commit] (@tpope) for commit messages. Most
importantly, do the following:

- Keep the first line a summary of 50 characters or less.
- Write the summary in the [imperative mood][imperative].
- Write a more detailed explanation (after a blank line) that explains more in
  depth (only if necessary).

Take a look at @elmart's [commits on Neovim][elmart] for examples.

[clint]: clint.py
[commit]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[entry]: https://github.com/neovim/neovim/issues?labels=entry-level&state=open
[elmart]: https://github.com/neovim/neovim/commits?author=elmart
[imperative]: http://en.wikipedia.org/wiki/Imperative_mood
[style]: http://neovim.org/develop/style-guide.xml
[waffle]: https://waffle.io/neovim/neovim
[wiki]: https://github.com/neovim/neovim/wiki/Contributing
