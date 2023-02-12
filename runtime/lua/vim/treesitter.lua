local a = vim.api
local query = require('vim.treesitter.query')
local language = require('vim.treesitter.language')
local LanguageTree = require('vim.treesitter.languagetree')

---@type table<integer,LanguageTree>
local parsers = setmetatable({}, { __mode = 'v' })

---@class TreesitterModule
---@field highlighter TSHighlighter
local M = vim.tbl_extend('error', query, language)

M.language_version = vim._ts_get_language_version()
M.minimum_language_version = vim._ts_get_minimum_language_version()

setmetatable(M, {
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
  end,
})

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
  language.require_language(lang)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  vim.fn.bufload(bufnr)

  local self = LanguageTree.new(bufnr, lang, opts)

  ---@diagnostic disable:invisible

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

  a.nvim_buf_attach(
    source,
    false,
    { on_bytes = bytes_cb, on_detach = detach_cb, on_reload = reload_cb, preview = true }
  )

  self:parse()

  return self
end

--- Returns the parser for a specific buffer and filetype and attaches it to the buffer
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
  language.require_language(lang)

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
---@param node_or_range (TSNode|table) Node or table of positions
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

--- Determines whether (line, col) position is in node range
---
---@param node TSNode defining the range
---@param line integer Line (0-based)
---@param col integer Column (0-based)
---
---@return boolean True if the position is in node range
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

--- Determines if a node contains a range
---
---@param node TSNode
---@param range table
---
---@return boolean True if the {node} contains the {range}
function M.node_contains(node, range)
  local start_row, start_col, end_row, end_col = node:range()
  local start_fits = start_row < range[1] or (start_row == range[1] and start_col <= range[2])
  local end_fits = end_row > range[3] or (end_row == range[3] and end_col >= range[4])

  return start_fits and end_fits
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
---@return table[] List of captures `{ capture = "capture name", metadata = { ... } }`
function M.get_captures_at_pos(bufnr, row, col)
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
          table.insert(matches, { capture = c, metadata = metadata, lang = tree:lang() })
        end
      end
    end
  end, true)
  return matches
end

--- Returns a list of highlight capture names under the cursor
---
---@param winnr (integer|nil) Window handle or 0 for current window (default)
---
---@return string[] List of capture names
function M.get_captures_at_cursor(winnr)
  winnr = winnr or 0
  local bufnr = a.nvim_win_get_buf(winnr)
  local cursor = a.nvim_win_get_cursor(winnr)

  local data = M.get_captures_at_pos(bufnr, cursor[1] - 1, cursor[2])

  local captures = {}

  for _, capture in ipairs(data) do
    table.insert(captures, capture.capture)
  end

  return captures
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
---@return TSNode|nil under the cursor
function M.get_node_at_pos(bufnr, row, col, opts)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local ts_range = { row, col, row, col }

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
function M.get_node_at_cursor(winnr)
  winnr = winnr or 0
  local bufnr = a.nvim_win_get_buf(winnr)
  local cursor = a.nvim_win_get_cursor(winnr)

  return M.get_node_at_pos(bufnr, cursor[1] - 1, cursor[2], { ignore_injections = false }):type()
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
  bufnr = bufnr or a.nvim_get_current_buf()
  local parser = M.get_parser(bufnr, lang)
  M.highlighter.new(parser)
end

