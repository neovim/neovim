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

local M = {}

local default_border = {
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {" ", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {"", "NormalFloat"},
  {" ", "NormalFloat"},
}

---@private
--- Check the border given by opts or the default border for the additional
--- size it adds to a float.
---@param opts (table, optional) options for the floating window
---            - border (string or table) the border
---@returns (table) size of border in the form of { height = height, width = width }
local function get_border_size(opts)
  local border = opts and opts.border or default_border
  local height = 0
  local width = 0

  if type(border) == 'string' then
    local border_size = {none = {0, 0}, single = {2, 2}, double = {2, 2}, rounded = {2, 2}, solid = {2, 2}, shadow = {1, 1}}
    if border_size[border] == nil then
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    height, width = unpack(border_size[border])
  else
    if 8 % #border ~= 0 then
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    ---@private
    local function border_width(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == "table" then
        -- border specified as a table of <character, highlight group>
        return vim.fn.strdisplaywidth(border[id][1])
      elseif type(border[id]) == "string" then
        -- border specified as a list of border characters
        return vim.fn.strdisplaywidth(border[id])
      end
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    ---@private
    local function border_height(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == "table" then
        -- border specified as a table of <character, highlight group>
        return #border[id][1] > 0 and 1 or 0
      elseif type(border[id]) == "string" then
        -- border specified as a list of border characters
        return #border[id] > 0 and 1 or 0
      end
      error(string.format("invalid floating preview border: %s. :help vim.api.nvim_open_win()", vim.inspect(border)))
    end
    height = height + border_height(2)  -- top
    height = height + border_height(6)  -- bottom
    width  = width  + border_width(4)  -- right
    width  = width  + border_width(8)  -- left
  end

  return { height = height, width = width }
end

---@private
local function split_lines(value)
  return split(value, '\n', true)
end

--- Convert byte index to `encoding` index.
--- Convenience wrapper around vim.str_utfindex
---@param line string line to be indexed
---@param index number byte index (utf-8), or `nil` for length
---@param encoding string utf-8|utf-16|utf-32|nil defaults to utf-16
---@return number `encoding` index of `index` in `line`
function M._str_utfindex_enc(line, index, encoding)
  if not encoding then encoding = 'utf-16' end
  if encoding == 'utf-8' then
    if index then return index else return #line end
  elseif encoding == 'utf-16' then
    local _, col16 = vim.str_utfindex(line, index)
    return col16
  elseif encoding == 'utf-32' then
    local col32, _ = vim.str_utfindex(line, index)
    return col32
  else
    error("Invalid encoding: " .. vim.inspect(encoding))
  end
end

--- Convert UTF index to `encoding` index.
--- Convenience wrapper around vim.str_byteindex
---Alternative to vim.str_byteindex that takes an encoding.
---@param line string line to be indexed
---@param index number UTF index
---@param encoding string utf-8|utf-16|utf-32|nil defaults to utf-16
---@return number byte (utf-8) index of `encoding` index `index` in `line`
function M._str_byteindex_enc(line, index, encoding)
  if not encoding then encoding = 'utf-16' end
  if encoding == 'utf-8' then
    if index then return index else return #line end
  elseif encoding == 'utf-16' then
    return vim.str_byteindex(line, index, true)
  elseif encoding == 'utf-32' then
    return vim.str_byteindex(line, index)
  else
    error("Invalid encoding: " .. vim.inspect(encoding))
  end
end

local _str_utfindex_enc = M._str_utfindex_enc
local _str_byteindex_enc = M._str_byteindex_enc
--- Replaces text in a range with new text.
---
--- CAUTION: Changes in-place!
---
---@param lines (table) Original list of strings
---@param A (table) Start position; a 2-tuple of {line, col} numbers
---@param B (table) End position; a 2-tuple of {line, col} numbers
---@param new_lines A list of strings to replace the original
---@returns (table) The modified {lines} object
function M.set_lines(lines, A, B, new_lines)
  -- 0-indexing to 1-indexing
  local i_0 = A[1] + 1
  -- If it extends past the end, truncate it to the end. This is because the
  -- way the LSP describes the range including the last newline is by
  -- specifying a line number after what we would call the last line.
  local i_n = math.min(B[1] + 1, #lines)
  if not (i_0 >= 1 and i_0 <= #lines + 1 and i_n >= 1 and i_n <= #lines) then
    error("Invalid range: "..vim.inspect{A = A; B = B; #lines, new_lines})
  end
  local prefix = ""
  local suffix = lines[i_n]:sub(B[2]+1)
  if A[2] > 0 then
    prefix = lines[i_0]:sub(1, A[2])
  end
  local n = i_n - i_0 + 1
  if n ~= #new_lines then
    for _ = 1, n - #new_lines do table.remove(lines, i_0) end
    for _ = 1, #new_lines - n do table.insert(lines, i_0, '') end
  end
  for i = 1, #new_lines do
    lines[i - 1 + i_0] = new_lines[i]
  end
  if #suffix > 0 then
    local i = i_0 + #new_lines - 1
    lines[i] = lines[i]..suffix
  end
  if #prefix > 0 then
    lines[i_0] = prefix..lines[i_0]
  end
  return lines
end

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
--- Gets the zero-indexed lines from the given buffer.
--- Works on unloaded buffers by reading the file using libuv to bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param bufnr number bufnr to get the lines from
---@param rows number[] zero-indexed line numbers
---@return table<number string> a table mapping rows to lines
local function get_lines(bufnr, rows)
  rows = type(rows) == "table" and rows or { rows }

  -- This is needed for bufload and bufloaded
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  ---@private
  local function buf_lines()
    local lines = {}
    for _, row in pairs(rows) do
      lines[row] = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { "" })[1]
    end
    return lines
  end

  local uri = vim.uri_from_bufnr(bufnr)

  -- load the buffer if this is not a file uri
  -- Custom language server protocol extensions can result in servers sending URIs with custom schemes. Plugins are able to load these via `BufReadCmd` autocmds.
  if uri:sub(1, 4) ~= "file" then
    vim.fn.bufload(bufnr)
    return buf_lines()
  end

  -- use loaded buffers if available
  if vim.fn.bufloaded(bufnr) == 1 then
    return buf_lines()
  end

  local filename = api.nvim_buf_get_name(bufnr)

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


---@private
--- Gets the zero-indexed line from the given buffer.
--- Works on unloaded buffers by reading the file using libuv to bypass buf reading events.
--- Falls back to loading the buffer and nvim_buf_get_lines for buffers with non-file URI.
---
---@param bufnr number
---@param row number zero-indexed line number
---@return string the line at row in filename
local function get_line(bufnr, row)
  return get_lines(bufnr, { row })[row]
end


---@private
--- Position is a https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position
--- Returns a zero-indexed column, since set_lines() does the conversion to
---@param offset_encoding string utf-8|utf-16|utf-32
--- 1-indexed
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

--- Process and return progress reports from lsp server
---@private
function M.get_progress_messages()

  local new_messages = {}
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

  end

  for _, item in ipairs(progress_remove) do
    item.client.messages.progress[item.token] = nil
  end

  return new_messages
end

--- Applies a list of text edits to a buffer.
---@param text_edits table list of `TextEdit` objects
---@param bufnr number Buffer id
---@param offset_encoding string utf-8|utf-16|utf-32
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textEdit
function M.apply_text_edits(text_edits, bufnr, offset_encoding)
  validate {
    text_edits = { text_edits, 't', false };
    bufnr = { bufnr, 'number', false };
    offset_encoding = { offset_encoding, 'string', false };
  }
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
  local has_eol_text_edit = false
  for _, text_edit in ipairs(text_edits) do
    -- Normalize line ending
    text_edit.newText, _ = string.gsub(text_edit.newText, '\r\n?', '\n')

    -- Convert from LSP style ranges to Neovim style ranges.
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(bufnr, text_edit.range.start, offset_encoding),
      end_row = text_edit.range['end'].line,
      end_col  = get_line_byte_from_position(bufnr, text_edit.range['end'], offset_encoding),
      text = vim.split(text_edit.newText, '\n', true),
    }

    -- Some LSP servers may return +1 range of the buffer content but nvim_buf_set_text can't accept it so we should fix it here.
    local max = vim.api.nvim_buf_line_count(bufnr)
    if max <= e.start_row or max <= e.end_row then
      local len = #(get_line(bufnr, max - 1) or '')
      if max <= e.start_row then
        e.start_row = max - 1
        e.start_col = len
        table.insert(e.text, 1, '')
      end
      if max <= e.end_row then
        e.end_row = max - 1
        e.end_col = len
      end
      has_eol_text_edit = true
    end
    vim.api.nvim_buf_set_text(bufnr, e.start_row, e.start_col, e.end_row, e.end_col, e.text)

    -- Fix cursor position.
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

  local max = vim.api.nvim_buf_line_count(bufnr)

  -- Apply fixed cursor position.
  if is_cursor_fixed then
    local is_valid_cursor = true
    is_valid_cursor = is_valid_cursor and cursor.row < max
    is_valid_cursor = is_valid_cursor and cursor.col <= #(get_line(bufnr, max - 1) or '')
    if is_valid_cursor then
      vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
    end
  end

  -- Remove final line if needed
  local fix_eol = has_eol_text_edit
  fix_eol = fix_eol and (api.nvim_buf_get_option(bufnr, 'eol') or (api.nvim_buf_get_option(bufnr, 'fixeol') and not api.nvim_buf_get_option(bufnr, 'binary')))
  fix_eol = fix_eol and get_line(bufnr, max - 1) == ''
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

--- Can be used to extract the completion items from a
--- `textDocument/completion` request, which may return one of
--- `CompletionItem[]`, `CompletionList` or null.
---@param result (table) The result of a `textDocument/completion` request
---@returns (table) List of completion items
---@see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
function M.extract_completion_items(result)
  if type(result) == 'table' and result.items then
    -- result is a `CompletionList`
    return result.items
  elseif result ~= nil then
    -- result is `CompletionItem[]`
    return result
  else
    -- result is `null`
    return {}
  end
end

--- Applies a `TextDocumentEdit`, which is a list of changes to a single
--- document.
---
---@param text_document_edit table: a `TextDocumentEdit` object
---@param index number: Optional index of the edit, if from a list of edits (or nil, if not from a list)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentEdit
function M.apply_text_document_edit(text_document_edit, index, offset_encoding)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)
  if offset_encoding == nil then
    vim.notify_once("apply_text_document_edit must be called with valid offset encoding", vim.log.levels.WARN)
  end

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

  M.apply_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end

--- Parses snippets in a completion entry.
---
---@param input string unparsed snippet
---@returns string parsed snippet
function M.parse_snippet(input)
  local ok, parsed = pcall(function()
    return tostring(snippet.parse(input))
  end)
  if not ok then
    return input
  end
  return parsed
end

---@private
--- Sorts by CompletionItem.sortText.
---
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function sort_completion_items(items)
  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)
end

---@private
--- Returns text that should be inserted when selecting completion item. The
--- precedence is as follows: textEdit.newText > insertText > label
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.textEdit.newText
    else
      return M.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return M.parse_snippet(item.insertText)
    end
  end
  return item.label
end

---@private
--- Some language servers return complementary candidates whose prefixes do not
--- match are also returned. So we exclude completion candidates whose prefix
--- does not match.
local function remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = get_completion_word(item)
    return vim.startswith(word, prefix)
  end, items)
end

--- According to LSP spec, if the client set `completionItemKind.valueSet`,
--- the client must handle it properly even if it receives a value outside the
--- specification.
---
---@param completion_item_kind (`vim.lsp.protocol.completionItemKind`)
---@returns (`vim.lsp.protocol.completionItemKind`)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
function M._get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or "Unknown"
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
---@param result The result of a `textDocument/completion` call, e.g. from
---|vim.lsp.buf.completion()|, which may be one of `CompletionItem[]`,
--- `CompletionList` or `null`
---@param prefix (string) the prefix to filter the completion items
---@returns { matches = complete-items table, incomplete = bool }
---@see |complete-items|
function M.text_document_completion_list_to_complete_items(result, prefix)
  local items = M.extract_completion_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  items = remove_unmatch_completion_items(items, prefix)
  sort_completion_items(items)

  local matches = {}

  for _, completion_item in ipairs(items) do
    local info = ' '
    local documentation = completion_item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      -- else
        -- TODO(ashkan) Validation handling here?
      end
    end

    local word = get_completion_word(completion_item)
    table.insert(matches, {
      word = word,
      abbr = completion_item.label,
      kind = M._get_completion_item_kind_name(completion_item.kind),
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = completion_item
          }
        }
      },
    })
  end

  return matches
