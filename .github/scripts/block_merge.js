module.exports = async ({ github, context }) => {
  const issue = await github.rest.issues.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
  });
  const labels = issue.data.labels.map((e) => e.name);

  error = labels.includes("DO NOT MERGE") || labels.includes("typo");

  if (error) {
    process.exit(1);
  }
};
