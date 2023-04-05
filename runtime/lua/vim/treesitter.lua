local api = vim.api
local LanguageTree = require('vim.treesitter.languagetree')
local Range = require('vim.treesitter._range')

---@type table<integer,LanguageTree>
local parsers = setmetatable({}, { __mode = 'v' })

---@class TreesitterModule
---@field highlighter TSHighlighter
---@field query TSQueryModule
---@field language TSLanguageModule
local M = setmetatable({}, {
  __index = function(t, k)
    ---@diagnostic disable:no-unknown
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

    local query = require('vim.treesitter.query')
    if query[k] then
      vim.deprecate('vim.treesitter.' .. k .. '()', 'vim.treesitter.query.' .. k .. '()', '0.10')
      t[k] = query[k]
      return t[k]
    end

    local language = require('vim.treesitter.language')
    if language[k] then
      vim.deprecate('vim.treesitter.' .. k .. '()', 'vim.treesitter.language.' .. k .. '()', '0.10')
      t[k] = language[k]
      return t[k]
    end
  end,
})

M.language_version = vim._ts_get_language_version()
M.minimum_language_version = vim._ts_get_minimum_language_version()

--- Creates a new parser
---
--- It is not recommended to use this; use |get_parser()| instead.
---
---@param bufnr integer Buffer the parser will be tied to (0 for current buffer)
---@param lang string Language of the parser
---@param opts (table|nil) Options to pass to the created language tree
---
---@return LanguageTree object to use for parsing
function M._create_parser(bufnr, lang, opts)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
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
  local function reload_cb(_)
    self:_on_reload()
  end

  local source = self:source() --[[@as integer]]

  api.nvim_buf_attach(
    source,
    false,
    { on_bytes = bytes_cb, on_detach = detach_cb, on_reload = reload_cb, preview = true }
  )

  self:parse()

  return self
end

--- @private
local function valid_lang(lang)
  return lang and lang ~= ''
end

--- Returns the parser for a specific buffer and attaches it to the buffer
---
--- If needed, this will create the parser.
---
---@param bufnr (integer|nil) Buffer the parser should be tied to (default: current buffer)
---@param lang (string|nil) Filetype of this parser (default: buffer filetype)
---@param opts (table|nil) Options to pass to the created language tree
---
---@return LanguageTree object to use for parsing
function M.get_parser(bufnr, lang, opts)
  opts = opts or {}

  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  if not valid_lang(lang) then
    lang = M.language.get_lang(vim.bo[bufnr].filetype) or vim.bo[bufnr].filetype
  end

  if not valid_lang(lang) then
    if not parsers[bufnr] then
      error(
        string.format(
          'There is no parser available for buffer %d and one could not be'
            .. ' created because lang could not be determined. Either pass lang'
            .. ' or set the buffer filetype',
          bufnr
        )
      )
    end
  elseif parsers[bufnr] == nil or parsers[bufnr]:lang() ~= lang then
    parsers[bufnr] = M._create_parser(bufnr, lang, opts)
  end

  parsers[bufnr]:register_cbs(opts.buf_attach_cbs)

  return parsers[bufnr]
end

---@package
---@param bufnr (integer|nil) Buffer number
---@return boolean
function M._has_parser(bufnr)
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  return parsers[bufnr] ~= nil
end

--- Returns a string parser
---
---@param str string Text to parse
---@param lang string Language of this string
---@param opts (table|nil) Options to pass to the created language tree
---
---@return LanguageTree object to use for parsing
function M.get_string_parser(str, lang, opts)
  vim.validate({
    str = { str, 'string' },
    lang = { lang, 'string' },
  })

  return LanguageTree.new(str, lang, opts)
end

--- Determines whether a node is the ancestor of another
---
---@param dest TSNode Possible ancestor
---@param source TSNode Possible descendant
---
---@return boolean True if {dest} is an ancestor of {source}
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

--- Returns the node's range or an unpacked range table
---
---@param node_or_range (TSNode | table) Node or table of positions
---
---@return integer start_row
---@return integer start_col
---@return integer end_row
---@return integer end_col
function M.get_node_range(node_or_range)
  if type(node_or_range) == 'table' then
    return unpack(node_or_range)
  else
    return node_or_range:range()
  end
end

