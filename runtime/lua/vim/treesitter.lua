local api = vim.api

---@type table<integer,vim.treesitter.LanguageTree>
local parsers = setmetatable({}, { __mode = 'v' })

local M = vim._defer_require('vim.treesitter', {
  _fold = ..., --- @module 'vim.treesitter._fold'
  _query_linter = ..., --- @module 'vim.treesitter._query_linter'
  _range = ..., --- @module 'vim.treesitter._range'
  dev = ..., --- @module 'vim.treesitter.dev'
  highlighter = ..., --- @module 'vim.treesitter.highlighter'
  language = ..., --- @module 'vim.treesitter.language'
  languagetree = ..., --- @module 'vim.treesitter.languagetree'
  query = ..., --- @module 'vim.treesitter.query'
})

local LanguageTree = M.languagetree

--- @nodoc
M.language_version = vim._ts_get_language_version()

--- @nodoc
M.minimum_language_version = vim._ts_get_minimum_language_version()

--- Creates a new parser
---
--- It is not recommended to use this; use |get_parser()| instead.
---
---@param bufnr integer Buffer the parser will be tied to (0 for current buffer)
---@param lang string Language of the parser
---@param opts (table|nil) Options to pass to the created language tree
---
---@return vim.treesitter.LanguageTree object to use for parsing
function M._create_parser(bufnr, lang, opts)
  bufnr = vim._resolve_bufnr(bufnr)

  local self = LanguageTree.new(bufnr, lang, opts)

  local function bytes_cb(_, ...)
    self:_on_bytes(...)
  end

  local function detach_cb(_, ...)
    if parsers[bufnr] == self then
      parsers[bufnr] = nil
    end
    self:_on_detach(...)
  end

  local function reload_cb(_)
    self:_on_reload()
  end

  local source = self:source() --[[@as integer]]

  api.nvim_buf_attach(
    source,
    false,
    { on_bytes = bytes_cb, on_detach = detach_cb, on_reload = reload_cb, preview = true }
  )

  return self
end

local function valid_lang(lang)
  return lang and lang ~= ''
end

--- Returns the parser for a specific buffer and attaches it to the buffer
---
--- If needed, this will create the parser.
---
--- If no parser can be created, an error is thrown. Set `opts.error = false` to suppress this and
--- return nil (and an error message) instead. WARNING: This behavior will become default in Nvim
--- 0.12 and the option will be removed.
---
---@param bufnr (integer|nil) Buffer the parser should be tied to (default: current buffer)
---@param lang (string|nil) Language of this parser (default: from buffer filetype)
---@param opts (table|nil) Options to pass to the created language tree
---
---@return vim.treesitter.LanguageTree? object to use for parsing
---@return string? error message, if applicable
function M.get_parser(bufnr, lang, opts)
  opts = opts or {}
  local should_error = opts.error == nil or opts.error

  bufnr = vim._resolve_bufnr(bufnr)

  if not valid_lang(lang) then
    lang = M.language.get_lang(vim.bo[bufnr].filetype)
  end

  if not valid_lang(lang) then
    if not parsers[bufnr] then
      local err_msg =
        string.format('Parser not found for buffer %s: language could not be determined', bufnr)
      if should_error then
        error(err_msg)
      end
      return nil, err_msg
    end
  elseif parsers[bufnr] == nil or parsers[bufnr]:lang() ~= lang then
    if not api.nvim_buf_is_loaded(bufnr) then
      error(('Buffer %s must be loaded to create parser'):format(bufnr))
    end
    local parser = vim.F.npcall(M._create_parser, bufnr, lang, opts)
    if not parser then
      local err_msg =
        string.format('Parser could not be created for buffer %s and language "%s"', bufnr, lang)
      if should_error then
        error(err_msg)
      end
      return nil, err_msg
    end
    parsers[bufnr] = parser
  end

  parsers[bufnr]:register_cbs(opts.buf_attach_cbs)

  return parsers[bufnr]
end

--- Returns a string parser
---
---@param str string Text to parse
---@param lang string Language of this string
---@param opts (table|nil) Options to pass to the created language tree
---
---@return vim.treesitter.LanguageTree object to use for parsing
function M.get_string_parser(str, lang, opts)
  vim.validate('str', str, 'string')
  vim.validate('lang', lang, 'string')

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

  return dest:child_with_descendant(source) ~= nil
end

--- Returns the node's range or an unpacked range table
---
---@param node_or_range TSNode|Range4 Node or table of positions
---
---@return integer start_row
---@return integer start_col
---@return integer end_row
---@return integer end_col
function M.get_node_range(node_or_range)
  if type(node_or_range) == 'table' then
    --- @cast node_or_range -TSNode LuaLS bug
    return M._range.unpack4(node_or_range)
  else
    return node_or_range:range(false)
  end
end

---Get the range of a |TSNode|. Can also supply {source} and {metadata}
---to get the range with directives applied.
---@param node TSNode
---@param source integer|string|nil Buffer or string from which the {node} is extracted
---@param metadata vim.treesitter.query.TSMetadata|nil
---@return Range6
function M.get_range(node, source, metadata)
  if metadata and metadata.range then
    assert(source)
    return M._range.add_bytes(source, metadata.range)
  end
  return { node:range(true) }
end

---@param buf integer
---@param range Range
---@returns string
local function buf_range_get_text(buf, range)
  local start_row, start_col, end_row, end_col = M._range.unpack4(range)
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
    local range = M.get_range(node, source, metadata)
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
  -- allow a table so nodes can be mocked
  vim.validate('node', node, { 'userdata', 'table' })
  vim.validate('range', range, M._range.validate, 'integer list with 4 or 6 elements')
  --- @diagnostic disable-next-line: missing-fields LuaLS bug
  local nrange = { node:range() } --- @type Range4
  return M._range.contains(nrange, range)
