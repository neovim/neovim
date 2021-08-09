#!/usr/bin/env python
"""

This script squashes a PR tagged with the "typo" label into a single, dedicated
"squash PR".

"""

import subprocess
import os
import re


def get_authors_and_emails_from_pr():
    """

    For a given PR number, returns all contributing authors and their emails
    for that PR. This includes co-authors, meaning that if two authors are
    credited for a single commit, which is possible with GitHub, then both will
    get credited.

    """

    # Get a list of all authors involved in the pull request (including co-authors).
    authors = subprocess.check_output(
        ["gh", "pr", "view", "--json", "commits", "--jq", ".[][].authors.[].name"],
        text=True,
    ).splitlines()

    # Get a list of emails of the aforementioned authors.
    emails = subprocess.check_output(
        ["gh", "pr", "view", "--json", "commits", "--jq", ".[][].authors.[].email"],
        text=True,
    ).splitlines()

    return [(author, mail) for author, mail in zip(authors, emails)]


def rebase_onto_pr(pr, squash_branch):
    """

    Add all commits from PR into current branch. This is done by rebasing
    current branch onto the PR.

    """

    # Check out the pull request.
    subprocess.call(["gh", "pr", "checkout", pr])

    pr_branch_name = subprocess.check_output(
        ["git", "branch", "--show-current"], text=True
    ).strip()

    # Change back to the original branch.
    subprocess.call(["git", "switch", squash_branch])

    # Rebase onto the pull request, aka include the commits in the pull
    # request in the current branch.
    subprocess.call(["git", "rebase", pr_branch_name])


def squash_all_commits():
    """

    Squash all commits into a single commit. Credit all authors by name and
    email.

    """

    authors_and_emails = get_authors_and_emails_from_pr()
    subprocess.call(["git", "reset", "--soft", f"{os.environ['GITHUB_BASE_REF']}"])

    authors_and_emails = sorted(set(authors_and_emails))
    commit_message_coauthors = "\n" + "\n".join(
        [f"Co-authored-by: {i[0]} <{i[1]}>" for i in authors_and_emails]
    )
    subprocess.call(
        ["git", "commit", "-m", "chore: typo fixes", "-m", commit_message_coauthors]
    )


def force_push(branch):
    gh_actor = os.environ["GITHUB_ACTOR"]
    gh_token = os.environ["GITHUB_TOKEN"]
    gh_repo = os.environ["GITHUB_REPOSITORY"]
    subprocess.call(
        [
            "git",
            "push",
            "--force",
            f"https://{gh_actor}:{gh_token}@github.com/{gh_repo}",
            branch,
        ]
    )


def main():
    squash_branch = "marvim/squash-typos"
    all_pr_urls = ""

    pr_number = re.sub(r"\D", "", os.environ["GITHUB_REF"])

    show_ref_output = subprocess.check_output(["git", "show-ref"], text=True).strip()

    if squash_branch in show_ref_output:
        subprocess.call(
            ["git", "checkout", "-b", squash_branch, f"origin/{squash_branch}"]
        )
        squash_branch_exists = True

        all_pr_urls += subprocess.check_output(
            ["gh", "pr", "view", "--json", "body", "--jq", ".body"], text=True
        )
    else:
        subprocess.call(["git", "checkout", "-b", squash_branch])
        squash_branch_exists = False

    all_pr_urls += subprocess.check_output(
        ["gh", "pr", "view", pr_number, "--json", "url", "--jq", ".url"], text=True
    ).strip()

    rebase_onto_pr(pr_number, squash_branch)
    force_push(squash_branch)

    subprocess.call(["gh", "pr", "close", pr_number])

    squash_all_commits()
    force_push(squash_branch)

    if not squash_branch_exists:
        subprocess.call(
            [
                "gh",
                "pr",
                "create",
                "--fill",
                "--head",
                squash_branch,
                "--title",
                "Dedicated PR for all typo fixes.",
            ]
        )

    subprocess.call(["gh", "pr", "edit", "--add-label", "typo", "--body", all_pr_urls])


if __name__ == "__main__":
    main()
