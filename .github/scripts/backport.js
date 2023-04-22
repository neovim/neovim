module.exports = async ({ github, context }) => {
  const commenter = context.actor;
  const issue = await github.rest.issues.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
  });
  const labels = issue.data.labels.map((e) => e.name);

  backport = false;
  branch_name = "";
  for (const e of labels) {
    if (e.startsWith("backport")) {
      backport = true;
      branch_name = e.split(" ")[1];
    }
  }

  if (backport) {
    console.log(branch_name);
  }
};
