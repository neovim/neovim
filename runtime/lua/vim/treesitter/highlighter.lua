local api = vim.api
local query = vim.treesitter.query

---@alias TSHlIter fun(): integer, TSNode, TSMetadata

---@class TSHighlightState
---@field next_row integer
---@field iter TSHlIter|nil

---@class TSHighlighter
---@field active table<integer,TSHighlighter>
---@field bufnr integer
---@field orig_spelloptions string
---@field _highlight_states table<TSTree,TSHighlightState>
---@field _queries table<string,TSHighlighterQuery>
---@field tree LanguageTree
local TSHighlighter = rawget(vim.treesitter, 'TSHighlighter') or {}
TSHighlighter.__index = TSHighlighter

TSHighlighter.active = TSHighlighter.active or {}

---@class TSHighlighterQuery
---@field _query Query|nil
---@field hl_cache table<integer,integer>
local TSHighlighterQuery = {}
TSHighlighterQuery.__index = TSHighlighterQuery

local ns = api.nvim_create_namespace('treesitter/highlighter')

---@private
function TSHighlighterQuery.new(lang, query_string)
  local self = setmetatable({}, { __index = TSHighlighterQuery })

  self.hl_cache = setmetatable({}, {
    __index = function(table, capture)
      local name = self._query.captures[capture]
      local id = 0
      if not vim.startswith(name, '_') then
        id = api.nvim_get_hl_id_by_name('@' .. name .. '.' .. lang)
      end

      rawset(table, capture, id)
      return id
    end,
  })

  if query_string then
    self._query = query.parse(lang, query_string)
  else
    self._query = query.get(lang, 'highlights')
  end

  return self
end

---@package
function TSHighlighterQuery:query()
  return self._query
end

---@package
---
--- Creates a highlighter for `tree`.
---
---@param tree LanguageTree parser object to use for highlighting
---@param opts (table|nil) Configuration of the highlighter:
---           - queries table overwrite queries used by the highlighter
---@return TSHighlighter Created highlighter object
function TSHighlighter.new(tree, opts)
  local self = setmetatable({}, TSHighlighter)

  if type(tree:source()) ~= 'number' then
    error('TSHighlighter can not be used with a string parser source.')
  end

  opts = opts or {} ---@type { queries: table<string,string> }
  self.tree = tree
  tree:register_cbs({
    on_bytes = function(...)
      self:on_bytes(...)
    end,
    on_detach = function()
      self:on_detach()
    end,
  })

  tree:register_cbs({
    on_changedtree = function(...)
      self:on_changedtree(...)
    end,
    on_child_removed = function(child)
      child:for_each_tree(function(t)
        self:on_changedtree(t:included_ranges(true))
      end)
    end,
  }, true)

  self.bufnr = tree:source() --[[@as integer]]
  self.edit_count = 0
  self.redraw_count = 0
  self.line_count = {}
  -- A map of highlight states.
  -- This state is kept during rendering across each line update.
  self._highlight_states = {}

  ---@type table<string,TSHighlighterQuery>
  self._queries = {}

  -- Queries for a specific language can be overridden by a custom
  -- string query... if one is not provided it will be looked up by file.
  if opts.queries then
    for lang, query_string in pairs(opts.queries) do
      self._queries[lang] = TSHighlighterQuery.new(lang, query_string)
    end
  end

  self.orig_spelloptions = vim.bo[self.bufnr].spelloptions

  vim.bo[self.bufnr].syntax = ''
  vim.b[self.bufnr].ts_highlight = true

  TSHighlighter.active[self.bufnr] = self

  -- Tricky: if syntax hasn't been enabled, we need to reload color scheme
  -- but use synload.vim rather than syntax.vim to not enable
  -- syntax FileType autocmds. Later on we should integrate with the
  -- `:syntax` and `set syntax=...` machinery properly.
  if vim.g.syntax_on ~= 1 then
    vim.cmd.runtime({ 'syntax/synload.vim', bang = true })
  end

  api.nvim_buf_call(self.bufnr, function()
    vim.opt_local.spelloptions:append('noplainbuffer')
  end)

  self.tree:parse()

  return self
end

--- Removes all internal references to the highlighter
function TSHighlighter:destroy()
  if TSHighlighter.active[self.bufnr] then
    TSHighlighter.active[self.bufnr] = nil
  end

  if vim.api.nvim_buf_is_loaded(self.bufnr) then
    vim.bo[self.bufnr].spelloptions = self.orig_spelloptions
    vim.b[self.bufnr].ts_highlight = nil
    if vim.g.syntax_on == 1 then
      api.nvim_exec_autocmds('FileType', { group = 'syntaxset', buffer = self.bufnr })
    end
  end
