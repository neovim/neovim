module.exports = async ({github, context}) => {
  const pr_data = await github.rest.pulls.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    pull_number: context.issue.number
  })
  const labels = pr_data.data.labels.map(e => e.name)

  const reviewers = new Set()
  if (labels.includes('api')) {
    reviewers.add("bfredl")
    reviewers.add("muniter")
  }

  if (labels.includes('build')) {
    reviewers.add("jamessan")
  }

  if (labels.includes('ci')) {
    reviewers.add("jamessan")
  }

  if (labels.includes('column')) {
    reviewers.add("lewis6991")
  }

  if (labels.includes('diagnostic')) {
    reviewers.add("gpanders")
  }

  if (labels.includes('diff')) {
    reviewers.add("lewis6991")
  }

  if (labels.includes('dependencies')) {
    reviewers.add("jamessan")
  }

  if (labels.includes('distribution')) {
    reviewers.add("jamessan")
  }

  if (labels.includes('documentation')) {
    reviewers.add("clason")
  }

  if (labels.includes('extmarks')) {
    reviewers.add("bfredl")
  }

  if (labels.includes('filetype')) {
    reviewers.add("clason")
    reviewers.add("gpanders")
  }

  if (labels.includes('gui')) {
    reviewers.add("glacambre")
    reviewers.add("smolck")
  }

  if (labels.includes('lsp')) {
    reviewers.add("mfussenegger")
  }

  if (labels.includes('treesitter')) {
    reviewers.add("bfredl")
    reviewers.add("vigoux")
  }

  if (labels.includes('typo')) {
    reviewers.add("dundargoc")
  }

  if (labels.includes('ui')) {
    reviewers.add("bfredl")
  }

  if (labels.includes('vim-patch')) {
    reviewers.add("seandewar")
    reviewers.add("zeertzjq")
  }

  // Remove person that opened the PR since they can't review themselves
  const pr_opener = pr_data.data.user.login
  reviewers.delete(pr_opener)

  github.rest.pulls.requestReviewers({
    owner: context.repo.owner,
    repo: context.repo.repo,
    pull_number: context.issue.number,
    reviewers: Array.from(reviewers)
  });
}
