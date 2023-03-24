-- skip if nvim started non-interactively
if vim.tbl_contains(vim.v.argv, '-l') then return end

-- skip if user opts out of checking versions
if vim.g.NVIM_NO_NEWS then return end

-- skip prereleases altogether
if vim.version().prerelease == true then return end

local group = vim.api.nvim_create_augroup('versioncheck', {})
vim.api.nvim_create_autocmd('CursorHold', {
  group = group,
  desc = 'Tells user how to see changes when a new version is detected.',
  callback = function()
    require('versioncheck').check()
  end,
})

