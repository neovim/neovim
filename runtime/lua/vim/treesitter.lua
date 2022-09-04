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
---@param bufnr The buffer the parser will be tied to
---@param lang The language of the parser
---@param opts Options to pass to the created language tree
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
---@param bufnr The buffer the parser should be tied to
---@param lang The filetype of this parser
---@param opts Options object to pass to the created language tree
---
---@returns The parser
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
---@param dest table the possible ancestor
---@param source table the possible descendant node
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
---@param node Node defining the range
---@param line A line (0-based)
---@param col A column (0-based)
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
---@param node table The node
---@param range table The range
---
---@returns (boolean) True if the node contains the range
function M.node_contains(node, range)
  local start_row, start_col, end_row, end_col = node:range()
  local start_fits = start_row < range[1] or (start_row == range[1] and start_col <= range[2])
  local end_fits = end_row > range[3] or (end_row == range[3] and end_col >= range[4])

  return start_fits and end_fits
end

---Gets a list of captures for a given cursor position
---@param bufnr number The buffer number
---@param row number The position row
---@param col number The position column
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

--- Gets the smallest named node under the cursor
---
---@param winnr number Window handle or 0 for current window
---@param opts table Options table
---@param opts.ignore_injections boolean (default true) Ignore injected languages.
---
---@returns (table) The named node under the cursor
function M.get_node_at_cursor(winnr, opts)
  winnr = winnr or 0
  local cursor = a.nvim_win_get_cursor(winnr)
  local ts_cursor_range = { cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2] }

  local buf = a.nvim_win_get_buf(winnr)
  local root_lang_tree = M.get_parser(buf)
  if not root_lang_tree then
    return
  end

  return root_lang_tree:named_node_for_range(ts_cursor_range, opts)
end

---Gets a compatible vim range (1 index based) from a TS node range.
---
---TS nodes start with 0 and the end col is ending exclusive.
---They also treat a EOF/EOL char as a char ending in the first
---col of the next row.
---
---@param bufnr number The buffer handle from which the range is from
---@param range table The treesitter range to transform
---
---@returns start_row, starcol, end_row, end_col
function M.get_vim_range(bufnr, range)
  local srow, scol, erow, ecol = unpack(range)
  srow = srow + 1
  scol = scol + 1
  erow = erow + 1

  if ecol == 0 then
    -- Use the value of the last col of the previous row instead.
    erow = erow - 1
    if not bufnr or bufnr == 0 then
      ecol = vim.fn.col({ erow, '$' }) - 1
    else
      ecol = #a.nvim_buf_get_lines(bufnr, erow - 1, erow, false)[1]
    end
  end
  return srow, scol, erow, ecol
end

---Highlights the given range
---
---@param bufnr number The buffer number
---@param range table The treesitter range to highlight
---@param ns number The namespace id
---@param hlgroup string The highlight group name
---@param opts table Options to pass to |vim.highlight.range()|
function M.highlight_range(bufnr, range, ns, hlgroup, opts)
  local start_row, start_col, end_row, end_col = unpack(range)
  vim.highlight.range(bufnr, ns, hlgroup, { start_row, start_col }, { end_row, end_col }, opts)
end

---Highlights the given node
---
---@param bufnr number The buffer number
---@param node table The node to highlight
---@param ns number The namespace id
---@param hlgroup string The highlight group name
function M.highlight_node(bufnr, node, ns, hlgroup)
  if not node then
    return
  end
  M.highlight_range(bufnr, { node:range() }, ns, hlgroup)
end

local function get_node_range(node_or_range)
  if type(node_or_range) == 'table' then
    return unpack(node_or_range)
  else
    return node_or_range:range()
  end
end

