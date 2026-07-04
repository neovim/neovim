local N_ = vim.fn.gettext

local M = {}

--- Convert a "term://" URI into a filename.
--- e.g. "term://~/project//12345:bash" -> "~-project-12345-bash"
---
---@param uri string
---@return string
local function uri2fname(uri)
  -- strip prefix
  local s = uri:gsub('^term://', '')
  -- replace unsafe chars with '-'
  s = s:gsub('[^%w._~-]+', '-')
  -- trim leading/trailing '-'
  s = s:gsub('^-+', ''):gsub('-+$', '')
  return s ~= '' and s or 'undefined_terminal'
end

--- Saves a terminal buffer's rendered state and metadata as a msgpack file.
---
--- Called as a BufWriteCmd handler for `term://*` buffers.
---
---@param args table autocmd args (buf, file, match)
function M.save(args)
  local bufnr = args.buf ---@type integer
  local fname = args.file ---@type string

  -- Resolve the destination path
  local des ---@type string
  local is_uri = vim.startswith(fname, 'term://')
  if is_uri then
    -- `:write` without args: derive a name from the URI
    local name = uri2fname(fname)
    des = vim.fs.joinpath(vim.fn.stdpath('state'), 'term', name .. '.mpack')
    vim.fn.mkdir(vim.fs.dirname(des), 'p')
  else
    -- `:write {name}`: use the user-specified path
    des = vim.fn.fnamemodify(vim.fs.normalize(fname), ':p')
  end

  -- For URI-derived paths, check_overwrite() in do_write() checked URI,
  -- and check_overwrite's os_isdir check is UNIX-only,
  -- so we must check them here.
  local stat = vim.uv.fs_stat(des)
  if stat and stat.type == 'directory' then
    vim.api.nvim_echo(
      { { N_('E17: "%s" is a directory'):format(des), 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end
  if is_uri and stat and vim.v.cmdbang == 0 then
    vim.api.nvim_echo(
      { { N_('E13: File exists (add ! to override)'), 'ErrorMsg' } },
      true,
      { err = true }
    )
    return
  end

  -- Export ANSI content from the terminal.
  -- Use '] and '[ marks (set by buf_write) to export the selected range.
  local start_mark = vim.api.nvim_buf_get_mark(bufnr, '[')
  local end_mark = vim.api.nvim_buf_get_mark(bufnr, ']')
  local ansi = vim.fn.term_getansi(bufnr, start_mark[1], end_mark[1])
  if ansi == '' then
    return
  end

  -- Get metadata
  local chan = vim.bo[bufnr].channel
  local info = vim.api.nvim_get_chan_info(chan)
  local cwd = info.cwd or ''

  -- Encode to msgpack
  local packed = vim.mpack.encode({
    version = 1,
    cwd = cwd,
    argv = info.argv,
    timestamp = vim.fn.localtime(),
    content = ansi,
  })

  -- Count lines
  local line_count = 0
  ---@type string
  for _ in ansi:gmatch('\n') do
    line_count = line_count + 1
  end

  -- Write atomically
  local tmp = des .. '.tmp'
  if vim.fn.writefile(packed, tmp, 'b') ~= 0 or not vim.uv.fs_rename(tmp, des) then
    os.remove(tmp)
    return
  end

  vim.bo[bufnr].modified = false

  -- Report message
  local msg = ('"%s"%s %dL, %dB %s'):format(
    des,
    stat and '' or (' ' .. N_('[New]')),
    line_count,
    #packed,
    N_('written')
  )
  vim.api.nvim_echo({ { msg } }, false, {})
end

return M
