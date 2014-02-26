# Third party dependencies for neovim

This directory contains any third party dependencies for neovim which, for one
reason or another, we cannot rely on the system to supply.

Ideally commits within this directory will only be merge commits from upstream
projects. The "git subtree" tool is a good choice for managing such merge
commits. In order to avoid needlessly inflating the bandwidth required to clone
neovim, the ``--squash`` option for git subtree should be used.
