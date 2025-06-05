local M = {}

--- Captures buffer state at file open (snapshot: 'open', also used as initial 'save').
---
--- @param bufnr integer
function M.capture_open_snapshot(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.api.nvim_buf_set_var(bufnr, 'snapshots', {
    open = { time = os.time(), lines = lines },
    save = { time = os.time(), lines = lines },
  })
end

--- Captures buffer state at save (snapshot: 'save').
---
--- @param bufnr integer
function M.capture_save_snapshot(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'snapshots')
  local snapshots = ok and val or {}
  snapshots.save = { time = os.time(), lines = lines }
  vim.api.nvim_buf_set_var(bufnr, 'snapshots', snapshots)
end

--- Retrieves a named snapshot ('open' or 'save').
---
--- @param bufnr integer
--- @param snapname string
---
--- @return string[]|nil
function M.get_snapshot(bufnr, snapname)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, 'snapshots')
  return ok and val[snapname] and val[snapname].lines or nil
end

--- Computes a unified diff between two line arrays.
---
--- @param a string[]
--- @param b string[]
---
--- @return table[] Diff
local function compute_diff(a, b)
  local diff = vim.diff(table.concat(a, '\n'), table.concat(b, '\n'), { result_type = 'indices' })
  local result = {}
  local a_idx, b_idx = 1, 1

  ---@type integer[][]
  local hunks = {}
  if type(diff) == 'table' then
    hunks = diff
  end
  for _, hunk in ipairs(hunks) do
    local start_a, count_a, start_b, count_b = unpack(hunk)

    while a_idx < start_a and b_idx < start_b do
      table.insert(result, { type = 'same', left = a[a_idx], right = b[b_idx] })
      a_idx = a_idx + 1
      b_idx = b_idx + 1
    end

    for _ = 1, count_a do
      table.insert(result, { type = 'remove', left = a[a_idx], right = '' })
      a_idx = a_idx + 1
    end

    for _ = 1, count_b do
      table.insert(result, { type = 'add', left = '', right = b[b_idx] })
      b_idx = b_idx + 1
    end
  end

  while a_idx <= #a and b_idx <= #b do
    table.insert(result, { type = 'same', left = a[a_idx], right = b[b_idx] })
    a_idx = a_idx + 1
    b_idx = b_idx + 1
  end
  return result
end

--- Compares buffer with a snapshot ('open' or 'save').
---
--- @param opts table
---
--- @return table|nil, string|nil
function M.get_diff(opts)
  local bufnr = opts.bufnr or 0
  local source_lines --- @type string[]|nil

  if opts.against == 'open' or opts.against == 'save' then
    source_lines = M.get_snapshot(bufnr, opts.against)
  else
    local err_msg = string.format('Unsupported against source: %s', tostring(opts.against))
    return nil, err_msg
  end

  if not source_lines then
    local notfound_msg =
      string.format('No snapshot found for %s in buffer %d', tostring(opts.against), bufnr)
    error(notfound_msg)
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  return {
    diff = compute_diff(source_lines, current_lines),
    left = source_lines,
    right = current_lines,
    meta = {
      --- @type string
      against = opts.against,
      ---@type integer|string|nil
      seq = opts.seq,
      timestamp = os.time(),
    },
  }
end

--- Restores snapshot of buffer ('open' or 'save'), skip if contents don't differ.
---
--- @param bufnr integer
--- @param snapname string
function M.restore_snapshot(bufnr, snapname)
  local lines = M.get_snapshot(bufnr, snapname)
  if not lines then
    local notfound_msg = string.format('No snapshot found for %s in buffer %d', snapname, bufnr)
    error(notfound_msg)
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local is_modf = vim.diff(
    table.concat(lines, '\n'),
    table.concat(current_lines, '\n'),
    { result_type = 'indices' }
  )

  if #is_modf == 0 then
    local not_modf =
      string.format('Snapshot %s identical — restore skipped in buffer %d', snapname, bufnr)
    vim.notify(not_modf, vim.log.levels.INFO)
  else
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
end

