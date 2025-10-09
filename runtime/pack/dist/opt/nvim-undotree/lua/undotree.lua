--- @class (private) vim.undotree.tree.entry
--- @field child integer[]
--- @field time integer

--- @alias vim.undotree.tree {[integer]: vim.undotree.tree.entry}

local M = {}

local ns = vim.api.nvim_create_namespace('nvim-undotree')

--- @param buf integer
--- @return vim.fn.undotree.entry[]
--- @return integer
local function get_undotree_entries(buf)
  local undotree = vim.fn.undotree(buf)
  local entries = undotree.entries

  --Maybe: `:undo 0` and then `undotree` to get seq 0 time
  table.insert(entries, 1, { seq = 0, time = -1 })

  return entries, undotree.seq_cur
end

--- @param ent vim.fn.undotree.entry[]
--- @param _tree vim.undotree.tree?
--- @param _last integer?
--- @return vim.undotree.tree
local function treefy(ent, _tree, _last)
  local tree = _tree or {}
  local last = _last or nil

  for idx, v in ipairs(ent) do
    local seq = v.seq

    if last then
      table.insert(tree[last].child, seq)
    else
      assert(idx == 1 and not _tree)
    end

    tree[seq] = { child = {}, time = v.time }
    if v.alt then
      assert(last)
      treefy(v.alt, tree, last)
    end
    last = seq
  end

  return tree
end

--- @class (private) vim.undotree.graph_line
--- @field kind 'node'|'remove'|'branch'|'remove+branch'|'nochange_remove'
--- @field index integer
--- @field node_count integer
--- @field node integer|integer[]
--- @field index2 integer? -- for branch-index in `remove+branch`