---Get the range of a |TSNode|. Can also supply {source} and {metadata}
---to get the range with directives applied.
---@param node TSNode
---@param source integer|string|nil Buffer or string from which the {node} is extracted
---@param metadata TSMetadata|nil
---@return Range6
function M.get_range(node, source, metadata)
  if metadata and metadata.range then
    assert(source)
    return Range.add_bytes(source, metadata.range)
  end
  return { node:range(true) }
end

---@private
---@param buf integer
---@param range Range
---@returns string
local function buf_range_get_text(buf, range)
  local start_row, start_col, end_row, end_col = Range.unpack4(range)
  if end_col == 0 then
    if start_row == end_row then
      start_col = -1
      start_row = start_row - 1
    end
    end_col = -1
    end_row = end_row - 1
  end
  local lines = api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col, {})
  return table.concat(lines, '\n')
end

--- Gets the text corresponding to a given node
---
---@param node TSNode
---@param source (integer|string) Buffer or string from which the {node} is extracted
---@param opts (table|nil) Optional parameters.
---          - metadata (table) Metadata of a specific capture. This would be
---            set to `metadata[capture_id]` when using |vim.treesitter.query.add_directive()|.
---@return string
function M.get_node_text(node, source, opts)
  opts = opts or {}
  local metadata = opts.metadata or {}

  if metadata.text then
    return metadata.text
  elseif type(source) == 'number' then
    local range = vim.treesitter.get_range(node, source, metadata)
    return buf_range_get_text(source, range)
  end

  ---@cast source string
  return source:sub(select(3, node:start()) + 1, select(3, node:end_()))
end

--- Determines whether (line, col) position is in node range
---
---@param node TSNode defining the range
---@param line integer Line (0-based)
---@param col integer Column (0-based)
---
---@return boolean True if the position is in node range
function M.is_in_node_range(node, line, col)
  return M.node_contains(node, { line, col, line, col + 1 })
end

--- Determines if a node contains a range
---
---@param node TSNode
---@param range table
---
---@return boolean True if the {node} contains the {range}
function M.node_contains(node, range)
  vim.validate({
    -- allow a table so nodes can be mocked
    node = { node, { 'userdata', 'table' } },
    range = { range, Range.validate, 'integer list with 4 or 6 elements' },
  })
  return Range.contains({ node:range() }, range)
end

--- Returns a list of highlight captures at the given position
---
--- Each capture is represented by a table containing the capture name as a string as
--- well as a table of metadata (`priority`, `conceal`, ...; empty if none are defined).
---
---@param bufnr integer Buffer number (0 for current buffer)
---@param row integer Position row
---@param col integer Position column
---
---@return table[] List of captures `{ capture = "name", metadata = { ... } }`
function M.get_captures_at_pos(bufnr, row, col)
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
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
          table.insert(matches, { capture = c, metadata = metadata, lang = tree:lang() })
        end
      end
    end
  end)
  return matches
end

--- Returns a list of highlight capture names under the cursor
---
---@param winnr (integer|nil) Window handle or 0 for current window (default)
---
---@return string[] List of capture names
function M.get_captures_at_cursor(winnr)
  winnr = winnr or 0
  local bufnr = api.nvim_win_get_buf(winnr)
  local cursor = api.nvim_win_get_cursor(winnr)

  local data = M.get_captures_at_pos(bufnr, cursor[1] - 1, cursor[2])

  local captures = {}

  for _, capture in ipairs(data) do
    table.insert(captures, capture.capture)
  end

  return captures
end

