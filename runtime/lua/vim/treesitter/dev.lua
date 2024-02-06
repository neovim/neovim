local api = vim.api

---@class TSDevModule
local M = {}

---@private
---@class TSTreeView
---@field ns integer API namespace
---@field opts TSTreeViewOpts
---@field nodes TSP.Node[]
---@field named TSP.Node[]
local TSTreeView = {}

---@private
---@class TSTreeViewOpts
---@field anon boolean If true, display anonymous nodes.
---@field lang boolean If true, display the language alongside each node.
---@field indent number Number of spaces to indent nested lines.

---@class TSP.Node
---@field node TSNode Treesitter node
---@field field string? Node field
---@field depth integer Depth of this node in the tree
---@field text string? Text displayed in the inspector for this node. Not computed until the
---                    inspector is drawn.
---@field lang string Source language of this node

---@class TSP.Injection
---@field lang string Source language of this injection
---@field root TSNode Root node of the injection

--- Traverse all child nodes starting at {node}.
---
--- This is a recursive function. The {depth} parameter indicates the current recursion level.
--- {lang} is a string indicating the language of the tree currently being traversed. Each traversed
--- node is added to {tree}. When recursion completes, {tree} is an array of all nodes in the order
--- they were visited.
---
--- {injections} is a table mapping node ids from the primary tree to language tree injections. Each
--- injected language has a series of trees nested within the primary language's tree, and the root
--- node of each of these trees is contained within a node in the primary tree. The {injections}
--- table maps nodes in the primary tree to root nodes of injected trees.
---
---@param node TSNode Starting node to begin traversal |tsnode|
---@param depth integer Current recursion depth
---@param field string|nil The field of the current node
---@param lang string Language of the tree currently being traversed
---@param injections table<string, TSP.Injection> Mapping of node ids to root nodes
---                  of injected language trees (see explanation above)
---@param tree TSP.Node[] Output table containing a list of tables each representing a node in the tree
local function traverse(node, depth, field, lang, injections, tree)
  table.insert(tree, {
    node = node,
    depth = depth,
    lang = lang,
    field = field,
  })

  local injection = injections[node:id()]
  if injection then
    traverse(injection.root, depth + 1, nil, injection.lang, injections, tree)
  end

  for child, child_field in node:iter_children() do
    traverse(child, depth + 1, child_field, lang, injections, tree)
  end

  return tree
end

