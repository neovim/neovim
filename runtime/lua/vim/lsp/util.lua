local protocol = require 'vim.lsp.protocol'
local snippet = require 'vim.lsp._snippet'
local vim = vim
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend
local highlight = require 'vim.highlight'
local uv = vim.loop

local npcall = vim.F.npcall
local split = vim.split

local _warned = {}
local warn_once = function(message)
  if not _warned[message] then
    vim.api.nvim_err_writeln(message)
    _warned[message] = true
  end
end

local M = {}

---@private
local function sort_by_key(fn)
  return function(a,b)
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

---@private
--- Position is a https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position
--- Returns a zero-indexed column, since set_lines() does the conversion to
--- 1-indexed
local function get_line_byte_from_position(bufnr, position, offset_encoding)
  -- LSP's line and characters are 0-indexed
  -- Vim's line and columns are 1-indexed
  local col = position.character
  -- When on the first character, we can ignore the difference between byte and
  -- character
  if col > 0 then
    if not api.nvim_buf_is_loaded(bufnr) then
      vim.fn.bufload(bufnr)
    end

    local line = position.line
    local lines = api.nvim_buf_get_lines(bufnr, line, line + 1, false)
    if #lines > 0 then
      local ok, result

      if offset_encoding == "utf-16" or not offset_encoding then
        ok, result = pcall(vim.str_byteindex, lines[1], col, true)
      elseif offset_encoding == "utf-32" then
        ok, result = pcall(vim.str_byteindex, lines[1], col, false)
      end

      if ok then
        return result
      end
      return math.min(#lines[1], col)
    end
  end
  return col
end

--- Process and return progress reports from lsp server
function M.get_progress_messages()

  local new_messages = {}
  local msg_remove = {}
  local progress_remove = {}

  for _, client in ipairs(vim.lsp.get_active_clients()) do
      local messages = client.messages
      local data = messages
      for token, ctx in pairs(data.progress) do

        local new_report = {
          name = data.name,
          title = ctx.title or "empty title",
          message = ctx.message,
          percentage = ctx.percentage,
          done = ctx.done,
          progress = true,
        }
        table.insert(new_messages, new_report)

        if ctx.done then
          table.insert(progress_remove, {client = client, token = token})
        end
      end

      for i, msg in ipairs(data.messages) do
        if msg.show_once then
          msg.shown = msg.shown + 1
          if msg.shown > 1 then
            table.insert(msg_remove, {client = client, idx = i})
          end
        end

        table.insert(new_messages, {name = data.name, content = msg.content})
      end

      if next(data.status) ~= nil then
        table.insert(new_messages, {
          name = data.name,
          content = data.status.content,
          uri = data.status.uri,
          status = true
        })
      end
    for _, item in ipairs(msg_remove) do
      table.remove(client.messages, item.idx)
    end

  end

  for _, item in ipairs(progress_remove) do
    item.client.messages.progress[item.token] = nil
  end

  return new_messages
end

--- Applies a list of text edits to a buffer.
---@param text_edits table list of `TextEdit` objects
---@param bufnr number Buffer id
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textEdit
function M.apply_text_edits(text_edits, bufnr)
  if not next(text_edits) then return end
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  api.nvim_buf_set_option(bufnr, 'buflisted', true)

  -- Fix reversed range and indexing each text_edits
  local index = 0
  text_edits = vim.tbl_map(function(text_edit)
    index = index + 1
    text_edit._index = index

    if text_edit.range.start.line > text_edit.range['end'].line or text_edit.range.start.line == text_edit.range['end'].line and text_edit.range.start.character > text_edit.range['end'].character then
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

  -- Some LSP servers may return +1 range of the buffer content but nvim_buf_set_text can't accept it so we should fix it here.
  local has_eol_text_edit = false
  local max = vim.api.nvim_buf_line_count(bufnr)
  -- TODO handle offset_encoding
  local _, len = vim.str_utfindex(vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or '')
  text_edits = vim.tbl_map(function(text_edit)
    if max <= text_edit.range.start.line then
      text_edit.range.start.line = max - 1
      text_edit.range.start.character = len
      text_edit.newText = '\n' .. text_edit.newText
      has_eol_text_edit = true
    end
    if max <= text_edit.range['end'].line then
      text_edit.range['end'].line = max - 1
      text_edit.range['end'].character = len
      has_eol_text_edit = true
    end
    return text_edit
  end, text_edits)

  -- Some LSP servers are depending on the VSCode behavior.
  -- The VSCode will re-locate the cursor position after applying TextEdit so we also do it.
  local is_current_buf = vim.api.nvim_get_current_buf() == bufnr
  local cursor = (function()
    if not is_current_buf then
      return {
        row = -1,
        col = -1,
      }
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    return {
      row = cursor[1] - 1,
      col = cursor[2],
    }
  end)()

  -- Apply text edits.
  local is_cursor_fixed = false
  for _, text_edit in ipairs(text_edits) do
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(bufnr, text_edit.range.start),
      end_row = text_edit.range['end'].line,
      end_col  = get_line_byte_from_position(bufnr, text_edit.range['end']),
      text = vim.split(text_edit.newText, '\n', true),
    }
    vim.api.nvim_buf_set_text(bufnr, e.start_row, e.start_col, e.end_row, e.end_col, e.text)

    local row_count = (e.end_row - e.start_row) + 1
    if e.end_row < cursor.row then
      cursor.row = cursor.row + (#e.text - row_count)
      is_cursor_fixed = true
    elseif e.end_row == cursor.row and e.end_col <= cursor.col then
      cursor.row = cursor.row + (#e.text - row_count)
      cursor.col = #e.text[#e.text] + (cursor.col - e.end_col)
      if #e.text == 1 then
        cursor.col = cursor.col + e.start_col
      end
      is_cursor_fixed = true
    end
  end

  if is_cursor_fixed then
    local is_valid_cursor = true
    is_valid_cursor = is_valid_cursor and cursor.row < vim.api.nvim_buf_line_count(bufnr)
    is_valid_cursor = is_valid_cursor and cursor.col <= #(vim.api.nvim_buf_get_lines(bufnr, cursor.row, cursor.row + 1, false)[1] or '')
    if is_valid_cursor then
      vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
    end
  end

  -- Remove final line if needed
  local fix_eol = has_eol_text_edit
  fix_eol = fix_eol and api.nvim_buf_get_option(bufnr, 'fixeol')
  fix_eol = fix_eol and (vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or '') == ''
  if fix_eol then
    vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  end
end

-- local valid_windows_path_characters = "[^<>:\"/\\|?*]"
-- local valid_unix_path_characters = "[^/]"
-- https://github.com/davidm/lua-glob-pattern
-- https://stackoverflow.com/questions/1976007/what-characters-are-forbidden-in-windows-and-linux-directory-names
-- function M.glob_to_regex(glob)
-- end

--- Applies a `TextDocumentEdit`, which is a list of changes to a single
--- document.
---
---@param text_document_edit table: a `TextDocumentEdit` object
---@param index number: Optional index of the edit, if from a list of edits (or nil, if not from a list)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentEdit
function M.apply_text_document_edit(text_document_edit, index)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)

  -- For lists of text document edits,
  -- do not check the version after the first edit.
  local should_check_version = true
  if index and index > 1 then
    should_check_version = false
  end

  -- `VersionedTextDocumentIdentifier`s version may be null
  --  https://microsoft.github.io/language-server-protocol/specification#versionedTextDocumentIdentifier
  if should_check_version and (text_document.version
      and text_document.version > 0
      and M.buf_versions[bufnr]
      and M.buf_versions[bufnr] > text_document.version) then
    print("Buffer ", text_document.uri, " newer than edits.")
    return
  end

  M.apply_text_edits(text_document_edit.edits, bufnr)
end
--- Rename old_fname to new_fname
---
---@param opts (table)
--         overwrite? bool
--         ignoreIfExists? bool
function M.rename(old_fname, new_fname, opts)
  opts = opts or {}
  local bufnr = vim.fn.bufadd(old_fname)
  vim.fn.bufload(bufnr)
  local target_exists = vim.loop.fs_stat(new_fname) ~= nil
  if target_exists and not opts.overwrite or opts.ignoreIfExists then
    vim.notify('Rename target already exists. Skipping rename.')
    return
  end
  local ok, err = os.rename(old_fname, new_fname)
  assert(ok, err)
  api.nvim_buf_call(bufnr, function()
    vim.cmd('saveas! ' .. vim.fn.fnameescape(new_fname))
  end)
end


local function create_file(change)
  local opts = change.options or {}
  -- from spec: Overwrite wins over `ignoreIfExists`
  local fname = vim.uri_to_fname(change.uri)
  if not opts.ignoreIfExists or opts.overwrite then
    local file = io.open(fname, 'w')
    file:close()
  end
  vim.fn.bufadd(fname)
end


local function delete_file(change)
  local opts = change.options or {}
  local fname = vim.uri_to_fname(change.uri)
  local stat = vim.loop.fs_stat(fname)
  if opts.ignoreIfNotExists and not stat then
    return
  end
  assert(stat, "Cannot delete not existing file or folder " .. fname)
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
---@param workspace_edit (table) `WorkspaceEdit`
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
function M.apply_workspace_edit(workspace_edit)
  if workspace_edit.documentChanges then
    for idx, change in ipairs(workspace_edit.documentChanges) do
      if change.kind == "rename" then
        M.rename(
          vim.uri_to_fname(change.oldUri),
          vim.uri_to_fname(change.newUri),
          change.options
        )
      elseif change.kind == 'create' then
        create_file(change)
      elseif change.kind == 'delete' then
        delete_file(change)
      elseif change.kind then
        error(string.format("Unsupported change: %q", vim.inspect(change)))
      else
        M.apply_text_document_edit(change, idx)
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
    M.apply_text_edits(changes, bufnr)
  end
end

--- Jumps to a location.
---
---@param location (`Location`|`LocationLink`)
---@returns `true` if the jump succeeded
function M.jump_to_location(location)
  -- location may be Location or LocationLink
  local uri = location.uri or location.targetUri
  if uri == nil then return end
  local bufnr = vim.uri_to_bufnr(uri)
  -- Save position in jumplist
  vim.cmd "normal! m'"

  -- Push a new item into tagstack
  local from = {vim.fn.bufnr('%'), vim.fn.line('.'), vim.fn.col('.'), 0}
  local items = {{tagname=vim.fn.expand('<cword>'), from=from}}
  vim.fn.settagstack(vim.fn.win_getid(), {items=items}, 't')

  --- Jump to new location (adjusting for UTF-16 encoding of characters)
  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_set_option(0, 'buflisted', true)
  local range = location.range or location.targetSelectionRange
  local row = range.start.line
  local col = get_line_byte_from_position(0, range.start)
  api.nvim_win_set_cursor(0, {row + 1, col})
  return true
end

--- Previews a location in a floating window
---
--- behavior depends on type of location:
---   - for Location, range is shown (e.g., function definition)
---   - for LocationLink, targetRange is shown (e.g., body of function definition)
---
---@param location a single `Location` or `LocationLink`
---@returns (bufnr,winnr) buffer and window number of floating window or nil
function M.preview_location(location, opts)
  -- location may be LocationLink or Location (more useful for the former)
  local uri = location.targetUri or location.uri
  if uri == nil then return end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  local range = location.targetRange or location.range
  local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line+1, false)
  local syntax = api.nvim_buf_get_option(bufnr, 'syntax')
  if syntax == "" then
    -- When no syntax is set, we use filetype as fallback. This might not result
    -- in a valid syntax definition. See also ft detection in stylize_markdown.
    -- An empty syntax is more common now with TreeSitter, since TS disables syntax.
    syntax = api.nvim_buf_get_option(bufnr, 'filetype')
  end
  opts = opts or {}
  opts.focus_id = "location"
  return M.open_floating_preview(contents, syntax, opts)
end


do --[[ References ]]
  local reference_ns = api.nvim_create_namespace("vim_lsp_references")

  --- Removes document highlights from a buffer.
  ---
  ---@param bufnr buffer id
  function M.buf_clear_references(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr, reference_ns, 0, -1)
  end

  --- Shows a list of document highlights for a certain buffer.
  ---
  ---@param bufnr buffer id
  ---@param references List of `DocumentHighlight` objects to highlight
  ---@see https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#documentHighlight
  function M.buf_highlight_references(bufnr, references, client_id)
    validate { bufnr = {bufnr, 'n', true} }
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
      return
    end
    for _, reference in ipairs(references) do
      local start_line, start_char = reference["range"]["start"]["line"], reference["range"]["start"]["character"]
      local end_line, end_char = reference["range"]["end"]["line"], reference["range"]["end"]["character"]

      local start_idx = get_line_byte_from_position(bufnr, { line = start_line, character = start_char }, client.offset_encoding)
      local end_idx = get_line_byte_from_position(bufnr, { line = start_line, character = end_char }, client.offset_encoding)

      local document_highlight_kind = {
        [protocol.DocumentHighlightKind.Text] = "LspReferenceText";
        [protocol.DocumentHighlightKind.Read] = "LspReferenceRead";
        [protocol.DocumentHighlightKind.Write] = "LspReferenceWrite";
      }
      local kind = reference["kind"] or protocol.DocumentHighlightKind.Text
      highlight.range(bufnr,
                      reference_ns,
                      document_highlight_kind[kind],
                      { start_line, start_idx },
                      { end_line, end_idx })
    end
  end
end

local position_sort = sort_by_key(function(v)
  return {v.start.line, v.start.character}
end)

--- Gets the zero-indexed line from the given uri.
---@param uri string uri of the resource to get the line from
---@param row number zero-indexed line number
---@return string the line at row in filename
-- For non-file uris, we load the buffer and get the line.
-- If a loaded buffer exists, then that is used.
-- Otherwise we get the line using libuv which is a lot faster than loading the buffer.
function M.get_line(uri, row)
  return M.get_lines(uri, { row })[row]
end

--- Gets the zero-indexed lines from the given uri.
---@param uri string uri of the resource to get the lines from
---@param rows number[] zero-indexed line numbers
---@return table<number string> a table mapping rows to lines
-- For non-file uris, we load the buffer and get the lines.
-- If a loaded buffer exists, then that is used.
-- Otherwise we get the lines using libuv which is a lot faster than loading the buffer.
function M.get_lines(uri, rows)
  rows = type(rows) == "table" and rows or { rows }

  local function buf_lines(bufnr)
    local lines = {}
    for _, row in pairs(rows) do
      lines[row] = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { "" })[1]
    end
    return lines
  end

  -- load the buffer if this is not a file uri
  -- Custom language server protocol extensions can result in servers sending URIs with custom schemes. Plugins are able to load these via `BufReadCmd` autocmds.
  if uri:sub(1, 4) ~= "file" then
    local bufnr = vim.uri_to_bufnr(uri)
    vim.fn.bufload(bufnr)
    return buf_lines(bufnr)
  end

  local filename = vim.uri_to_fname(uri)

  -- use loaded buffers if available
  if vim.fn.bufloaded(filename) == 1 then
    local bufnr = vim.fn.bufnr(filename, false)
    return buf_lines(bufnr)
  end

  -- get the data from the file
  local fd = uv.fs_open(filename, "r", 438)
  if not fd then return "" end
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

  for line in string.gmatch(data, "([^\n]*)\n?") do
    if lines[lnum] == true then
      lines[lnum] = line
      found = found + 1
      if found == need then break end
    end
    lnum = lnum + 1
  end

  -- change any lines we didn't find to the empty string
  for i, line in pairs(lines) do
    if line == true then
      lines[i] = ""
    end
  end
  return lines
