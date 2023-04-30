vim.api.nvim_create_user_command('Inspect', function(cmd)
  if cmd.bang then
    vim.print(vim.inspect_pos())
  else
    vim.show_pos()
  end
end, { desc = 'Inspect highlights and extmarks at the cursor', bang = true })

vim.api.nvim_create_user_command('InspectTree', function(cmd)
  if cmd.mods ~= '' or cmd.count ~= 0 then
    local count = cmd.count ~= 0 and cmd.count or ''
    local new = cmd.mods ~= '' and 'new' or 'vnew'

    vim.treesitter.inspect_tree({
      command = ('%s %s%s'):format(cmd.mods, count, new),
    })
  else
    vim.treesitter.inspect_tree()
  end
end, { desc = 'Inspect treesitter language tree for buffer', count = true })

if vim.g.use_lua_gx == nil or vim.g.use_lua_gx == true then
  vim.keymap.set({ 'n', 'x' }, 'gx', function()
    local uri = vim.fn.expand('<cfile>')

    vim.ui.open(uri)
  end, { desc = 'Open URI under cursor with system app' })
end
