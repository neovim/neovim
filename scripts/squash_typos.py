#!/usr/bin/env python
"""

This script squashes a PR tagged with the "typo" label into a single, dedicated
"squash PR".

"""

import subprocess
import sys
import os


def get_authors_and_emails_from_pr():
    """

    Return all contributing authors and their emails for the PR on current branch.
    This includes co-authors, meaning that if two authors are credited for a
    single commit, which is possible with GitHub, then both will get credited.

    """

    # Get a list of all authors involved in the pull request (including co-authors).
    authors = subprocess.check_output(
        [
            "gh",
            "pr",
            "view",
            os.environ["PR_NUMBER"],
            "--json",
            "commits",
            "--jq",
            ".[][].authors.[].name",
        ],
        text=True,
    ).splitlines()

    # Get a list of emails of the aforementioned authors.
    emails = subprocess.check_output(
        [
            "gh",
            "pr",
            "view",
            os.environ["PR_NUMBER"],
            "--json",
            "commits",
            "--jq",
            ".[][].authors.[].email",
        ],
        text=True,
    ).splitlines()

    authors_and_emails = [(author, mail) for author, mail in zip(authors, emails)]

    return authors_and_emails


def rebase_onto_pr():
    """

    Rebase current branch onto the PR.

    """

    # Check out the pull request.
    subprocess.call(["gh", "pr", "checkout", os.environ["PR_NUMBER"]])

    rebase_onto_master()

    # Change back to the original branch.
    subprocess.call(["git", "switch", "-"])

    # Rebase onto the pull request, aka include the commits in the pull request
    # in the current branch. Abort with error message if rebase fails.

    try:
        subprocess.check_call(["git", "rebase", "-"])
    except subprocess.CalledProcessError:
        subprocess.call(["git", "rebase", "--abort"])
        squash_url = subprocess.check_output(
            ["gh", "pr", "view", "--json", "url", "--jq", ".url"], text=True
        ).strip()

        subprocess.call(
            [
                "gh",
                "pr",
                "comment",
                os.environ["PR_NUMBER"],
                "--body",
                f"Your edit conflicts with an already scheduled fix \
                ({squash_url}). Please check that batch PR whether your fix is \
                already included; if not, then please wait until the batch PR \
                is merged and then rebase your PR on top of master.",
            ]
        )

        sys.exit(
            f"\n\nERROR: Your edit conflicts with an already scheduled fix \
{squash_url} \n\n"
        )


def rebase_onto_master():
    """

    Rebase current branch onto the master i.e. make sure current branch is up
    to date. Abort on error.

    """

    default_branch = f"{os.environ['GITHUB_BASE_REF']}"
    subprocess.check_call(["git", "rebase", default_branch])


def squash_all_commits(message_body_before):
    """

    Squash all commits on the PR into a single commit. Credit all authors by
    name and email.

    """

    default_branch = f"{os.environ['GITHUB_BASE_REF']}"
    subprocess.call(["git", "reset", "--soft", default_branch])

    authors_and_emails = get_authors_and_emails_from_pr()
    commit_message_coauthors = (
        "\n"
        + "\n".join([f"Co-authored-by: {i[0]} <{i[1]}>" for i in authors_and_emails])
        + "\n"
        + message_body_before
    )
    subprocess.call(
        ["git", "commit", "-m", "chore: typo fixes", "-m", commit_message_coauthors]
    )


def force_push(branch):
    """

    Like the name implies, force push <branch>.

    """

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


def checkout_branch(branch):
    """

    Create and checkout <branch>. Check if branch exists on remote, if so then
    sync local branch to remote.

    Return True if remote branch exists, else False.

    """

    # FIXME I'm not sure why the local branch isn't tracking the remote branch
    # automatically. This works but I'm pretty sure it can be done in a more
    # "elegant" fashion

    show_ref_output = subprocess.check_output(["git", "show-ref"], text=True).strip()

    if branch in show_ref_output:
        subprocess.call(["git", "checkout", "-b", branch, f"origin/{branch}"])
        return True

    subprocess.call(["git", "checkout", "-b", branch])
    return False


def get_all_pr_urls(pr_branch_exists):
    """

    Return a list of URLs for the pull requests with the typo fixes. If a
    squash branch exists then extract the URLs from the body text.

    """

    all_pr_urls = ""
    if pr_branch_exists:
        all_pr_urls += subprocess.check_output(
            ["gh", "pr", "view", "--json", "body", "--jq", ".body"], text=True
        )

    all_pr_urls += subprocess.check_output(
        ["gh", "pr", "view", os.environ["PR_NUMBER"], "--json", "url", "--jq", ".url"],
        text=True,
    ).strip()

    return all_pr_urls


def main():
    pr_branch = "marvim/squash-typos"

    pr_branch_exists = checkout_branch(pr_branch)

    rebase_onto_master()
    force_push(pr_branch)

    message_body_before = "\n".join(
        subprocess.check_output(
            ["git", "log", "--format=%B", "-n1", pr_branch], text=True
        ).splitlines()[2:]
    )

    rebase_onto_pr()
    force_push(pr_branch)

    subprocess.call(
        [
            "gh",
            "pr",
            "create",
            "--fill",
            "--head",
            pr_branch,
            "--title",
            "chore: typo fixes (automated)",
        ],
        text=True,
    )

    squash_all_commits(message_body_before)
    force_push(pr_branch)

    all_pr_urls = get_all_pr_urls(pr_branch_exists)
    subprocess.call(["gh", "pr", "edit", "--add-label", "typo", "--body", all_pr_urls])

    subprocess.call(["gh", "pr", "close", os.environ["PR_NUMBER"]])

    squash_url = subprocess.check_output(
        ["gh", "pr", "view", "--json", "url", "--jq", ".url"], text=True
    ).strip()
    subprocess.call(
        [
            "gh",
            "pr",
            "comment",
            os.environ["PR_NUMBER"],
            "--body",
            f"Thank you for your contribution! We collect all typo fixes \
                into a single pull request and merge it once it gets big enough: \
                {squash_url}",
        ]
    )


if __name__ == "__main__":
    main()
