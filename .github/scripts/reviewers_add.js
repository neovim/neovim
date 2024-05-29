module.exports = async ({ github, context }) => {
  const pr_data = await github.rest.pulls.get({
    owner: context.repo.owner,
    repo: context.repo.repo,
    pull_number: context.issue.number,
  });
  const labels = pr_data.data.labels.map((e) => e.name);
  const reviewers = new Set();

  if (labels.includes("build")) {
    reviewers.add("dundargoc");
    reviewers.add("jamessan");
    reviewers.add("justinmk");
  }

  if (labels.includes("ci")) {
    reviewers.add("dundargoc");
    reviewers.add("jamessan");
    reviewers.add("justinmk");
  }

  if (labels.includes("column")) {
    reviewers.add("lewis6991");
  }

  if (labels.includes("comment")) {
    reviewers.add("echasnovski");
  }

  if (labels.includes("defaults")) {
    reviewers.add("gpanders");
  }

  if (labels.includes("diagnostic")) {
    reviewers.add("gpanders");
  }

  if (labels.includes("diff")) {
    reviewers.add("lewis6991");
  }

  if (labels.includes("documentation")) {
    reviewers.add("clason");
  }

  if (labels.includes("editorconfig")) {
    reviewers.add("gpanders");
  }

  if (labels.includes("marks")) {
    reviewers.add("bfredl");
  }

  if (labels.includes("filetype")) {
    reviewers.add("clason");
    reviewers.add("gpanders");
  }

  if (labels.includes("inccommand")) {
    reviewers.add("famiu");
  }

  if (labels.includes("lsp")) {
    reviewers.add("MariaSolOs");
    reviewers.add("mfussenegger");
  }

  if (labels.includes("netrw")) {
    reviewers.add("justinmk");
  }

  if (labels.includes("options")) {
    reviewers.add("famiu");
  }

  if (labels.includes("platform:nix")) {
    reviewers.add("teto");
  }

  if (labels.includes("project-management")) {
    reviewers.add("bfredl");
    reviewers.add("justinmk");
  }

  if (labels.includes("snippet")) {
    reviewers.add("MariaSolOs");
  }

  if (labels.includes("statusline")) {
    reviewers.add("famiu");
  }

  if (labels.includes("test")) {
    reviewers.add("justinmk");
  }

  if (labels.includes("treesitter")) {
    reviewers.add("bfredl");
    reviewers.add("clason");
    reviewers.add("lewis6991");
    reviewers.add("wookayin");
  }

  if (labels.includes("tui")) {
    reviewers.add("gpanders");
  }

  if (labels.includes("typo")) {
    reviewers.add("dundargoc");
  }

  if (labels.includes("vim-patch")) {
    reviewers.add("seandewar");
    reviewers.add("zeertzjq");
  }

  // Remove person that opened the PR since they can't review themselves
  const pr_opener = pr_data.data.user.login;
  reviewers.delete(pr_opener);

  github.rest.pulls.requestReviewers({
    owner: context.repo.owner,
    repo: context.repo.repo,
    pull_number: context.issue.number,
    reviewers: Array.from(reviewers),
  });
};