--- Stops treesitter highlighting for a buffer
---
---@param bufnr (integer|nil) Buffer to stop highlighting (default: current buffer)
function M.stop(bufnr)
  bufnr = bufnr or a.nvim_get_current_buf()

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
---@param opts table|nil Optional options table with the following possible keys:
---                      - lang (string|nil): The language of the source buffer. If omitted, the
---                        filetype of the source buffer is used.
---                      - bufnr (integer|nil): Buffer to draw the tree into. If omitted, a new
---                        buffer is created.
---                      - winid (integer|nil): Window id to display the tree buffer in. If omitted,
---                        a new window is created with {command}.
---                      - command (string|nil): Vimscript command to create the window. Default
---                        value is "topleft 60vnew". Only used when {winid} is nil.
---                      - title (string|fun(bufnr:integer):string|nil): Title of the window. If a
---                        function, it accepts the buffer number of the source buffer as its only
---                        argument and should return a string.
function M.show_tree(opts)
  vim.validate({
    opts = { opts, 't', true },
  })

  opts = opts or {}

  local Playground = require('vim.treesitter.playground')
  local buf = a.nvim_get_current_buf()
  local win = a.nvim_get_current_win()
  local pg = assert(Playground:new(buf, opts.lang))

  -- Close any existing playground window
  if vim.b[buf].playground then
    local w = vim.b[buf].playground
    if a.nvim_win_is_valid(w) then
      a.nvim_win_close(w, true)
    end
  end

  local w = opts.winid
  if not w then
    vim.cmd(opts.command or 'topleft 60vnew')
    w = a.nvim_get_current_win()
  end

  local b = opts.bufnr
  if b then
    a.nvim_win_set_buf(w, b)
  else
    b = a.nvim_win_get_buf(w)
  end

  vim.b[buf].playground = w

  vim.wo[w].scrolloff = 5
  vim.wo[w].wrap = false
  vim.bo[b].buflisted = false
  vim.bo[b].buftype = 'nofile'
  vim.bo[b].bufhidden = 'wipe'

  local title = opts.title
  if not title then
    local bufname = a.nvim_buf_get_name(buf)
    title = string.format('Syntax tree for %s', vim.fn.fnamemodify(bufname, ':.'))
  elseif type(title) == 'function' then
    title = title(buf)
  end

  assert(type(title) == 'string', 'Window title must be a string')
  a.nvim_buf_set_name(b, title)

  pg:draw(b)

  vim.fn.matchadd('Comment', '\\[[0-9:-]\\+\\]')
  vim.fn.matchadd('String', '".*"')

  a.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
  a.nvim_buf_set_keymap(b, 'n', '<CR>', '', {
    desc = 'Jump to the node under the cursor in the source buffer',
    callback = function()
      local row = a.nvim_win_get_cursor(w)[1]
      local pos = pg:get(row)
      a.nvim_set_current_win(win)
      a.nvim_win_set_cursor(win, { pos.lnum + 1, pos.col })
    end,
  })
  a.nvim_buf_set_keymap(b, 'n', 'a', '', {
    desc = 'Toggle anonymous nodes',
    callback = function()
      pg.opts.anon = not pg.opts.anon
      pg:draw(b)
    end,
  })
  a.nvim_buf_set_keymap(b, 'n', 'I', '', {
    desc = 'Toggle language display',
    callback = function()
      pg.opts.lang = not pg.opts.lang
      pg:draw(b)
    end,
  })

  local group = a.nvim_create_augroup('treesitter/playground', {})

  a.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = b,
    callback = function()
      a.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
      local row = a.nvim_win_get_cursor(w)[1]
      local pos = pg:get(row)
      a.nvim_buf_set_extmark(buf, pg.ns, pos.lnum, pos.col, {
        end_row = pos.end_lnum,
        end_col = math.max(0, pos.end_col),
        hl_group = 'Visual',
      })
    end,
  })

  a.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = buf,
    callback = function()
      if not a.nvim_buf_is_loaded(b) then
        return true
      end

      a.nvim_buf_clear_namespace(b, pg.ns, 0, -1)

      local cursor = a.nvim_win_get_cursor(win)
      local cursor_node = M.get_node_at_pos(buf, cursor[1] - 1, cursor[2], {
        lang = opts.lang,
        ignore_injections = false,
      })
      if not cursor_node then
        return
      end

      local cursor_node_id = cursor_node:id()
      for i, v in pg:iter() do
        if v.id == cursor_node_id then
          local start = v.depth
          local end_col = start + #v.text
          a.nvim_buf_set_extmark(b, pg.ns, i - 1, start, {
            end_col = end_col,
            hl_group = 'Visual',
          })
          a.nvim_win_set_cursor(w, { i, 0 })
          break
        end
      end
    end,
  })

  a.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = group,
    buffer = buf,
    callback = function()
      if not a.nvim_buf_is_loaded(b) then
        return true
      end

      pg = assert(Playground:new(buf, opts.lang))
      pg:draw(b)
    end,
  })

  a.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = b,
    callback = function()
      a.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
    end,
  })

  a.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = buf,
    callback = function()
      if not a.nvim_buf_is_loaded(b) then
        return true
      end

      a.nvim_buf_clear_namespace(b, pg.ns, 0, -1)
    end,
  })

  a.nvim_create_autocmd('BufHidden', {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      if a.nvim_win_is_valid(w) then
        a.nvim_win_close(w, true)
      end
    end,
  })
end

return M
