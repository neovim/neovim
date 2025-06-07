if vim.g.loaded_remote_file_loader ~= nil then
  return
end
vim.g.loaded_remote_file_loader = true

if not vim.net or type(vim.net.request) ~= 'function' then
  vim.api.nvim_echo({
    { 'Warning: vim.net.request is not available. Remote file loading disabled.', 'WarningMsg' },
  }, true, {})
  return
end

local autocmd_group = vim.api.nvim_create_augroup('NetRemoteFile', { clear = true })

vim.api.nvim_create_autocmd('BufReadCmd', {
  group = autocmd_group,
  pattern = {
    'http://*',
    'https://*',
  },
  desc = 'Asynchronously load remote files via vim.net.request',
  callback = function(args)
    local bufnr = args.buf
    local url = vim.api.nvim_buf_get_name(bufnr)
    local view = vim.fn.winsaveview()

    vim.api.nvim_echo({ { 'Fetching ' .. url .. '...', 'MoreMsg' } }, true, {})

    vim.net.request(
      url,
      {},
      vim.schedule_wrap(function(err, content)
        if err then
          vim.notify('Failed to fetch ' .. url .. ': ' .. tostring(err), vim.log.levels.ERROR)
          vim.fn.winrestview(view)
          return
        end

        local text = vim.split(content, '\n', { plain = true })

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, text)

        vim.fn.winrestview(view)
        vim.api.nvim_echo({ { 'Loaded ' .. url, 'Normal' } }, true, {})
      end)
    )
  end,
})
