--- @brief
---<pre>help
---:DiffTool {left} {right}                                           *:DiffTool*
---Compares two directories or files side-by-side.
---Supports directory diffing, rename detection, and highlights changes
---in quickfix list.
---</pre>
---
--- The plugin is not loaded by default; use `:packadd nvim.difftool` before invoking `:DiffTool`.
---
--- Example `git difftool -d` integration using `DiffTool` command:
---
--- ```ini
--- [difftool "nvim_difftool"]
---   cmd = nvim -c "packadd nvim.difftool" -c "DiffTool $LOCAL $REMOTE"
--- [diff]
---   tool = nvim_difftool
--- ```

local highlight_groups = {
  A = 'DiffAdd',
  D = 'DiffDelete',
  M = 'DiffText',
  R = 'DiffChange',
}

local layout = {
  group = nil,
  left_win = nil,
  right_win = nil,
}

local util = require('vim._core.util')

--- Set up a consistent layout with two diff windows
--- @param with_qf boolean whether to open the quickfix window
local function setup_layout(with_qf)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local left_valid = layout.left_win and vim.api.nvim_win_is_valid(layout.left_win)
  local right_valid = layout.right_win and vim.api.nvim_win_is_valid(layout.right_win)
  local wins_passed = left_valid and right_valid

  local qf_passed = not with_qf
  if not qf_passed and wins_passed then
    for _, win in ipairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if ft == 'qf' then
        qf_passed = true
        break
      end
    end
  end

  if wins_passed and qf_passed then
    return false
  end

  vim.cmd.only()
  layout.left_win = vim.api.nvim_get_current_win()
  vim.cmd.vsplit()
  layout.right_win = vim.api.nvim_get_current_win()

  if with_qf then
    vim.cmd('botright copen')
  end
  vim.api.nvim_set_current_win(layout.right_win)
end

--- Diff two files
--- @param left_file string
--- @param right_file string
--- @param with_qf boolean? whether to open the quickfix window
local function diff_files(left_file, right_file, with_qf)
  setup_layout(with_qf or false)

  local left_buf = util.edit_in(layout.left_win, left_file)
  local right_buf = util.edit_in(layout.right_win, right_file)

  -- When one of the windows is closed, clean up the layout
  vim.api.nvim_create_autocmd('WinClosed', {
    group = layout.group,
    buffer = left_buf,
    callback = function()
      if layout.group and layout.left_win then
        vim.api.nvim_del_augroup_by_id(layout.group)
        layout.left_win = nil
        layout.group = nil
        vim.fn.setqflist({})
        vim.cmd.cclose()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = layout.group,
    buffer = right_buf,
    callback = function()
      if layout.group and layout.right_win then
        vim.api.nvim_del_augroup_by_id(layout.group)
        layout.right_win = nil
        layout.group = nil
        vim.fn.setqflist({})
        vim.cmd.cclose()
      end
    end,
  })

  vim.cmd('diffoff!')
  vim.api.nvim_win_call(layout.left_win, vim.cmd.diffthis)
  vim.api.nvim_win_call(layout.right_win, vim.cmd.diffthis)
end

--- Diff two directories using external `diff` command
--- @param left_dir string
--- @param right_dir string
--- @param opt difftool.opt
--- @return table[] list of quickfix entries
local function diff_dirs_diffr(left_dir, right_dir, opt)
  local args = { 'diff', '-qrN' }
  for _, pattern in ipairs(opt.ignore) do
    table.insert(args, '-x')
    table.insert(args, pattern)
  end
  table.insert(args, left_dir)
  table.insert(args, right_dir)

  local output = vim.fn.system(args)
  local lines = vim.split(output, '\n')
  local qf_entries = {}

  for _, line in ipairs(lines) do
    local modified_left, modified_right = line:match('^Files (.+) and (.+) differ$')
    if modified_left and modified_right then
      local left_exists = vim.fn.filereadable(modified_left) == 1
      local right_exists = vim.fn.filereadable(modified_right) == 1
      local status = '?'
      if left_exists and right_exists then
        status = 'M'
      elseif left_exists then
        status = 'D'
      elseif right_exists then
        status = 'A'
      end
      table.insert(qf_entries, {
        filename = modified_right,
        text = status,
        user_data = {
          diff = true,
          rel = vim.fs.relpath(left_dir, modified_left),
          left = vim.fs.abspath(modified_left),
          right = vim.fs.abspath(modified_right),
        },
      })
    end
  end

  return qf_entries
end

