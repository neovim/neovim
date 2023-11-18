if vim.g.versioncheck == false then
  return
end

-- detect non-interactive startups
if vim.tbl_contains(vim.v.argv, '-l') then
  return
end

-- startup with -i NONE means no shada file read or written, so bail
if vim.tbl_contains(vim.v.argv, '-i NONE') then
  return
end

-- missing '!' in shada option means no storing/reading of global vars
if not vim.o.shada:match('!') then
  return
end

if vim.version().prerelease ~= true then
  return
end

vim.g.versioncheck = {}

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