end

--- Returns the items with the byte position calculated correctly and in sorted
--- order, for display in quickfix and location lists.
---
--- The result can be passed to the {list} argument of |setqflist()| or
--- |setloclist()|.
---
---@param locations (table) list of `Location`s or `LocationLink`s
---@returns (table) list of items
function M.locations_to_items(locations)
  local items = {}
  local grouped = setmetatable({}, {
    __index = function(t, k)
      local v = {}
      rawset(t, k, v)
      return v
    end;
  })
  for _, d in ipairs(locations) do
    -- locations may be Location or LocationLink
    local uri = d.uri or d.targetUri
    local range = d.range or d.targetSelectionRange
    table.insert(grouped[uri], {start = range.start})
  end


  local keys = vim.tbl_keys(grouped)
  table.sort(keys)
  -- TODO(ashkan) I wish we could do this lazily.
  for _, uri in ipairs(keys) do
    local rows = grouped[uri]
    table.sort(rows, position_sort)
    local filename = vim.uri_to_fname(uri)

    -- list of row numbers
    local uri_rows = {}
    for _, temp in ipairs(rows) do
      local pos = temp.start
      local row = pos.line
      table.insert(uri_rows, row)
    end

    -- get all the lines for this uri
    local lines = M.get_lines(uri, uri_rows)

    for _, temp in ipairs(rows) do
      local pos = temp.start
      local row = pos.line
      local line = lines[row] or ""
      local col = pos.character
      table.insert(items, {
        filename = filename,
        lnum = row + 1,
        col = col + 1;
        text = line;
      })
    end
  end
  return items
