local a = vim.api
_G.a = vim.api
local luadev = require'luadev'
local ssp = _G.ssp or {}
_G.ssp = ssp

ssp.ns = a.nvim_create_namespace("ssp")

function ssp.start(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  ssp.bufnr = bufnr
  ssp.sched = false
  ssp.reset()
  a.nvim_buf_attach(bufnr, false, {on_bytes=function(...)
    ssp.on_bytes(...)
  end})
end

function ssp.reset()
  local text = a.nvim_buf_get_lines(ssp.bufnr, 0, -1, true)
  local bytes = table.concat(text, '\n') .. '\n'
  ssp.shadow = bytes
  ssp.dirty = false
  a.nvim_buf_clear_namespace(ssp.bufnr, ssp.ns, 0, -1)
end

function ssp.on_bytes(_, buf, tick, start_row, start_col, start_byte, old_row, old_col, old_byte, new_row, new_col, new_byte)
  local before = string.sub(ssp.shadow, 1, start_byte)
  -- assume no text will contain 0xff bytes (invalid UTF-8)
  -- so we can use it as marker for unknown bytes
  local unknown = string.rep('\255', new_byte)
  local after = string.sub(ssp.shadow, start_byte + old_byte + 1)
  ssp.shadow = before .. unknown .. after
  if not ssp.sched then
    vim.schedule(ssp.show)
    ssp.sched = true
  end

  vim.schedule(function()
    luadev.print(vim.inspect{start_row, start_col, start_byte, old_row, old_col, old_byte, new_row, new_col, new_byte})
  end)
end

function ssp.sync()
  local text = a.nvim_buf_get_lines(ssp.bufnr, 0, -1, true)
  local bytes = table.concat(text, '\n') .. '\n'
  for i = 1, string.len(ssp.shadow) do
    local shadowbyte = string.sub(ssp.shadow, i, i)
    if shadowbyte ~= '\255' then
      if string.sub(bytes, i, i) ~= shadowbyte then
        error(i)
      end
    end
  end
end

function ssp.show()
  ssp.sched = false
  a.nvim_buf_clear_namespace(ssp.bufnr, ssp.ns, 0, -1)
  local text = a.nvim_buf_get_lines(ssp.bufnr, 0, -1, true)
  local bytes = table.concat(text, '\n') .. '\n'
  local line, lastpos = 0, 0
  for i = 1, string.len(ssp.shadow) do
    local textbyte = string.sub(bytes, i, i)
    if textbyte == '\n' then
      line = line + 1
      lastpos = i
    end
    local shadowbyte = string.sub(ssp.shadow, i, i)
    pcall(function()
      if shadowbyte ~= '\255' then
        if textbyte ~= shadowbyte then
            a.nvim_buf_set_virtual_text(ssp.bufnr, ssp.ns, line, {{"ERR", "ErrorMsg"}}, {})
            a.nvim_buf_add_highlight(ssp.bufnr, ssp.ns, "ErrorMsg", line, i-lastpos-1, i-lastpos)
        end
      else
        if i - lastpos == 0 then
          a.nvim_buf_set_virtual_text(ssp.bufnr, ssp.ns, line-1, {{" ", "RedrawDebugComposed"}}, {})
        else
          a.nvim_buf_add_highlight(ssp.bufnr, ssp.ns, "StatusLine", line, i-lastpos-1, i-lastpos)
        end
      end
    end)
  end
end

ssp.reset()

ra = [[
ssp.start()
ssp.reset()
eee
eee
eeee
ssp.show()
ssp.sync()
bx
yb
  vim.schedule(function() luadev.print(vim.inspect(yarg)) end)
  -- args are "nvim_buf_lines_event", 1, 85, 8, 8, { "" }, false
bb
]]
