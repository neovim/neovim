# Contributing to Neovim

## Thank you

Thanks for considering contributing to Neovim.
To make the process as smooth as possible we would ask you to follow
the guidelines below.
If you need support see [the wiki](https://github.com/neovim/neovim/wiki/Contributing).

## Issues

- Search existing issues before raising a new one.
- Include as much detail as possible. In particular, we need to know which
  OS you're using.

## Pull requests

### For all PRs

- Make it clear in the issue tracker what you are working on, so that
  someone else doesn't duplicate the work.
- Be descriptive in your PR message: what is it for, why is it needed, etc.
- Don't make cosmetic changes to unrelated files in the same PR.

#### Tagging in the issue tracker

When submitting pull requests, include one of the following 'tags' in the title:

* `[WIP]` - Work In Progress. The pull request will change, and there is no need
  to review it yet.
* `[RFC]` - Request For Comment. The request needs reviewing and/or comments.
* `[RDY]` - The request is ready to be merged. The request must have been
  reviewed by at least one person and have no outstanding issues.

This lets people quickly see the status of the PR, and reduces the risk of
merging requests that are not yet ready or reviewed.  By tagging, you'll also
save reviewers and mergers some work.

If a pull request doesn't have a tag, it's considered `WIP` as long as there are
no comments indicating it's `RFC` or `RDY`.

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

All code changes should follow the [Neovim style guide](http://neovim.org/development-wiki/style-guide/style-guide.xml).

Please run `clint.py` to detect style errors. `clint.py` is Google's
[`cpplint.py`](http://google-styleguide.googlecode.com/svn/trunk/cppguide.xml#cpplint)
script modified with the neovim style guidelines. It is not perfect and may
have false positives and negatives, but is still a valuable tool. To have
`clint.py` ignore certain special cases, put `// NOLINT` at the end of the
line.