end

-- According to LSP spec, if the client set "symbolKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
function M._get_symbol_kind_name(symbol_kind)
  return protocol.SymbolKind[symbol_kind] or "Unknown"
end

--- Converts symbols to quickfix list items.
---
---@param symbols DocumentSymbol[] or SymbolInformation[]
function M.symbols_to_items(symbols, bufnr)
  ---@private
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
          text = '['..kind..'] '..symbol.name,
        })
      elseif symbol.selectionRange then -- DocumentSymbole type
        local kind = M._get_symbol_kind_name(symbol.kind)
        table.insert(_items, {
          -- bufnr = _bufnr,
          filename = vim.api.nvim_buf_get_name(_bufnr),
          lnum = symbol.selectionRange.start.line + 1,
          col = symbol.selectionRange.start.character + 1,
          kind = kind,
          text = '['..kind..'] '..symbol.name
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
  return _symbols_to_items(symbols, {}, bufnr)
end

local str_utfindex = vim.str_utfindex
---@private
local function make_position_param()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  if not line then
    return { line = 0; character = 0; }
  end
  -- TODO handle offset_encoding
  local _
  _, col = str_utfindex(line, col)
  return { line = row; character = col; }
end

--- Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---
---@returns `TextDocumentPositionParams` object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
function M.make_position_params()
  return {
    textDocument = M.make_text_document_params();
    position = make_position_param()
  }
end

--- Using the current position in the current buffer, creates an object that
--- can be used as a building block for several LSP requests, such as
--- `textDocument/codeAction`, `textDocument/colorPresentation`,
--- `textDocument/rangeFormatting`.
---
---@returns { textDocument = { uri = `current_file_uri` }, range = { start =
---`current_position`, end = `current_position` } }
function M.make_range_params()
  local position = make_position_param()
  return {
    textDocument = M.make_text_document_params(),
    range = { start = position; ["end"] = position; }
  }
end

--- Using the given range in the current buffer, creates an object that
--- is similar to |vim.lsp.util.make_range_params()|.
---
---@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
---@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
---@returns { textDocument = { uri = `current_file_uri` }, range = { start =
---`start_position`, end = `end_position` } }
function M.make_given_range_params(start_pos, end_pos)
  validate {
    start_pos = {start_pos, 't', true};
    end_pos = {end_pos, 't', true};
  }
  local A = list_extend({}, start_pos or api.nvim_buf_get_mark(0, '<'))
  local B = list_extend({}, end_pos or api.nvim_buf_get_mark(0, '>'))
  -- convert to 0-index
  A[1] = A[1] - 1
  B[1] = B[1] - 1
  -- account for encoding.
  -- TODO handle offset_encoding
  if A[2] > 0 then
    local _, char = M.character_offset(0, A[1], A[2])
    A = {A[1], char}
  end
  if B[2] > 0 then
    local _, char = M.character_offset(0, B[1], B[2])
    B = {B[1], char}
  end
  -- we need to offset the end character position otherwise we loose the last
  -- character of the selection, as LSP end position is exclusive
  -- see https://microsoft.github.io/language-server-protocol/specification#range
  if vim.o.selection ~= 'exclusive' then
    B[2] = B[2] + 1
  end
  return {
    textDocument = M.make_text_document_params(),
    range = {
      start = {line = A[1], character = A[2]},
      ['end'] = {line = B[1], character = B[2]}
    }
  }
end

--- Creates a `TextDocumentIdentifier` object for the current buffer.
---
---@returns `TextDocumentIdentifier`
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentIdentifier
function M.make_text_document_params()
  return { uri = vim.uri_from_bufnr(0) }
end

--- Create the workspace params
---@param added
---@param removed
function M.make_workspace_params(added, removed)
  return { event = { added = added; removed = removed; } }
end
--- Returns visual width of tabstop.
---
---@see |softtabstop|
---@param bufnr (optional, number): Buffer handle, defaults to current
---@returns (number) tabstop visual width
function M.get_effective_tabstop(bufnr)
  validate { bufnr = {bufnr, 'n', true} }
  local bo = bufnr and vim.bo[bufnr] or vim.bo
  local sts = bo.softtabstop
  return (sts > 0 and sts) or (sts < 0 and bo.shiftwidth) or bo.tabstop
end

--- Creates a `DocumentFormattingParams` object for the current buffer and cursor position.
---
---@param options Table with valid `FormattingOptions` entries
---@returns `DocumentFormattingParams` object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
function M.make_formatting_params(options)
  validate { options = {options, 't', true} }
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = M.get_effective_tabstop();
    insertSpaces = vim.bo.expandtab;
  })
  return {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    options = options;
  }
end

--- Returns the UTF-32 and UTF-16 offsets for a position in a certain buffer.
---
---@param buf buffer id (0 for current)
---@param row 0-indexed line
---@param col 0-indexed byte offset in line
---@returns (number, number) UTF-32 and UTF-16 index of the character in line {row} column {col} in buffer {buf}
function M.character_offset(bufnr, row, col)
  local uri = vim.uri_from_bufnr(bufnr)
  local line = M.get_line(uri, row)
  -- If the col is past the EOL, use the line length.
  if col > #line then
    return str_utfindex(line)
  end
  return str_utfindex(line, col)
end

--- Helper function to return nested values in language server settings
---
---@param settings a table of language server settings
---@param section  a string indicating the field of the settings table
---@returns (table or string) The value of settings accessed via section
function M.lookup_section(settings, section)
  for part in vim.gsplit(section, '.', true) do
    settings = settings[part]
    if not settings then
      return
    end
  end
  return settings
end

M._get_line_byte_from_position = get_line_byte_from_position
M._warn_once = warn_once

M.buf_versions = {}

return M
-- vim:sw=2 ts=2 et