end

---@package
---@param tstree TSTree
---@return TSHighlightState
function TSHighlighter:get_highlight_state(tstree)
  if not self._highlight_states[tstree] then
    self._highlight_states[tstree] = {
      next_row = 0,
      iter = nil,
    }
  end

  return self._highlight_states[tstree]
end

---@private
function TSHighlighter:reset_highlight_state()
  self._highlight_states = {}
end

---@package
---@param start_row integer
---@param new_end integer
function TSHighlighter:on_bytes(_, _, start_row, _, _, _, _, _, new_end)
  api.nvim__buf_redraw_range(self.bufnr, start_row, start_row + new_end + 1)
end

---@package
function TSHighlighter:on_detach()
  self:destroy()
end

---@package
---@param changes Range6[][]
function TSHighlighter:on_changedtree(changes)
  for _, ch in ipairs(changes) do
    api.nvim__buf_redraw_range(self.bufnr, ch[1], ch[4] + 1)
  end
end

--- Gets the query used for @param lang
--
---@package
---@param lang string Language used by the highlighter.
---@return TSHighlighterQuery
function TSHighlighter:get_query(lang)
  if not self._queries[lang] then
    self._queries[lang] = TSHighlighterQuery.new(lang)
  end

  return self._queries[lang]
end

---@private
---@param self TSHighlighter
---@param buf integer
---@param line integer
---@param is_spell_nav boolean
local function on_line_impl(self, buf, line, is_spell_nav)
  self.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root_node = tstree:root()
    local root_start_row, _, root_end_row, _ = root_node:range()

    -- Only worry about trees within the line range
    if root_start_row > line or root_end_row < line then
      return
    end

    local state = self:get_highlight_state(tstree)
    local highlighter_query = self:get_query(tree:lang())

    -- Some injected languages may not have highlight queries.
    if not highlighter_query:query() then
      return
    end

    if state.iter == nil or state.next_row < line then
      state.iter =
        highlighter_query:query():iter_captures(root_node, self.bufnr, line, root_end_row + 1)
    end

    while line >= state.next_row do
      local capture, node, metadata = state.iter()

      if capture == nil then
        break
      end

      local range = vim.treesitter.get_range(node, buf, metadata[capture])
      local start_row, start_col, _, end_row, end_col, _ = unpack(range)
      local hl = highlighter_query.hl_cache[capture]

      local capture_name = highlighter_query:query().captures[capture]
      local spell = nil ---@type boolean?
      if capture_name == 'spell' then
        spell = true
      elseif capture_name == 'nospell' then
        spell = false
      end

      -- Give nospell a higher priority so it always overrides spell captures.
      local spell_pri_offset = capture_name == 'nospell' and 1 or 0

      if hl and end_row >= line and (not is_spell_nav or spell ~= nil) then
        api.nvim_buf_set_extmark(buf, ns, start_row, start_col, {
          end_line = end_row,
          end_col = end_col,
          hl_group = hl,
          ephemeral = true,
          priority = (tonumber(metadata.priority) or 100) + spell_pri_offset, -- Low but leaves room below
          conceal = metadata.conceal,
          spell = spell,
        })
      end
      if start_row > line then
        state.next_row = start_row
      end
    end
  end)
end

---@private
---@param _win integer
---@param buf integer
---@param line integer
function TSHighlighter._on_line(_, _win, buf, line, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  on_line_impl(self, buf, line, false)
end

---@private
---@param buf integer
---@param srow integer
---@param erow integer
function TSHighlighter._on_spell_nav(_, _, buf, srow, _, erow, _)
  local self = TSHighlighter.active[buf]
  if not self then
    return
  end

  self:reset_highlight_state()

  for row = srow, erow do
    on_line_impl(self, buf, row, true)
  end
end

---@private
---@param buf integer
function TSHighlighter._on_buf(_, buf)
  local self = TSHighlighter.active[buf]
  if self then
    self.tree:parse()
  end
end

---@private
---@param _win integer
---@param buf integer
---@param _topline integer
function TSHighlighter._on_win(_, _win, buf, _topline)
  local self = TSHighlighter.active[buf]
  if not self then
    return false
  end

  self:reset_highlight_state()
  self.redraw_count = self.redraw_count + 1
  return true
end

api.nvim_set_decoration_provider(ns, {
  on_buf = TSHighlighter._on_buf,
  on_win = TSHighlighter._on_win,
  on_line = TSHighlighter._on_line,
  _on_spell_nav = TSHighlighter._on_spell_nav,
})

return TSHighlighter
