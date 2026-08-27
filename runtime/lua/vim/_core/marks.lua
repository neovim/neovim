--- Marks functionality
--- - |:marks| command/completion

local api = vim.api
local util = require('vim._core.util')
local N_ = vim.fn.gettext

local M = {}

--- Names of the namespaces that have extmarks in the current buffer, sorted.
--- @return string[]
local function buf_namespaces()
  local names = {} ---@type string[]
  for name, id in pairs(api.nvim_get_namespaces()) do
    if #api.nvim_buf_get_extmarks(0, id, 0, -1, { limit = 1 }) > 0 then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

--- Completion for ":marks {arg}":
--- - set marks (buffer-local and global)
--- - extmark namespaces (buffer-local)
--- @return string[]
function M.complete()
  local names = {} ---@type string[]
  for _, list in ipairs({ vim.fn.getmarklist(api.nvim_get_current_buf()), vim.fn.getmarklist() }) do
    for _, m in ipairs(list) do
      names[#names + 1] = m.mark:sub(2) -- "'a" => "a"
    end
  end
  table.sort(names)
  return vim.list_extend(names, buf_namespaces())
end

--- ":marks {ns}": lists the extmarks of namespace {ns} in the current buffer.
--- @param ns string
--- @return boolean handled false: {ns} is not a namespace (it is a set of mark names)
function M.show(ns)
  local id = api.nvim_get_namespaces()[ns]
  if not id then
    return false
  end
  local extmarks = api.nvim_buf_get_extmarks(0, id, 0, -1, {})
  if #extmarks == 0 then
    api.nvim_echo({ { ('No extmarks in this buffer for namespace "%s"'):format(ns) } }, false, {})
    return true
  end
  local chunks = { { ('%6s %5s  %4s %s'):format('id', 'line', 'col', 'text'), 'Title' } }
  for _, m in ipairs(extmarks) do
    local text = api.nvim_buf_get_lines(0, m[2], m[2] + 1, false)[1] or ''
    chunks[#chunks + 1] = { ('\n%6d %5d  %4d %s'):format(m[1], m[2] + 1, m[3], vim.trim(text)) }
  end
  api.nvim_echo(chunks, false, { kind = 'list_cmd' })
  return true
end

--- The line at mark line {lnum}, sans leading whitespace, truncated to fit in the window
--- (cells), like C mark_line().
--- @param lnum integer
--- @return string
local function mark_line(lnum)
  if lnum > api.nvim_buf_line_count(0) then
    return '-invalid-'
  end
  local text = api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]:gsub('^%s+', '')
  local limit = vim.o.columns - 15
  if vim.fn.strdisplaywidth(text) < limit then
    return text
  end
  local keep = {} ---@type string[]
  local width = 0
  for _, c in ipairs(vim.fn.split(text, [[\zs]])) do
    width = width + vim.fn.strdisplaywidth(c)
    if width >= limit then
      break
    end
    keep[#keep + 1] = c
  end
  return table.concat(keep)
end

--- ":marks [arg]" (|ex_cmds.lua| "marks" => C ex_marks() => this).
--- @param args vim._core.ExCmdArgs
function M.ex_marks(args)
  local arg = args.args ~= '' and args.args or nil

  -- ":marks {ns}": list namespace's extmarks, or fallthrough if unknown.
  if arg and #arg > 1 and M.show(arg) then
    return
  end

  local curbuf = api.nvim_get_current_buf()
  local marks = {} ---@type table<string,{mark:string, pos:integer[], file?:string}>
  for _, list in ipairs({ vim.fn.getmarklist(curbuf), vim.fn.getmarklist() }) do
    for _, m in ipairs(list) do
      marks[m.mark:sub(2)] = m
    end
  end

  -- "<" and ">" are shown as where they will jump to: start before end.
  local vs, ve = marks['<'], marks['>']
  if vs and ve then
    local s, e = vs.pos, ve.pos
    if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then
      vs.pos, ve.pos = e, s
    end
  elseif ve and not vs then
    marks['<'], marks['>'] = ve, nil
  end

  --- The "file/text" column: the text at the mark if it is in the current buffer (highlighted
  --- as "Directory", like C show_one_mark()), else the file name.
  --- @param m {pos:integer[], file?:string}
  --- @return string text, string? hl
  local function displayname(m)
    if m.pos[1] == curbuf then
      return mark_line(m.pos[2]), 'Directory'
    elseif m.pos[1] == 0 then
      return m.file or '', nil
    end
    return vim.fn.fnamemodify(vim.fn.bufname(m.pos[1]), ':~'), nil
  end

  -- Fixed :marks order.
  local order = { "'" }
  for _, range in ipairs({ { 'a', 'z' }, { 'A', 'Z' }, { '0', '9' } }) do
    for b = range[1]:byte(), range[2]:byte() do
      order[#order + 1] = string.char(b)
    end
  end
  vim.list_extend(order, { '"', '[', ']', '^', '.', ':', '<', '>' })

  local filtered = require('vim._core.ex_cmd').filter
  local chunks = {} ---@type [string, string?][]
  for _, name in ipairs(order) do
    local m = marks[name]
    if m and (not arg or arg:find(name, 1, true)) then
      local text, hl = displayname(m)
      if not filtered(args.smods.filter, text) then
        chunks[#chunks + 1] = { ('\n %s %6d %4d '):format(name, m.pos[2], m.pos[3] - 1) }
        if text ~= '' then
          chunks[#chunks + 1] = { text, hl }
        end
      end
    end
  end

  if #chunks == 0 then
    if arg then
      util.echo_err(N_('E283: No marks matching "%s"'):format(arg))
      return
    end
    api.nvim_echo({ { N_('No marks set') } }, false, {})
  else
    table.insert(chunks, 1, { N_('\nmark line  col file/text'), 'Title' })
    api.nvim_echo(chunks, false, { kind = 'list_cmd' })
  end

  if not arg then
    -- By default, list extmarks namespaces (but not their extmarks).
    local names = buf_namespaces()
    if #names > 0 then
      local msg = ('Extmark namespaces (use ":marks {ns}"): %s'):format(table.concat(names, ', '))
      api.nvim_echo({ { msg } }, false, {})
    end
  end
end

return M
