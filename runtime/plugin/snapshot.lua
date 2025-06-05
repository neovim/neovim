local snapshot = require('vim.snapshot')

vim.cmd([[
  highlight default DiffMarkerAdd    guifg=#00ff00 gui=bold
  highlight default DiffMarkerRemove guifg=#ff4444 gui=bold
]])

vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function(args)
    snapshot.capture_open_snapshot(args.buf)
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
  callback = function(args)
    snapshot.capture_save_snapshot(args.buf)
  end,
})

vim.api.nvim_create_user_command('DiffWithOpen', function(opts)
  local bufnr = tonumber(opts.args) or 0
  local result = snapshot.get_diff {
    bufnr = bufnr,
    against = 'open',
  }
  if result then
    snapshot.render_diff_view(result)
  else
    vim.notify('No diff available for buffer ' .. bufnr, vim.log.levels.ERROR)
  end
end, {
  nargs = '?',
  desc = 'Diff buffer against on open snapshot.',
})

vim.api.nvim_create_user_command('DiffWithSave', function(opts)
  local bufnr = tonumber(opts.args) or 0
  local result = snapshot.get_diff {
    bufnr = bufnr,
    against = 'save',
  }
  if result then
    snapshot.render_diff_view(result)
  else
    vim.notify('No diff available for buffer ' .. bufnr, vim.log.levels.ERROR)
  end
end, {
  nargs = '?',
  desc = 'Diff buffer against most recent save.',
})

vim.api.nvim_create_user_command('RestoreOpenSnap', function(opts)
  local bufnr = tonumber(opts.args) or 0
  snapshot.restore_snapshot(bufnr, 'open')
end, {
  nargs = '?',
  desc = 'Restore buffer from on open snapshot.',
})

vim.api.nvim_create_user_command('RestoreSaveSnap', function(opts)
  local bufnr = tonumber(opts.args) or 0
  snapshot.restore_snapshot(bufnr, 'save')
end, {
  nargs = '?',
  desc = 'Restore buffer from most recent save.',
})

vim.api.nvim_create_user_command('ExportDiffWithOpen', function(opts)
  local bufnr = tonumber(opts.args) or 0
  snapshot.export_diff(bufnr, 'open')
end, {
  nargs = '?',
  desc = 'Export diff against open snapshot to clipboard.',
})

vim.api.nvim_create_user_command('ExportDiffWithSave', function(opts)
  local bufnr = tonumber(opts.args) or 0
  snapshot.export_diff(bufnr, 'save')
end, {
  nargs = '?',
  desc = 'Export diff against most recent save to clipboard.',
})

vim.api.nvim_create_autocmd('LspAttach', {
  callback = function()
    require('vim.snapshot').register_lsp_commands()
  end,
})
