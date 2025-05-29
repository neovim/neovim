local M = {}

--- Return the OSC 52 escape sequence
---
--- @param clipboard string The clipboard to read from or write to
--- @param contents string The Base64 encoded contents to write to the clipboard, or '?' to read
---                        from the clipboard
local function osc52(clipboard, contents)
  return string.format('\027]52;%s;%s\027\\', clipboard, contents)
end

---@class clipboard_cache
---
---@field lines_str string String representation of lines passed to the copy() function
---@field regtype string regtype argument passed to the copy() function
---
---@type table<string, clipboard_cache>
M.cache = {}

-- When OSC 52 lines are the same as our cache, return our cache regtype
local function get_regtype(reg, lines_str)
  local cb_cache = M.cache[reg]
  if cb_cache then
    if cb_cache.lines_str == lines_str then
      return cb_cache.regtype
    end
  end
  return ''
end

function M.copy(reg)
  local clipboard = reg == '+' and 'c' or 'p'
  ---@param regtype string
  return function(lines, regtype)
    local s = table.concat(lines, '\n')
    M.cache[reg] = {
      lines_str = s,
      regtype = regtype,
    }
    -- The data to be written here can be quite long.
    -- Use nvim_chan_send() as io.stdout:write() doesn't handle EAGAIN. #26688
    vim.api.nvim_chan_send(2, osc52(clipboard, vim.base64.encode(s)))
  end
end

function M.paste(reg)
  local clipboard = reg == '+' and 'c' or 'p'
  return function()
    local contents = nil
    local id = vim.api.nvim_create_autocmd('TermResponse', {
      callback = function(args)
        local resp = args.data.sequence ---@type string
        local encoded = resp:match('\027%]52;%w?;([A-Za-z0-9+/=]*)')
        if encoded then
          contents = vim.base64.decode(encoded)
          return true
        end
      end,
    })

    io.stdout:write(osc52(clipboard, '?'))

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
    local regtype = get_regtype(reg, contents)
    return { vim.split(assert(contents), '\n'), regtype }
  end
end

return M
