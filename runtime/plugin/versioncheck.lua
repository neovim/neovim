if not vim.g.versioncheck then
  return
end

-- detect non-interactive startups
if vim.tbl_contains(vim.v.argv, '-l') then
  return
end

if vim.version().prerelease ~= true then
  return
end

local augroup = vim.api.nvim_create_augroup('versioncheck', {})
vim.api.nvim_create_autocmd('CursorHold', {
  group = augroup,
  desc = 'Tell user about news.txt changes.',
  callback = function()
    require('versioncheck').check_for_news()
  end,
  once = true,
  nested = true,
})