--- Renders a side-by-side diff view in a vertical scratch buffer.
---
--- @param result { diff: {type: string, left: string, right: string}[] }
function M.render_diff_view(result)
  --- @type table[]
  local diff_lines = result.diff
  vim.cmd('vnew')
  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  local markers = {
    add = '+ ',
    remove = '- ',
    same = '  ',
  }
  local lines = {}

  --- @type table[]
  for _, entry in ipairs(diff_lines) do
    local left = (entry.left or ''):gsub('\t', '    ')
    local right = (entry.right or ''):gsub('\t', '    ')
    local marker = markers[entry.type] or '? '
    local formatted_line = string.format('%s %-40s │ %s', marker, left, right)
    table.insert(lines, formatted_line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local ns = vim.api.nvim_create_namespace('diff_highlight')

  --- @type table[]
  for i, entry in ipairs(diff_lines) do
    local line = i - 1
    --- @type string
    local marker_group = ({
      add = 'DiffMarkerAdd',
      remove = 'DiffMarkerRemove',
    })[entry.type]

    if marker_group then
      vim.highlight.range(buf, ns, marker_group, { line, 0 }, { line, 2 }, { inclusive = false })
    end

    --- @type string
    local content_group = ({
      add = 'DiffAdd',
      remove = 'DiffRemove',
    })[entry.type]

    if content_group then
      vim.highlight.range(buf, ns, marker_group, { line, 3 }, { line, -1 }, { inclusive = false })
    end
  end
end

--- Generates a header as a formatted string with name and capture date of a snapshot diff.
---
--- @param bufnr integer
local function get_export_header(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr or 0):gsub(vim.loop.cwd() .. '/', '')
  local now = os.date('%Y-%m-%d %H:%M:%S')
  return string.format(
    [[
  === Snapshot Diff ===
  Buffer: %s
  Timestamp: %s
  =====================
  ]],
    filename ~= '' and filename or '[No Name]',
    now
  )
end

--- Exports a snapshot diff as a formatted string and copies it to the unnamed register.
---
--- @param bufnr integer
--- @param snapname string
function M.export_diff(bufnr, snapname)
  bufnr = bufnr or 0
  local ok, result = pcall(M.get_diff, {
    bufnr = bufnr,
    against = snapname,
  })

  if not ok or not result then
    local errmsg =
      string.format('Buffer %d - Export failed for diff against %s snapshot.', bufnr, snapname)
    vim.notify(errmsg, vim.log.levels.ERROR)
    return
  end

  local lines = {}
  table.insert(lines, get_export_header(bufnr))
  local markers = {
    add = '+ ',
    remove = '- ',
    same = '  ',
  }

  local diff_lines = {}
  if type(result.diff) == 'table' then
    ---@type {type: string, left: string, right: string}[]
    diff_lines = result.diff
  end
  for _, entry in ipairs(diff_lines) do
    local marker = markers[entry.type] or '? '
    ---@type string
    local content

    if entry.type == 'remove' then
      content = entry.left or ''
    elseif entry.type == 'add' then
      content = entry.right or ''
    else
      content = entry.right or entry.left or ''
    end

    table.insert(lines, marker .. content)
  end

  local output = table.concat(lines, '\n')
  vim.fn.setreg('"', output)
  vim.fn.setreg('+', output)
  local exprt =
    string.format('Diff against %s snapshot for buffer %d - exported to clipboard', snapname, bufnr)
  vim.notify(exprt, vim.log.levels.INFO)

  return output
end

--- LSP command handler to render a diff with the given snapshot ('open' or 'save').
---
--- @param snapname string
function M.lsp_diff_with(snapname)
  return function(ctx)
    local bufnr = ctx.bufnr or 0
    local ok, result = pcall(M.get_diff, {
      bufnr = bufnr,
      against = snapname,
    })
    if ok and result then
      M.render_diff_view(result)
    else
      local errmsg = string.format('DiffWith %s failed: %s', snapname, result)
      vim.notify(errmsg, vim.log.levels.ERROR)
    end
  end
end

--- LSP command handler to restore the given snapshot ('open' or 'save').
---
--- @param snapname string
function M.lsp_restore_snapshot(snapname)
  return function(ctx)
    local bufnr = ctx.bufnr or 0
    local ok, err = pcall(M.restore_snapshot, bufnr, snapname)
    if not ok then
      local errmsg = string.format('Restore snapshot %s failed: %s', snapname, err)
      vim.notify(errmsg, vim.log.levels.ERROR)
    end
  end
end

--- Registers LSP commands for snapshot diff and restore actions.
function M.register_lsp_commands()
  vim.lsp.commands = vim.lsp.commands or {}
  vim.lsp.commands['snapshot.DiffWithOpen'] = M.lsp_diff_with('open')
  vim.lsp.commands['snapshot.DiffWithSave'] = M.lsp_diff_with('save')
  vim.lsp.commands['snapshot.RestoreOpenSnap'] = M.lsp_restore_snapshot('open')
  vim.lsp.commands['snapshot.RestoreSaveSnap'] = M.lsp_restore_snapshot('save')
end

return M