--- Returns the smallest named node at the given position
---
---@param opts table|nil Optional keyword arguments:
---             - bufnr integer|nil Buffer number (nil or 0 for current buffer)
---             - pos table|nil 0-indexed (row, col) tuple. Defaults to cursor position in the
---                             current window. Required if {bufnr} is not the current buffer
---             - ignore_injections boolean Ignore injected languages (default true)
---
---@return TSNode | nil Node at the given position
function M.get_node(opts)
  opts = opts or {}

  local bufnr = opts.bufnr

  if not bufnr or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local row, col
  if opts.pos then
    assert(#opts.pos == 2, 'Position must be a (row, col) tuple')
    row, col = opts.pos[1], opts.pos[2]
  else
    assert(
      bufnr == api.nvim_get_current_buf(),
      'Position must be explicitly provided when not using the current buffer'
    )
    local pos = api.nvim_win_get_cursor(0)
    -- Subtract one to account for 1-based row indexing in nvim_win_get_cursor
    row, col = pos[1] - 1, pos[2]
  end

  assert(row >= 0 and col >= 0, 'Invalid position: row and col must be non-negative')

  local ts_range = { row, col, row, col }

  local root_lang_tree = M.get_parser(bufnr)
  if not root_lang_tree then
    return
  end

  return root_lang_tree:named_node_for_range(ts_range, opts)
end

--- Returns the smallest named node at the given position
---
---@param bufnr integer Buffer number (0 for current buffer)
---@param row integer Position row
---@param col integer Position column
---@param opts table Optional keyword arguments:
---             - lang string|nil Parser language
---             - ignore_injections boolean Ignore injected languages (default true)
---
---@return TSNode | nil Node at the given position
---@deprecated
function M.get_node_at_pos(bufnr, row, col, opts)
  vim.deprecate('vim.treesitter.get_node_at_pos()', 'vim.treesitter.get_node()', '0.10')
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end
  local ts_range = { row, col, row, col }

  opts = opts or {}

  local root_lang_tree = M.get_parser(bufnr, opts.lang)
  if not root_lang_tree then
    return
  end

  return root_lang_tree:named_node_for_range(ts_range, opts)
end

--- Returns the smallest named node under the cursor
---
---@param winnr (integer|nil) Window handle or 0 for current window (default)
---
---@return string Name of node under the cursor
---@deprecated
function M.get_node_at_cursor(winnr)
  vim.deprecate('vim.treesitter.get_node_at_cursor()', 'vim.treesitter.get_node():type()', '0.10')
  winnr = winnr or 0
  local bufnr = api.nvim_win_get_buf(winnr)

  return M.get_node({ bufnr = bufnr, ignore_injections = false }):type()
end

--- Starts treesitter highlighting for a buffer
---
--- Can be used in an ftplugin or FileType autocommand.
---
--- Note: By default, disables regex syntax highlighting, which may be required for some plugins.
--- In this case, add ``vim.bo.syntax = 'on'`` after the call to `start`.
---
--- Example:
--- <pre>lua
--- vim.api.nvim_create_autocmd( 'FileType', { pattern = 'tex',
---     callback = function(args)
---         vim.treesitter.start(args.buf, 'latex')
---         vim.bo[args.buf].syntax = 'on'  -- only if additional legacy syntax is needed
---     end
--- })
--- </pre>
---
---@param bufnr (integer|nil) Buffer to be highlighted (default: current buffer)
---@param lang (string|nil) Language of the parser (default: buffer filetype)
function M.start(bufnr, lang)
  bufnr = bufnr or api.nvim_get_current_buf()
  local parser = M.get_parser(bufnr, lang)
  M.highlighter.new(parser)
end

--- Stops treesitter highlighting for a buffer
---
---@param bufnr (integer|nil) Buffer to stop highlighting (default: current buffer)
function M.stop(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if M.highlighter.active[bufnr] then
    M.highlighter.active[bufnr]:destroy()
  end
end

--- Open a window that displays a textual representation of the nodes in the language tree.
---
--- While in the window, press "a" to toggle display of anonymous nodes, "I" to toggle the
--- display of the source language of each node, and press <Enter> to jump to the node under the
--- cursor in the source buffer.
---
--- Can also be shown with `:InspectTree`. *:InspectTree*
---
---@param opts table|nil Optional options table with the following possible keys:
---                      - lang (string|nil): The language of the source buffer. If omitted, the
---                        filetype of the source buffer is used.
---                      - bufnr (integer|nil): Buffer to draw the tree into. If omitted, a new
---                        buffer is created.
---                      - winid (integer|nil): Window id to display the tree buffer in. If omitted,
---                        a new window is created with {command}.
---                      - command (string|nil): Vimscript command to create the window. Default
---                        value is "60vnew". Only used when {winid} is nil.
---                      - title (string|fun(bufnr:integer):string|nil): Title of the window. If a
---                        function, it accepts the buffer number of the source buffer as its only
---                        argument and should return a string.
function M.inspect_tree(opts)
  ---@cast opts InspectTreeOpts
  require('vim.treesitter.playground').inspect_tree(opts)
end

--- Returns the fold level for {lnum} in the current buffer. Can be set directly to 'foldexpr':
--- <pre>lua
--- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--- </pre>
---@param lnum integer|nil Line number to calculate fold level for
---@return string
function M.foldexpr(lnum)
  return require('vim.treesitter._fold').foldexpr(lnum)
end

return M
