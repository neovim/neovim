local api = vim.api

---@class TSDevModule
local M = {}

---@class TSTreeView
---@field ns integer API namespace
---@field opts table Options table with the following keys:
---                  - anon (boolean): If true, display anonymous nodes
---                  - lang (boolean): If true, display the language alongside each node
---@field nodes TSP.Node[]
---@field named TSP.Node[]
local TSTreeView = {}

---@class TSP.Node
---@field id integer Node id
---@field text string Node text
---@field named boolean True if this is a named (non-anonymous) node
---@field depth integer Depth of the node within the tree
---@field lnum integer Beginning line number of this node in the source buffer
---@field col integer Beginning column number of this node in the source buffer
---@field end_lnum integer Final line number of this node in the source buffer
---@field end_col integer Final column number of this node in the source buffer
---@field lang string Source language of this node
---@field root TSNode

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
---@param lang string Language of the tree currently being traversed
---@param injections table<integer,TSP.Node> Mapping of node ids to root nodes of injected language trees (see
---                        explanation above)
---@param tree TSP.Node[] Output table containing a list of tables each representing a node in the tree
---@private
local function traverse(node, depth, lang, injections, tree)
  local injection = injections[node:id()]
  if injection then
    traverse(injection.root, depth, injection.lang, injections, tree)
  end

  for child, field in node:iter_children() do
    local type = child:type()
    local lnum, col, end_lnum, end_col = child:range()
    local named = child:named()
    local text ---@type string
    if named then
      if field then
        text = string.format('%s: (%s)', field, type)
      else
        text = string.format('(%s)', type)
      end
    else
      text = string.format('"%s"', type:gsub('\n', '\\n'))
    end

    table.insert(tree, {
      id = child:id(),
      text = text,
      named = named,
      depth = depth,
      lnum = lnum,
      col = col,
      end_lnum = end_lnum,
      end_col = end_col,
      lang = lang,
    })

    traverse(child, depth + 1, lang, injections, tree)
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
    return nil, 'No parser available for the given buffer'
  end

  -- For each child tree (injected language), find the root of the tree and locate the node within
  -- the primary tree that contains that root. Add a mapping from the node in the primary tree to
  -- the root in the child tree to the {injections} table.
  local root = parser:parse()[1]:root()
  local injections = {} ---@type table<integer,table>
  parser:for_each_child(function(child, lang_)
    child:for_each_tree(function(tree)
      local r = tree:root()
      local node = root:named_descendant_for_range(r:range())
      if node then
        injections[node:id()] = {
          lang = lang_,
          root = r,
        }
      end
    end)
  end)

  local nodes = traverse(root, 0, parser:lang(), injections, {})

  local named = {} ---@type TSP.Node[]
  for _, v in ipairs(nodes) do
    if v.named then
      named[#named + 1] = v
    end
  end

  local t = {
    ns = api.nvim_create_namespace(''),
    nodes = nodes,
    named = named,
    opts = {
      anon = false,
      lang = false,
    },
  }

  setmetatable(t, self)
  self.__index = self
  return t
end

local decor_ns = api.nvim_create_namespace('ts.dev')

---@private
---@param lnum integer
---@param col integer
---@param end_lnum integer
---@param end_col integer
---@return string
local function get_range_str(lnum, col, end_lnum, end_col)
  if lnum == end_lnum then
    return string.format('[%d:%d - %d]', lnum + 1, col + 1, end_col)
  end
  return string.format('[%d:%d - %d:%d]', lnum + 1, col + 1, end_lnum + 1, end_col)
end

--- Write the contents of this View into {bufnr}.
---
---@param bufnr integer Buffer number to write into.
---@package
function TSTreeView:draw(bufnr)
  vim.bo[bufnr].modifiable = true
  local lines = {} ---@type string[]
  local lang_hl_marks = {} ---@type table[]

  for _, item in self:iter() do
    local range_str = get_range_str(item.lnum, item.col, item.end_lnum, item.end_col)
    local lang_str = self.opts.lang and string.format(' %s', item.lang) or ''
    local line =
      string.format('%s%s ; %s%s', string.rep(' ', item.depth), item.text, range_str, lang_str)

    if self.opts.lang then
      lang_hl_marks[#lang_hl_marks + 1] = {
        col = #line - #lang_str,
        end_col = #line,
      }
    end

    lines[#lines + 1] = line
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
--- @param opts InspectTreeOpts
function M.inspect_tree(opts)
  vim.validate({
    opts = { opts, 't', true },
  })

  opts = opts or {}

  local buf = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local pg = assert(TSTreeView:new(buf, opts.lang))

  -- Close any existing dev window
  if vim.b[buf].dev then
    local w = vim.b[buf].dev
    if api.nvim_win_is_valid(w) then
      api.nvim_win_close(w, true)
    end
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

  vim.b[buf].dev = w

  vim.wo[w].scrolloff = 5
  vim.wo[w].wrap = false
  vim.wo[w].foldmethod = 'manual' -- disable folding
  vim.bo[b].buflisted = false
  vim.bo[b].buftype = 'nofile'
  vim.bo[b].bufhidden = 'wipe'
  vim.b[b].disable_query_linter = true
  vim.bo[b].filetype = 'query'

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

  pg:draw(b)

  api.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
  api.nvim_buf_set_keymap(b, 'n', '<CR>', '', {
    desc = 'Jump to the node under the cursor in the source buffer',
    callback = function()
      local row = api.nvim_win_get_cursor(w)[1]
      local pos = pg:get(row)
      api.nvim_set_current_win(win)
      api.nvim_win_set_cursor(win, { pos.lnum + 1, pos.col })
    end,
  })
  api.nvim_buf_set_keymap(b, 'n', 'a', '', {
    desc = 'Toggle anonymous nodes',
    callback = function()
      local row, col = unpack(api.nvim_win_get_cursor(w))
      local curnode = pg:get(row)
      while curnode and not curnode.named do
        row = row - 1
        curnode = pg:get(row)
      end

      pg.opts.anon = not pg.opts.anon
      pg:draw(b)

      if not curnode then
        return
      end

      local id = curnode.id
      for i, node in pg:iter() do
        if node.id == id then
          api.nvim_win_set_cursor(w, { i, col })
          break
        end
      end
    end,
  })
  api.nvim_buf_set_keymap(b, 'n', 'I', '', {
    desc = 'Toggle language display',
    callback = function()
      pg.opts.lang = not pg.opts.lang
      pg:draw(b)
    end,
  })

  local group = api.nvim_create_augroup('treesitter/dev', {})

  api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = b,
    callback = function()
      api.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
      local row = api.nvim_win_get_cursor(w)[1]
      local pos = pg:get(row)
      api.nvim_buf_set_extmark(buf, pg.ns, pos.lnum, pos.col, {
        end_row = pos.end_lnum,
        end_col = math.max(0, pos.end_col),
        hl_group = 'Visual',
      })

      local topline, botline = vim.fn.line('w0', win), vim.fn.line('w$', win)

      -- Move the cursor if highlighted range is completely out of view
      if pos.lnum < topline and pos.end_lnum < topline then
        api.nvim_win_set_cursor(win, { pos.end_lnum + 1, 0 })
      elseif pos.lnum > botline and pos.end_lnum > botline then
        api.nvim_win_set_cursor(win, { pos.lnum + 1, 0 })
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

      api.nvim_buf_clear_namespace(b, pg.ns, 0, -1)

      local cursor_node = vim.treesitter.get_node({
        bufnr = buf,
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
          api.nvim_buf_set_extmark(b, pg.ns, i - 1, start, {
            end_col = end_col,
            hl_group = 'Visual',
          })
          api.nvim_win_set_cursor(w, { i, 0 })
          break
        end
      end
    end,
  })

  api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = group,
    buffer = buf,
    callback = function()
      if not api.nvim_buf_is_loaded(b) then
        return true
      end

      pg = assert(TSTreeView:new(buf, opts.lang))
      pg:draw(b)
    end,
  })

  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = b,
    callback = function()
      api.nvim_buf_clear_namespace(buf, pg.ns, 0, -1)
    end,
  })

  api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = buf,
    callback = function()
      if not api.nvim_buf_is_loaded(b) then
        return true
      end

      api.nvim_buf_clear_namespace(b, pg.ns, 0, -1)
    end,
  })

  api.nvim_create_autocmd('BufHidden', {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      if api.nvim_win_is_valid(w) then
        api.nvim_win_close(w, true)
      end
    end,
  })
end

return M
