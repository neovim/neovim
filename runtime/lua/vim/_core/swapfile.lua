local api = vim.api
local N_ = vim.fn.gettext

local M = {}

--- Renders a swap file as a multi-line block:
--- ```
--- %home%foo%bar%README.md.swl
---              dated: Thu Apr 23 17:25:52 2026
---          file name: ~foo/bar/README.md
---           modified: no
---          user name: justin   host name: minime
---         process ID: 10521 (STILL RUNNING)
--- ```
--- @param path string
--- @return string
local function format_swap(path)
  local info = vim.fn.swapinfo(path)
  local mtime = info.mtime and vim.fn.strftime('%a %b %d %H:%M:%S %Y', info.mtime) or '?'
  local lines = {
    vim.fs.basename(path),
    ('             dated: %s'):format(mtime),
  }
  if info.error then
    lines[#lines + 1] = ('         [%s]'):format(info.error)
  else
    lines[#lines + 1] = ('         file name: %s'):format(
      info.fname == '' and '[No Name]' or info.fname
    )
    lines[#lines + 1] = ('          modified: %s'):format(info.dirty == 1 and 'YES' or 'no')
    if info.user ~= '' or info.host ~= '' then
      local parts = {} ---@type string[]
      if info.user ~= '' then
        parts[#parts + 1] = ('user name: %s'):format(info.user)
      end
      if info.host ~= '' then
        parts[#parts + 1] = ('host name: %s'):format(info.host)
      end
      lines[#lines + 1] = ('         %s'):format(table.concat(parts, '   '))
    end
    if info.pid > 0 then
      lines[#lines + 1] = ('        process ID: %d (STILL RUNNING)'):format(info.pid)
    end
  end
  return table.concat(lines, '\n')
end

--- Implements `:recover` (when there are multiple swap files): let the user pick via vim.ui.select().
---
--- async: returns immediately, then schedules `:recover {path}` on the chosen swapfile.
---
--- @param items string[] List of swapfile paths.
function M.select_swap(items)
  vim.ui.select(items, {
    prompt = N_('Select a swapfile:'),
    kind = 'swap',
    format_item = format_swap,
  }, function(_, idx)
    if not idx then
      return
    end
    -- Queue ":recover! <swapfile>" as user input, so the recursive recovery runs via the normal
    -- input-dispatch loop. Using vim.schedule + vim.cmd can hang bc of "Press ENTER".
    vim.fn.feedkeys(
      vim.keycode(('<Cmd>recover! %s<CR>'):format(vim.fn.fnameescape(items[idx]))),
      'in'
    )
  end)
end

--- Implements `nvim -r` (no arg): list every swapfile found in 'directory'.
---
--- @param items string[] List of swapfile paths.
function M.list_swaps(items)
  local lines = { { N_('Swap files found:') .. '\n' } } ---@type [string][]
  if #items == 0 then
    lines[#lines + 1] = { '   ' .. N_('-- none --') }
  else
    for i, path in ipairs(items) do
      lines[#lines + 1] = { ('%d. %s\n'):format(i, format_swap(path)) }
    end
  end
  api.nvim_echo(lines, false, {})
end

return M