---Sets visual selection for node
---@param bufnr number The buffer number
---@param node table The node to visually select select
---@param opts table Options table
---@param opts.selection_mode string (default 'charwise') Set the selection mode:
---       - 'charwise'(or 'v')
---       - 'linewise'(or 'V')
---       - 'blockwise'(or '<C-v>')
function M.update_selection(bufnr, node, opts)
  opts = opts or {}

  local selection_mode = opts.selection_mode or 'charwise'
  local start_row, start_col, end_row, end_col = M.get_vim_range(bufnr, { get_node_range(node) })

  vim.fn.setpos('.', { bufnr, start_row, start_col, 0 })

  -- Start visual selection in appropriate mode
  local v_table = { charwise = 'v', linewise = 'V', blockwise = '<C-v>' }
  ---- Call to `nvim_replace_termcodes()` is needed for sending appropriate
  ---- command to enter blockwise mode
  local mode_string =
    vim.api.nvim_replace_termcodes(v_table[selection_mode] or selection_mode, true, true, true)
  vim.cmd('normal! ' .. mode_string)
  vim.fn.setpos('.', { bufnr, start_row, start_col, 0 })
  vim.cmd('normal! o')
  vim.fn.setpos('.', { bufnr, end_row, end_col, 0 })
end

---Goes to the given node
---
---@param node table The node to go to
---@param opts table Options table
---@param opts.goto_end boolean (default false) set cursor at the end of the node
---@param opts.set_jump boolean (default false) mark current position before moving the cursor
function M.goto_node(node, opts)
  opts = opts or {}
  local goto_end = vim.F.if_nil(opts.goto_end, false)
  local set_jump = vim.F.if_nil(opts.goto_end, false)

  if not node then
    return
  end

  if set_jump then
    vim.cmd("normal! m'")
  end

  local range = { M.get_vim_range(nil, { node:range() }) }
  local position
  if goto_end then
    position = { range[3], range[4] }
  else
    position = { range[1], range[2] }
  end

  -- Position is 1, 0 indexed.
  a.nvim_win_set_cursor(0, { position[1], position[2] - 1 })
end

---Gets the node range in the lsp range format
---@param node table The node to convert
---
---@returns { start =`start_position`, end = `end_position` }
function M.node_to_lsp_range(node)
  local start_line, start_col, end_line, end_col = get_node_range(node)
  local rtn = {}
  rtn.start = { line = start_line, character = start_col }
  rtn['end'] = { line = end_line, character = end_col }
  return rtn
end

---Swaps the two given nodes
---@param bufnr number The buffer number
---@param node_or_range1 table The 1st node or its range
---@param node_or_range2 table The 2nd node or its range
---@param opts table Options table
---@param opts.cursor_to_second boolean (default false) set cursor on the second node after the swap
function M.swap_nodes(bufnr, node_or_range1, node_or_range2, opts)
  opts = opts or {}
  local cursor_to_second = vim.F.if_nil(opts.cursor_to_second, false)

  if not node_or_range1 or not node_or_range2 then
    return
  end

  local range1 = M.node_to_lsp_range(node_or_range1)
  local range2 = M.node_to_lsp_range(node_or_range2)

  local text1 = query.get_node_text(node_or_range1, bufnr, { concat = false })
  local text2 = query.get_node_text(node_or_range2, bufnr, { concat = false })

  local edit1 = { range = range1, newText = table.concat(text2, '\n') }
  local edit2 = { range = range2, newText = table.concat(text1, '\n') }
  vim.lsp.util.apply_text_edits({ edit1, edit2 }, bufnr, 'utf-8')

  if cursor_to_second then
    vim.cmd("normal! m'")

    local char_delta = 0
    local line_delta = 0
    if
      range1['end'].line < range2.start.line
      or (
        range1['end'].line == range2.start.line
        and range1['end'].character < range2.start.character
      )
    then
      line_delta = #text2 - #text1
    end

    if
      range1['end'].line == range2.start.line and range1['end'].character < range2.start.character
    then
      if line_delta ~= 0 then
        --- why?
        --correction_after_line_change =  -range2.start.character
        --text_now_before_range2 = #(text2[#text2])
        --space_between_ranges = range2.start.character - range1['end'].character
        --char_delta = correction_after_line_change + text_now_before_range2 + space_between_ranges
        --- Equivalent to:
        char_delta = #text2[#text2] - range1['end'].character

        -- add range1.start.character if last line of range1 (now text2) does not start at 0
        if range1.start.line == range2.start.line + line_delta then
          char_delta = char_delta + range1.start.character
        end
      else
        char_delta = #text2[#text2] - #text1[#text1]
      end
    end

    a.nvim_win_set_cursor(
      a.nvim_get_current_win(),
      { range2.start.line + 1 + line_delta, range2.start.character + char_delta }
    )
  end
end

return M