--- @param tree vim.undotree.tree
--- @return vim.undotree.graph_line[]
local function tree_to_graph_lines(tree)
  --- @type vim.undotree.graph_line[]
  local graph_lines = {}

  assert(tree[0], "tree doesn't have 0-th node")
  --- @type (integer[]|integer)[]
  local nodes = { 0 }

  while #nodes > 0 do
    local minseq = math.huge
    --- @type integer
    local index
    --- @type integer
    local node_index

    for k, v in ipairs(nodes) do
      if type(v) == 'table' then
        for i, j in ipairs(v) do
          if j < minseq then
            minseq = j
            index = k
            node_index = i
          end
        end
      elseif v < minseq then
        assert(type(v) == 'number')
        minseq = v
        index = k
      end
    end

    local node = nodes[index]

    --- @param kind 'node'|'remove'|'branch'|'nochange_remove'
    local function add_graph_line(kind)
      table.insert(graph_lines, { kind = kind, index = index, node_count = #nodes, node = node })
    end

    if type(node) == 'number' then
      add_graph_line('node')

      local child = tree[node].child
      if #child == 0 then
        if index ~= #nodes then
          add_graph_line('remove')
        else
          add_graph_line('nochange_remove')
        end

        table.remove(nodes, index)
      elseif #child == 1 then
        nodes[index] = child[1]
      else
        nodes[index] = child
      end
    else
      assert(type(node) == 'table')

      add_graph_line('branch')

      table.remove(nodes, index)
      if #node == 2 then
        table.insert(nodes, index, math.min(unpack(node)))
        table.insert(nodes, index, math.max(unpack(node)))
      elseif #node > 2 then
        table.insert(nodes, index, node[node_index])
        table.insert(nodes, index, node)
        table.remove(node, node_index)
      end
    end
  end

  for k, v in ipairs(graph_lines) do
    if v.kind == 'remove' and (graph_lines[k + 1] or {}).kind == 'branch' then
      v.kind = 'remove+branch'
      v.index2 = graph_lines[k + 1].index
      table.remove(graph_lines, k + 1)
    end
  end

  return graph_lines
end

--- @param time integer
--- @return string
local function undo_fmt_time(time)
  if time == -1 then
    return 'origin'
  end

  local diff = os.time() - time

  if diff >= 100 then
    if diff < (60 * 60 * 12) then
      return os.date('%H:%M:%S', time) --[[@as string]]
    else
      return os.date('%Y/%m/%d %H:%M:%S', time) --[[@as string]]
    end
  else
    return ('%d second%s ago'):format(diff, diff == 1 and '' or 's')
  end
end

--- @param tree vim.undotree.tree
--- @param graph_lines vim.undotree.graph_line[]
--- @param buf integer
--- @param meta {[integer]:integer}
--- @param find_seq? integer
--- @return integer?
local function buf_apply_graph_lines(tree, graph_lines, buf, meta, find_seq)
  -- As in io-buffer, not vim-buffer
  local line_buffer = {}
  local extmark_buffer = {}

  --- @type integer?
  local found_seq

  for k, v in ipairs(graph_lines) do
    local is_last = k == #graph_lines

    --- @type string?
    local line
    if v.kind == 'node' then
      line = ('| '):rep(v.index - 1)
        .. '*'
        .. (' |'):rep(v.node_count - v.index)
        .. '    '
        .. v.node
        .. '    ('
        .. undo_fmt_time(tree[v.node].time)
        .. ')'
    elseif v.kind == 'remove' then
      line = ('| '):rep(v.index - 1) .. (' /'):rep(v.node_count - v.index)
    elseif v.kind == 'branch' then
      line = ('| '):rep(v.index - 1) .. '|\\' .. (' \\'):rep(v.node_count - v.index)
    elseif v.kind == 'remove+branch' then
      if v.index2 < v.index then
        line = ('| '):rep(v.index2 - 1)
          .. '|\\'
          .. (' \\'):rep(v.index - v.index2 - 1)
          .. ' '
          .. (' |'):rep(v.node_count - v.index)
      else
        line = ('| '):rep(v.index - 1)
          .. (' /'):rep(v.index2 - v.index)
          .. ' /|'
          .. (' |'):rep(v.node_count - v.index2 - 1)
      end
    elseif v.kind == 'nochange_remove' then
      line = nil
    else
      error 'unreachable'
    end

    if v.kind == 'node' then
      table.insert(line_buffer, line)
      table.insert(meta, v.node)

      if v.node == find_seq then
        found_seq = #meta
      end
    elseif line then
      table.insert(extmark_buffer, { { line, 'Comment' } })
    end

    if next(extmark_buffer) and (v.kind == 'node' or is_last) then
      local row = vim.api.nvim_buf_line_count(buf)
      vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, { virt_lines = extmark_buffer })
      extmark_buffer = {}
    end

    if next(line_buffer) and (v.kind ~= 'node' or is_last) then
      vim.api.nvim_buf_set_lines(buf, -1, -1, true, line_buffer)

      if #line_buffer > 3 then
        local end_ = vim.api.nvim_buf_line_count(buf) - 1
        local start = end_ - #line_buffer + 3
        vim.api.nvim_buf_call(buf, function()
          vim.cmd.fold { range = { start, end_ } }
        end)
      end

      line_buffer = {}
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, 1, true, {})

  return found_seq
end

---@param inbuf integer
---@param outbuf integer
---@return {[integer]:integer}
local function draw(inbuf, outbuf)
  local entries, curseq = get_undotree_entries(inbuf)
  local tree = treefy(entries)
  local graph_lines = tree_to_graph_lines(tree)

  local meta = {}
  vim.bo[outbuf].modifiable = true
  vim.api.nvim_buf_set_lines(outbuf, 0, -1, true, {})
  vim.api.nvim_buf_clear_namespace(outbuf, ns, 0, -1)
  local curseq_line = buf_apply_graph_lines(tree, graph_lines, outbuf, meta, curseq)
  vim.bo[outbuf].modifiable = false

  if vim.api.nvim_win_is_valid(vim.b[outbuf].nvim_is_undotree) then
    vim.api.nvim_win_set_cursor(vim.b[outbuf].nvim_is_undotree, { curseq_line, 0 })
  end

  return meta
