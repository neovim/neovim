## What's this?

A basic set of tools to ease adding review trailers, in order to acknowledge reviewers' work.

## Which trailers are to be added?

- `Helped-by: Full Name <email@address>`
   Added by regular users to particular commits within a PR. Applies to the commit it appears on. Means "this commit was somehow improved based on suggestions by @reviewer".
- `Reviewed-by: Full Name <email@address>`
   Added by maintainer to PR merge commit. Applies to whole PR. Means "these changes were carefully reviewed by @reviewer an he has stated conformity with them."

## Which tools are included, and how they help?

- **github_user_info**: Command line tool to transform GitHub usernames into `Full Name <email@address>` info.
  It's a bash script that uses GitHub API to look for the info. If user doesn't have a published email, it tries to find a matching one at local git repo. Successful results are cached locally to speed up subsequent requests for the same user.
  INSTALL: You need curl and jq for this work. Then, put the script in your path.

- **insert-github-user-info.vim**: Vim plugin to insert user info. It shells out to use previous script and inserts result in place.
  Type a username, Esc to normal mode, and press `<Leader>gu`. Username will be replace by user info.
  INSTALL: Put file in $NVIM_RUNTIME_PATH/plugin, or copy its contents into your $NVIMRC.

- **gitcommit.snippets**: UltiSnips templates to insert "Helped-by: " and "Reviewed-by: " headers.
  They will only fire when editing a git commit message, and at the beginning of a line.
  Press h (or r) and UltiSnips trigger.
  INSTALL: Put file under UltiSnips search path (usually $NVIM_RUNTIME_PATH/UltiSnips).

- **post_rewrite**: Git hook for automatic insertion of Helped-by trailers on rebase:
  This is done so that regular users dont' have to deal with trailers at all, as long as they follow a simple convention: Title review commits (commits introducing changes suggested by others, meant to be fixedup/squashed with original commits before merging) this way:
  `Review: <reviewer-github-username>: ...`.
  If you do that, when you fixup/squash that commit into other (through git rebase -i), corresponding Helped-by trailer will be automatically added.
  INSTALL: Put file in $GIT_DIR/hooks. Check it's executable. You need a git version recent enough to support interpret-trailers for this to work. You should also set `git config trailer.ifexists addIfDifferent`.

## Intended workflow

- User opens a PR.
- It receives comments from reviewers.
- User adds review commits titled as specified above to address reviewers comments he agrees on, and pushes to PR. This gets repeated until all reviewers have stated "LGTM".
- User reintegrates review commits into original commits (through git rebase -i), force-pushes to PR, and marks RDY. Helped-by trailers have automatically been added here.
- Maintainer adds Reviewed-by trailers to merge commit, and commits.

Note that's the usual workflow considered better, but others are equally supported. For example, you can reintegrate review commits and force push before being finished, if that's considered better for the PR at hand.
