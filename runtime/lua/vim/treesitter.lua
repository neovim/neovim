local a = vim.api
local query = require('vim.treesitter.query')
local language = require('vim.treesitter.language')
local LanguageTree = require('vim.treesitter.languagetree')

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

local M = vim.tbl_extend('error', query, language)

M.language_version = vim._ts_get_language_version()
M.minimum_language_version = vim._ts_get_minimum_language_version()

setmetatable(M, {
  __index = function(t, k)
    if k == 'highlighter' then
      t[k] = require('vim.treesitter.highlighter')
      return t[k]
    elseif k == 'language' then
      t[k] = require('vim.treesitter.language')
      return t[k]
    elseif k == 'query' then
      t[k] = require('vim.treesitter.query')
      return t[k]
    end
  end,
})

--- Creates a new parser.
---
--- It is not recommended to use this, use vim.treesitter.get_parser() instead.
---
---@param bufnr string Buffer the parser will be tied to (0 for current buffer)
---@param lang string Language of the parser
---@param opts table|nil Options to pass to the created language tree
---
---@returns table Created parser object
function M._create_parser(bufnr, lang, opts)
  language.require_language(lang)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end

  vim.fn.bufload(bufnr)

  local self = LanguageTree.new(bufnr, lang, opts)

  ---@private
  local function bytes_cb(_, ...)
    self:_on_bytes(...)
  end

  ---@private
  local function detach_cb(_, ...)
    if parsers[bufnr] == self then
      parsers[bufnr] = nil
    end
    self:_on_detach(...)
  end

  ---@private
  local function reload_cb(_, ...)
    self:_on_reload(...)
  end

  a.nvim_buf_attach(
    self:source(),
    false,
    { on_bytes = bytes_cb, on_detach = detach_cb, on_reload = reload_cb, preview = true }
  )

  self:parse()

  return self
end

--- Gets the parser for this bufnr / ft combination.
---
--- If needed this will create the parser.
--- Unconditionally attach the provided callback
---
---@param bufnr number|nil Buffer the parser should be tied to: (default current buffer)
---@param lang string |nil Filetype of this parser (default: buffer filetype)
---@param opts table|nil Options to pass to the created language tree
---
---@returns table Parser object
function M.get_parser(bufnr, lang, opts)
  opts = opts or {}

  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if lang == nil then
    lang = a.nvim_buf_get_option(bufnr, 'filetype')
  end

  if parsers[bufnr] == nil or parsers[bufnr]:lang() ~= lang then
    parsers[bufnr] = M._create_parser(bufnr, lang, opts)
  end

  parsers[bufnr]:register_cbs(opts.buf_attach_cbs)

  return parsers[bufnr]
end

--- Gets a string parser
---
---@param str The string to parse
---@param lang The language of this string
---@param opts Options to pass to the created language tree
function M.get_string_parser(str, lang, opts)
  vim.validate({
    str = { str, 'string' },
    lang = { lang, 'string' },
  })
  language.require_language(lang)

  return LanguageTree.new(str, lang, opts)
end

--- Determines whether a node is the ancestor of another
---
---@param dest table Possible ancestor
---@param source table Possible descendant node
---
---@returns (boolean) True if dest is an ancestor of source
function M.is_ancestor(dest, source)
  if not (dest and source) then
    return false
  end

  local current = source
  while current ~= nil do
    if current == dest then
      return true
    end

    current = current:parent()
  end

  return false
end

--- Get the node's range or unpack a range table
---
---@param node_or_range table
---
---@returns start_row, start_col, end_row, end_col
function M.get_node_range(node_or_range)
  if type(node_or_range) == 'table' then
    return unpack(node_or_range)
  else
    return node_or_range:range()
  end
end

---Determines whether (line, col) position is in node range
---
---@param node table Node defining the range
---@param line number Line (0-based)
---@param col number Column (0-based)
---
---@returns (boolean) True if the position is in node range
function M.is_in_node_range(node, line, col)
  local start_line, start_col, end_line, end_col = M.get_node_range(node)
  if line >= start_line and line <= end_line then
    if line == start_line and line == end_line then
      return col >= start_col and col < end_col
    elseif line == start_line then
      return col >= start_col
    elseif line == end_line then
      return col < end_col
    else
      return true
    end
  else
    return false
  end
end

---Determines if a node contains a range
---@param node table
---@param range table
---
---@returns (boolean) True if the node contains the range
function M.node_contains(node, range)
  local start_row, start_col, end_row, end_col = node:range()
  local start_fits = start_row < range[1] or (start_row == range[1] and start_col <= range[2])
  local end_fits = end_row > range[3] or (end_row == range[3] and end_col >= range[4])

  return start_fits and end_fits
end

---Gets a list of captures for a given cursor position
---@param bufnr number Buffer number (0 for current buffer)
---@param row number Position row
---@param col number Position column
---
---@returns (table) A table of captures
function M.get_captures_at_position(bufnr, row, col)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local buf_highlighter = M.highlighter.active[bufnr]

  if not buf_highlighter then
    return {}
  end

  local matches = {}

  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()
    local root_start_row, _, root_end_row, _ = root:range()

    -- Only worry about trees within the line range
    if root_start_row > row or root_end_row < row then
      return
    end

    local q = buf_highlighter:get_query(tree:lang())

    -- Some injected languages may not have highlight queries.
    if not q:query() then
      return
    end

    local iter = q:query():iter_captures(root, buf_highlighter.bufnr, row, row + 1)

    for capture, node, metadata in iter do
      if M.is_in_node_range(node, row, col) then
        local c = q._query.captures[capture] -- name of the capture in the query
        if c ~= nil then
          table.insert(matches, { capture = c, priority = metadata.priority })
        end
      end
    end
  end, true)
  return matches
end

--- Start treesitter highlighting for a buffer
---
--- Can be used in an ftplugin or FileType autocommand
---
--- Note: By default, disables regex syntax highlighting, which may be required for some plugins.
--- In this case, add `vim.bo.syntax = 'on'` after the call to `start`.
---
--- Example:
---
--- <pre>
--- vim.api.nvim_create_autocmd( 'FileType', { pattern = 'tex',
---     callback = function(args)
---         vim.treesitter.start(args.buf, 'latex')
---         vim.bo[args.buf].syntax = 'on'  -- only if additional legacy syntax is needed
---     end
--- })
--- </pre>
---
---@param bufnr number|nil Buffer to be highlighted (default: current buffer)
---@param lang string|nil Language of the parser (default: buffer filetype)
function M.start(bufnr, lang)
  bufnr = bufnr or a.nvim_get_current_buf()

  local parser = M.get_parser(bufnr, lang)

  M.highlighter.new(parser)

  vim.b[bufnr].ts_highlight = true
end

---Stop treesitter highlighting for a buffer
---
---@param bufnr number|nil Buffer to stop highlighting (default: current buffer)
function M.stop(bufnr)
  bufnr = bufnr or a.nvim_get_current_buf()

  if M.highlighter.active[bufnr] then
    M.highlighter.active[bufnr]:destroy()
  end

  vim.bo[bufnr].syntax = 'on'
end

return M