--- Create a new treesitter view.
---
---@param bufnr integer Source buffer number
---@param lang string|nil Language of source buffer
---
---@return TSTreeView|nil
---@return string|nil Error message, if any
---
---@package
function TSTreeView:new(bufnr, lang)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr or 0, lang)
  if not ok then
    local err = parser --[[ @as string ]]
    return nil, 'No parser available for the given buffer:\n' .. err
  end

  -- For each child tree (injected language), find the root of the tree and locate the node within
  -- the primary tree that contains that root. Add a mapping from the node in the primary tree to
  -- the root in the child tree to the {injections} table.
  local root = parser:parse(true)[1]:root()
  local injections = {} ---@type table<string, TSP.Injection>

  parser:for_each_tree(function(parent_tree, parent_ltree)
    local parent = parent_tree:root()
    for _, child in pairs(parent_ltree:children()) do
      for _, tree in pairs(child:trees()) do
        local r = tree:root()
        local node = assert(parent:named_descendant_for_range(r:range()))
        local id = node:id()
        if not injections[id] or r:byte_length() > injections[id].root:byte_length() then
          injections[id] = {
            lang = child:lang(),
            root = r,
          }
        end
      end
    end
  end)

  local nodes = traverse(root, 0, nil, parser:lang(), injections, {})

  local named = {} ---@type TSP.Node[]
  for _, v in ipairs(nodes) do
    if v.node:named() then
      named[#named + 1] = v
    end
  end

  local t = {
    ns = api.nvim_create_namespace('treesitter/dev-inspect'),
    nodes = nodes,
    named = named,
    ---@type TSTreeViewOpts
    opts = {
      anon = false,
      lang = false,
      indent = 2,
    },
  }

  setmetatable(t, self)
  self.__index = self
  return t
end

local decor_ns = api.nvim_create_namespace('ts.dev')

---@param range Range4
---@return string
local function range_to_string(range)
  ---@type integer, integer, integer, integer
  local row, col, end_row, end_col = unpack(range)
  return string.format('[%d, %d] - [%d, %d]', row, col, end_row, end_col)
end

---@param w integer
---@return boolean closed Whether the window was closed.
local function close_win(w)
  if api.nvim_win_is_valid(w) then
    api.nvim_win_close(w, true)
    return true
  end

  return false
end

---@param w integer
---@param b integer
local function set_dev_properties(w, b)
  vim.wo[w].scrolloff = 5
  vim.wo[w].wrap = false
  vim.wo[w].foldmethod = 'manual' -- disable folding
  vim.bo[b].buflisted = false
  vim.bo[b].buftype = 'nofile'
  vim.bo[b].bufhidden = 'wipe'
  vim.bo[b].filetype = 'query'
end

--- Updates the cursor position in the inspector to match the node under the cursor.
---
--- @param treeview TSTreeView
--- @param lang string
--- @param source_buf integer
--- @param inspect_buf integer
--- @param inspect_win integer
--- @param pos? { [1]: integer, [2]: integer }
local function set_inspector_cursor(treeview, lang, source_buf, inspect_buf, inspect_win, pos)
  api.nvim_buf_clear_namespace(inspect_buf, treeview.ns, 0, -1)

  local cursor_node = vim.treesitter.get_node({
    bufnr = source_buf,
    lang = lang,
    pos = pos,
    ignore_injections = false,
  })
  if not cursor_node then
    return
  end

  local cursor_node_id = cursor_node:id()
  for i, v in treeview:iter() do
    if v.node:id() == cursor_node_id then
      local start = v.depth * treeview.opts.indent ---@type integer
      local end_col = start + #v.text
      api.nvim_buf_set_extmark(inspect_buf, treeview.ns, i - 1, start, {
        end_col = end_col,
        hl_group = 'Visual',
      })
      api.nvim_win_set_cursor(inspect_win, { i, 0 })
      break
    end
  end
end

--- Write the contents of this View into {bufnr}.
---
--- Calling this function computes the text that is displayed for each node.
---
---@param bufnr integer Buffer number to write into.
---@package
function TSTreeView:draw(bufnr)
  vim.bo[bufnr].modifiable = true
  local lines = {} ---@type string[]
  local lang_hl_marks = {} ---@type table[]

  for i, item in self:iter() do
    local range_str = range_to_string({ item.node:range() })
    local lang_str = self.opts.lang and string.format(' %s', item.lang) or ''

    local text ---@type string
    if item.node:named() then
      if item.field then
        text = string.format('%s: (%s', item.field, item.node:type())
      else
        text = string.format('(%s', item.node:type())
      end
    else
      text = string.format('"%s"', item.node:type():gsub('\n', '\\n'):gsub('"', '\\"'))
    end

    local next = self:get(i + 1)
    if not next or next.depth <= item.depth then
      local parens = item.depth - (next and next.depth or 0) + (item.node:named() and 1 or 0)
      if parens > 0 then
        text = string.format('%s%s', text, string.rep(')', parens))
      end
    end

    item.text = text

    local line = string.format(
      '%s%s ; %s%s',
      string.rep(' ', item.depth * self.opts.indent),
      text,
      range_str,
      lang_str
    )

    if self.opts.lang then
      lang_hl_marks[#lang_hl_marks + 1] = {
        col = #line - #lang_str,
        end_col = #line,
      }
    end

    lines[i] = line
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  api.nvim_buf_clear_namespace(bufnr, decor_ns, 0, -1)

  for i, m in ipairs(lang_hl_marks) do
    api.nvim_buf_set_extmark(bufnr, decor_ns, i - 1, m.col, {
      hl_group = 'Title',
      end_col = m.end_col,
    })
  end

  vim.bo[bufnr].modifiable = false
end

--- Get node {i} from this View.
---
--- The node number is dependent on whether or not anonymous nodes are displayed.
---
---@param i integer Node number to get
---@return TSP.Node
---@package
function TSTreeView:get(i)
  local t = self.opts.anon and self.nodes or self.named
  return t[i]
end

--- Iterate over all of the nodes in this View.
---
---@return (fun(): integer, TSP.Node) Iterator over all nodes in this View
---@return table
---@return integer
---@package
function TSTreeView:iter()
  return ipairs(self.opts.anon and self.nodes or self.named)
end

--- @class InspectTreeOpts
--- @field lang string? The language of the source buffer. If omitted, the
---                     filetype of the source buffer is used.
--- @field bufnr integer? Buffer to draw the tree into. If omitted, a new
---                       buffer is created.
--- @field winid integer? Window id to display the tree buffer in. If omitted,
---                       a new window is created with {command}.
--- @field command string? Vimscript command to create the window. Default
---                       value is "60vnew". Only used when {winid} is nil.
--- @field title (string|fun(bufnr:integer):string|nil) Title of the window. If a
---                       function, it accepts the buffer number of the source
---                       buffer as its only argument and should return a string.

--- @private
---
--- @param opts InspectTreeOpts?
function M.inspect_tree(opts)
  vim.validate({
    opts = { opts, 't', true },
  })

  opts = opts or {}

  local buf = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local treeview = assert(TSTreeView:new(buf, opts.lang))

  -- Close any existing inspector window
  if vim.b[buf].dev_inspect then
    close_win(vim.b[buf].dev_inspect)
  end

  local w = opts.winid
  if not w then
    vim.cmd(opts.command or '60vnew')
    w = api.nvim_get_current_win()
  end

  local b = opts.bufnr
  if b then
    api.nvim_win_set_buf(w, b)
  else
    b = api.nvim_win_get_buf(w)
  end

  vim.b[buf].dev_inspect = w
  vim.b[b].dev_base = win -- base window handle
  vim.b[b].disable_query_linter = true
  set_dev_properties(w, b)

  local title --- @type string?
  local opts_title = opts.title
  if not opts_title then
    local bufname = api.nvim_buf_get_name(buf)
    title = string.format('Syntax tree for %s', vim.fn.fnamemodify(bufname, ':.'))
  elseif type(opts_title) == 'function' then
    title = opts_title(buf)
  end

  assert(type(title) == 'string', 'Window title must be a string')
  api.nvim_buf_set_name(b, title)

  treeview:draw(b)

  local cursor = api.nvim_win_get_cursor(win)
  set_inspector_cursor(treeview, opts.lang, buf, b, w, { cursor[1] - 1, cursor[2] })

  api.nvim_buf_clear_namespace(buf, treeview.ns, 0, -1)
  api.nvim_buf_set_keymap(b, 'n', '<CR>', '', {
    desc = 'Jump to the node under the cursor in the source buffer',
    callback = function()
      local row = api.nvim_win_get_cursor(w)[1]
      local lnum, col = treeview:get(row).node:start()
      api.nvim_set_current_win(win)
      api.nvim_win_set_cursor(win, { lnum + 1, col })
    end,
  })
  api.nvim_buf_set_keymap(b, 'n', 'a', '', {
    desc = 'Toggle anonymous nodes',
    callback = function()
      local row, col = unpack(api.nvim_win_get_cursor(w)) ---@type integer, integer
      local curnode = treeview:get(row)
      while curnode and not curnode.node:named() do
        row = row - 1
        curnode = treeview:get(row)
      end

      treeview.opts.anon = not treeview.opts.anon
      treeview:draw(b)

      if not curnode then
        return
      end

      local id = curnode.node:id()
      for i, node in treeview:iter() do
        if node.node:id() == id then
          api.nvim_win_set_cursor(w, { i, col })
          break
        end
      end
    end,
  })
  api.nvim_buf_set_keymap(b, 'n', 'I', '', {
    desc = 'Toggle language display',
    callback = function()
      treeview.opts.lang = not treeview.opts.lang
      treeview:draw(b)
    end,
  })
  api.nvim_buf_set_keymap(b, 'n', 'o', '', {
    desc = 'Toggle query editor',
    callback = function()
      local edit_w = vim.b[buf].dev_edit
      if not edit_w or not close_win(edit_w) then
        M.edit_query()
      end
    end,
  })

  local group = api.nvim_create_augroup('treesitter/dev', {})

  api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = b,
    callback = function()
      if not api.nvim_buf_is_loaded(buf) then
        return true
      end

      api.nvim_buf_clear_namespace(buf, treeview.ns, 0, -1)
      local row = api.nvim_win_get_cursor(w)[1]
      local lnum, col, end_lnum, end_col = treeview:get(row).node:range()
      api.nvim_buf_set_extmark(buf, treeview.ns, lnum, col, {
        end_row = end_lnum,
        end_col = math.max(0, end_col),
        hl_group = 'Visual',
      })

      local topline, botline = vim.fn.line('w0', win), vim.fn.line('w$', win)

      -- Move the cursor if highlighted range is completely out of view
      if lnum < topline and end_lnum < topline then
        api.nvim_win_set_cursor(win, { end_lnum + 1, 0 })
      elseif lnum > botline and end_lnum > botline then
        api.nvim_win_set_cursor(win, { lnum + 1, 0 })
      end
    end,
  })

  api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = buf,
    callback = function()
      if not api.nvim_buf_is_loaded(b) then
        return true
      end

      set_inspector_cursor(treeview, opts.lang, buf, b, w)
    end,
  })

  api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = group,
    buffer = buf,
    callback = function()
      if not api.nvim_buf_is_loaded(b) then
        return true
      end

      local treeview_opts = treeview.opts
      treeview = assert(TSTreeView:new(buf, opts.lang))
      treeview.opts = treeview_opts
      treeview:draw(b)
    end,
  })

  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = b,
    callback = function()
      if not api.nvim_buf_is_loaded(buf) then
        return true
      end
      api.nvim_buf_clear_namespace(buf, treeview.ns, 0, -1)
    end,
  })

  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = buf,
    callback = function()
      if not api.nvim_buf_is_loaded(b) then
        return true
      end
      api.nvim_buf_clear_namespace(b, treeview.ns, 0, -1)
    end,
  })

  api.nvim_create_autocmd('BufHidden', {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      close_win(w)
    end,
  })
