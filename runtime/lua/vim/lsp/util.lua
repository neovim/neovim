local protocol = require('vim.lsp.protocol')
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend
local highlight = vim.highlight
local uv = vim.uv

local npcall = vim.F.npcall
local split = vim.split

local M = {}

local default_border = {
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { ' ', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { ' ', 'NormalFloat' },
}

--- Check the border given by opts or the default border for the additional
--- size it adds to a float.
---@param opts table optional options for the floating window
---            - border (string or table) the border
---@return table size of border in the form of { height = height, width = width }
local function get_border_size(opts)
  local border = opts and opts.border or default_border
  local height = 0
  local width = 0

  if type(border) == 'string' then
    local border_size = {
      none = { 0, 0 },
      single = { 2, 2 },
      double = { 2, 2 },
      rounded = { 2, 2 },
      solid = { 2, 2 },
      shadow = { 1, 1 },
    }
    if border_size[border] == nil then
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end
    height, width = unpack(border_size[border])
  else
    if 8 % #border ~= 0 then
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end
    local function border_width(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == 'table' then
        -- border specified as a table of <character, highlight group>
        return vim.fn.strdisplaywidth(border[id][1])
      elseif type(border[id]) == 'string' then
        -- border specified as a list of border characters
        return vim.fn.strdisplaywidth(border[id])
      end
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end
    local function border_height(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == 'table' then
        -- border specified as a table of <character, highlight group>
        return #border[id][1] > 0 and 1 or 0
      elseif type(border[id]) == 'string' then
        -- border specified as a list of border characters
        return #border[id] > 0 and 1 or 0
      end
      error(
        string.format(
          'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
          vim.inspect(border)
        )
      )
    end
    height = height + border_height(2) -- top
    height = height + border_height(6) -- bottom
    width = width + border_width(4) -- right
    width = width + border_width(8) -- left
  end

  return { height = height, width = width }
end

local function split_lines(value)
  value = string.gsub(value, '\r\n?', '\n')
  return split(value, '\n', { plain = true, trimempty = true })
end

local function create_window_without_focus()
  local prev = vim.api.nvim_get_current_win()
  vim.cmd.new()
  local new = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(prev)
  return new
end

--- Convert byte index to `encoding` index.
--- Convenience wrapper around vim.str_utfindex
---@param line string line to be indexed
---@param index integer|nil byte index (utf-8), or `nil` for length
---@param encoding string|nil utf-8|utf-16|utf-32|nil defaults to utf-16
---@return integer `encoding` index of `index` in `line`
function M._str_utfindex_enc(line, index, encoding)
  if not encoding then
    encoding = 'utf-16'
  end
  if encoding == 'utf-8' then
    if index then
      return index
    else
      return #line
    end
  elseif encoding == 'utf-16' then
    local _, col16 = vim.str_utfindex(line, index)
    return col16
  elseif encoding == 'utf-32' then
    local col32, _ = vim.str_utfindex(line, index)
    return col32
  else
    error('Invalid encoding: ' .. vim.inspect(encoding))
  end
end

--- Convert UTF index to `encoding` index.
--- Convenience wrapper around vim.str_byteindex
---Alternative to vim.str_byteindex that takes an encoding.
---@param line string line to be indexed
---@param index integer UTF index
---@param encoding string utf-8|utf-16|utf-32| defaults to utf-16
---@return integer byte (utf-8) index of `encoding` index `index` in `line`
function M._str_byteindex_enc(line, index, encoding)
  if not encoding then
    encoding = 'utf-16'
  end
  if encoding == 'utf-8' then
    if index then
      return index
    else
      return #line
    end
  elseif encoding == 'utf-16' then
    return vim.str_byteindex(line, index, true)
  elseif encoding == 'utf-32' then
    return vim.str_byteindex(line, index)
  else
    error('Invalid encoding: ' .. vim.inspect(encoding))
  end
end

local _str_utfindex_enc = M._str_utfindex_enc
local _str_byteindex_enc = M._str_byteindex_enc

--- Replaces text in a range with new text.
---
--- CAUTION: Changes in-place!
---
---@deprecated
---@param lines string[] Original list of strings
---@param A [integer, integer] Start position; a 2-tuple of {line,col} numbers
---@param B [integer, integer] End position; a 2-tuple {line,col} numbers
---@param new_lines string[] list of strings to replace the original
---@return string[] The modified {lines} object
function M.set_lines(lines, A, B, new_lines)
  vim.deprecate('vim.lsp.util.set_lines()', 'nil', '0.12')
  -- 0-indexing to 1-indexing
  local i_0 = A[1] + 1
  -- If it extends past the end, truncate it to the end. This is because the
  -- way the LSP describes the range including the last newline is by
  -- specifying a line number after what we would call the last line.
  local i_n = math.min(B[1] + 1, #lines)
  if not (i_0 >= 1 and i_0 <= #lines + 1 and i_n >= 1 and i_n <= #lines) then
    error('Invalid range: ' .. vim.inspect({ A = A, B = B, #lines, new_lines }))
  end
  local prefix = ''
  local suffix = lines[i_n]:sub(B[2] + 1)
  if A[2] > 0 then
    prefix = lines[i_0]:sub(1, A[2])
  end
  local n = i_n - i_0 + 1
  if n ~= #new_lines then
    for _ = 1, n - #new_lines do
      table.remove(lines, i_0)
    end
    for _ = 1, #new_lines - n do
      table.insert(lines, i_0, '')
    end
  end
  for i = 1, #new_lines do
    lines[i - 1 + i_0] = new_lines[i]
  end
  if #suffix > 0 then
    local i = i_0 + #new_lines - 1
    lines[i] = lines[i] .. suffix
  end
  if #prefix > 0 then
    lines[i_0] = prefix .. lines[i_0]
  end
  return lines
end

local function sort_by_key(fn)
  return function(a, b)
    local ka, kb = fn(a), fn(b)
    assert(#ka == #kb)
    for i = 1, #ka do
      if ka[i] ~= kb[i] then
        return ka[i] < kb[i]
      end
    end
    -- every value must have been equal here, which means it's not less than.
    return false
  end
end

--- Gets the zero-indexed lines from the given buffer.
--- Works on unloaded buffers by reading the file using libuv to bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param bufnr integer bufnr to get the lines from
---@param rows integer[] zero-indexed line numbers
---@return table<integer, string>|string a table mapping rows to lines
local function get_lines(bufnr, rows)
  rows = type(rows) == 'table' and rows or { rows }

  -- This is needed for bufload and bufloaded
  if bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local function buf_lines()
    local lines = {}
    for _, row in ipairs(rows) do
      lines[row] = (api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { '' })[1]
    end
    return lines
  end

  -- use loaded buffers if available
  if vim.fn.bufloaded(bufnr) == 1 then
    return buf_lines()
  end

  local uri = vim.uri_from_bufnr(bufnr)

  -- load the buffer if this is not a file uri
  -- Custom language server protocol extensions can result in servers sending URIs with custom schemes. Plugins are able to load these via `BufReadCmd` autocmds.
  if uri:sub(1, 4) ~= 'file' then
    vim.fn.bufload(bufnr)
    return buf_lines()
  end

  local filename = api.nvim_buf_get_name(bufnr)

  -- get the data from the file
  local fd = uv.fs_open(filename, 'r', 438)
  if not fd then
    return ''
  end
  local stat = uv.fs_fstat(fd)
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)

  local lines = {} -- rows we need to retrieve
  local need = 0 -- keep track of how many unique rows we need
  for _, row in pairs(rows) do
    if not lines[row] then
      need = need + 1
    end
    lines[row] = true
  end

  local found = 0
  local lnum = 0

  for line in string.gmatch(data, '([^\n]*)\n?') do
    if lines[lnum] == true then
      lines[lnum] = line
      found = found + 1
      if found == need then
        break
      end
    end
    lnum = lnum + 1
  end

  -- change any lines we didn't find to the empty string
  for i, line in pairs(lines) do
    if line == true then
      lines[i] = ''
    end
  end
  return lines
end

--- Gets the zero-indexed line from the given buffer.
--- Works on unloaded buffers by reading the file using libuv to bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param bufnr integer
---@param row integer zero-indexed line number
---@return string the line at row in filename
local function get_line(bufnr, row)
  return get_lines(bufnr, { row })[row]
end

--- Position is a https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position
---@param offset_encoding string|nil utf-8|utf-16|utf-32
---@return integer
local function get_line_byte_from_position(bufnr, position, offset_encoding)
  -- LSP's line and characters are 0-indexed
  -- Vim's line and columns are 1-indexed
  local col = position.character
  -- When on the first character, we can ignore the difference between byte and
  -- character
  if col > 0 then
    local line = get_line(bufnr, position.line) or ''
    local ok, result
    ok, result = pcall(_str_byteindex_enc, line, col, offset_encoding)
    if ok then
      return result
    end
    return math.min(#line, col)
  end
  return col
end

--- Applies a list of text edits to a buffer.
---@param text_edits lsp.TextEdit[]
---@param bufnr integer Buffer id
---@param offset_encoding string utf-8|utf-16|utf-32
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textEdit
function M.apply_text_edits(text_edits, bufnr, offset_encoding)
  validate({
    text_edits = { text_edits, 't', false },
    bufnr = { bufnr, 'number', false },
    offset_encoding = { offset_encoding, 'string', false },
  })
  if not next(text_edits) then
    return
  end

  assert(bufnr ~= 0, 'Explicit buffer number is required')

  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  vim.bo[bufnr].buflisted = true

  -- Fix reversed range and indexing each text_edits
  local index = 0
  text_edits = vim.tbl_map(function(text_edit)
    index = index + 1
    text_edit._index = index

    if
      text_edit.range.start.line > text_edit.range['end'].line
      or text_edit.range.start.line == text_edit.range['end'].line
        and text_edit.range.start.character > text_edit.range['end'].character
    then
      local start = text_edit.range.start
      text_edit.range.start = text_edit.range['end']
      text_edit.range['end'] = start
    end
    return text_edit
  end, text_edits)

  -- Sort text_edits
  table.sort(text_edits, function(a, b)
    if a.range.start.line ~= b.range.start.line then
      return a.range.start.line > b.range.start.line
    end
    if a.range.start.character ~= b.range.start.character then
      return a.range.start.character > b.range.start.character
    end
    if a._index ~= b._index then
      return a._index > b._index
    end
  end)

  -- save and restore local marks since they get deleted by nvim_buf_set_lines
  local marks = {}
  for _, m in pairs(vim.fn.getmarklist(bufnr)) do
    if m.mark:match("^'[a-z]$") then
      marks[m.mark:sub(2, 2)] = { m.pos[2], m.pos[3] - 1 } -- api-indexed
    end
  end

  -- Apply text edits.
  local has_eol_text_edit = false
  for _, text_edit in ipairs(text_edits) do
    -- Normalize line ending
    text_edit.newText, _ = string.gsub(text_edit.newText, '\r\n?', '\n')

    -- Convert from LSP style ranges to Neovim style ranges.
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(bufnr, text_edit.range.start, offset_encoding),
      end_row = text_edit.range['end'].line,
      end_col = get_line_byte_from_position(bufnr, text_edit.range['end'], offset_encoding),
      text = split(text_edit.newText, '\n', { plain = true }),
    }

    local max = api.nvim_buf_line_count(bufnr)
    -- If the whole edit is after the lines in the buffer we can simply add the new text to the end
    -- of the buffer.
    if max <= e.start_row then
      api.nvim_buf_set_lines(bufnr, max, max, false, e.text)
    else
      local last_line_len = #(get_line(bufnr, math.min(e.end_row, max - 1)) or '')
      -- Some LSP servers may return +1 range of the buffer content but nvim_buf_set_text can't
      -- accept it so we should fix it here.
      if max <= e.end_row then
        e.end_row = max - 1
        e.end_col = last_line_len
        has_eol_text_edit = true
      else
        -- If the replacement is over the end of a line (i.e. e.end_col is out of bounds and the
        -- replacement text ends with a newline We can likely assume that the replacement is assumed
        -- to be meant to replace the newline with another newline and we need to make sure this
        -- doesn't add an extra empty line. E.g. when the last line to be replaced contains a '\r'
        -- in the file some servers (clangd on windows) will include that character in the line
        -- while nvim_buf_set_text doesn't count it as part of the line.
        if
          e.end_col > last_line_len
          and #text_edit.newText > 0
          and string.sub(text_edit.newText, -1) == '\n'
        then
          table.remove(e.text, #e.text)
        end
      end
      -- Make sure we don't go out of bounds for e.end_col
      e.end_col = math.min(last_line_len, e.end_col)

      api.nvim_buf_set_text(bufnr, e.start_row, e.start_col, e.end_row, e.end_col, e.text)
    end
  end

  local max = api.nvim_buf_line_count(bufnr)

  -- no need to restore marks that still exist
  for _, m in pairs(vim.fn.getmarklist(bufnr)) do
    marks[m.mark:sub(2, 2)] = nil
  end
  -- restore marks
  for mark, pos in pairs(marks) do
    if pos then
      -- make sure we don't go out of bounds
      pos[1] = math.min(pos[1], max)
      pos[2] = math.min(pos[2], #(get_line(bufnr, pos[1] - 1) or ''))
      vim.api.nvim_buf_set_mark(bufnr or 0, mark, pos[1], pos[2], {})
    end
  end

  -- Remove final line if needed
  local fix_eol = has_eol_text_edit
  fix_eol = fix_eol and (vim.bo[bufnr].eol or (vim.bo[bufnr].fixeol and not vim.bo[bufnr].binary))
  fix_eol = fix_eol and get_line(bufnr, max - 1) == ''
  if fix_eol then
    api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  end
end

--- Applies a `TextDocumentEdit`, which is a list of changes to a single
--- document.
---
---@param text_document_edit lsp.TextDocumentEdit
---@param index? integer: Optional index of the edit, if from a list of edits (or nil, if not from a list)
---@param offset_encoding? string
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentEdit
function M.apply_text_document_edit(text_document_edit, index, offset_encoding)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)
  if offset_encoding == nil then
    vim.notify_once(
      'apply_text_document_edit must be called with valid offset encoding',
      vim.log.levels.WARN
    )
  end

  -- For lists of text document edits,
  -- do not check the version after the first edit.
  local should_check_version = true
  if index and index > 1 then
    should_check_version = false
  end

  -- changedtick increases on save but server only receives version updates
  -- on line changes (via didChange)
  -- This allows a gap of 1 to account for the servers outdated view
  local version_offset = vim.b[bufnr].modified and 0 or 1

  -- `VersionedTextDocumentIdentifier`s version may be null
  --  https://microsoft.github.io/language-server-protocol/specification#versionedTextDocumentIdentifier
  if
    should_check_version
    and (
      text_document.version
      and text_document.version > 0
      and vim.b[bufnr].changedtick > (text_document.version + version_offset)
    )
  then
    print('Buffer ', text_document.uri, ' newer than edits.')
    return
  end

  M.apply_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end

local function path_components(path)
  return vim.split(path, '/', { plain = true })
end

local function path_under_prefix(path, prefix)
  for i, c in ipairs(prefix) do
    if c ~= path[i] then
      return false
    end
  end
  return true
end

--- Get list of buffers whose filename matches the given path prefix (normalized full path)
---@param prefix string
---@return integer[]
local function get_bufs_with_prefix(prefix)
  prefix = path_components(prefix)
  local buffers = {}
  for _, v in ipairs(vim.api.nvim_list_bufs()) do
    local bname = vim.api.nvim_buf_get_name(v)
    local path = path_components(vim.fs.normalize(bname, { expand_env = false }))
    if path_under_prefix(path, prefix) then
      table.insert(buffers, v)
    end
  end
  return buffers
end

local function escape_gsub_repl(s)
  return (s:gsub('%%', '%%%%'))
end

--- @class vim.lsp.util.rename.Opts
--- @inlinedoc
--- @field overwrite? boolean
--- @field ignoreIfExists? boolean

--- Rename old_fname to new_fname
---
--- Existing buffers are renamed as well, while maintaining their bufnr.
---
--- It deletes existing buffers that conflict with the renamed file name only when
--- * `opts` requests overwriting; or
--- * the conflicting buffers are not loaded, so that deleting them does not result in data loss.
---
--- @param old_fname string
--- @param new_fname string
--- @param opts? vim.lsp.util.rename.Opts Options:
function M.rename(old_fname, new_fname, opts)
  opts = opts or {}
  local skip = not opts.overwrite or opts.ignoreIfExists

  local old_fname_full = vim.uv.fs_realpath(vim.fs.normalize(old_fname, { expand_env = false }))
  if not old_fname_full then
    vim.notify('Invalid path: ' .. old_fname, vim.log.levels.ERROR)
    return
  end

  local target_exists = uv.fs_stat(new_fname) ~= nil
  if target_exists and skip then
    vim.notify(new_fname .. ' already exists. Skipping rename.', vim.log.levels.ERROR)
    return
  end

  local buf_rename = {} ---@type table<integer, {from: string, to: string}>
  local old_fname_pat = '^' .. vim.pesc(old_fname_full)
  for b in
    vim.iter(get_bufs_with_prefix(old_fname_full)):filter(function(b)
      -- No need to care about unloaded or nofile buffers. Also :saveas won't work for them.
      return api.nvim_buf_is_loaded(b)
        and not vim.list_contains({ 'nofile', 'nowrite' }, vim.bo[b].buftype)
    end)
  do
    -- Renaming a buffer may conflict with another buffer that happens to have the same name. In
    -- most cases, this would have been already detected by the file conflict check above, but the
    -- conflicting buffer may not be associated with a file. For example, 'buftype' can be "nofile"
    -- or "nowrite", or the buffer can be a normal buffer but has not been written to the file yet.
    -- Renaming should fail in such cases to avoid losing the contents of the conflicting buffer.
    local old_bname = vim.api.nvim_buf_get_name(b)
    local new_bname = old_bname:gsub(old_fname_pat, escape_gsub_repl(new_fname))
    if vim.fn.bufexists(new_bname) == 1 then
      local existing_buf = vim.fn.bufnr(new_bname)
      if api.nvim_buf_is_loaded(existing_buf) and skip then
        vim.notify(
          new_bname .. ' already exists in the buffer list. Skipping rename.',
          vim.log.levels.ERROR
        )
        return
      end
      -- no need to preserve if such a buffer is empty
      api.nvim_buf_delete(existing_buf, {})
    end

    buf_rename[b] = { from = old_bname, to = new_bname }
  end

  local newdir = vim.fs.dirname(new_fname)
  vim.fn.mkdir(newdir, 'p')

  local ok, err = os.rename(old_fname_full, new_fname)
  assert(ok, err)

  local old_undofile = vim.fn.undofile(old_fname_full)
  if uv.fs_stat(old_undofile) ~= nil then
    local new_undofile = vim.fn.undofile(new_fname)
    vim.fn.mkdir(vim.fs.dirname(new_undofile), 'p')
    os.rename(old_undofile, new_undofile)
  end

  for b, rename in pairs(buf_rename) do
    -- Rename with :saveas. This does two things:
    -- * Unset BF_WRITE_MASK, so that users don't get E13 when they do :write.
    -- * Send didClose and didOpen via textDocument/didSave handler.
    api.nvim_buf_call(b, function()
      vim.cmd('keepalt saveas! ' .. vim.fn.fnameescape(rename.to))
    end)
    -- Delete the new buffer with the old name created by :saveas. nvim_buf_delete and
    -- :bwipeout are futile because the buffer will be added again somewhere else.
    vim.cmd('bdelete! ' .. vim.fn.bufnr(rename.from))
  end
end

local function create_file(change)
  local opts = change.options or {}
  -- from spec: Overwrite wins over `ignoreIfExists`
  local fname = vim.uri_to_fname(change.uri)
  if not opts.ignoreIfExists or opts.overwrite then
    vim.fn.mkdir(vim.fs.dirname(fname), 'p')
    local file = io.open(fname, 'w')
    if file then
      file:close()
    end
  end
  vim.fn.bufadd(fname)
end

local function delete_file(change)
  local opts = change.options or {}
  local fname = vim.uri_to_fname(change.uri)
  local stat = uv.fs_stat(fname)
  if opts.ignoreIfNotExists and not stat then
    return
  end
  assert(stat, 'Cannot delete not existing file or folder ' .. fname)
  local flags
  if stat and stat.type == 'directory' then
    flags = opts.recursive and 'rf' or 'd'
  else
    flags = ''
  end
  local bufnr = vim.fn.bufadd(fname)
  local result = tonumber(vim.fn.delete(fname, flags))
  assert(result == 0, 'Could not delete file: ' .. fname .. ', stat: ' .. vim.inspect(stat))
  api.nvim_buf_delete(bufnr, { force = true })
end

--- Applies a `WorkspaceEdit`.
---
---@param workspace_edit lsp.WorkspaceEdit
---@param offset_encoding string utf-8|utf-16|utf-32 (required)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
function M.apply_workspace_edit(workspace_edit, offset_encoding)
  if offset_encoding == nil then
    vim.notify_once(
      'apply_workspace_edit must be called with valid offset encoding',
      vim.log.levels.WARN
    )
  end
  if workspace_edit.documentChanges then
    for idx, change in ipairs(workspace_edit.documentChanges) do
      if change.kind == 'rename' then
        M.rename(vim.uri_to_fname(change.oldUri), vim.uri_to_fname(change.newUri), change.options)
      elseif change.kind == 'create' then
        create_file(change)
      elseif change.kind == 'delete' then
        delete_file(change)
      elseif change.kind then
        error(string.format('Unsupported change: %q', vim.inspect(change)))
      else
        M.apply_text_document_edit(change, idx, offset_encoding)
      end
    end
    return
  end

  local all_changes = workspace_edit.changes
  if not (all_changes and not vim.tbl_isempty(all_changes)) then
    return
  end

  for uri, changes in pairs(all_changes) do
    local bufnr = vim.uri_to_bufnr(uri)
    M.apply_text_edits(changes, bufnr, offset_encoding)
  end
end

--- Converts any of `MarkedString` | `MarkedString[]` | `MarkupContent` into
--- a list of lines containing valid markdown. Useful to populate the hover
--- window for `textDocument/hover`, for parsing the result of
--- `textDocument/signatureHelp`, and potentially others.
---
--- Note that if the input is of type `MarkupContent` and its kind is `plaintext`,
--- then the corresponding value is returned without further modifications.
---
---@param input lsp.MarkedString|lsp.MarkedString[]|lsp.MarkupContent
---@param contents string[]|nil List of strings to extend with converted lines. Defaults to {}.
---@return string[] extended with lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
function M.convert_input_to_markdown_lines(input, contents)
  contents = contents or {}
  -- MarkedString variation 1
  if type(input) == 'string' then
    list_extend(contents, split_lines(input))
  else
    assert(type(input) == 'table', 'Expected a table for LSP input')
    -- MarkupContent
    if input.kind then
      local value = input.value or ''
      list_extend(contents, split_lines(value))
      -- MarkupString variation 2
    elseif input.language then
      table.insert(contents, '```' .. input.language)
      list_extend(contents, split_lines(input.value or ''))
      table.insert(contents, '```')
      -- By deduction, this must be MarkedString[]
    else
      -- Use our existing logic to handle MarkedString
      for _, marked_string in ipairs(input) do
        M.convert_input_to_markdown_lines(marked_string, contents)
      end
    end
  end
  if (contents[1] == '' or contents[1] == nil) and #contents == 1 then
    return {}
  end
  return contents
end

--- Converts `textDocument/signatureHelp` response to markdown lines.
---
---@param signature_help lsp.SignatureHelp Response of `textDocument/SignatureHelp`
---@param ft string|nil filetype that will be use as the `lang` for the label markdown code block
---@param triggers table|nil list of trigger characters from the lsp server. used to better determine parameter offsets
---@return string[]|nil table list of lines of converted markdown.
---@return number[]|nil table of active hl
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
function M.convert_signature_help_to_markdown_lines(signature_help, ft, triggers)
  if not signature_help.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length == 0`.
  --Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_hl
  local active_signature = signature_help.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  -- In 3.15 of the protocol, activeSignature was allowed to be negative
  if active_signature >= #signature_help.signatures or active_signature < 0 then
    active_signature = 0
  end
  local signature = signature_help.signatures[active_signature + 1]
  if not signature then
    return
  end
  local label = signature.label
  if ft then
    -- wrap inside a code block for proper rendering
    label = ('```%s\n%s\n```'):format(ft, label)
  end
  list_extend(contents, split(label, '\n', { plain = true, trimempty = true }))
  if signature.documentation then
    -- if LSP returns plain string, we treat it as plaintext. This avoids
    -- special characters like underscore or similar from being interpreted
    -- as markdown font modifiers
    if type(signature.documentation) == 'string' then
      signature.documentation = { kind = 'plaintext', value = signature.documentation }
    end
    M.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = (signature.activeParameter or signature_help.activeParameter or 0)
    if active_parameter < 0 then
      active_parameter = 0
    end

    -- If the activeParameter is > #parameters, then set it to the last
    -- NOTE: this is not fully according to the spec, but a client-side interpretation
    if active_parameter >= #signature.parameters then
      active_parameter = #signature.parameters - 1
    end

    local parameter = signature.parameters[active_parameter + 1]
    if parameter then
      --[=[
      --Represents a parameter of a callable-signature. A parameter can
      --have a label and a doc-comment.
      interface ParameterInformation {
        --The label of this parameter information.
        --
        --Either a string or an inclusive start and exclusive end offsets within its containing
        --signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
        --string representation as `Position` and `Range` does.
        --
        --*Note*: a label of type string should be a substring of its containing signature label.
        --Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
        label: string | [number, number];
        --The human-readable doc-comment of this parameter. Will be shown
        --in the UI but can be omitted.
        documentation?: string | MarkupContent;
      }
      --]=]
      if parameter.label then
        if type(parameter.label) == 'table' then
          active_hl = parameter.label
        else
          local offset = 1
          -- try to set the initial offset to the first found trigger character
          for _, t in ipairs(triggers or {}) do
            local trigger_offset = signature.label:find(t, 1, true)
            if trigger_offset and (offset == 1 or trigger_offset < offset) then
              offset = trigger_offset
            end
          end
          for p, param in pairs(signature.parameters) do
            offset = signature.label:find(param.label, offset, true)
            if not offset then
              break
            end
            if p == active_parameter + 1 then
              active_hl = { offset - 1, offset + #parameter.label - 1 }
              break
            end
            offset = offset + #param.label + 1
          end
        end
      end
      if parameter.documentation then
        M.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end
  return contents, active_hl
end

--- Creates a table with sensible default options for a floating window. The
--- table can be passed to |nvim_open_win()|.
---
---@param width integer window width (in character cells)
---@param height integer window height (in character cells)
---@param opts table optional
---        - offset_x (integer) offset to add to `col`
---        - offset_y (integer) offset to add to `row`
---        - border (string or table) override `border`
---        - focusable (string or table) override `focusable`
---        - zindex (string or table) override `zindex`, defaults to 50
---        - relative ("mouse"|"cursor") defaults to "cursor"
---        - anchor_bias ("auto"|"above"|"below") defaults to "auto"
---          - "auto": place window based on which side of the cursor has more lines
---          - "above": place the window above the cursor unless there are not enough lines
---            to display the full window height.
---          - "below": place the window below the cursor unless there are not enough lines
---            to display the full window height.
---@return table Options
function M.make_floating_popup_options(width, height, opts)
  validate({
    opts = { opts, 't', true },
  })
  opts = opts or {}
  validate({
    ['opts.offset_x'] = { opts.offset_x, 'n', true },
    ['opts.offset_y'] = { opts.offset_y, 'n', true },
  })

  local anchor = ''
  local row, col

  local lines_above = opts.relative == 'mouse' and vim.fn.getmousepos().line - 1
    or vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above

  local anchor_bias = opts.anchor_bias or 'auto'

  local anchor_below

  if anchor_bias == 'below' then
    anchor_below = (lines_below > lines_above) or (height <= lines_below)
  elseif anchor_bias == 'above' then
    local anchor_above = (lines_above > lines_below) or (height <= lines_above)
    anchor_below = not anchor_above
  else
    anchor_below = lines_below > lines_above
  end

  local border_height = get_border_size(opts).height
  if anchor_below then
    anchor = anchor .. 'N'
    height = math.max(math.min(lines_below - border_height, height), 0)
    row = 1
  else
    anchor = anchor .. 'S'
    height = math.max(math.min(lines_above - border_height, height), 0)
    row = 0
  end

  local wincol = opts.relative == 'mouse' and vim.fn.getmousepos().column or vim.fn.wincol()

  if wincol + width + (opts.offset_x or 0) <= vim.o.columns then
    anchor = anchor .. 'W'
    col = 0
  else
    anchor = anchor .. 'E'
    col = 1
  end

  local title = (opts.border and opts.title) and opts.title or nil
  local title_pos

  if title then
    title_pos = opts.title_pos or 'center'
  end

  return {
    anchor = anchor,
    col = col + (opts.offset_x or 0),
    height = height,
    focusable = opts.focusable,
    relative = opts.relative == 'mouse' and 'mouse' or 'cursor',
    row = row + (opts.offset_y or 0),
    style = 'minimal',
    width = width,
    border = opts.border or default_border,
    zindex = opts.zindex or 50,
    title = title,
    title_pos = title_pos,
  }
end

--- Shows document and optionally jumps to the location.
---
---@param location lsp.Location|lsp.LocationLink
---@param offset_encoding string|nil utf-8|utf-16|utf-32
---@param opts table|nil options
---        - reuse_win (boolean) Jump to existing window if buffer is already open.
---        - focus (boolean) Whether to focus/jump to location if possible. Defaults to true.
---@return boolean `true` if succeeded
function M.show_document(location, offset_encoding, opts)
  -- location may be Location or LocationLink
  local uri = location.uri or location.targetUri
  if uri == nil then
    return false
  end
  if offset_encoding == nil then
    vim.notify_once('show_document must be called with valid offset encoding', vim.log.levels.WARN)
  end
  local bufnr = vim.uri_to_bufnr(uri)

  opts = opts or {}
  local focus = vim.F.if_nil(opts.focus, true)
  if focus then
    -- Save position in jumplist
    vim.cmd("normal! m'")

    -- Push a new item into tagstack
    local from = { vim.fn.bufnr('%'), vim.fn.line('.'), vim.fn.col('.'), 0 }
    local items = { { tagname = vim.fn.expand('<cword>'), from = from } }
    vim.fn.settagstack(vim.fn.win_getid(), { items = items }, 't')
  end

  local win = opts.reuse_win and vim.fn.win_findbuf(bufnr)[1]
    or focus and api.nvim_get_current_win()
    or create_window_without_focus()

  vim.bo[bufnr].buflisted = true
  api.nvim_win_set_buf(win, bufnr)
  if focus then
    api.nvim_set_current_win(win)
  end

  -- location may be Location or LocationLink
  local range = location.range or location.targetSelectionRange
  if range then
    -- Jump to new location (adjusting for encoding of characters)
    local row = range.start.line
    local col = get_line_byte_from_position(bufnr, range.start, offset_encoding)
    api.nvim_win_set_cursor(win, { row + 1, col })
    api.nvim_win_call(win, function()
      -- Open folds under the cursor
      vim.cmd('normal! zv')
    end)
  end

  return true
end

--- Jumps to a location.
---
---@param location lsp.Location|lsp.LocationLink
---@param offset_encoding string|nil utf-8|utf-16|utf-32
---@param reuse_win boolean|nil Jump to existing window if buffer is already open.
---@return boolean `true` if the jump succeeded
function M.jump_to_location(location, offset_encoding, reuse_win)
  if offset_encoding == nil then
    vim.notify_once(
      'jump_to_location must be called with valid offset encoding',
      vim.log.levels.WARN
    )
  end

  return M.show_document(location, offset_encoding, { reuse_win = reuse_win, focus = true })
end

--- Previews a location in a floating window
---
--- behavior depends on type of location:
---   - for Location, range is shown (e.g., function definition)
---   - for LocationLink, targetRange is shown (e.g., body of function definition)
---
---@param location lsp.Location|lsp.LocationLink
---@param opts table
---@return integer|nil buffer id of float window
---@return integer|nil window id of float window
function M.preview_location(location, opts)
  -- location may be LocationLink or Location (more useful for the former)
  local uri = location.targetUri or location.uri
  if uri == nil then
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  local range = location.targetRange or location.range
  local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range['end'].line + 1, false)
  local syntax = vim.bo[bufnr].syntax
  if syntax == '' then
    -- When no syntax is set, we use filetype as fallback. This might not result
    -- in a valid syntax definition.
    -- An empty syntax is more common now with TreeSitter, since TS disables syntax.
    syntax = vim.bo[bufnr].filetype
  end
  opts = opts or {}
  opts.focus_id = 'location'
  return M.open_floating_preview(contents, syntax, opts)
end

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

---Returns true if the line is empty or only contains whitespace.
---@param line string
---@return boolean
local function is_blank_line(line)
  return line and line:match('^%s*$')
end

---Returns true if the line corresponds to a Markdown thematic break.
---@param line string
---@return boolean
local function is_separator_line(line)
  return line and line:match('^ ? ? ?%-%-%-+%s*$')
end

---Replaces separator lines by the given divider and removing surrounding blank lines.
---@param contents string[]
---@param divider string
---@return string[]
local function replace_separators(contents, divider)
  local trimmed = {}
  local l = 1
  while l <= #contents do
    local line = contents[l]
    if is_separator_line(line) then
      if l > 1 and is_blank_line(contents[l - 1]) then
        table.remove(trimmed)
      end
      table.insert(trimmed, divider)
      if is_blank_line(contents[l + 1]) then
        l = l + 1
      end
    else
      table.insert(trimmed, line)
    end
    l = l + 1
  end

  return trimmed
end

---Collapses successive blank lines in the input table into a single one.
---@param contents string[]
---@return string[]
local function collapse_blank_lines(contents)
  local collapsed = {}
  local l = 1
  while l <= #contents do
    local line = contents[l]
    if is_blank_line(line) then
      while is_blank_line(contents[l + 1]) do
        l = l + 1
      end
    end
    table.insert(collapsed, line)
    l = l + 1
  end
  return collapsed
end

local function get_markdown_fences()
  local fences = {}
  for _, fence in pairs(vim.g.markdown_fenced_languages or {}) do
    local lang, syntax = fence:match('^(.*)=(.*)$')
    if lang then
      fences[lang] = syntax
    end
  end
  return fences
end

--- Converts markdown into syntax highlighted regions by stripping the code
--- blocks and converting them into highlighted code.
--- This will by default insert a blank line separator after those code block
--- regions to improve readability.
---
--- This method configures the given buffer and returns the lines to set.
---
--- If you want to open a popup with fancy markdown, use `open_floating_preview` instead
---
---@param bufnr integer
---@param contents string[] of lines to show in window
---@param opts table with optional fields
---  - height    of floating window
---  - width     of floating window
---  - wrap_at   character to wrap at for computing height
---  - max_width  maximal width of floating window
---  - max_height maximal height of floating window
---  - separator insert separator after code block
---@return table stripped content
function M.stylize_markdown(bufnr, contents, opts)
  validate({
    contents = { contents, 't' },
    opts = { opts, 't', true },
  })
  opts = opts or {}

  -- table of fence types to {ft, begin, end}
  -- when ft is nil, we get the ft from the regex match
  local matchers = {
    block = { nil, '```+%s*([a-zA-Z0-9_]*)', '```+' },
    pre = { nil, '<pre>([a-z0-9]*)', '</pre>' },
    code = { '', '<code>', '</code>' },
    text = { 'text', '<text>', '</text>' },
  }

  local match_begin = function(line)
    for type, pattern in pairs(matchers) do
      local ret = line:match(string.format('^%%s*%s%%s*$', pattern[2]))
      if ret then
        return {
          type = type,
          ft = pattern[1] or ret,
        }
      end
    end
  end

  local match_end = function(line, match)
    local pattern = matchers[match.type]
    return line:match(string.format('^%%s*%s%%s*$', pattern[3]))
  end

  -- Clean up
  contents = vim.split(table.concat(contents, '\n'), '\n', { trimempty = true })

  local stripped = {}
  local highlights = {}
  -- keep track of lnums that contain markdown
  local markdown_lines = {}
  do
    local i = 1
    while i <= #contents do
      local line = contents[i]
      local match = match_begin(line)
      if match then
        local start = #stripped
        i = i + 1
        while i <= #contents do
          line = contents[i]
          if match_end(line, match) then
            i = i + 1
            break
          end
          table.insert(stripped, line)
          i = i + 1
        end
        table.insert(highlights, {
          ft = match.ft,
          start = start + 1,
          finish = #stripped,
        })
        -- add a separator, but not on the last line
        if opts.separator and i < #contents then
          table.insert(stripped, '---')
          markdown_lines[#stripped] = true
        end
      else
        -- strip any empty lines or separators prior to this separator in actual markdown
        if line:match('^---+$') then
          while
            markdown_lines[#stripped]
            and (stripped[#stripped]:match('^%s*$') or stripped[#stripped]:match('^---+$'))
          do
            markdown_lines[#stripped] = false
            table.remove(stripped, #stripped)
          end
        end
        -- add the line if its not an empty line following a separator
        if
          not (
            line:match('^%s*$')
            and markdown_lines[#stripped]
            and stripped[#stripped]:match('^---+$')
          )
        then
          table.insert(stripped, line)
          markdown_lines[#stripped] = true
        end
        i = i + 1
      end
    end
  end

  -- Handle some common html escape sequences
  stripped = vim.tbl_map(function(line)
    local escapes = {
      ['&gt;'] = '>',
      ['&lt;'] = '<',
      ['&quot;'] = '"',
      ['&apos;'] = "'",
      ['&ensp;'] = ' ',
      ['&emsp;'] = ' ',
      ['&amp;'] = '&',
    }
    return (string.gsub(line, '&[^ ;]+;', escapes))
  end, stripped)

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo['wrap'] and api.nvim_win_get_width(0))
  local width = M._make_floating_popup_size(stripped, opts)

  local sep_line = string.rep('─', math.min(width, opts.wrap_at or width))

  for l in pairs(markdown_lines) do
    if stripped[l]:match('^---+$') then
      stripped[l] = sep_line
    end
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

  local idx = 1
  -- keep track of syntaxes we already included.
  -- no need to include the same syntax more than once
  local langs = {}
  local fences = get_markdown_fences()
  local function apply_syntax_to_region(ft, start, finish)
    if ft == '' then
      vim.cmd(
        string.format(
          'syntax region markdownCode start=+\\%%%dl+ end=+\\%%%dl+ keepend extend',
          start,
          finish + 1
        )
      )
      return
    end
    ft = fences[ft] or ft
    local name = ft .. idx
    idx = idx + 1
    local lang = '@' .. ft:upper()
    if not langs[lang] then
      -- HACK: reset current_syntax, since some syntax files like markdown won't load if it is already set
      pcall(api.nvim_buf_del_var, bufnr, 'current_syntax')
      if #api.nvim_get_runtime_file(('syntax/%s.vim'):format(ft), true) == 0 then
        return
      end
      pcall(vim.cmd, string.format('syntax include %s syntax/%s.vim', lang, ft))
      langs[lang] = true
    end
    vim.cmd(
      string.format(
        'syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s keepend',
        name,
        start,
        finish + 1,
        lang
      )
    )
  end

  -- needs to run in the buffer for the regions to work
  api.nvim_buf_call(bufnr, function()
    -- we need to apply lsp_markdown regions speperately, since otherwise
    -- markdown regions can "bleed" through the other syntax regions
    -- and mess up the formatting
    local last = 1
    for _, h in ipairs(highlights) do
      if last < h.start then
        apply_syntax_to_region('lsp_markdown', last, h.start - 1)
      end
      apply_syntax_to_region(h.ft, h.start, h.finish)
      last = h.finish + 1
    end
    if last <= #stripped then
      apply_syntax_to_region('lsp_markdown', last, #stripped)
    end
  end)

  return stripped
end

--- @class (private) vim.lsp.util._normalize_markdown.Opts
--- @field width integer Thematic breaks are expanded to this size. Defaults to 80.

--- Normalizes Markdown input to a canonical form.
---
--- The returned Markdown adheres to the GitHub Flavored Markdown (GFM)
--- specification.
---
--- The following transformations are made:
---
---   1. Carriage returns ('\r') and empty lines at the beginning and end are removed
---   2. Successive empty lines are collapsed into a single empty line
---   3. Thematic breaks are expanded to the given width
---
---@private
---@param contents string[]
---@param opts? vim.lsp.util._normalize_markdown.Opts
---@return string[] table of lines containing normalized Markdown
---@see https://github.github.com/gfm
function M._normalize_markdown(contents, opts)
  validate({
    contents = { contents, 't' },
    opts = { opts, 't', true },
  })
  opts = opts or {}

  -- 1. Carriage returns are removed
  contents = vim.split(table.concat(contents, '\n'):gsub('\r', ''), '\n', { trimempty = true })

  -- 2. Successive empty lines are collapsed into a single empty line
  contents = collapse_blank_lines(contents)

  -- 3. Thematic breaks are expanded to the given width
  local divider = string.rep('─', opts.width or 80)
  contents = replace_separators(contents, divider)

  return contents
end

--- Closes the preview window
---
---@param winnr integer window id of preview window
---@param bufnrs table|nil optional list of ignored buffers
local function close_preview_window(winnr, bufnrs)
  vim.schedule(function()
    -- exit if we are in one of ignored buffers
    if bufnrs and vim.list_contains(bufnrs, api.nvim_get_current_buf()) then
      return
    end

    local augroup = 'preview_window_' .. winnr
    pcall(api.nvim_del_augroup_by_name, augroup)
    pcall(api.nvim_win_close, winnr, true)
  end)
end

--- Creates autocommands to close a preview window when events happen.
---
---@param events table list of events
---@param winnr integer window id of preview window
---@param bufnrs table list of buffers where the preview window will remain visible
---@see autocmd-events
local function close_preview_autocmd(events, winnr, bufnrs)
  local augroup = api.nvim_create_augroup('preview_window_' .. winnr, {
    clear = true,
  })

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      close_preview_window(winnr, bufnrs)
    end,
  })

  if #events > 0 then
    api.nvim_create_autocmd(events, {
      group = augroup,
      buffer = bufnrs[2],
      callback = function()
        close_preview_window(winnr)
      end,
    })
  end
end

---@private
--- Computes size of float needed to show contents (with optional wrapping)
---
---@param contents table of lines to show in window
---@param opts table with optional fields
---            - height  of floating window
---            - width   of floating window
---            - wrap_at character to wrap at for computing height
---            - max_width  maximal width of floating window
---            - max_height maximal height of floating window
---@return integer width size of float
---@return integer height size of float
function M._make_floating_popup_size(contents, opts)
  validate({
    contents = { contents, 't' },
    opts = { opts, 't', true },
  })
  opts = opts or {}

  local width = opts.width
  local height = opts.height
  local wrap_at = opts.wrap_at
  local max_width = opts.max_width
  local max_height = opts.max_height
  local line_widths = {}

  if not width then
    width = 0
    for i, line in ipairs(contents) do
      -- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
      line_widths[i] = vim.fn.strdisplaywidth(line:gsub('%z', '\n'))
      width = math.max(line_widths[i], width)
    end
  end

  local border_width = get_border_size(opts).width
  local screen_width = api.nvim_win_get_width(0)
  width = math.min(width, screen_width)

  -- make sure borders are always inside the screen
  if width + border_width > screen_width then
    width = width - (width + border_width - screen_width)
  end

  if wrap_at and wrap_at > width then
    wrap_at = width
  end

  if max_width then
    width = math.min(width, max_width)
    wrap_at = math.min(wrap_at or max_width, max_width)
  end

  if not height then
    height = #contents
    if wrap_at and width >= wrap_at then
      height = 0
      if vim.tbl_isempty(line_widths) then
        for _, line in ipairs(contents) do
          local line_width = vim.fn.strdisplaywidth(line:gsub('%z', '\n'))
          height = height + math.ceil(line_width / wrap_at)
        end
      else
        for i = 1, #contents do
          height = height + math.max(1, math.ceil(line_widths[i] / wrap_at))
        end
      end
    end
  end
  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
end

--- @class vim.lsp.util.open_floating_preview.Opts
--- @inlinedoc
---
--- Height of floating window
--- @field height? integer
---
--- Width of floating window
--- @field width? integer
---
--- Wrap long lines
--- (default: `true`)
--- @field wrap? boolean
---
--- Character to wrap at for computing height when wrap is enabled
--- @field wrap_at? integer
---
--- Maximal width of floating window
--- @field max_width? integer
---
--- Maximal height of floating window
--- @field max_height? integer
---
--- If a popup with this id is opened, then focus it
--- @field focus_id? string
---
--- List of events that closes the floating window
--- @field close_events? table
---
--- Make float focusable.
--- (default: `true`)
--- @field focusable? boolean
---
--- If `true`, and if {focusable} is also `true`, focus an existing floating
--- window with the same {focus_id}
--- (default: `true`)
--- @field focus? boolean

--- Shows contents in a floating window.
---
---@param contents table of lines to show in window
---@param syntax string of syntax to set for opened buffer
---@param opts? vim.lsp.util.open_floating_preview.Opts with optional fields
--- (additional keys are filtered with |vim.lsp.util.make_floating_popup_options()|
--- before they are passed on to |nvim_open_win()|)
---@return integer bufnr of newly created float window
---@return integer winid of newly created float window preview window
function M.open_floating_preview(contents, syntax, opts)
  validate({
    contents = { contents, 't' },
    syntax = { syntax, 's', true },
    opts = { opts, 't', true },
  })
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.focus = opts.focus ~= false
  opts.close_events = opts.close_events or { 'CursorMoved', 'CursorMovedI', 'InsertCharPre' }

  local bufnr = api.nvim_get_current_buf()

  -- check if this popup is focusable and we need to focus
  if opts.focus_id and opts.focusable ~= false and opts.focus then
    -- Go back to previous window if we are in a focusable one
    local current_winnr = api.nvim_get_current_win()
    if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
      api.nvim_command('wincmd p')
      return bufnr, current_winnr
    end
    do
      local win = find_window_by_var(opts.focus_id, bufnr)
      if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
        -- focus and return the existing buf, win
        api.nvim_set_current_win(win)
        api.nvim_command('stopinsert')
        return api.nvim_win_get_buf(win), win
      end
    end
  end

  -- check if another floating preview already exists for this buffer
  -- and close it if needed
  local existing_float = npcall(api.nvim_buf_get_var, bufnr, 'lsp_floating_preview')
  if existing_float and api.nvim_win_is_valid(existing_float) then
    api.nvim_win_close(existing_float, true)
  end

  -- Create the buffer
  local floating_bufnr = api.nvim_create_buf(false, true)

  -- Set up the contents, using treesitter for markdown
  local do_stylize = syntax == 'markdown' and vim.g.syntax_on ~= nil
  if do_stylize then
    local width = M._make_floating_popup_size(contents, opts)
    contents = M._normalize_markdown(contents, { width = width })
    vim.bo[floating_bufnr].filetype = 'markdown'
    vim.treesitter.start(floating_bufnr)
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, false, contents)
  else
    -- Clean up input: trim empty lines
    contents = vim.split(table.concat(contents, '\n'), '\n', { trimempty = true })

    if syntax then
      vim.bo[floating_bufnr].syntax = syntax
    end
    api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
  end

  -- Compute size of float needed to show (wrapped) lines
  if opts.wrap then
    opts.wrap_at = opts.wrap_at or api.nvim_win_get_width(0)
  else
    opts.wrap_at = nil
  end
  local width, height = M._make_floating_popup_size(contents, opts)

  local float_option = M.make_floating_popup_options(width, height, opts)
  local floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)

  if do_stylize then
    vim.wo[floating_winnr].conceallevel = 2
  end
  -- disable folding
  vim.wo[floating_winnr].foldenable = false
  -- soft wrapping
  vim.wo[floating_winnr].wrap = opts.wrap

  vim.bo[floating_bufnr].modifiable = false
  vim.bo[floating_bufnr].bufhidden = 'wipe'

  api.nvim_buf_set_keymap(
    floating_bufnr,
    'n',
    'q',
    '<cmd>bdelete<cr>',
    { silent = true, noremap = true, nowait = true }
  )
  close_preview_autocmd(opts.close_events, floating_winnr, { floating_bufnr, bufnr })

  -- save focus_id
  if opts.focus_id then
    api.nvim_win_set_var(floating_winnr, opts.focus_id, bufnr)
  end
  api.nvim_buf_set_var(bufnr, 'lsp_floating_preview', floating_winnr)

  return floating_bufnr, floating_winnr
end

do --[[ References ]]
  local reference_ns = api.nvim_create_namespace('vim_lsp_references')

  --- Removes document highlights from a buffer.
  ---
  ---@param bufnr integer|nil Buffer id
  function M.buf_clear_references(bufnr)
    validate({ bufnr = { bufnr, { 'n' }, true } })
    api.nvim_buf_clear_namespace(bufnr or 0, reference_ns, 0, -1)
  end

  --- Shows a list of document highlights for a certain buffer.
  ---
  ---@param bufnr integer Buffer id
  ---@param references lsp.DocumentHighlight[] objects to highlight
  ---@param offset_encoding string One of "utf-8", "utf-16", "utf-32".
  ---@see https://microsoft.github.io/language-server-protocol/specification/#textDocumentContentChangeEvent
  function M.buf_highlight_references(bufnr, references, offset_encoding)
    validate({
      bufnr = { bufnr, 'n', true },
      offset_encoding = { offset_encoding, 'string', false },
    })
    for _, reference in ipairs(references) do
      local start_line, start_char =
        reference['range']['start']['line'], reference['range']['start']['character']
      local end_line, end_char =
        reference['range']['end']['line'], reference['range']['end']['character']

      local start_idx = get_line_byte_from_position(
        bufnr,
        { line = start_line, character = start_char },
        offset_encoding
      )
      local end_idx = get_line_byte_from_position(
        bufnr,
        { line = start_line, character = end_char },
        offset_encoding
      )

      local document_highlight_kind = {
        [protocol.DocumentHighlightKind.Text] = 'LspReferenceText',
        [protocol.DocumentHighlightKind.Read] = 'LspReferenceRead',
        [protocol.DocumentHighlightKind.Write] = 'LspReferenceWrite',
      }
      local kind = reference['kind'] or protocol.DocumentHighlightKind.Text
      highlight.range(
        bufnr,
        reference_ns,
        document_highlight_kind[kind],
        { start_line, start_idx },
        { end_line, end_idx },
        { priority = vim.highlight.priorities.user }
      )
    end
  end
end

local position_sort = sort_by_key(function(v)
  return { v.start.line, v.start.character }
end)

---@class vim.lsp.util.locations_to_items.ret
---@inlinedoc
---@field filename string
---@field lnum integer 1-indexed line number
---@field col integer 1-indexed column
---@field text string
---@field user_data lsp.Location|lsp.LocationLink

--- Returns the items with the byte position calculated correctly and in sorted
--- order, for display in quickfix and location lists.
---
--- The `user_data` field of each resulting item will contain the original
--- `Location` or `LocationLink` it was computed from.
---
--- The result can be passed to the {list} argument of |setqflist()| or
--- |setloclist()|.
---
---@param locations lsp.Location[]|lsp.LocationLink[]
---@param offset_encoding string offset_encoding for locations utf-8|utf-16|utf-32
---                              default to first client of buffer
---@return vim.lsp.util.locations_to_items.ret[]
function M.locations_to_items(locations, offset_encoding)
  if offset_encoding == nil then
    vim.notify_once(
      'locations_to_items must be called with valid offset encoding',
      vim.log.levels.WARN
    )
    offset_encoding = vim.lsp.get_clients({ bufnr = 0 })[1].offset_encoding
  end

  local items = {}
  ---@type table<string, {start: lsp.Position, location: lsp.Location|lsp.LocationLink}[]>
  local grouped = setmetatable({}, {
    __index = function(t, k)
      local v = {}
      rawset(t, k, v)
      return v
    end,
  })
  for _, d in ipairs(locations) do
    -- locations may be Location or LocationLink
    local uri = d.uri or d.targetUri
    local range = d.range or d.targetSelectionRange
    table.insert(grouped[uri], { start = range.start, location = d })
  end

  ---@type string[]
  local keys = vim.tbl_keys(grouped)
  table.sort(keys)
  -- TODO(ashkan) I wish we could do this lazily.
  for _, uri in ipairs(keys) do
    local rows = grouped[uri]
    table.sort(rows, position_sort)
    local filename = vim.uri_to_fname(uri)

    local line_numbers = {}
    for _, temp in ipairs(rows) do
      table.insert(line_numbers, temp.start.line)
    end

    -- get all the lines for this uri
    local lines = get_lines(vim.uri_to_bufnr(uri), line_numbers)

    for _, temp in ipairs(rows) do
      local pos = temp.start
      local row = pos.line
      local line = lines[row] or ''
      local col = M._str_byteindex_enc(line, pos.character, offset_encoding)
      table.insert(items, {
        filename = filename,
        lnum = row + 1,
        col = col + 1,
        text = line,
        user_data = temp.location,
      })
    end
  end
  return items
end

-- According to LSP spec, if the client set "symbolKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
function M._get_symbol_kind_name(symbol_kind)
  return protocol.SymbolKind[symbol_kind] or 'Unknown'
end

--- Converts symbols to quickfix list items.
---
---@param symbols table DocumentSymbol[] or SymbolInformation[]
---@param bufnr integer
function M.symbols_to_items(symbols, bufnr)
  local function _symbols_to_items(_symbols, _items, _bufnr)
    for _, symbol in ipairs(_symbols) do
      if symbol.location then -- SymbolInformation type
        local range = symbol.location.range
        local kind = M._get_symbol_kind_name(symbol.kind)
        table.insert(_items, {
          filename = vim.uri_to_fname(symbol.location.uri),
          lnum = range.start.line + 1,
          col = range.start.character + 1,
          kind = kind,
          text = '[' .. kind .. '] ' .. symbol.name,
        })
      elseif symbol.selectionRange then -- DocumentSymbole type
        local kind = M._get_symbol_kind_name(symbol.kind)
        table.insert(_items, {
          -- bufnr = _bufnr,
          filename = api.nvim_buf_get_name(_bufnr),
          lnum = symbol.selectionRange.start.line + 1,
          col = symbol.selectionRange.start.character + 1,
          kind = kind,
          text = '[' .. kind .. '] ' .. symbol.name,
        })
        if symbol.children then
          for _, v in ipairs(_symbols_to_items(symbol.children, _items, _bufnr)) do
            for _, s in ipairs(v) do
              table.insert(_items, s)
            end
          end
        end
      end
    end
    return _items
  end
  return _symbols_to_items(symbols, {}, bufnr or 0)
end

--- Removes empty lines from the beginning and end.
---@deprecated use `vim.split()` with `trimempty` instead
---@param lines table list of lines to trim
---@return table trimmed list of lines
function M.trim_empty_lines(lines)
  vim.deprecate('vim.lsp.util.trim_empty_lines()', 'vim.split() with `trimempty`', '0.12')
  local start = 1
  for i = 1, #lines do
    if lines[i] ~= nil and #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if lines[i] ~= nil and #lines[i] > 0 then
      finish = i
      break
    end
  end
  return list_extend({}, lines, start, finish)
end

--- Accepts markdown lines and tries to reduce them to a filetype if they
--- comprise just a single code block.
---
--- CAUTION: Modifies the input in-place!
---
---@deprecated
---@param lines string[] list of lines
---@return string filetype or "markdown" if it was unchanged.
function M.try_trim_markdown_code_blocks(lines)
  vim.deprecate('vim.lsp.util.try_trim_markdown_code_blocks()', 'nil', '0.12')
  local language_id = lines[1]:match('^```(.*)')
  if language_id then
    local has_inner_code_fence = false
    for i = 2, (#lines - 1) do
      local line = lines[i]
      if line:sub(1, 3) == '```' then
        has_inner_code_fence = true
        break
      end
    end
    -- No inner code fences + starting with code fence = hooray.
    if not has_inner_code_fence then
      table.remove(lines, 1)
      table.remove(lines)
      return language_id
    end
  end
  return 'markdown'
end

---@param window integer|nil: window handle or 0 for current, defaults to current
---@param offset_encoding? string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of buffer of `window`
local function make_position_param(window, offset_encoding)
  window = window or 0
  local buf = api.nvim_win_get_buf(window)
  local row, col = unpack(api.nvim_win_get_cursor(window))
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  row = row - 1
  local line = api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
  if not line then
    return { line = 0, character = 0 }
  end

  col = _str_utfindex_enc(line, col, offset_encoding)

  return { line = row, character = col }
end

--- Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---
---@param window integer|nil: window handle or 0 for current, defaults to current
---@param offset_encoding string|nil utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of buffer of `window`
---@return lsp.TextDocumentPositionParams
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
function M.make_position_params(window, offset_encoding)
  window = window or 0
  local buf = api.nvim_win_get_buf(window)
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  return {
    textDocument = M.make_text_document_params(buf),
    position = make_position_param(window, offset_encoding),
  }
end

--- Utility function for getting the encoding of the first LSP client on the given buffer.
---@param bufnr integer buffer handle or 0 for current, defaults to current
---@return string encoding first client if there is one, nil otherwise
function M._get_offset_encoding(bufnr)
  validate({
    bufnr = { bufnr, 'n', true },
  })

  local offset_encoding

  for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.offset_encoding == nil then
      vim.notify_once(
        string.format(
          'Client (id: %s) offset_encoding is nil. Do not unset offset_encoding.',
          client.id
        ),
        vim.log.levels.ERROR
      )
    end
    local this_offset_encoding = client.offset_encoding
    if not offset_encoding then
      offset_encoding = this_offset_encoding
    elseif offset_encoding ~= this_offset_encoding then
      vim.notify_once(
        'warning: multiple different client offset_encodings detected for buffer, this is not supported yet',
        vim.log.levels.WARN
      )
    end
  end

  return offset_encoding
end

--- Using the current position in the current buffer, creates an object that
--- can be used as a building block for several LSP requests, such as
--- `textDocument/codeAction`, `textDocument/colorPresentation`,
--- `textDocument/rangeFormatting`.
---
---@param window integer|nil: window handle or 0 for current, defaults to current
---@param offset_encoding "utf-8"|"utf-16"|"utf-32"|nil defaults to `offset_encoding` of first client of buffer of `window`
---@return table { textDocument = { uri = `current_file_uri` }, range = { start =
---`current_position`, end = `current_position` } }
function M.make_range_params(window, offset_encoding)
  local buf = api.nvim_win_get_buf(window or 0)
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  local position = make_position_param(window, offset_encoding)
  return {
    textDocument = M.make_text_document_params(buf),
    range = { start = position, ['end'] = position },
  }
end

--- Using the given range in the current buffer, creates an object that
--- is similar to |vim.lsp.util.make_range_params()|.
---
---@param start_pos integer[]|nil {row,col} mark-indexed position.
--- Defaults to the start of the last visual selection.
---@param end_pos integer[]|nil {row,col} mark-indexed position.
--- Defaults to the end of the last visual selection.
---@param bufnr integer|nil buffer handle or 0 for current, defaults to current
---@param offset_encoding "utf-8"|"utf-16"|"utf-32"|nil defaults to `offset_encoding` of first client of `bufnr`
---@return table { textDocument = { uri = `current_file_uri` }, range = { start =
---`start_position`, end = `end_position` } }
function M.make_given_range_params(start_pos, end_pos, bufnr, offset_encoding)
  validate({
    start_pos = { start_pos, 't', true },
    end_pos = { end_pos, 't', true },
    offset_encoding = { offset_encoding, 's', true },
  })
  bufnr = bufnr or api.nvim_get_current_buf()
  offset_encoding = offset_encoding or M._get_offset_encoding(bufnr)
  local A = list_extend({}, start_pos or api.nvim_buf_get_mark(bufnr, '<'))
  local B = list_extend({}, end_pos or api.nvim_buf_get_mark(bufnr, '>'))
  -- convert to 0-index
  A[1] = A[1] - 1
  B[1] = B[1] - 1
  -- account for offset_encoding.
  if A[2] > 0 then
    A = { A[1], M.character_offset(bufnr, A[1], A[2], offset_encoding) }
  end
  if B[2] > 0 then
    B = { B[1], M.character_offset(bufnr, B[1], B[2], offset_encoding) }
  end
  -- we need to offset the end character position otherwise we loose the last
  -- character of the selection, as LSP end position is exclusive
  -- see https://microsoft.github.io/language-server-protocol/specification#range
  if vim.o.selection ~= 'exclusive' then
    B[2] = B[2] + 1
  end
  return {
    textDocument = M.make_text_document_params(bufnr),
    range = {
      start = { line = A[1], character = A[2] },
      ['end'] = { line = B[1], character = B[2] },
    },
  }
end

--- Creates a `TextDocumentIdentifier` object for the current buffer.
---
---@param bufnr integer|nil: Buffer handle, defaults to current
---@return lsp.TextDocumentIdentifier
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentIdentifier
function M.make_text_document_params(bufnr)
  return { uri = vim.uri_from_bufnr(bufnr or 0) }
end

--- Create the workspace params
---@param added lsp.WorkspaceFolder[]
---@param removed lsp.WorkspaceFolder[]
---@return lsp.WorkspaceFoldersChangeEvent
function M.make_workspace_params(added, removed)
  return { event = { added = added, removed = removed } }
end

--- Returns indentation size.
---
---@see 'shiftwidth'
---@param bufnr integer|nil: Buffer handle, defaults to current
---@return integer indentation size
function M.get_effective_tabstop(bufnr)
  validate({ bufnr = { bufnr, 'n', true } })
  local bo = bufnr and vim.bo[bufnr] or vim.bo
  local sw = bo.shiftwidth
  return (sw == 0 and bo.tabstop) or sw
end

--- Creates a `DocumentFormattingParams` object for the current buffer and cursor position.
---
---@param options lsp.FormattingOptions|nil with valid `FormattingOptions` entries
---@return lsp.DocumentFormattingParams object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
function M.make_formatting_params(options)
  validate({ options = { options, 't', true } })
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = M.get_effective_tabstop(),
    insertSpaces = vim.bo.expandtab,
  })
  return {
    textDocument = { uri = vim.uri_from_bufnr(0) },
    options = options,
  }
end

--- Returns the UTF-32 and UTF-16 offsets for a position in a certain buffer.
---
---@param buf integer buffer number (0 for current)
---@param row integer 0-indexed line
---@param col integer 0-indexed byte offset in line
---@param offset_encoding string utf-8|utf-16|utf-32 defaults to `offset_encoding` of first client of `buf`
---@return integer `offset_encoding` index of the character in line {row} column {col} in buffer {buf}
function M.character_offset(buf, row, col, offset_encoding)
  local line = get_line(buf, row)
  if offset_encoding == nil then
    vim.notify_once(
      'character_offset must be called with valid offset encoding',
      vim.log.levels.WARN
    )
    offset_encoding = vim.lsp.get_clients({ bufnr = buf })[1].offset_encoding
  end
  -- If the col is past the EOL, use the line length.
  if col > #line then
    return _str_utfindex_enc(line, nil, offset_encoding)
  end
  return _str_utfindex_enc(line, col, offset_encoding)
end

--- Helper function to return nested values in language server settings
---
---@param settings table language server settings
---@param section  string indicating the field of the settings table
---@return table|string|vim.NIL The value of settings accessed via section. `vim.NIL` if not found.
---@deprecated
function M.lookup_section(settings, section)
  vim.deprecate('vim.lsp.util.lookup_section()', 'vim.tbl_get() with `vim.split`', '0.12')
  for part in vim.gsplit(section, '.', { plain = true }) do
    settings = settings[part]
    if settings == nil then
      return vim.NIL
    end
  end
  return settings
end

--- Converts line range (0-based, end-inclusive) to lsp range,
--- handles absence of a trailing newline
---
---@param bufnr integer
---@param start_line integer
---@param end_line integer
---@param offset_encoding lsp.PositionEncodingKind
---@return lsp.Range
local function make_line_range_params(bufnr, start_line, end_line, offset_encoding)
  local last_line = api.nvim_buf_line_count(bufnr) - 1

  ---@type lsp.Position
  local end_pos

  if end_line == last_line and not vim.api.nvim_get_option_value('endofline', { buf = bufnr }) then
    end_pos = {
      line = end_line,
      character = M.character_offset(bufnr, end_line, #get_line(bufnr, end_line), offset_encoding),
    }
  else
    end_pos = { line = end_line + 1, character = 0 }
  end

  return {
    start = { line = start_line, character = 0 },
    ['end'] = end_pos,
  }
end

---@class (private) vim.lsp.util._refresh.Opts
---@field bufnr integer? Buffer to refresh (default: 0)
---@field only_visible? boolean Whether to only refresh for the visible regions of the buffer (default: false)
---@field client_id? integer Client ID to refresh (default: all clients)

---@private
--- Request updated LSP information for a buffer.
---
---@param method string LSP method to call
---@param opts? vim.lsp.util._refresh.Opts Options table
function M._refresh(method, opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if bufnr == nil or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method, id = opts.client_id })

  if #clients == 0 then
    return
  end

  local textDocument = M.make_text_document_params(bufnr)

  local only_visible = opts.only_visible or false

  if only_visible then
    for _, window in ipairs(api.nvim_list_wins()) do
      if api.nvim_win_get_buf(window) == bufnr then
        local first = vim.fn.line('w0', window)
        local last = vim.fn.line('w$', window)
        for _, client in ipairs(clients) do
          client.request(method, {
            textDocument = textDocument,
            range = make_line_range_params(bufnr, first - 1, last - 1, client.offset_encoding),
          }, nil, bufnr)
        end
      end
    end
  else
    for _, client in ipairs(clients) do
      client.request(method, {
        textDocument = textDocument,
        range = make_line_range_params(
          bufnr,
          0,
          api.nvim_buf_line_count(bufnr) - 1,
          client.offset_encoding
        ),
      }, nil, bufnr)
    end
  end
end

---@nodoc
---@deprecated
---@type table<integer,integer>
M.buf_versions = setmetatable({}, {
  __index = function(_, bufnr)
    vim.deprecate('vim.lsp.util.buf_versions', 'vim.b.changedtick', '0.13')
    return vim.b[bufnr].changedtick
  end,
})

M._get_line_byte_from_position = get_line_byte_from_position

return M
