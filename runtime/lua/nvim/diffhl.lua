--- Tree-sitter highlighting of the code inside diff hunks. When attached, every
--- added/removed line also gets a background tint and a colored +/- marker.
--- Lines without an available parser keep the tint but receive no syntax highlighting.

local api = vim.api
local ts = vim.treesitter

local M = {}

local ns = api.nvim_create_namespace('nvim.diffhl')

---@param ft string? the filetype extracted from the hunk header
---@return string? the treestitter language name, or nil if missing/not installed
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

-- Derive hunk treesitter language from header path
---@param path string
---@return string?
local function path_lang(path)
  if path == '' or path == '/dev/null' then
    return nil
  end
  return resolve_lang(vim.filetype.match({ filename = path }))
end

--- Normalize a diff header path: strip Git's surrounding quotes (used for
--- special characters), any trailing "\t<metadata>", and the leading a/ or b/.
---@param path string
---@return string
local function clean_path(path)
  return (path:gsub('^"(.*)"$', '%1'):gsub('\t.*$', ''):gsub('^[ab]/', ''))
end

---@class (private) nvim.diffhl.Hunk
---@field old_lang string?
---@field new_lang string?
---@field start integer
---@field cols integer
---@field lines string[]
---@field new nvim.diffhl.Side?
---@field old nvim.diffhl.Side?

--- Scan {buf} line by line for diff hunks, resolving each hunk's old/new
--- language from the preceding ---/+++ headers and recording its body lines.
---@param buf integer
---@return nvim.diffhl.Hunk[]
local function parse(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local hunks = {} ---@type nvim.diffhl.Hunk[]
  local old_lang = nil ---@type string?
  local new_lang = nil ---@type string?
  local hunk = nil ---@type nvim.diffhl.Hunk?

  for i = 1, #lines do
    local line = lines[i]

    -- Inside a hunk: collect body lines until a line that is not part of the
    -- body ends it. A "\ No newline at end of file" marker (c == '\\') is
    -- skipped without ending the hunk.
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

    -- Between hunks: track the per-file languages from the ---/+++ headers
    -- (reset at each "diff" line) and open a hunk at each @@/@@@ header.
    if not hunk then
      local newf = line:match('^%+%+%+ (.*)$')
      local oldf = line:match('^%-%-%- (.*)$')
      if newf then
        new_lang = path_lang(clean_path(newf))
      elseif oldf then
        old_lang = path_lang(clean_path(oldf))
      elseif line:match('^diff ') then
        old_lang, new_lang = nil, nil
      else
        -- A combined (merge) diff header carries one extra '@' per parent, so
        -- the number of leading '@' minus one is the count of status columns.
        -- Hunks are recorded even when the language is unknown so the background
        -- tint still applies.
        local at = line:match('^(@@+) %-%d')
        if at then
          hunk = {
            old_lang = old_lang,
            new_lang = new_lang,
            start = i,
            cols = #at - 1,
            lines = {},
          }
          hunks[#hunks + 1] = hunk
        end
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

--- Reconstruct the hunk's new and old file contents as separate strings so each
--- parses as contiguous source. Context lines belong to both sides (so each
--- parses correctly) but are painted only once, via the new side.
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

--- Parse {side}'s reconstructed source with the {lang} parser once and cache the
--- trees. If the parse completes asynchronously, request a redraw, but only
--- while {buf} is still unchanged from {tick}.
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
  -- parse() may finish synchronously or hand off to a background job. "sync"
  -- lets the callback tell the two apart: only an asynchronous completion needs
  -- to request a redraw, and only while the buffer is still unchanged.
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

--- Run {fn} for each tree-sitter highlight span on {side} that intersects the
--- visible rows [{toprow}, {botrow}], passing the buffer row, start/end columns,
--- and highlight group.
---@param side nvim.diffhl.Side
---@param toprow integer
---@param botrow integer
---@param fn fun(row: integer, col: integer, end_col: integer, hl: string)
local function each_span(side, toprow, botrow, fn)
  if not side.parser or not side.trees then
    return
  end
  local n = #side.lines
  local first = vim.list.bisect(side.rows, toprow, { lo = 0, hi = n })
  local stop = vim.list.bisect(side.rows, botrow + 1, { lo = 0, hi = n })
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
            -- Columns are relative to the prefix-stripped side text; +1 maps
            -- them back past the leading +/-/space diff marker in the buffer.
            if col_end > col_start then
              fn(side.rows[r], col_start + 1, col_end + 1, hl)
            end
          end
        end
      end
    end
  end)
end

--- Apply {side}'s tree-sitter highlights as ephemeral extmarks over the visible
--- rows [{toprow}, {botrow}].
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

--- Return the parsed hunk state for {buf}, re-parsing only when the buffer has
--- changed since the last call (tracked via changedtick).
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
      if hunk.start <= botrow and hunk.start + #hunk.lines - 1 >= toprow then
        -- Background pass: tint every added/removed line and recolor its marker,
        -- independent of language, so an enabled diff is never left untinted.
        local jlo = math.max(1, toprow - hunk.start + 1)
        local jhi = math.min(#hunk.lines, botrow - hunk.start + 1)
        for j = jlo, jhi do
          -- Status comes from the leading column(s): cols is 1 for a unified
          -- diff and >1 for a combined/merge diff.
          local prefix = hunk.lines[j]:sub(1, hunk.cols)
          local bg, marker ---@type string?, string?
          if prefix:find('+', 1, true) then
            bg, marker = 'DiffAdd', 'Added'
          elseif prefix:find('-', 1, true) then
            bg, marker = 'DiffDelete', 'Removed'
          end
          if bg then
            local row = hunk.start + j - 1
            -- Full-width tint, kept just below the tree-sitter priority so the
            -- syntax foreground composes on top of it.
            pcall(api.nvim_buf_set_extmark, buf, ns, row, 0, {
              end_row = row + 1,
              end_col = 0,
              hl_group = bg,
              hl_eol = true,
              priority = vim.hl.priorities.treesitter - 1,
              ephemeral = true,
            })
            -- Re-color only the marker column(s) on top of the tint.
            pcall(api.nvim_buf_set_extmark, buf, ns, row, 0, {
              end_col = hunk.cols,
              hl_group = marker,
              priority = vim.hl.priorities.treesitter,
              ephemeral = true,
            })
          end
        end
        -- Foreground pass: only unified hunks are reconstructed and tree-sitter
        -- highlighted; combined/merge hunks keep the tint without syntax.
        if hunk.cols == 1 and (hunk.old_lang or hunk.new_lang) then
          if not hunk.new then
            hunk.new, hunk.old = build_sides(hunk)
          end
          if hunk.new_lang then
            ensure_side_parsed(buf, s.tick, hunk.new, hunk.new_lang)
            emit_side(buf, hunk.new, toprow, botrow)
          end
          if hunk.old_lang then
            ensure_side_parsed(buf, s.tick, hunk.old, hunk.old_lang)
            emit_side(buf, hunk.old, toprow, botrow)
          end
        end
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