end

local edit_ns = api.nvim_create_namespace('treesitter/dev-edit')

---@param query_win integer
---@param base_win integer
---@param lang string
local function update_editor_highlights(query_win, base_win, lang)
  local base_buf = api.nvim_win_get_buf(base_win)
  local query_buf = api.nvim_win_get_buf(query_win)
  local parser = vim.treesitter.get_parser(base_buf, lang)
  api.nvim_buf_clear_namespace(base_buf, edit_ns, 0, -1)
  local query_content = table.concat(api.nvim_buf_get_lines(query_buf, 0, -1, false), '\n')

  local ok_query, query = pcall(vim.treesitter.query.parse, lang, query_content)
  if not ok_query then
    return
  end

  local cursor_word = vim.fn.expand('<cword>') --[[@as string]]
  -- Only highlight captures if the cursor is on a capture name
  if cursor_word:find('^@') == nil then
    return
  end
  -- Remove the '@' from the cursor word
  cursor_word = cursor_word:sub(2)
  local topline, botline = vim.fn.line('w0', base_win), vim.fn.line('w$', base_win)
  for id, node in query:iter_captures(parser:trees()[1]:root(), base_buf, topline - 1, botline) do
    local capture_name = query.captures[id]
    if capture_name == cursor_word then
      local lnum, col, end_lnum, end_col = node:range()
      api.nvim_buf_set_extmark(base_buf, edit_ns, lnum, col, {
        end_row = end_lnum,
        end_col = end_col,
        hl_group = 'Visual',
        virt_text = {
          { capture_name, 'Title' },
        },
      })
    end
  end