end


--- Rename old_fname to new_fname
---
---@param opts (table)
--         overwrite? bool
--         ignoreIfExists? bool
function M.rename(old_fname, new_fname, opts)
  opts = opts or {}
  local target_exists = vim.loop.fs_stat(new_fname) ~= nil
  if target_exists and not opts.overwrite or opts.ignoreIfExists then
    vim.notify('Rename target already exists. Skipping rename.')
    return
  end
  local oldbuf = vim.fn.bufadd(old_fname)
  vim.fn.bufload(oldbuf)

  -- The there may be pending changes in the buffer
  api.nvim_buf_call(oldbuf, function()
    vim.cmd('w!')
  end)

  local ok, err = os.rename(old_fname, new_fname)
  assert(ok, err)

  local newbuf = vim.fn.bufadd(new_fname)
  for _, win in pairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(win) == oldbuf then
      api.nvim_win_set_buf(win, newbuf)
    end
  end
  api.nvim_buf_delete(oldbuf, { force = true })
end

---@private
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

---@private
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
---@param workspace_edit table `WorkspaceEdit`
---@param offset_encoding string utf-8|utf-16|utf-32 (required)
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
function M.apply_workspace_edit(workspace_edit, offset_encoding)
  if offset_encoding == nil then
    vim.notify_once("apply_workspace_edit must be called with valid offset encoding", vim.log.levels.WARN)
  end
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
---@param input (`MarkedString` | `MarkedString[]` | `MarkupContent`)
---@param contents (table, optional, default `{}`) List of strings to extend with converted lines
---@returns {contents}, extended with lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
function M.convert_input_to_markdown_lines(input, contents)
  contents = contents or {}
  -- MarkedString variation 1
  if type(input) == 'string' then
    list_extend(contents, split_lines(input))
  else
    assert(type(input) == 'table', "Expected a table for Hover.contents")
    -- MarkupContent
    if input.kind then
      -- The kind can be either plaintext or markdown.
      -- If it's plaintext, then wrap it in a <text></text> block

      -- Some servers send input.value as empty, so let's ignore this :(
      local value = input.value or ''

      if input.kind == "plaintext" then
        -- wrap this in a <text></text> block so that stylize_markdown
        -- can properly process it as plaintext
        value = string.format("<text>\n%s\n</text>", value)
      end

      -- assert(type(value) == 'string')
      list_extend(contents, split_lines(value))
    -- MarkupString variation 2
    elseif input.language then
      -- Some servers send input.value as empty, so let's ignore this :(
      -- assert(type(input.value) == 'string')
      table.insert(contents, "```"..input.language)
      list_extend(contents, split_lines(input.value or ''))
      table.insert(contents, "```")
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