end

--- @class vim.undotree.opts
--- @inlinedoc
---
--- Buffer to draw the tree into. If omitted, a new buffer is created.
--- @field bufnr integer?
---
--- Window id to display the tree buffer in. If omitted, a new window is
--- created with {command}.
--- @field winid integer?
---
--- Vimscript command to create the window. Default value is "30vnew".
--- Only used when {winid} is nil.
--- @field command string?
---
--- Title of the window. If a function, it accepts the buffer number of the
--- source buffer as its only argument and should return a string.
--- @field title (string|fun(bufnr:integer):string|nil)

--- Open a window that displays a textual representation of the undotree.
---
--- While in the window, moving the cursor changes the undo.
---
--- Load the plugin with this command:
--- ```
---         packadd nvim-undotree
--- ```
---
--- Can also be shown with `:Undotree`. [:Undotree]()
---
--- @param opts vim.undotree.opts?
function M.open(opts)
  -- The following lines of code was copied from
  -- `vim.treesitter.dev.inspect_tree` and then modified to fit

  vim.validate('opts', opts, 'table', true)

  opts = opts or {}

  local buf = vim.api.nvim_get_current_buf()

  if vim.b[buf].nvim_undotree then
    local w = vim.b[buf].nvim_undotree
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
      return true
    end
  elseif vim.b[buf].nvim_is_undotree then
    local w = vim.b[buf].nvim_is_undotree
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
      return true
    end
  end

  local w = opts.winid
  if not w then
    vim.cmd(opts.command or '30vnew')
    w = vim.api.nvim_get_current_win()
  end

  local b = opts.bufnr
  if b then
    vim.api.nvim_win_set_buf(w, b)
  else
    b = vim.api.nvim_win_get_buf(w)
  end

  vim.b[buf].nvim_undotree = w
  vim.b[b].nvim_is_undotree = w

  local title --- @type string?
  local opts_title = opts.title
  if not opts_title then
    local bufname = vim.api.nvim_buf_get_name(buf)
    title = string.format('Undo tree for %s', vim.fn.fnamemodify(bufname, ':.'))
  elseif type(opts_title) == 'function' then
    title = opts_title(buf)
  end

  assert(type(title) == 'string', 'Window title must be a string')
  vim.api.nvim_buf_set_name(b, title)

  vim.wo[w][0].scrolloff = 5
  vim.wo[w][0].wrap = false
  vim.wo[w][0].foldmethod = 'manual'
  vim.wo[w][0].foldenable = true
  vim.wo[w][0].cursorline = true
  vim.bo[b].buflisted = false
  vim.bo[b].buftype = 'nofile'
  vim.bo[b].bufhidden = 'wipe'
  vim.bo[b].swapfile = false

  local meta = draw(buf, b)

  vim.api.nvim_win_set_cursor(w, { vim.api.nvim_buf_line_count(b), 0 })

  local group = vim.api.nvim_create_augroup('nvim-undotree', { clear = false })
  vim.api.nvim_clear_autocmds({ buffer = b })
  vim.api.nvim_clear_autocmds({ buffer = buf })

  vim.api.nvim_win_call(w, function()
    vim.cmd.syntax('region Comment start="(" end=")"')
  end)

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    buffer = b,
    callback = function()
      local row = vim.fn.line('.')
      vim.api.nvim_buf_call(buf, function()
        vim.cmd.undo { meta[row], mods = { silent = true } }
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
    group = group,
    buffer = buf,
    callback = function()
      if not vim.api.nvim_buf_is_valid(b) then
        return true
      end

      meta = draw(buf, b)

      if vim.api.nvim_win_is_valid(w) then
        vim.wo[w][0].foldlevel = 99
      end
    end,
  })
end

return M
