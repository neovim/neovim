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

- Use the 'hybrid' style described [here](https://gist.github.com/davidzchen/9188090). Get a `.editorconfig` for it [here](https://gist.github.com/ashleyh/9292108)
- Don't abuse the pre-processor.
- Don't mix platform-specific stuff into the main code.
- TODO: commit messages?
