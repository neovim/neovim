#!/usr/bin/env python

import subprocess
import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("typo_branch_name")
    args = parser.parse_args()

    subprocess.call(["git", "checkout", "-b", args.typo_branch_name])

    # Get a list of pull-request numbers for all pull-requests with
    # the label "typo".
    typo_pull_request_numbers = subprocess.check_output(
        [
            "gh",
            "pr",
            "list",
            "--label",
            "typo",
            "--json",
            "number",
            "--jq",
            ".[].number",
        ],
        text=True,
    ).split()

    total_number_of_commits = 0

    author_mail_tuple = []
    for pr in typo_pull_request_numbers:
        # Get a list of all authors involved in the pull request (including co-authors).
        authors = subprocess.check_output(
            [
                "gh",
                "pr",
                "view",
                pr,
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
                pr,
                "--json",
                "commits",
                "--jq",
                ".[][].authors.[].email",
            ],
            text=True,
        ).splitlines()

        author_mail_tuple.extend(
            [(author, mail) for author, mail in zip(authors, emails)]
        )

        number_of_commits = int(
            subprocess.check_output(
                ["gh", "pr", "view", pr, "--json", "commits", "--jq", ".[] | length"]
            )
        )
        total_number_of_commits += number_of_commits

        # Check out the pull request.
        subprocess.call(["gh", "pr", "checkout", "--force", pr])

        # Change back to the original branch.
        subprocess.call(["git", "switch", "-"])

        # Rebase onto(?) the pull request, aka include the commits in the pull
        # request in the current branch.
        subprocess.call(["git", "rebase", "-"])

    # Squash all added commits.
    subprocess.call(["git", "reset", "--soft", "HEAD~" + str(total_number_of_commits)])

    author_mail_tuple = sorted(set(author_mail_tuple))
    commit_message_coauthors = "\n" + "\n".join(
        [f"Co-authored-by: {i[0]} <{i[1]}>" for i in author_mail_tuple]
    )

    subprocess.call(
        ["git", "commit", "-m", "Multiple typo fixes", "-m", commit_message_coauthors]
    )

    # Close PR:s at the end of the script so they aren't closed prematurely in case
    # an error occurs and the script aborts midway.
    for pr in typo_pull_request_numbers:
        subprocess.call(["gh", "pr", "close", pr])


if __name__ == "__main__":
    main()
