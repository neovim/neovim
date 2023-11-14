local M = {}

function M.copy(lines)
  local s = table.concat(lines, '\n')
  io.stdout:write(string.format('\027]52;;%s\027\\', vim.base64.encode(s)))
end

function M.paste()
  local contents = nil
  local id = vim.api.nvim_create_autocmd('TermResponse', {
    callback = function(args)
      local resp = args.data ---@type string
      local encoded = resp:match('\027%]52;%w?;([A-Za-z0-9+/=]*)')
      if encoded then
        contents = vim.base64.decode(encoded)
        return true
      end
    end,
  })

  io.stdout:write('\027]52;;?\027\\')

  local ok, res

  -- Wait 1s first for terminals that respond quickly
  ok, res = vim.wait(1000, function()
    return contents ~= nil
  end)

  if res == -1 then
    -- If no response was received after 1s, print a message and keep waiting
    vim.api.nvim_echo(
      { { 'Waiting for OSC 52 response from the terminal. Press Ctrl-C to interrupt...' } },
      false,
      {}
    )
    ok, res = vim.wait(9000, function()
      return contents ~= nil
    end)
  end

  if not ok then
    vim.api.nvim_del_autocmd(id)
    if res == -1 then
      vim.notify(
        'Timed out waiting for a clipboard response from the terminal',
        vim.log.levels.WARN
      )
    elseif res == -2 then
      -- Clear message area
      vim.api.nvim_echo({ { '' } }, false, {})
    end
    return 0
  end

  -- If we get here, contents should be non-nil
  return vim.split(assert(contents), '\n')
end

return M
