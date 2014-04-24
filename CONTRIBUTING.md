# Contributing to Neovim

## Thank you

Thanks for considering contributing to neovim. To make the process as smooth
as possible we would ask you to follow the guidelines below.

## Help with contributing

See [Communicating](https://github.com/neovim/neovim/wiki/Communicating).
Raise documentation issues.

## Guidelines

### Finding something to do

Neovim uses [waffle.io](https://waffle.io/neovim/neovim), so check there
first.

You can also ask for an issues to be assigned to you.
Ideally wait until we assign it to you to minimize
work duplication.

### Reporting an issue

- Search existing issues before raising a new one.
- Include as much detail as possible. In particular, we need to know which
  OS you're using.

### Pull requests

- Make it clear in the issue tracker what you are working on, so that
someone else doesn't duplicate the work.
- Use a feature branch, not master.
- Rebase your feature branch onto origin/master before raising the PR.
- Keep up to date with changes in master so your PR is easy to merge.
- Be descriptive in your PR message: what is it for, why is it needed, etc.
- Make sure the tests pass (TODO: we need to make this easier with travis etc.)
- Squash related commits as much as possible.

### Coding style

All code changes should follow the [neovim style guide](http://neovim.org/development-wiki/style-guide/style-guide.xml).

Please run `clint.py` to detect style errors. `clint.py` is Google's
[`cpplint.py`](http://google-styleguide.googlecode.com/svn/trunk/cppguide.xml#cpplint)
script modified with the neovim style guidelines. It is not perfect and may
have false positives and negatives, but is still a valuable tool. To have
`clint.py` ignore certain special cases, put `// NOLINT` at the end of the
line.

### Commit messages

TODO
