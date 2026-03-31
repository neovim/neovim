if vim.g.loaded_difftool ~= nil then
  return
end
vim.g.loaded_difftool = true

vim.api.nvim_create_user_command('DiffTool', function(opts)
  if #opts.fargs == 2 then
    require('difftool').open(opts.fargs[1], opts.fargs[2])
  else
    vim.notify('Usage: DiffTool <left> <right>', vim.log.levels.ERROR)
  end
end, { nargs = '*', complete = 'file' })

-- If we are in diff mode (e.g. `nvim -d file1 file2`), open the difftool automatically.
local function start_diff()
  if not vim.o.diff then
    return
  end
  local args = vim.v.argf
  if #args == 2 then
    vim.schedule(function()
      require('difftool').open(args[1], args[2])
    end)
  end
end
if vim.v.vim_did_enter > 0 then
  start_diff()
  return
end
vim.api.nvim_create_autocmd('VimEnter', {
  callback = start_diff,
})
