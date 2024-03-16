local api = vim.api
local TSHighlighterQuery = require('vim.treesitter.highlighter.query')
local Capture = require('vim.treesitter.highlighter.capture')
local Range = require('vim.treesitter._range')
-- Should this have it's own namespace ?
local ns = api.nvim_create_namespace('treesitter/highlighter')
---@nodoc
---@class vim.treesitter.linehighlighter
---@field bufnr integer
---@field lang string
---@field private _queries table<string,vim.treesitter.highlighter.Query>
local TSLineHighlighter = {}

TSLineHighlighter.__index = TSLineHighlighter

--- @param bufnr number
--- @param lang string
--- @param opts (table|nil) Configuration of the highlighter:
---           - queries table overwrite queries used by the highlighter
function TSLineHighlighter.new(bufnr, lang, opts)
  opts = opts or {} ---@type { queries: table<string,string> }
  local self = setmetatable({}, TSLineHighlighter)
  self.bufnr = bufnr
  self.lang = lang
  self._queries = {}
  if opts.queries then
    for lang, query_string in pairs(opts.queries) do
      self._queries[lang] = TSHighlighterQuery.new(lang, query_string)
    end
  end
  vim.bo[self.bufnr].syntax = ''
  vim.bo[bufnr].spelloptions = 'noplainbuffer'
  vim.b[self.bufnr].ts_highlight = true
  if vim.g.syntax_on ~= 1 then
    vim.cmd.runtime({ 'syntax/synload.vim', bang = true })
  end
  api.nvim_buf_attach(bufnr, false, {
    on_bytes = function(_, _, _, start_row, _, _, old_row, _, _, new_row, _, _)
      -- No rows were deleted and no rows were added probably a column change on the current line
      if old_row == 0 and new_row == 0 then
        new_row = 1
      end
      vim.schedule(function()
        self:highlight(start_row, start_row + new_row)
      end)
    end,
  })
  -- TODO: only highlight the viewable region then highlight when the window is scrolled
  self:highlight(0, vim.api.nvim_buf_line_count(bufnr))
  return self
end

--- Gets the query used for @param lang
---@package
---@param lang string Language used by the highlighter.
---@return vim.treesitter.highlighter.Query
function TSLineHighlighter:get_query(lang)
  if not self._queries[lang] then
    self._queries[lang] = TSHighlighterQuery.new(lang)
  end

  return self._queries[lang]
end

--- Highlight the range between start and end_ using persistent marks, with each line having it's own
--- language tree.
--- @param start number (0-indexed)
--- @param end_ number (0-indexed) exclusive
function TSLineHighlighter:highlight(start, end_)
  local bufnr = self.bufnr
  vim.api.nvim_buf_clear_namespace(bufnr, ns, start, end_)
  for i = start, end_ - 1, 1 do
    local line = api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    local line_tree = vim.treesitter.get_string_parser(line, self.lang)
    line_tree:parse(true)
    line_tree:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local highlighter_query = self:get_query(tree:lang())
      if not highlighter_query then
        return
      end
      local t = tree
      local level = 0
      while t do
        t = t:parent()
        level = level + 1
      end
      local query = highlighter_query:query()
      local pattern_offset = level * 1000
      for pattern, match, metadata in query:iter_matches(tstree:root(), line, 0, 1, { all = true }) do
        if not match then
          break
        end
        for capture, nodes in pairs(match) do
          local capture_name = highlighter_query:query().captures[capture]
          local spell, spell_pri_offset = Capture.get_spell(capture_name)
          local hl = highlighter_query:get_hl_from_capture(capture)
          local priority = (
            tonumber(metadata.priority or metadata[capture] and metadata[capture].priority)
            or vim.highlight.priorities.treesitter
          ) + spell_pri_offset
          local url = Capture.get_url(match, bufnr, capture, metadata)
          -- The "conceal" attribute can be set at the pattern level or on a particular capture
          local conceal = metadata.conceal or metadata[capture] and metadata[capture].conceal --- @type string
          for _, node in ipairs(nodes) do
            local range = vim.treesitter.get_range(node, line, metadata[capture])
            local _, start_col, _, end_col = Range.unpack4(range)
            api.nvim_buf_set_extmark(bufnr, ns, i, start_col, {
              end_line = i,
              end_col = end_col,
              hl_group = hl,
              -- TODO: store the extmarks in an array then make them ephemeral with _subpriority
              priority = priority + pattern + pattern_offset,
              conceal = conceal,
              spell = spell,
              url = url,
            })
          end
        end
      end
    end)
  end
end

return TSLineHighlighter
