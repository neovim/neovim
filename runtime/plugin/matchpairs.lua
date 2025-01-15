if vim.g.loaded_matchpairs_plugin ~= nil then
  return
end
vim.g.loaded_matchpairs_plugin = true

-- loaded_matchit is used in ftplugin files to detect matchit
-- TODO: untested yet
vim.g.loaded_matchit = true


vim.keymap.set('n', 'H', function()
  require('vim._matchpairs').match_syntax()
end)

vim.keymap.set('n', 'gH', function()
  require('vim._matchpairs').match_syntax(true)
end)

local augroup = vim.api.nvim_create_augroup('nvim.matchpairs', {})

vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinEnter' }, {
  callback = vim.schedule_wrap(function ()
    require('vim._matchpairs').highlight()
  end),
  group = augroup,
})

-- TODO: backwards compatibility commands
-- :NoMatchParen
-- :DoMatchParen
-- :let matchparen_disable_cursor_hl = 1
-- :let loaded_matchparen = 1 ?

vim.api.nvim_create_user_command('NoMatchPairs', function ()
  vim.api.nvim_del_augroup_by_id(augroup)
  vim.cmd[[DoMatchParen]]
end, {})