end

--- Returns a list of highlight captures at the given position
---
--- Each capture is represented by a table containing the capture name as a string, the capture's
--- language, a table of metadata (`priority`, `conceal`, ...; empty if none are defined), and the
--- id of the capture.
---
---@param bufnr integer Buffer number (0 for current buffer)
---@param row integer Position row
---@param col integer Position column
---
---@return {capture: string, lang: string, metadata: vim.treesitter.query.TSMetadata, id: integer}[]
function M.get_captures_at_pos(bufnr, row, col)
  bufnr = vim._resolve_bufnr(bufnr)
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
    local query = q:query()

    -- Some injected languages may not have highlight queries.
    if not query then
      return
    end

    local iter = query:iter_captures(root, buf_highlighter.bufnr, row, row + 1)

    for id, node, metadata, match in iter do
      if M.is_in_node_range(node, row, col) then
        ---@diagnostic disable-next-line: invisible
        local capture = query.captures[id] -- name of the capture in the query
        if capture ~= nil then
          local _, pattern_id = match:info()
          table.insert(matches, {
            capture = capture,
            metadata = metadata,
            lang = tree:lang(),
            id = id,
            pattern_id = pattern_id,
          })
        end
      end
    end
  end)
  return matches
end

--- Returns a list of highlight capture names under the cursor
---
---@param winnr (integer|nil): |window-ID| or 0 for current window (default)
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

--- Optional keyword arguments:
--- @class vim.treesitter.get_node.Opts : vim.treesitter.LanguageTree.tree_for_range.Opts
--- @inlinedoc
---
--- Buffer number (nil or 0 for current buffer)
--- @field bufnr integer?
---
--- 0-indexed (row, col) tuple. Defaults to cursor position in the
--- current window. Required if {bufnr} is not the current buffer
--- @field pos [integer, integer]?
---
--- Parser language. (default: from buffer filetype)
--- @field lang string?
---
--- Ignore injected languages (default true)
--- @field ignore_injections boolean?
---
--- Include anonymous nodes (default false)
--- @field include_anonymous boolean?

--- Returns the smallest named node at the given position
---
--- NOTE: Calling this on an unparsed tree can yield an invalid node.
--- If the tree is not known to be parsed by, e.g., an active highlighter,
--- parse the tree first via
---
--- ```lua
--- vim.treesitter.get_parser(bufnr):parse(range)
--- ```
---
---@param opts vim.treesitter.get_node.Opts?
---
---@return TSNode | nil Node at the given position
function M.get_node(opts)
  opts = opts or {}

  local bufnr = vim._resolve_bufnr(opts.bufnr)

  local row, col --- @type integer, integer
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

  local root_lang_tree = M.get_parser(bufnr, opts.lang, { error = false })
  if not root_lang_tree then
    return
  end

  if opts.include_anonymous then
    return root_lang_tree:node_for_range(ts_range, opts)
  end
  return root_lang_tree:named_node_for_range(ts_range, opts)
end

--- Starts treesitter highlighting for a buffer
---
--- Can be used in an ftplugin or FileType autocommand.
---
--- Note: By default, disables regex syntax highlighting, which may be required for some plugins.
--- In this case, add `vim.bo.syntax = 'on'` after the call to `start`.
---
--- Note: By default, the highlighter parses code asynchronously, using a segment time of 3ms.
---
--- Example:
---
--- ```lua
--- vim.api.nvim_create_autocmd( 'FileType', { pattern = 'tex',
---     callback = function(args)
---         vim.treesitter.start(args.buf, 'latex')
---         vim.bo[args.buf].syntax = 'on'  -- only if additional legacy syntax is needed
---     end
--- })
--- ```
---
---@param bufnr integer? Buffer to be highlighted (default: current buffer)
---@param lang string? Language of the parser (default: from buffer filetype)
function M.start(bufnr, lang)
  bufnr = vim._resolve_bufnr(bufnr)
  -- Ensure buffer is loaded. `:edit` over `bufload()` to show swapfile prompt.
  if not api.nvim_buf_is_loaded(bufnr) then
    if api.nvim_buf_get_name(bufnr) ~= '' then
      pcall(api.nvim_buf_call, bufnr, vim.cmd.edit)
    else
      vim.fn.bufload(bufnr)
    end
  end
  local parser = assert(M.get_parser(bufnr, lang, { error = false }))
  M.highlighter.new(parser)
end

--- Stops treesitter highlighting for a buffer
---
---@param bufnr (integer|nil) Buffer to stop highlighting (default: current buffer)
function M.stop(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)

  if M.highlighter.active[bufnr] then
    M.highlighter.active[bufnr]:destroy()
  end
end

--- Open a window that displays a textual representation of the nodes in the language tree.
---
--- While in the window, press "a" to toggle display of anonymous nodes, "I" to toggle the
--- display of the source language of each node, "o" to toggle the query editor, and press
--- [<Enter>] to jump to the node under the cursor in the source buffer. Folding also works
--- (try |zo|, |zc|, etc.).
---
--- Can also be shown with `:InspectTree`. [:InspectTree]()
---
---@since 11
---@param opts table|nil Optional options table with the following possible keys:
---                      - lang (string|nil): The language of the source buffer. If omitted, detect
---                        from the filetype of the source buffer.
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
  ---@diagnostic disable-next-line: invisible
  M.dev.inspect_tree(opts)
end

--- Returns the fold level for {lnum} in the current buffer. Can be set directly to 'foldexpr':
---
--- ```lua
--- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
--- ```
---
---@since 11
---@param lnum integer|nil Line number to calculate fold level for
---@return string
function M.foldexpr(lnum)
  return M._fold.foldexpr(lnum)
end

return M