end

--- @private
--- @param lang? string language to open the query editor for.
function M.edit_query(lang)
  local buf = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()

  -- Close any existing editor window
  if vim.b[buf].dev_edit then
    close_win(vim.b[buf].dev_edit)
  end

  local cmd = '60vnew'
  -- If the inspector is open, place the editor above it.
  local base_win = vim.b[buf].dev_base ---@type integer?
  local base_buf = base_win and api.nvim_win_get_buf(base_win)
  local inspect_win = base_buf and vim.b[base_buf].dev_inspect
  if base_win and base_buf and api.nvim_win_is_valid(inspect_win) then
    vim.api.nvim_set_current_win(inspect_win)
    buf = base_buf
    win = base_win
    cmd = 'new'
  end
  vim.cmd(cmd)

  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  if not ok then
    return nil, 'No parser available for the given buffer'
  end
  lang = parser:lang()

  local query_win = api.nvim_get_current_win()
  local query_buf = api.nvim_win_get_buf(query_win)

  vim.b[buf].dev_edit = query_win
  vim.bo[query_buf].omnifunc = 'v:lua.vim.treesitter.query.omnifunc'
  set_dev_properties(query_win, query_buf)

  -- Note that omnifunc guesses the language based on the containing folder,
  -- so we add the parser's language to the buffer's name so that omnifunc
  -- can infer the language later.
  api.nvim_buf_set_name(query_buf, string.format('%s/query_editor.scm', lang))

  local group = api.nvim_create_augroup('treesitter/dev-edit', {})
  api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = group,
    buffer = query_buf,
    desc = 'Update query editor diagnostics when the query changes',
    callback = function()
      vim.treesitter.query.lint(query_buf, { langs = lang, clear = false })
    end,
  })
  api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'CursorMoved', 'BufEnter' }, {
    group = group,
    buffer = query_buf,
    desc = 'Update query editor highlights when the cursor moves',
    callback = function()
      if api.nvim_win_is_valid(win) then
        update_editor_highlights(query_win, win, lang)
      end
    end,
  })
  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = query_buf,
    desc = 'Clear highlights when leaving the query editor',
    callback = function()
      api.nvim_buf_clear_namespace(buf, edit_ns, 0, -1)
    end,
  })
  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = buf,
    desc = 'Clear the query editor highlights when leaving the source buffer',
    callback = function()
      if not api.nvim_buf_is_loaded(query_buf) then
        return true
      end

      api.nvim_buf_clear_namespace(query_buf, edit_ns, 0, -1)
    end,
  })
  api.nvim_create_autocmd('BufHidden', {
    group = group,
    buffer = buf,
    desc = 'Close the editor window when the source buffer is hidden',
    once = true,
    callback = function()
      close_win(query_win)
    end,
  })

  api.nvim_buf_set_lines(query_buf, 0, -1, false, {
    ';; Write queries here (see $VIMRUNTIME/queries/ for examples).',
    ';; Move cursor to a capture ("@foo") to highlight matches in the source buffer.',
    ';; Completion for grammar nodes is available (:help compl-omni)',
    '',
    '',
  })
  vim.cmd('normal! G')
  vim.cmd.startinsert()
end

return M