--- Diff two directories using built-in Lua implementation
--- @param left_dir string
--- @param right_dir string
--- @param opt difftool.opt
--- @return table[] list of quickfix entries
local function diff_dirs_builtin(left_dir, right_dir, opt)
  --- @param rel_path string?
  --- @param ignore string[]
  --- @return boolean
  local function is_ignored(rel_path, ignore)
    if not rel_path then
      return false
    end
    for _, pat in ipairs(ignore) do
      if vim.fn.match(rel_path, pat) >= 0 then
        return true
      end
    end
    return false
  end

  --- @param file1 string
  --- @param file2 string
  --- @param chunk_size number
  --- @param chunk_cache table<string, any>
  --- @return number similarity ratio (0 to 1)
  local function calculate_similarity(file1, file2, chunk_size, chunk_cache)
    -- Get or read chunk for file1
    local chunk1 = chunk_cache[file1]
    if not chunk1 then
      chunk1 = util.read_chunk(file1, chunk_size)
      chunk_cache[file1] = chunk1
    end

    -- Get or read chunk for file2
    local chunk2 = chunk_cache[file2]
    if not chunk2 then
      chunk2 = util.read_chunk(file2, chunk_size)
      chunk_cache[file2] = chunk2
    end

    if not chunk1 or not chunk2 then
      return 0
    end
    if chunk1 == chunk2 then
      return 1
    end
    local matches = 0
    local len = math.min(#chunk1, #chunk2)
    for i = 1, len do
      if chunk1:sub(i, i) == chunk2:sub(i, i) then
        matches = matches + 1
      end
    end
    return matches / len
  end

  -- Create a map of all relative paths

  --- @type table<string, {left: string?, right: string?}>
  local all_paths = {}
  --- @type table<string, string>
  local left_only = {}
  --- @type table<string, string>
  local right_only = {}

  local function process_files_in_directory(dir_path, is_left)
    local files = vim.fs.find(function(name, path)
      local rel_path = vim.fs.relpath(dir_path, vim.fs.joinpath(path, name))
      return not is_ignored(rel_path, opt.ignore)
    end, { limit = math.huge, path = dir_path, follow = false })

    for _, full_path in ipairs(files) do
      local rel_path = vim.fs.relpath(dir_path, full_path)
      if rel_path then
        full_path = vim.fn.resolve(full_path)

        if vim.fn.isdirectory(full_path) == 0 then
          all_paths[rel_path] = all_paths[rel_path] or { left = nil, right = nil }

          if is_left then
            all_paths[rel_path].left = full_path
            if not all_paths[rel_path].right then
              left_only[rel_path] = full_path
            end
          else
            all_paths[rel_path].right = full_path
            if not all_paths[rel_path].left then
              right_only[rel_path] = full_path
            end
          end
        end
      end
    end
  end

  -- Process both directories
  process_files_in_directory(left_dir, true)
  process_files_in_directory(right_dir, false)

  --- @type table<string, string>
  local renamed = {}
  --- @type table<string, string>
  local chunk_cache = {}

  -- Detect possible renames
  if opt.rename.detect then
    for left_rel, left_path in pairs(left_only) do
      ---@type {similarity: number, path: string?, rel: string}
      local best_match = { similarity = opt.rename.similarity, path = nil }

      for right_rel, right_path in pairs(right_only) do
        local similarity =
          calculate_similarity(left_path, right_path, opt.rename.chunk_size, chunk_cache)

        if similarity > best_match.similarity then
          best_match = {
            similarity = similarity,
            path = right_path,
            rel = right_rel,
          }
        end
      end

      if best_match.path and best_match.rel then
        renamed[left_rel] = best_match.rel
        all_paths[left_rel].right = best_match.path
        all_paths[best_match.rel] = nil
        left_only[left_rel] = nil
        right_only[best_match.rel] = nil
      end
    end
  end

  local qf_entries = {}

  -- Convert to quickfix entries
  for rel_path, files in pairs(all_paths) do
    local status = nil
    if files.left and files.right then
      --- @type number
      local similarity
      if opt.rename.detect then
        similarity =
          calculate_similarity(files.left, files.right, opt.rename.chunk_size, chunk_cache)
      else
        similarity = vim.fn.getfsize(files.left) == vim.fn.getfsize(files.right) and 1 or 0
      end
      if similarity < 1 then
        status = renamed[rel_path] and 'R' or 'M'
      end
    elseif files.left then
      status = 'D'
      files.right = right_dir .. rel_path
    elseif files.right then
      status = 'A'
      files.left = left_dir .. rel_path
    end

    if status then
      table.insert(qf_entries, {
        filename = files.right,
        text = status,
        user_data = {
          diff = true,
          rel = rel_path,
          left = files.left,
          right = files.right,
        },
      })
    end
  end

  return qf_entries
end

--- Diff two directories
--- @param left_dir string
--- @param right_dir string
--- @param opt difftool.opt
local function diff_dirs(left_dir, right_dir, opt)
  local method = opt.method
  if method == 'auto' then
    if not opt.rename.detect and vim.fn.executable('diff') == 1 then
      method = 'diffr'
    else
      method = 'builtin'
    end
  end

  --- @type table[]
  local qf_entries
  if method == 'diffr' then
    qf_entries = diff_dirs_diffr(left_dir, right_dir, opt)
  elseif method == 'builtin' then
    qf_entries = diff_dirs_builtin(left_dir, right_dir, opt)
  else
    vim.notify('Unknown diff method: ' .. method, vim.log.levels.ERROR)
    return
  end

  -- Sort entries by filename for consistency
  table.sort(qf_entries, function(a, b)
    return a.user_data.rel < b.user_data.rel
  end)

  vim.fn.setqflist({}, 'r', {
    nr = '$',
    title = 'DiffTool',
    items = qf_entries,
    ---@param info {id: number, start_idx: number, end_idx: number}
    quickfixtextfunc = function(info)
      --- @type table[]
      local items = vim.fn.getqflist({ id = info.id, items = 1 }).items
      local out = {}
      for item = info.start_idx, info.end_idx do
        local entry = items[item]
        table.insert(out, entry.text .. ' ' .. entry.user_data.rel)
      end
      return out
    end,
  })

  setup_layout(true)
  vim.cmd.cfirst()
end

local M = {}

--- @class difftool.opt
--- @inlinedoc
---
--- Diff method to use
--- (default: `auto`)
--- @field method 'auto'|'builtin'|'diffr'
---
--- List of file patterns to ignore (for example: `'.git', '*.log'`)
--- (default: `{}`)
--- @field ignore string[]
---
--- Rename detection options (supported only by `builtin` method)
--- @field rename table Controls rename detection
---
---   - {rename.detect} (`boolean`, default: `false`) Whether to detect renames
---   - {rename.similarity} (`number`, default: `0.5`) Minimum similarity for rename detection (0 to 1)
---   - {rename.chunk_size} (`number`, default: `4096`) Maximum chunk size to read from files for similarity calculation

--- Diff two files or directories
--- @param left string
--- @param right string
--- @param opt? difftool.opt
function M.open(left, right, opt)
  if not left or not right then
    vim.notify('Both arguments are required', vim.log.levels.ERROR)
    return
  end

  local config = vim.tbl_deep_extend('force', {
    method = 'auto',
    ignore = {},
    rename = {
      detect = false,
      similarity = 0.5,
      chunk_size = 4096,
    },
  }, opt or {})

  layout.group = vim.api.nvim_create_augroup('nvim.difftool.events', { clear = true })
  local hl_id = vim.api.nvim_create_namespace('nvim.difftool.hl')

  local function get_diff_entry()
    --- @type {idx: number, items: table[], size: number}
    local qf_info = vim.fn.getqflist({ idx = 0, items = 1, size = 1 })
    if qf_info.size == 0 then
      return false
    end

    local entry = qf_info.items[qf_info.idx]
    if not entry or not entry.user_data or not entry.user_data.diff then
      return nil
    end

    return entry
  end

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = layout.group,
    pattern = 'quickfix',
    callback = function(args)
      if not get_diff_entry() then
        return
      end

      vim.api.nvim_buf_clear_namespace(args.buf, hl_id, 0, -1)
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)

      -- Map status codes to highlight groups
      for i, line in ipairs(lines) do
        local status = line:match('^(%a) ')
        local hl_group = highlight_groups[status]
        if hl_group then
          vim.hl.range(args.buf, hl_id, hl_group, { i - 1, 0 }, { i - 1, 1 })
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = layout.group,
    pattern = '*',
    callback = function()
      local entry = get_diff_entry()
      if not entry then
        return
      end

      vim.schedule(function()
        diff_files(entry.user_data.left, entry.user_data.right, true)
      end)
    end,
  })

  left = vim.fs.normalize(left)
  right = vim.fs.normalize(right)

  if vim.fn.isdirectory(left) == 1 and vim.fn.isdirectory(right) == 1 then
    diff_dirs(left, right, config)
  elseif vim.fn.filereadable(left) == 1 and vim.fn.filereadable(right) == 1 then
    diff_files(left, right)
  else
    vim.notify('Both arguments must be files or directories', vim.log.levels.ERROR)
  end
end

return M
