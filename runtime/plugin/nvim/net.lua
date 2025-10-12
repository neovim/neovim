if vim.g.loaded_nvim_net_plugin ~= nil then
  return
end
vim.g.loaded_nvim_net_plugin = true

vim.api.nvim_create_autocmd({ 'BufReadCmd', 'FileReadCmd' }, {
  group = vim.api.nvim_create_augroup('nvim.net.remotefile', {}),
  pattern = { 'http://*', 'https://*' },
  desc = 'Edit remote files (:edit https://example.com)',
  callback = function(args)
    if vim.fn.executable('curl') ~= 1 then
      vim.notify(
        '[vim.net.request]: curl not found; remote URL loading disabled.',
        vim.log.levels.WARN
      )
      return true
    end

    -- FileReadCmd (:read) inserts in the current buffer. We mimic that
    -- behavior by writing the output to a scratch buffer and then copying it
    -- to the current buffer.
    local buf = args.event == 'BufReadCmd' and args.buf or vim.api.nvim_create_buf(false, true)

    local url = args.file
    vim.notify(('Fetching %s …'):format(url), vim.log.levels.INFO)

    vim.net.request(
      url,
      { retry = 3, outbuf = buf },
      vim.schedule_wrap(function(err, _)
        if args.event == 'FileReadCmd' then
          local current_line, _ = unpack(vim.api.nvim_win_get_cursor(0))
          local response = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          vim.api.nvim_buf_set_lines(0, current_line, current_line, true, response)
          vim.api.nvim_buf_delete(buf, { force = true })
        end
        local lvl = err and vim.log.levels.ERROR or vim.log.levels.INFO
        local msg = err and ('Failed to fetch %s: %s'):format(url, err) or ('Loaded %s'):format(url)
        vim.notify(msg, lvl)
      end)
    )
  end,
})
