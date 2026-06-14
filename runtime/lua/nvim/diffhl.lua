local api = vim.api
local ts = vim.treesitter
local bit = require('bit')

local M = {}

local ns = api.nvim_create_namespace('nvim.diffhl')

---@param ft string?
---@return string?
local function resolve_lang(ft)
  if not ft or ft == '' then
    return nil
  end
  local lang = ts.language.get_lang(ft)
  if not lang then
    return nil
  end
  local ok, added = pcall(ts.language.add, lang)
  if ok and added then
    return lang
  end
  return nil
end

---@param path string
---@return string?
local function path_lang(path)
  if path == '' or path == '/dev/null' then
    return nil
  end
  return resolve_lang(vim.filetype.match({ filename = path }))
end

---@param path string
---@return string
local function clean_path(path)
  return (path:gsub('^"(.*)"$', '%1'):gsub('\t.*$', ''):gsub('^[ab]/', ''))
end

---@class (private) nvim.diffhl.Hunk
---@field lang string
---@field start integer
---@field lines string[]
---@field new nvim.diffhl.Side?
---@field old nvim.diffhl.Side?

---@param buf integer
---@return nvim.diffhl.Hunk[]
local function parse(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = {} ---@type nvim.diffhl.Hunk[]
  local lang = nil ---@type string?
  local hunk = nil ---@type nvim.diffhl.Hunk?

  for i = 1, #lines do
    local line = lines[i]

    if hunk then
      local c = line:sub(1, 1)
      if c == ' ' or c == '+' or c == '-' then
        hunk.lines[#hunk.lines + 1] = line
      elseif line == '' then
        hunk.lines[#hunk.lines + 1] = ' '
      elseif c ~= '\\' then
        hunk = nil
      end
    end

    if not hunk then
      local newf = line:match('^%+%+%+ (.*)$')
      local oldf = line:match('^%-%-%- (.*)$')
      if newf then
        lang = path_lang(clean_path(newf)) or lang
      elseif oldf then
        lang = path_lang(clean_path(oldf))
      elseif line:match('^diff ') then
        lang = nil
      elseif lang and line:match('^@@ %-%d') then
        hunk = { lang = lang, start = i, lines = {} }
        hunks[#hunks + 1] = hunk
      end
    end
  end

  return hunks
end

---@class (private) nvim.diffhl.Side
---@field lines string[]
---@field rows table<integer, integer>
---@field paint table<integer, boolean>
---@field src string?
---@field parser vim.treesitter.LanguageTree?
---@field trees table<integer, TSTree>?
---@field parsing boolean?

---@param hunk nvim.diffhl.Hunk
---@return nvim.diffhl.Side new
---@return nvim.diffhl.Side old
local function build_sides(hunk)
  local new = { lines = {}, rows = {}, paint = {} } ---@type nvim.diffhl.Side
  local old = { lines = {}, rows = {}, paint = {} } ---@type nvim.diffhl.Side

  for j = 1, #hunk.lines do
    local line = hunk.lines[j]
    local c = line:sub(1, 1)
    local content = line:sub(2)
    local row = hunk.start + j - 1
    if c == '+' then
      local i = #new.lines
      new.rows[i] = row
      new.paint[i] = true
      new.lines[i + 1] = content
    elseif c == '-' then
      local i = #old.lines
      old.rows[i] = row
      old.paint[i] = true
      old.lines[i + 1] = content
    else
      local ni = #new.lines
      new.rows[ni] = row
      new.paint[ni] = true
      new.lines[ni + 1] = content
      local oi = #old.lines
      old.rows[oi] = row
      old.paint[oi] = false
      old.lines[oi + 1] = content
    end
  end

  return new, old
end

---@param rows table<integer, integer>
---@param n integer
---@param target integer
---@return integer
local function lower_bound(rows, n, target)
  local lo, hi = 0, n
  while lo < hi do
    local mid = bit.rshift(lo + hi, 1)
    if rows[mid] < target then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

---@param buf integer
---@param tick integer
---@param side nvim.diffhl.Side
---@param lang string
local function ensure_side_parsed(buf, tick, side, lang)
  if side.trees or side.parsing then
    return
  end
  if #side.lines == 0 then
    side.trees = {}
    return
  end
  side.src = table.concat(side.lines, '\n')
  local ok, parser = pcall(ts.get_string_parser, side.src, lang)
  if not ok or not parser then
    side.trees = {}
    return
  end
  side.parser = parser
  side.parsing = true
  local sync = true
  parser:parse(true, function(_, trees)
    side.parsing = false
    side.trees = trees or {}
    if
      not sync
      and trees
      and api.nvim_buf_is_valid(buf)
      and api.nvim_buf_get_changedtick(buf) == tick
    then
      api.nvim__redraw({ buf = buf, valid = false, flush = false })
    end
  end)
  sync = false
end

---@param side nvim.diffhl.Side
---@param toprow integer
---@param botrow integer
---@param fn fun(row: integer, col: integer, end_col: integer, hl: string)
local function each_span(side, toprow, botrow, fn)
  if not side.parser or not side.trees then
    return
  end
  local n = #side.lines
  local first = lower_bound(side.rows, n, toprow)
  local stop = lower_bound(side.rows, n, botrow + 1)
  if first >= stop then
    return
  end

  side.parser:for_each_tree(function(tree, ltree)
    local tree_lang = ltree:lang()
    local query = ts.query.get(tree_lang, 'highlights')
    if not query then
      return
    end

    for id, node in query:iter_captures(tree:root(), side.src, first, stop) do
      local name = query.captures[id]
      if not vim.startswith(name, '_') and name ~= 'spell' and name ~= 'nospell' then
        local srow, scol, erow, ecol = node:range()
        local hl = '@' .. name .. '.' .. tree_lang
        for r = math.max(srow, first), math.min(erow, stop - 1) do
          if side.paint[r] then
            local col_start = (r == srow) and scol or 0
            local col_end = (r == erow) and ecol or #side.lines[r + 1]
            if col_end > col_start then
              fn(side.rows[r], col_start + 1, col_end + 1, hl)
            end
          end
        end
      end
    end
  end)
end

---@param buf integer
---@param side nvim.diffhl.Side
---@param toprow integer
---@param botrow integer
local function emit_side(buf, side, toprow, botrow)
  each_span(side, toprow, botrow, function(row, col, end_col, hl)
    pcall(api.nvim_buf_set_extmark, buf, ns, row, col, {
      end_col = end_col,
      hl_group = hl,
      priority = vim.hl.priorities.treesitter,
      ephemeral = true,
    })
  end)
end

---@class (private) nvim.diffhl.State
---@field tick integer
---@field hunks nvim.diffhl.Hunk[]

---@type table<integer, nvim.diffhl.State>
local state = {}

---@type table<integer, true>
local attached = {}

---@param buf integer
---@return nvim.diffhl.State
local function ensure_state(buf)
  local tick = api.nvim_buf_get_changedtick(buf)
  local s = state[buf]
  if s and s.tick == tick then
    return s
  end
  s = { tick = tick, hunks = parse(buf) }
  state[buf] = s
  return s
end

api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, buf, toprow, botrow)
    if not attached[buf] then
      return false
    end
    local s = ensure_state(buf)
    for i = 1, #s.hunks do
      local hunk = s.hunks[i]
      if hunk.lang and hunk.start <= botrow and hunk.start + #hunk.lines - 1 >= toprow then
        if not hunk.new then
          hunk.new, hunk.old = build_sides(hunk)
        end
        ensure_side_parsed(buf, s.tick, hunk.new, hunk.lang)
        ensure_side_parsed(buf, s.tick, hunk.old, hunk.lang)
        emit_side(buf, hunk.new, toprow, botrow)
        emit_side(buf, hunk.old, toprow, botrow)
      end
    end
  end,
})

api.nvim_create_autocmd('OptionSet', {
  group = api.nvim_create_augroup('nvim.diffhl', {}),
  pattern = 'runtimepath',
  desc = 'Invalidate diff hunk highlight cache when a parser may have become available',
  callback = function()
    state = {}
    vim.schedule(function()
      pcall(api.nvim__redraw, { valid = false })
    end)
  end,
})

--- Attach tree-sitter language highlighting of code inside diff hunks to {buf}.
---@param buf integer? (default: current buffer)
function M.attach(buf)
  buf = vim._resolve_bufnr(buf)
  if attached[buf] then
    return
  end
  attached[buf] = true
  api.nvim_buf_attach(buf, false, {
    on_reload = function()
      state[buf] = nil
    end,
    on_detach = function()
      attached[buf] = nil
      state[buf] = nil
    end,
  })
end

--- Detach diff hunk highlighting from {buf}.
---@param buf integer? (default: current buffer)
function M.detach(buf)
  buf = vim._resolve_bufnr(buf)
  attached[buf] = nil
  state[buf] = nil
  pcall(api.nvim_buf_clear_namespace, buf, ns, 0, -1)
end

return M
