if vim.g.loaded_difftool ~= nil then
  return
end
vim.g.loaded_difftool = true

vim.api.nvim_create_user_command('DiffTool', function(opts)
  if #opts.fargs == 2 then
    require('difftool').open(opts.fargs[1], opts.fargs[2])
  elseif #opts.fargs == 0 then
    require('difftool').close()
  else
    vim.notify('Usage: DiffTool <left> <right>', vim.log.levels.ERROR)
  end
end, { nargs = '*', complete = 'file' })
