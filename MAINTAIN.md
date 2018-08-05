Maintaining the Neovim project
==============================

Notes on maintaining the Neovim project.

See also: https://github.com/git/git/blob/master/Documentation/howto/maintain-git.txt

Ticket Triage
-------------

In practice we haven't found a meaningful way to forecast more precisely than
"next" and "after next". That means there are usually one or two (at most)
planned milestones:

- Next bugfix-release (1.0.x)
- Next feature-release (1.x.0)

The forecasting problem might be solved with an explicit priority system (like
Bram's todo.txt). Meanwhile the Neovim priority system is defined by:

- PRs nearing completion (RDY).
- Issue labels. E.g. the +plan label increases the ticket's priority merely for
  having a plan written down: it is _closer to completion_ than tickets without
  a plan.
- Comment activity or new information.

Anything that isn't in the next milestone, and doesn't have a RDY PR ... is
just not something you care very much about, by construction. Post-release you
can review open issues, but chances are your next milestone is already getting
full :)

Release Policy
--------------

The goal is "early and often".

Up to now we use only one branch, the `master` branch.

- If `master` is unstable we don't release.
- If the last release has a major bug, we:
  1. Fix the bug on `master`.
  2. Disable or remove any known risks present on `master`.
  3. Cut a release from `master`.

This is a bit silly, but it works ok. And it keeps `master` from biting off
more feature-creep than it can chew.

See also: https://github.com/neovim/neovim/issues/862
