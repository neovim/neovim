-- TODO: support g:zip_zipcmd and friends
-- TODO: check if backend available
-- TODO: check if zip is safe to execute
local M = {}

local ns = vim.api.nvim_create_namespace('nvim.archive')

local function errprint(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

---@param cmd string[]
---@param cb fun(err: string?, text: string[])
local function system_out(cmd, cb)
  -- TODO: avoid callback-hell once vim.async lands
  vim.system(cmd, { text = true }, function (obj)
    local err
    if obj.signal ~= 0 then
      err = ('command "%s" received signal %d'):format(table.concat(cmd, ' '), obj.signal)
    elseif obj.code ~= 0 then
      err = ('command "%s" exited with exit code %d'):format(table.concat(cmd, ' '), obj.code)
    end
    cb(err, vim.split(obj.stdout, '\n', { plain = true, trimempty = true }))
  end)
end

---@param source string
---@param opts table?
---@param cb fun(err: string?, files: string[])
function M.list(source, opts, cb)
  -- TODO: sanity check "PK" magic header

  -- TODO: support g:zip_unzipcmd?
  local cmd_zip = { 'unzip', '-Z1', source }
  local cmd_powershell = {
    'pwsh',
    '-NoProfile',
    '-Command',
    ([[
      $zip = [System.IO.Compression.ZipFile]::OpenRead('%s');
      $zip.Entries | ForEach-Object { $_.FullName };
      $zip.Dispose()
    ]]):format(source):gsub('\n', ' '),
  }

  local ok = pcall(system_out, cmd_zip, cb)
  if not ok then
    ok = pcall(system_out, cmd_powershell, cb)
    if not ok then
      errprint(('archive: no command found to browse "%s"'):format(source))
    end
  end
end

function M.update(source, entry, cb)
  -- TODO(zip#Write): implement writeback with zip -u using a staged temp dir tree.
  -- TODO(zip#Write): mirror path traversal hardening (simplify(), absolute path reject, ../ stripping).
  -- TODO(zip#Write): support relative member rename flow (delete old path and rewrite normalized path).
  -- TODO(zip#Write): handle remote archive write path parity (netrw#NetWrite) or explicitly gate unsupported.
  -- TODO(zip#Write): keep zipfile:// buffer name in sync after rename and clear modified state.

  local cmd_zip = { 'zip', '-u', '--', source, entry }
  -- TODO: powershell

  -- (1) should create tempdir with zip file and write buffer to that dir
  -- (2) update that temp zip with updated one
  -- (3) overwrite original zip file

  local ok = pcall(system_out, cmd_zip, cb)
  if not ok then
    errprint(('archive: no command found to extract "%s" from "%s"'):format(entry, source))
  end
end

function M.extract(source, entry, cb)
  -- TODO(zip#Read): extract a single member payload (unzip -p) and return lines for buffer load.
  -- TODO(zip#Read): keep quoting/globbing parity for [], ?, *, and leading '-' handling.
  -- TODO(zip#Read): mirror quickfix-safe temp-file read semantics from zip#Read.
  local cmd_zip = { 'unzip', '-p', '--', source, entry }

  -- TODO: powershell

  local ok = pcall(system_out, cmd_zip, cb)
  if not ok then
    errprint(('archive: no command found to extract "%s" from "%s"'):format(entry, source))
  end
end

function M.open_file(buf, fname)
  fname = fname or vim.api.nvim_buf_get_name(buf)
  local _, _, source, entry = string.find(fname, 'zipfile://(.+)::(.+)')
  -- TODO: if not a zip file, read file normally (ignore BufReadCmd) and return early
  if not source or not entry then
    errprint(('archive: could not parse name of buffer %d: "%s"'):format(buf, fname))
    return
  end

  M.extract(source, entry, vim.schedule_wrap(function(err, text)
    -- TODO: if not a zip file, read file normally (ignore BufReadCmd) and return early
    if err then
      errprint(err)
      return
    end
    vim.bo[buf].swapfile = false
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
    -- TODO(zip#Read): keepalt/file-name dance parity so :write targets zipfile:// member reliably.
    vim.cmd('filetype detect')
    vim.bo[buf].modified = false
  end))
end

---Show contents of {source} in buffer {buf}.
---@param buf integer Buffer to put file listing of {source} to.
---@param source string Path to the archive file.
function M.open_listing(buf, source)
  M.list(source, nil, vim.schedule_wrap(function(err, files)
    vim.bo[buf].swapfile = false
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].buflisted = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true

    if err then
      errprint(err)
      -- TODO: if not a zip file, read file normally (ignore BufReadCmd) and return early
      return
    end

    -- TODO(later): set correct archive ft
    vim.bo[buf].filetype = 'zip'

    vim.keymap.set('n', 'x', function()
      -- TODO(zip#Extract): implement extract-under-cursor with overwrite checks and traversal guards.
      -- TODO(zip#Extract): mirror shell escaping compatibility for cmd.exe and unzip 6.0 leading '-' workaround.
    end, { buf = buf })

    -- TODO: decide if we want to setup BufWriteCmd here or in plugin/archive.lua
    -- TODO(s:ZipBrowseSelect): track originating browse buffer/window for writeback parity (s:zipfile_{winnr()}).
    vim.keymap.set('n', '<CR>', function()
      local entry = vim.api.nvim_get_current_line()
      vim.cmd.split(string.format('zipfile://%s::%s', source, entry))
    end, { buf = buf })

    if vim.o.mouse then
      vim.keymap.set('n', '<leftmouse>', function()
        vim.cmd('norm! <leftmouse>')
        local entry = vim.api.nvim_get_current_line()
        vim.cmd.split(string.format('zipfile://%s::%s', source, entry))
      end, { buf = buf })
    end

    -- TODO: filter lines
    vim._with({ buf = buf, bo = { modifiable = true, readonly = false } }, function ()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)
    end)

    vim.bo[buf].modified = false

    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
      virt_lines_above = true,
      virt_lines = {
        { { 'Browsing archive file ' .. vim.fn.fnamemodify(source, ':~:.'), 'Comment' } },
      }
    })

    -- HACK: virtual lines above the first line are not displayed #16166
    vim.cmd.norm(vim.keycode('<C-b>'))
  end))
end

return M
