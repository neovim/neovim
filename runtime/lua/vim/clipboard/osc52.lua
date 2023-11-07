local M = {}

function M.copy(lines)
  local s = table.concat(lines, '\n')
  io.stdout:write(string.format('\x1b]52;;%s\x1b\\', vim.base64.encode(s)))
end

function M.paste()
  local contents = nil
  local id = vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(args)
      local resp = args.data ---@type string
      local encoded = resp:match('\x1b%]52;%w?;([A-Za-z0-9+/=]*)')
      if encoded then
        contents = vim.base64.decode(encoded)
        return true
      end
    end,
  })

  io.stdout:write('\x1b]52;;?\x1b\\')

  vim.wait(1000, function()
    return contents ~= nil
  end)

  -- Delete the autocommand if it didn't already delete itself
  pcall(vim.api.nvim_del_autocmd, id)

  if contents then
    return vim.split(contents, '\n')
  end

  vim.notify('Timed out waiting for a clipboard response from the terminal', vim.log.levels.WARN)
  return 0
end

return M
