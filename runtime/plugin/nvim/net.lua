vim.g.loaded_remote_file_loader = true

--- Callback for BufReadCmd on remote URLs.
--- @param args { buf: integer }
local function on_remote_read(args)
  if vim.fn.executable('curl') ~= 1 then
    vim.api.nvim_echo({
      { 'Warning: `curl` not found; remote URL loading disabled.', 'WarningMsg' },
    }, true, {})
    return true
  end

  local bufnr = args.buf
  local url = vim.api.nvim_buf_get_name(bufnr)
  local view = vim.fn.winsaveview()

  vim.api.nvim_echo({ { 'Fetching ' .. url .. ' …', 'MoreMsg' } }, true, {})

  vim.net.request(
    url,
    { retry = 3 },
    vim.schedule_wrap(function(err, content)
      if err then
        vim.notify('Failed to fetch ' .. url .. ': ' .. tostring(err), vim.log.levels.ERROR)
        vim.fn.winrestview(view)
        return
      end

      local lines = vim.split(content.body, '\n', { plain = true })
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)

      vim.fn.winrestview(view)
      vim.api.nvim_echo({ { 'Loaded ' .. url, 'Normal' } }, true, {})
    end)
  )
end

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = vim.api.nvim_create_augroup('nvim.net.remotefile', {}),
  pattern = { 'http://*', 'https://*' },
  desc = 'Edit remote files (:edit https://example.com)',
  callback = on_remote_read,
})
