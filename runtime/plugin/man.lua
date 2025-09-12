if vim.g.loaded_man ~= nil then
  return
end
vim.g.loaded_man = true

vim.api.nvim_create_user_command('Man', function(params)
  local man = require('man')
  if params.bang then
    man.init_pager()
  else
    local _, err = pcall(man.open_page, params.count, params.smods, params.fargs)
    if err then
      vim.notify('man.lua: ' .. err, vim.log.levels.ERROR)
    end
  end
end, {
  bang = true,
  bar = true,
  range = true,
  addr = 'other',
  nargs = '*',
  complete = function(...)
    return require('man').man_complete(...)
  end,
})

local augroup = vim.api.nvim_create_augroup('nvim.man', {})

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = augroup,
  pattern = 'man://*',
  nested = true,
  callback = function(params)
    local err = require('man').read_page(assert(params.match:match('man://(.*)')))
    if err then
      vim.notify('man.lua: ' .. err, vim.log.levels.ERROR)
    end
  end,
})
