vim.api.nvim_create_user_command('Inspect', function(cmd)
  if cmd.bang then
    vim.pretty_print(vim.inspect_pos())
  else
    vim.show_pos()
  end
end, { desc = 'Inspect highlights and extmarks at the cursor', bang = true })