--- Converts `textDocument/SignatureHelp` response to markdown lines.
---
---@param signature_help Response of `textDocument/SignatureHelp`
---@param ft optional filetype that will be use as the `lang` for the label markdown code block
---@param triggers optional list of trigger characters from the lsp server. used to better determine parameter offsets
---@returns list of lines of converted markdown.
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
function M.convert_signature_help_to_markdown_lines(signature_help, ft, triggers)
  if not signature_help.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
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
    -- wrap inside a code block so stylize_markdown can render it properly
    label = ("```%s\n%s\n```"):format(ft, label)
  end
  vim.list_extend(contents, vim.split(label, '\n', true))
  if signature.documentation then
    M.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = (signature.activeParameter or signature_help.activeParameter or 0)
    if active_parameter < 0
      then active_parameter = 0
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
        if type(parameter.label) == "table" then
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
            if not offset then break end
            if p == active_parameter + 1 then
              active_hl = {offset - 1, offset + #parameter.label - 1}
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
---@param width (number) window width (in character cells)
---@param height (number) window height (in character cells)
---@param opts (table, optional)
---        - offset_x (number) offset to add to `col`
---        - offset_y (number) offset to add to `row`
---        - border (string or table) override `border`
---        - focusable (string or table) override `focusable`
---        - zindex (string or table) override `zindex`, defaults to 50
---@returns (table) Options
function M.make_floating_popup_options(width, height, opts)
  validate {
    opts = { opts, 't', true };
  }
  opts = opts or {}
  validate {
    ["opts.offset_x"] = { opts.offset_x, 'n', true };
    ["opts.offset_y"] = { opts.offset_y, 'n', true };
  }

  local anchor = ''
  local row, col

  local lines_above = vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above

  if lines_above < lines_below then
    anchor = anchor..'N'
    height = math.min(lines_below, height)
    row = 1
  else
    anchor = anchor..'S'
    height = math.min(lines_above, height)
    row = 0
  end

  if vim.fn.wincol() + width + (opts.offset_x or 0) <= api.nvim_get_option('columns') then
    anchor = anchor..'W'
    col = 0
  else
    anchor = anchor..'E'
    col = 1
  end

  return {
    anchor = anchor,
    col = col + (opts.offset_x or 0),
    height = height,
    focusable = opts.focusable,
    relative = 'cursor',
    row = row + (opts.offset_y or 0),
    style = 'minimal',
    width = width,
    border = opts.border or default_border,
    zindex = opts.zindex or 50,
  }
end

--- Jumps to a location.
---
---@param location table (`Location`|`LocationLink`)
---@param offset_encoding string utf-8|utf-16|utf-32 (required)
---@returns `true` if the jump succeeded
function M.jump_to_location(location, offset_encoding)
  -- location may be Location or LocationLink
  local uri = location.uri or location.targetUri
  if uri == nil then return end
  if offset_encoding == nil then
    vim.notify_once("jump_to_location must be called with valid offset encoding", vim.log.levels.WARN)
  end
  local bufnr = vim.uri_to_bufnr(uri)
  -- Save position in jumplist
  vim.cmd "normal! m'"

  -- Push a new item into tagstack
  local from = {vim.fn.bufnr('%'), vim.fn.line('.'), vim.fn.col('.'), 0}
  local items = {{tagname=vim.fn.expand('<cword>'), from=from}}
  vim.fn.settagstack(vim.fn.win_getid(), {items=items}, 't')

  --- Jump to new location (adjusting for UTF-16 encoding of characters)
  api.nvim_set_current_buf(bufnr)
  api.nvim_buf_set_option(bufnr, 'buflisted', true)
  local range = location.range or location.targetSelectionRange
  local row = range.start.line
  local col = get_line_byte_from_position(bufnr, range.start, offset_encoding)
  api.nvim_win_set_cursor(0, {row + 1, col})
  -- Open folds under the cursor
  vim.cmd("normal! zv")
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

---@private
local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

--- Trims empty lines from input and pad top and bottom with empty lines
---
---@param contents table of lines to trim and pad
---@param opts dictionary with optional fields
---             - pad_top    number of lines to pad contents at top (default 0)
---             - pad_bottom number of lines to pad contents at bottom (default 0)
---@return contents table of trimmed and padded lines
function M._trim(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}
  contents = M.trim_empty_lines(contents)
  if opts.pad_top then
    for _ = 1, opts.pad_top do
      table.insert(contents, 1, "")
    end
  end
  if opts.pad_bottom then
    for _ = 1, opts.pad_bottom do
      table.insert(contents, "")
    end
  end
  return contents
end

--- Generates a table mapping markdown code block lang to vim syntax,
--- based on g:markdown_fenced_languages
---@return a table of lang -> syntax mappings
---@private
local function get_markdown_fences()
  local fences = {}
  for _, fence in pairs(vim.g.markdown_fenced_languages or {}) do
    local lang, syntax = fence:match("^(.*)=(.*)$")
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
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---  - height    of floating window
---  - width     of floating window
---  - wrap_at   character to wrap at for computing height
---  - max_width  maximal width of floating window
---  - max_height maximal height of floating window
---  - pad_top    number of lines to pad contents at top
---  - pad_bottom number of lines to pad contents at bottom
---  - separator insert separator after code block
---@returns width,height size of float
function M.stylize_markdown(bufnr, contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  -- table of fence types to {ft, begin, end}
  -- when ft is nil, we get the ft from the regex match
  local matchers = {
    block = {nil, "```+([a-zA-Z0-9_]*)", "```+"},
    pre = {"", "<pre>", "</pre>"},
    code = {"", "<code>", "</code>"},
    text = {"text", "<text>", "</text>"},
  }

  local match_begin = function(line)
    for type, pattern in pairs(matchers) do
      local ret = line:match(string.format("^%%s*%s%%s*$", pattern[2]))
      if ret then
        return {
          type = type,
          ft = pattern[1] or ret
        }
      end
    end
  end

  local match_end = function(line, match)
    local pattern = matchers[match.type]
    return line:match(string.format("^%%s*%s%%s*$", pattern[3]))
  end

  -- Clean up
  contents = M._trim(contents, opts)

  -- Insert blank line separator after code block?
  local add_sep = opts.separator == nil and true or opts.separator
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
          ft = match.ft;
          start = start + 1;
          finish = #stripped;
        })
        -- add a separator, but not on the last line
        if add_sep and i < #contents then
          table.insert(stripped, "---")
          markdown_lines[#stripped] = true
        end
      else
        -- strip any empty lines or separators prior to this separator in actual markdown
        if line:match("^---+$") then
          while markdown_lines[#stripped] and (stripped[#stripped]:match("^%s*$") or stripped[#stripped]:match("^---+$")) do
            markdown_lines[#stripped] = false
            table.remove(stripped, #stripped)
          end
        end
        -- add the line if its not an empty line following a separator
        if not (line:match("^%s*$") and markdown_lines[#stripped] and stripped[#stripped]:match("^---+$")) then
          table.insert(stripped, line)
          markdown_lines[#stripped] = true
        end
        i = i + 1
      end
    end
  end

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
  local width = M._make_floating_popup_size(stripped, opts)

  local sep_line = string.rep("─", math.min(width, opts.wrap_at or width))

  for l in pairs(markdown_lines) do
    if stripped[l]:match("^---+$") then
      stripped[l] = sep_line
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

  local idx = 1
  ---@private
  -- keep track of syntaxes we already included.
  -- no need to include the same syntax more than once
  local langs = {}
  local fences = get_markdown_fences()
  local function apply_syntax_to_region(ft, start, finish)
    if ft == "" then
      vim.cmd(string.format("syntax region markdownCode start=+\\%%%dl+ end=+\\%%%dl+ keepend extend", start, finish + 1))
      return
    end
    ft = fences[ft] or ft
    local name = ft..idx
    idx = idx + 1
    local lang = "@"..ft:upper()
    if not langs[lang] then
      -- HACK: reset current_syntax, since some syntax files like markdown won't load if it is already set
      pcall(vim.api.nvim_buf_del_var, bufnr, "current_syntax")
      -- TODO(ashkan): better validation before this.
      if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
        return
      end
      langs[lang] = true
    end
    vim.cmd(string.format("syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s keepend", name, start, finish + 1, lang))
  end

  -- needs to run in the buffer for the regions to work
  api.nvim_buf_call(bufnr, function()
    -- we need to apply lsp_markdown regions speperately, since otherwise
    -- markdown regions can "bleed" through the other syntax regions
    -- and mess up the formatting
    local last = 1
    for _, h in ipairs(highlights) do
      if last < h.start then
        apply_syntax_to_region("lsp_markdown", last, h.start - 1)
      end
      apply_syntax_to_region(h.ft, h.start, h.finish)
      last = h.finish + 1
    end
    if last <= #stripped then
      apply_syntax_to_region("lsp_markdown", last, #stripped)
    end
  end)

  return stripped
end

---@private
--- Creates autocommands to close a preview window when events happen.
---
---@param events table list of events
---@param winnr number window id of preview window
---@param bufnrs table list of buffers where the preview window will remain visible
---@see |autocmd-events|
local function close_preview_autocmd(events, winnr, bufnrs)
  local augroup = 'preview_window_'..winnr

  -- close the preview window when entered a buffer that is not
  -- the floating window buffer or the buffer that spawned it
  vim.cmd(string.format([[
    augroup %s
      autocmd!
      autocmd BufEnter * lua vim.lsp.util._close_preview_window(%d, {%s})
    augroup end
  ]], augroup, winnr, table.concat(bufnrs, ',')))

  if #events > 0 then
    vim.cmd(string.format([[
      augroup %s
        autocmd %s <buffer> lua vim.lsp.util._close_preview_window(%d)
      augroup end
    ]], augroup, table.concat(events, ','), winnr))
  end
end

---@private
--- Closes the preview window
---
---@param winnr number window id of preview window
---@param bufnrs table|nil optional list of ignored buffers
function M._close_preview_window(winnr, bufnrs)
  vim.schedule(function()
    -- exit if we are in one of ignored buffers
    if bufnrs and vim.tbl_contains(bufnrs, api.nvim_get_current_buf()) then
      return
    end

    local augroup = 'preview_window_'..winnr
    vim.cmd(string.format([[
      augroup %s
        autocmd!
      augroup end
      augroup! %s
    ]], augroup, augroup))
    pcall(vim.api.nvim_win_close, winnr, true)
  end)
end

---@internal
--- Computes size of float needed to show contents (with optional wrapping)
---
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---            - height  of floating window
---            - width   of floating window
---            - wrap_at character to wrap at for computing height
---            - max_width  maximal width of floating window
---            - max_height maximal height of floating window
---@returns width,height size of float
function M._make_floating_popup_size(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
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
      line_widths[i] = vim.fn.strdisplaywidth(line)
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
          local line_width = vim.fn.strdisplaywidth(line)
          height = height + math.ceil(line_width/wrap_at)
        end
      else
        for i = 1, #contents do
          height = height + math.max(1, math.ceil(line_widths[i]/wrap_at))
        end
      end
    end
  end
  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
end

--- Shows contents in a floating window.
---
---@param contents table of lines to show in window
---@param syntax string of syntax to set for opened buffer
---@param opts table with optional fields (additional keys are passed on to |vim.api.nvim_open_win()|)
---             - height: (number) height of floating window
---             - width: (number) width of floating window
---             - wrap: (boolean, default true) wrap long lines
---             - wrap_at: (string) character to wrap at for computing height when wrap is enabled
---             - max_width: (number) maximal width of floating window
---             - max_height: (number) maximal height of floating window
---             - pad_top: (number) number of lines to pad contents at top
---             - pad_bottom: (number) number of lines to pad contents at bottom
---             - focus_id: (string) if a popup with this id is opened, then focus it
---             - close_events: (table) list of events that closes the floating window
---             - focusable: (boolean, default true) Make float focusable
---             - focus: (boolean, default true) If `true`, and if {focusable}
---                      is also `true`, focus an existing floating window with the same
---                      {focus_id}
---@returns bufnr,winnr buffer and window number of the newly created floating
---preview window
function M.open_floating_preview(contents, syntax, opts)
  validate {
    contents = { contents, 't' };
    syntax = { syntax, 's', true };
    opts = { opts, 't', true };
  }
  opts = opts or {}
  opts.wrap = opts.wrap ~= false -- wrapping by default
  opts.stylize_markdown = opts.stylize_markdown ~= false
  opts.focus = opts.focus ~= false
  opts.close_events = opts.close_events or {"CursorMoved", "CursorMovedI", "InsertCharPre"}

  local bufnr = api.nvim_get_current_buf()

  -- check if this popup is focusable and we need to focus
  if opts.focus_id and opts.focusable ~= false and opts.focus then
    -- Go back to previous window if we are in a focusable one
    local current_winnr = api.nvim_get_current_win()
    if npcall(api.nvim_win_get_var, current_winnr, opts.focus_id) then
      api.nvim_command("wincmd p")
      return bufnr, current_winnr
    end
    do
      local win = find_window_by_var(opts.focus_id, bufnr)
      if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
        -- focus and return the existing buf, win
        api.nvim_set_current_win(win)
        api.nvim_command("stopinsert")
        return api.nvim_win_get_buf(win), win
      end
    end
  end

  -- check if another floating preview already exists for this buffer
  -- and close it if needed
  local existing_float = npcall(api.nvim_buf_get_var, bufnr, "lsp_floating_preview")
  if existing_float and api.nvim_win_is_valid(existing_float) then
    api.nvim_win_close(existing_float, true)
  end

  local floating_bufnr = api.nvim_create_buf(false, true)
  local do_stylize = syntax == "markdown" and opts.stylize_markdown


  -- Clean up input: trim empty lines from the end, pad
  contents = M._trim(contents, opts)

  if do_stylize then
    -- applies the syntax and sets the lines to the buffer
    contents = M.stylize_markdown(floating_bufnr, contents, opts)
  else
    if syntax then
      api.nvim_buf_set_option(floating_bufnr, 'syntax', syntax)
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
    api.nvim_win_set_option(floating_winnr, 'conceallevel', 2)
    api.nvim_win_set_option(floating_winnr, 'concealcursor', 'n')
  end
  -- disable folding
  api.nvim_win_set_option(floating_winnr, 'foldenable', false)
  -- soft wrapping
  api.nvim_win_set_option(floating_winnr, 'wrap', opts.wrap)

  api.nvim_buf_set_option(floating_bufnr, 'modifiable', false)
  api.nvim_buf_set_option(floating_bufnr, 'bufhidden', 'wipe')
  api.nvim_buf_set_keymap(floating_bufnr, "n", "q", "<cmd>bdelete<cr>", {silent = true, noremap = true, nowait = true})
  close_preview_autocmd(opts.close_events, floating_winnr, {floating_bufnr, bufnr})

  -- save focus_id
  if opts.focus_id then
    api.nvim_win_set_var(floating_winnr, opts.focus_id, bufnr)
  end
  api.nvim_buf_set_var(bufnr, "lsp_floating_preview", floating_winnr)

  return floating_bufnr, floating_winnr
end

do --[[ References ]]
  local reference_ns = api.nvim_create_namespace("vim_lsp_references")

  --- Removes document highlights from a buffer.
  ---
  ---@param bufnr number Buffer id
  function M.buf_clear_references(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr or 0, reference_ns, 0, -1)
  end

  --- Shows a list of document highlights for a certain buffer.
  ---
  ---@param bufnr number Buffer id
  ---@param references table List of `DocumentHighlight` objects to highlight
  ---@param offset_encoding string One of "utf-8", "utf-16", "utf-32".
  ---@see https://microsoft.github.io/language-server-protocol/specifications/specification-3-17/#documentHighlight
  function M.buf_highlight_references(bufnr, references, offset_encoding)
    validate {
      bufnr = {bufnr, 'n', true},
      offset_encoding = { offset_encoding, 'string', false };
    }
    for _, reference in ipairs(references) do
      local start_line, start_char = reference["range"]["start"]["line"], reference["range"]["start"]["character"]
      local end_line, end_char = reference["range"]["end"]["line"], reference["range"]["end"]["character"]

      local start_idx = get_line_byte_from_position(bufnr, { line = start_line, character = start_char }, offset_encoding)
      local end_idx = get_line_byte_from_position(bufnr, { line = start_line, character = end_char }, offset_encoding)

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
                      { end_line, end_idx },
                      { priority = vim.highlight.priorities.user })
    end
  end
end

local position_sort = sort_by_key(function(v)
  return {v.start.line, v.start.character}
end)

--- Returns the items with the byte position calculated correctly and in sorted
--- order, for display in quickfix and location lists.
---
--- The result can be passed to the {list} argument of |setqflist()| or
--- |setloclist()|.
---
---@param locations table list of `Location`s or `LocationLink`s
---@param offset_encoding string offset_encoding for locations utf-8|utf-16|utf-32
---@returns (table) list of items
function M.locations_to_items(locations, offset_encoding)
  if offset_encoding == nil then
    vim.notify_once("locations_to_items must be called with valid offset encoding", vim.log.levels.WARN)
  end

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
    local lines = get_lines(vim.uri_to_bufnr(uri), uri_rows)

    for _, temp in ipairs(rows) do
      local pos = temp.start
      local row = pos.line
      local line = lines[row] or ""
      local col = M._str_byteindex_enc(line, pos.character, offset_encoding)
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

--- Fills target window's location list with given list of items.
--- Can be obtained with e.g. |vim.lsp.util.locations_to_items()|.
--- Defaults to current window.
---
---@deprecated Use |setloclist()|
---
---@param items (table) list of items
function M.set_loclist(items, win_id)
  vim.api.nvim_echo({{'vim.lsp.util.set_loclist is deprecated. See :h deprecated', 'WarningMsg'}}, true, {})
  vim.fn.setloclist(win_id or 0, {}, ' ', {
    title = 'Language Server';
    items = items;
  })
end

--- Fills quickfix list with given list of items.
--- Can be obtained with e.g. |vim.lsp.util.locations_to_items()|.
---
---@deprecated Use |setqflist()|
---
---@param items (table) list of items
function M.set_qflist(items)
  vim.api.nvim_echo({{'vim.lsp.util.set_qflist is deprecated. See :h deprecated', 'WarningMsg'}}, true, {})
  vim.fn.setqflist({}, ' ', {
    title = 'Language Server';
    items = items;
  })
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
  return _symbols_to_items(symbols, {}, bufnr or 0)
end

--- Removes empty lines from the beginning and end.
---@param lines (table) list of lines to trim
---@returns (table) trimmed list of lines
function M.trim_empty_lines(lines)
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
  return vim.list_extend({}, lines, start, finish)
end

--- Accepts markdown lines and tries to reduce them to a filetype if they
--- comprise just a single code block.
---
--- CAUTION: Modifies the input in-place!
---
---@param lines (table) list of lines
---@returns (string) filetype or 'markdown' if it was unchanged.
function M.try_trim_markdown_code_blocks(lines)
  local language_id = lines[1]:match("^```(.*)")
  if language_id then
    local has_inner_code_fence = false
    for i = 2, (#lines - 1) do
      local line = lines[i]
      if line:sub(1,3) == '```' then
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

---@private
---@param window (optional, number): window handle or 0 for current, defaults to current
---@param offset_encoding string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of buffer of `window`
local function make_position_param(window, offset_encoding)
  window = window or 0
  local buf = vim.api.nvim_win_get_buf(window)
  local row, col = unpack(api.nvim_win_get_cursor(window))
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  row = row - 1
  local line = api.nvim_buf_get_lines(buf, row, row+1, true)[1]
  if not line then
    return { line = 0; character = 0; }
  end

  col = _str_utfindex_enc(line, col, offset_encoding)

  return { line = row; character = col; }
end

--- Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---
---@param window (optional, number): window handle or 0 for current, defaults to current
---@param offset_encoding string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of buffer of `window`
---@returns `TextDocumentPositionParams` object
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
function M.make_position_params(window, offset_encoding)
  window = window or 0
  local buf = vim.api.nvim_win_get_buf(window)
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  return {
    textDocument = M.make_text_document_params(buf);
    position = make_position_param(window, offset_encoding)
  }
end

--- Utility function for getting the encoding of the first LSP client on the given buffer.
---@param bufnr (number) buffer handle or 0 for current, defaults to current
---@returns (string) encoding first client if there is one, nil otherwise
function M._get_offset_encoding(bufnr)
  validate {
    bufnr = {bufnr, 'n', true};
  }

  local offset_encoding

  for _, client in pairs(vim.lsp.buf_get_clients(bufnr)) do
    if client.offset_encoding == nil then
      vim.notify_once(
        string.format("Client (id: %s) offset_encoding is nil. Do not unset offset_encoding.", client.id),
        vim.log.levels.ERROR
      )
    end
    local this_offset_encoding = client.offset_encoding
    if not offset_encoding then
      offset_encoding = this_offset_encoding
    elseif offset_encoding ~= this_offset_encoding then
      vim.notify("warning: multiple different client offset_encodings detected for buffer, this is not supported yet", vim.log.levels.WARN)
    end
  end

  return offset_encoding
end

--- Using the current position in the current buffer, creates an object that
--- can be used as a building block for several LSP requests, such as
--- `textDocument/codeAction`, `textDocument/colorPresentation`,
--- `textDocument/rangeFormatting`.
---
---@param window (optional, number): window handle or 0 for current, defaults to current
---@param offset_encoding string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of buffer of `window`
---@returns { textDocument = { uri = `current_file_uri` }, range = { start =
---`current_position`, end = `current_position` } }
function M.make_range_params(window, offset_encoding)
  local buf = vim.api.nvim_win_get_buf(window or 0)
  offset_encoding = offset_encoding or M._get_offset_encoding(buf)
  local position = make_position_param(window, offset_encoding)
  return {
    textDocument = M.make_text_document_params(buf),
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
---@param bufnr (optional, number): buffer handle or 0 for current, defaults to current
---@param offset_encoding string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of `bufnr`
---@returns { textDocument = { uri = `current_file_uri` }, range = { start =
---`start_position`, end = `end_position` } }
function M.make_given_range_params(start_pos, end_pos, bufnr, offset_encoding)
  validate {
    start_pos = {start_pos, 't', true};
    end_pos = {end_pos, 't', true};
    offset_encoding = {offset_encoding, 's', true};
  }
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  offset_encoding = offset_encoding or M._get_offset_encoding(bufnr)
  local A = list_extend({}, start_pos or api.nvim_buf_get_mark(bufnr, '<'))
  local B = list_extend({}, end_pos or api.nvim_buf_get_mark(bufnr, '>'))
  -- convert to 0-index
  A[1] = A[1] - 1
  B[1] = B[1] - 1
  -- account for offset_encoding.
  if A[2] > 0 then
    A = {A[1], M.character_offset(bufnr, A[1], A[2], offset_encoding)}
  end
  if B[2] > 0 then
    B = {B[1], M.character_offset(bufnr, B[1], B[2], offset_encoding)}
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
      start = {line = A[1], character = A[2]},
      ['end'] = {line = B[1], character = B[2]}
    }
  }
end

--- Creates a `TextDocumentIdentifier` object for the current buffer.
---
---@param bufnr (optional, number): Buffer handle, defaults to current
---@returns `TextDocumentIdentifier`
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentIdentifier
function M.make_text_document_params(bufnr)
  return { uri = vim.uri_from_bufnr(bufnr or 0) }
end

--- Create the workspace params
---@param added
---@param removed
function M.make_workspace_params(added, removed)
  return { event = { added = added; removed = removed; } }
end
--- Returns indentation size.
---
---@see |shiftwidth|
---@param bufnr (optional, number): Buffer handle, defaults to current
---@returns (number) indentation size
function M.get_effective_tabstop(bufnr)
  validate { bufnr = {bufnr, 'n', true} }
  local bo = bufnr and vim.bo[bufnr] or vim.bo
  local sw = bo.shiftwidth
  return (sw == 0 and bo.tabstop) or sw
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
---@param offset_encoding string utf-8|utf-16|utf-32|nil defaults to `offset_encoding` of first client of `buf`
---@returns (number, number) `offset_encoding` index of the character in line {row} column {col} in buffer {buf}
function M.character_offset(buf, row, col, offset_encoding)
  local line = get_line(buf, row)
  if offset_encoding == nil then
    vim.notify_once("character_offset must be called with valid offset encoding", vim.log.levels.WARN)
  end
  -- If the col is past the EOL, use the line length.
  if col > #line then
    return _str_utfindex_enc(line, nil, offset_encoding)
  end
  return _str_utfindex_enc(line, col, offset_encoding)
end

--- Helper function to return nested values in language server settings
---
---@param settings a table of language server settings
---@param section  a string indicating the field of the settings table
---@returns (table or string) The value of settings accessed via section
function M.lookup_section(settings, section)
  for part in vim.gsplit(section, '.', true) do
    settings = settings[part]
    if settings == nil then
      return vim.NIL
    end
  end
  return settings
end

M._get_line_byte_from_position = get_line_byte_from_position

M.buf_versions = {}

return M
-- vim:sw=2 ts=2 et
