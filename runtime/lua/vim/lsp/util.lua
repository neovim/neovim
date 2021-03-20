local protocol = require 'vim.lsp.protocol'
local vim = vim
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend
local highlight = require 'vim.highlight'

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

--@private
local function split_lines(value)
  return split(value, '\n', true)
end

--- Replaces text in a range with new text.
---
--- CAUTION: Changes in-place!
---
--@param lines (table) Original list of strings
--@param A (table) Start position; a 2-tuple of {line, col} numbers
--@param B (table) End position; a 2-tuple of {line, col} numbers
--@param new_lines A list of strings to replace the original
--@returns (table) The modified {lines} object
function M.set_lines(lines, A, B, new_lines)
  -- 0-indexing to 1-indexing
  local i_0 = A[1] + 1
  -- If it extends past the end, truncate it to the end. This is because the
  -- way the LSP describes the range including the last newline is by
  -- specifying a line number after what we would call the last line.
  local i_n = math.min(B[1] + 1, #lines)
  if not (i_0 >= 1 and i_0 <= #lines and i_n >= 1 and i_n <= #lines) then
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

--@private
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
--@private
local edit_sort_key = sort_by_key(function(e)
  return {e.A[1], e.A[2], e.i}
end)

--@private
--- Position is a https://microsoft.github.io/language-server-protocol/specifications/specification-current/#position
--- Returns a zero-indexed column, since set_lines() does the conversion to
--- 1-indexed
local function get_line_byte_from_position(bufnr, position)
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
      local ok, result = pcall(vim.str_byteindex, lines[1], col)

      if ok then
        return result
      end
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

    for _, item in ipairs(progress_remove) do
      client.messages.progress[item.token] = nil
    end
  end

  return new_messages
end

--- Applies a list of text edits to a buffer.
--@param text_edits (table) list of `TextEdit` objects
--@param buf_nr (number) Buffer id
function M.apply_text_edits(text_edits, bufnr)
  if not next(text_edits) then return end
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  api.nvim_buf_set_option(bufnr, 'buflisted', true)
  local start_line, finish_line = math.huge, -1
  local cleaned = {}
  for i, e in ipairs(text_edits) do
    -- adjust start and end column for UTF-16 encoding of non-ASCII characters
    local start_row = e.range.start.line
    local start_col = get_line_byte_from_position(bufnr, e.range.start)
    local end_row = e.range["end"].line
    local end_col = get_line_byte_from_position(bufnr, e.range['end'])
    start_line = math.min(e.range.start.line, start_line)
    finish_line = math.max(e.range["end"].line, finish_line)
    -- TODO(ashkan) sanity check ranges for overlap.
    table.insert(cleaned, {
      i = i;
      A = {start_row; start_col};
      B = {end_row; end_col};
      lines = vim.split(e.newText, '\n', true);
    })
  end

  -- Reverse sort the orders so we can apply them without interfering with
  -- eachother. Also add i as a sort key to mimic a stable sort.
  table.sort(cleaned, edit_sort_key)
  local lines = api.nvim_buf_get_lines(bufnr, start_line, finish_line + 1, false)
  local fix_eol = api.nvim_buf_get_option(bufnr, 'fixeol')
  local set_eol = fix_eol and api.nvim_buf_line_count(bufnr) <= finish_line + 1
  if set_eol and (#lines == 0 or #lines[#lines] ~= 0) then
    table.insert(lines, '')
  end

  for i = #cleaned, 1, -1 do
    local e = cleaned[i]
    local A = {e.A[1] - start_line, e.A[2]}
    local B = {e.B[1] - start_line, e.B[2]}
    lines = M.set_lines(lines, A, B, e.lines)
  end
  if set_eol and #lines[#lines] == 0 then
    table.remove(lines)
  end
  api.nvim_buf_set_lines(bufnr, start_line, finish_line + 1, false, lines)
end

-- local valid_windows_path_characters = "[^<>:\"/\\|?*]"
-- local valid_unix_path_characters = "[^/]"
-- https://github.com/davidm/lua-glob-pattern
-- https://stackoverflow.com/questions/1976007/what-characters-are-forbidden-in-windows-and-linux-directory-names
-- function M.glob_to_regex(glob)
-- end

--@private
--- Finds the first line and column of the difference between old and new lines
--@param old_lines table list of lines
--@param new_lines table list of lines
--@returns (int, int) start_line_idx and start_col_idx of range
local function first_difference(old_lines, new_lines, start_line_idx)
  local line_count = math.min(#old_lines, #new_lines)
  if line_count == 0 then return 1, 1 end
  if not start_line_idx then
    for i = 1, line_count do
      start_line_idx = i
      if old_lines[start_line_idx] ~= new_lines[start_line_idx] then
        break
      end
    end
  end
  local old_line = old_lines[start_line_idx]
  local new_line = new_lines[start_line_idx]
  local length = math.min(#old_line, #new_line)
  local start_col_idx = 1
  while start_col_idx <= length do
    if string.sub(old_line, start_col_idx, start_col_idx) ~= string.sub(new_line, start_col_idx, start_col_idx) then
      break
    end
    start_col_idx  = start_col_idx  + 1
  end
  return start_line_idx, start_col_idx
end


--@private
--- Finds the last line and column of the differences between old and new lines
--@param old_lines table list of lines
--@param new_lines table list of lines
--@param start_char integer First different character idx of range
--@returns (int, int) end_line_idx and end_col_idx of range
local function last_difference(old_lines, new_lines, start_char, end_line_idx)
  local line_count = math.min(#old_lines, #new_lines)
  if line_count == 0 then return 0,0 end
  if not end_line_idx then
    end_line_idx = -1
  end
  for i = end_line_idx, -line_count, -1  do
    if old_lines[#old_lines + i + 1] ~= new_lines[#new_lines + i + 1] then
      end_line_idx = i
      break
    end
  end
  local old_line
  local new_line
  if end_line_idx <= -line_count then
    end_line_idx = -line_count
    old_line  = string.sub(old_lines[#old_lines + end_line_idx + 1], start_char)
    new_line  = string.sub(new_lines[#new_lines + end_line_idx + 1], start_char)
  else
    old_line  = old_lines[#old_lines + end_line_idx + 1]
    new_line  = new_lines[#new_lines + end_line_idx + 1]
  end
  local old_line_length = #old_line
  local new_line_length = #new_line
  local length = math.min(old_line_length, new_line_length)
  local end_col_idx = -1
  while end_col_idx >= -length do
    local old_char =  string.sub(old_line, old_line_length + end_col_idx + 1, old_line_length + end_col_idx + 1)
    local new_char =  string.sub(new_line, new_line_length + end_col_idx + 1, new_line_length + end_col_idx + 1)
    if old_char ~= new_char then
      break
    end
    end_col_idx = end_col_idx - 1
  end
  return end_line_idx, end_col_idx

end

--@private
--- Get the text of the range defined by start and end line/column
--@param lines table list of lines
--@param start_char integer First different character idx of range
--@param end_char integer Last different character idx of range
--@param start_line integer First different line idx of range
--@param end_line integer Last different line idx of range
--@returns string text extracted from defined region
local function extract_text(lines, start_line, start_char, end_line, end_char)
  if start_line == #lines + end_line + 1 then
    if end_line == 0 then return '' end
    local line = lines[start_line]
    local length = #line + end_char - start_char
    return string.sub(line, start_char, start_char + length + 1)
  end
  local result = string.sub(lines[start_line], start_char) .. '\n'
  for line_idx = start_line + 1, #lines + end_line do
    result = result .. lines[line_idx] .. '\n'
  end
  if end_line ~= 0 then
    local line = lines[#lines + end_line + 1]
    local length = #line + end_char + 1
    result = result .. string.sub(line, 1, length)
  end
  return result
end

--@private
--- Compute the length of the substituted range
--@param lines table list of lines
--@param start_char integer First different character idx of range
--@param end_char integer Last different character idx of range
--@param start_line integer First different line idx of range
--@param end_line integer Last different line idx of range
--@returns (int, int) end_line_idx and end_col_idx of range
local function compute_length(lines, start_line, start_char, end_line, end_char)
  local adj_end_line = #lines + end_line + 1
  local adj_end_char
  if adj_end_line > #lines then
    adj_end_char =  end_char - 1
  else
    adj_end_char = #lines[adj_end_line] + end_char
  end
  if start_line == adj_end_line then
    return adj_end_char - start_char + 1
  end
  local result = #lines[start_line] - start_char + 1
  for line = start_line + 1, adj_end_line -1 do
    result = result + #lines[line] + 1
  end
  result = result + adj_end_char + 1
  return result
end

--- Returns the range table for the difference between old and new lines
--@param old_lines table list of lines
--@param new_lines table list of lines
--@returns table start_line_idx and start_col_idx of range
function M.compute_diff(old_lines, new_lines, start_line_idx, end_line_idx)
  local start_line, start_char = first_difference(old_lines, new_lines, start_line_idx)
  local end_line, end_char = last_difference(vim.list_slice(old_lines, start_line, #old_lines),
      vim.list_slice(new_lines, start_line, #new_lines), start_char, end_line_idx)
  local text = extract_text(new_lines, start_line, start_char, end_line, end_char)
  local length = compute_length(old_lines, start_line, start_char, end_line, end_char)

  local adj_end_line = #old_lines + end_line
  local adj_end_char
  if end_line == 0 then
    adj_end_char = 0
  else
    adj_end_char = #old_lines[#old_lines + end_line + 1] + end_char + 1
  end

  local result = {
    range = {
      start = { line = start_line - 1, character = start_char - 1},
      ["end"] = { line = adj_end_line, character = adj_end_char}
    },
    text = text,
    rangeLength = length + 1,
  }

  return result
end

--- Can be used to extract the completion items from a
--- `textDocument/completion` request, which may return one of
--- `CompletionItem[]`, `CompletionList` or null.
--@param result (table) The result of a `textDocument/completion` request
--@returns (table) List of completion items
--@see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
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
      and M.buf_versions[bufnr]
      and M.buf_versions[bufnr] > text_document.version) then
    print("Buffer ", text_document.uri, " newer than edits.")
    return
  end

  M.apply_text_edits(text_document_edit.edits, bufnr)
end

--@private
--- Recursively parses snippets in a completion entry.
---
--@param input (string) Snippet text to parse for snippets
--@param inner (bool) Whether this function is being called recursively
--@returns 2-tuple of strings: The first is the parsed result, the second is the
---unparsed rest of the input
local function parse_snippet_rec(input, inner)
  local res = ""

  local close, closeend = nil, nil
  if inner then
    close, closeend = input:find("}", 1, true)
    while close ~= nil and input:sub(close-1,close-1) == "\\" do
      close, closeend = input:find("}", closeend+1, true)
    end
  end

  local didx = input:find('$',  1, true)
  if didx == nil and close == nil then
    return input, ""
  elseif close ~=nil and (didx == nil or close < didx) then
    -- No inner placeholders
    return input:sub(0, close-1), input:sub(closeend+1)
  end

  res = res .. input:sub(0, didx-1)
  input = input:sub(didx+1)

  local tabstop, tabstopend = input:find('^%d+')
  local placeholder, placeholderend = input:find('^{%d+:')
  local choice, choiceend = input:find('^{%d+|')

  if tabstop then
    input = input:sub(tabstopend+1)
  elseif choice then
    input = input:sub(choiceend+1)
    close, closeend = input:find("|}", 1, true)

    res = res .. input:sub(0, close-1)
    input = input:sub(closeend+1)
  elseif placeholder then
    -- TODO: add support for variables
    input = input:sub(placeholderend+1)

    -- placeholders and variables are recursive
    while input ~= "" do
      local r, tail = parse_snippet_rec(input, true)
      r = r:gsub("\\}", "}")

      res = res .. r
      input = tail
    end
  else
    res = res .. "$"
  end

  return res, input
end

--- Parses snippets in a completion entry.
---
--@param input (string) unparsed snippet
--@returns (string) parsed snippet
function M.parse_snippet(input)
  local res, _ = parse_snippet_rec(input, false)

  return res
end

--@private
--- Sorts by CompletionItem.sortText.
---
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function sort_completion_items(items)
  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)
end

--@private
--- Returns text that should be inserted when selecting completion item. The
--- precedence is as follows: textEdit.newText > insertText > label
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    if protocol.InsertTextFormat[item.insertTextFormat] == "PlainText" then
      return item.textEdit.newText
    else
      return M.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    if protocol.InsertTextFormat[item.insertTextFormat] == "PlainText" then
      return item.insertText
    else
      return M.parse_snippet(item.insertText)
    end
  end
  return item.label
end

--@private
--- Some language servers return complementary candidates whose prefixes do not
--- match are also returned. So we exclude completion candidates whose prefix
--- does not match.
local function remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = get_completion_word(item)
    return vim.startswith(word, prefix)
  end, items)
end

--- Acording to LSP spec, if the client set `completionItemKind.valueSet`,
--- the client must handle it properly even if it receives a value outside the
--- specification.
---
--@param completion_item_kind (`vim.lsp.protocol.completionItemKind`)
--@returns (`vim.lsp.protocol.completionItemKind`)
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
function M._get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or "Unknown"
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
--@param result The result of a `textDocument/completion` call, e.g. from
---|vim.lsp.buf.completion()|, which may be one of `CompletionItem[]`,
--- `CompletionList` or `null`
--@param prefix (string) the prefix to filter the completion items
--@returns { matches = complete-items table, incomplete = bool }
--@see |complete-items|
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
--
--@param opts (table)
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
--@param workspace_edit (table) `WorkspaceEdit`
-- @see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#workspace_applyEdit
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

--- Converts any of `MarkedString` | `MarkedString[]` | `MarkupContent` into
--- a list of lines containing valid markdown. Useful to populate the hover
--- window for `textDocument/hover`, for parsing the result of
--- `textDocument/signatureHelp`, and potentially others.
---
--@param input (`MarkedString` | `MarkedString[]` | `MarkupContent`)
--@param contents (table, optional, default `{}`) List of strings to extend with converted lines
--@returns {contents}, extended with lines of converted markdown.
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_hover
function M.convert_input_to_markdown_lines(input, contents)
  contents = contents or {}
  -- MarkedString variation 1
  if type(input) == 'string' then
    list_extend(contents, split_lines(input))
  else
    assert(type(input) == 'table', "Expected a table for Hover.contents")
    -- MarkupContent
    if input.kind then
      -- The kind can be either plaintext or markdown. However, either way we
      -- will just be rendering markdown, so we handle them both the same way.
      -- TODO these can have escaped/sanitized html codes in markdown. We
      -- should make sure we handle this correctly.

      -- Some servers send input.value as empty, so let's ignore this :(
      -- assert(type(input.value) == 'string')
      list_extend(contents, split_lines(input.value or ''))
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
--@param signature_help Response of `textDocument/SignatureHelp`
--@returns list of lines of converted markdown.
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_signatureHelp
function M.convert_signature_help_to_markdown_lines(signature_help)
  if not signature_help.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_signature = signature_help.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  if active_signature >= #signature_help.signatures then
    active_signature = 0
  end
  local signature = signature_help.signatures[active_signature + 1]
  if not signature then
    return
  end
  vim.list_extend(contents, vim.split(signature.label, '\n', true))
  if signature.documentation then
    M.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if signature.parameters and #signature.parameters > 0 then
    local active_parameter = signature_help.activeParameter or 0
    -- If the activeParameter is not inside the valid range, then clip it.
    if active_parameter >= #signature.parameters then
      active_parameter = 0
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
      -- TODO highlight parameter
      if parameter.documentation then
        M.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end
  return contents
end

--- Creates a table with sensible default options for a floating window. The
--- table can be passed to |nvim_open_win()|.
---
--@param width (number) window width (in character cells)
--@param height (number) window height (in character cells)
--@param opts (table, optional)
--@returns (table) Options
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

  if vim.fn.wincol() + width <= api.nvim_get_option('columns') then
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
    relative = 'cursor',
    row = row + (opts.offset_y or 0),
    style = 'minimal',
    width = width,
  }
end

--- Jumps to a location.
---
--@param location (`Location`|`LocationLink`)
--@returns `true` if the jump succeeded
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
--@param location a single `Location` or `LocationLink`
--@returns (bufnr,winnr) buffer and window number of floating window or nil
function M.preview_location(location)
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
  return M.open_floating_preview(contents, syntax)
end

--@private
local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

--- Enters/leaves the focusable window associated with the current buffer via the
--window - variable `unique_name`. If no such window exists, run the function
--{fn}.
---
--@param unique_name (string) Window variable
--@param fn (function) should return create a new window and return a tuple of
---({focusable_buffer_id}, {window_id}). if {focusable_buffer_id} is a valid
---buffer id, the newly created window will be the new focus associated with
---the current buffer via the tag `unique_name`.
--@returns (pbufnr, pwinnr) if `fn()` has created a new window; nil otherwise
function M.focusable_float(unique_name, fn)
  -- Go back to previous window if we are in a focusable one
  if npcall(api.nvim_win_get_var, 0, unique_name) then
    return api.nvim_command("wincmd p")
  end
  local bufnr = api.nvim_get_current_buf()
  do
    local win = find_window_by_var(unique_name, bufnr)
    if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
      api.nvim_set_current_win(win)
      api.nvim_command("stopinsert")
      return
    end
  end
  local pbufnr, pwinnr = fn()
  if pbufnr then
    api.nvim_win_set_var(pwinnr, unique_name, bufnr)
    return pbufnr, pwinnr
  end
end

--- Focuses/unfocuses the floating preview window associated with the current
--- buffer via the window variable `unique_name`. If no such preview window
--- exists, makes a new one.
---
--@param unique_name (string) Window variable
--@param fn (function) The return values of this function will be passed
---directly to |vim.lsp.util.open_floating_preview()|, in the case that a new
---floating window should be created
function M.focusable_preview(unique_name, fn)
  return M.focusable_float(unique_name, function()
    return M.open_floating_preview(fn())
  end)
end

--- Trims empty lines from input and pad left and right with spaces
---
---@param contents table of lines to trim and pad
---@param opts dictionary with optional fields
---             - pad_left   number of columns to pad contents at left (default 1)
---             - pad_right  number of columns to pad contents at right (default 1)
---             - pad_top    number of lines to pad contents at top (default 0)
---             - pad_bottom number of lines to pad contents at bottom (default 0)
---@return contents table of trimmed and padded lines
function M._trim_and_pad(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}
  local left_padding = (" "):rep(opts.pad_left or 1)
  local right_padding = (" "):rep(opts.pad_right or 1)
  contents = M.trim_empty_lines(contents)
  for i, line in ipairs(contents) do
    contents[i] = string.format('%s%s%s', left_padding, line:gsub("\r", ""), right_padding)
  end
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



-- TODO: refactor to separate stripping/converting and make use of open_floating_preview
--
--- Converts markdown into syntax highlighted regions by stripping the code
--- blocks and converting them into highlighted code.
--- This will by default insert a blank line separator after those code block
--- regions to improve readability.
--- The result is shown in a floating preview.
---
---@param contents table of lines to show in window
---@param opts dictionary with optional fields
---  - height    of floating window
---  - width     of floating window
---  - wrap_at   character to wrap at for computing height
---  - max_width  maximal width of floating window
---  - max_height maximal height of floating window
---  - pad_left   number of columns to pad contents at left
---  - pad_right  number of columns to pad contents at right
---  - pad_top    number of lines to pad contents at top
---  - pad_bottom number of lines to pad contents at bottom
---  - separator insert separator after code block
---@returns width,height size of float
function M.fancy_floating_markdown(contents, opts)
  validate {
    contents = { contents, 't' };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  local stripped = {}
  local highlights = {}
  do
    local i = 1
    while i <= #contents do
      local line = contents[i]
      -- TODO(ashkan): use a more strict regex for filetype?
      local ft = line:match("^```([a-zA-Z0-9_]*)$")
      -- local ft = line:match("^```(.*)$")
      -- TODO(ashkan): validate the filetype here.
      if ft then
        local start = #stripped
        i = i + 1
        while i <= #contents do
          line = contents[i]
          if line == "```" then
            i = i + 1
            break
          end
          table.insert(stripped, line)
          i = i + 1
        end
        table.insert(highlights, {
          ft = ft;
          start = start + 1;
          finish = #stripped + 1 - 1;
        })
      else
        table.insert(stripped, line)
        i = i + 1
      end
    end
  end
  -- Clean up and add padding
  stripped = M._trim_and_pad(stripped, opts)

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
  local width, height = M._make_floating_popup_size(stripped, opts)

  -- Insert blank line separator after code block
  local insert_separator = opts.separator
  if insert_separator == nil then insert_separator = true end
  if insert_separator then
    for i, h in ipairs(highlights) do
      h.start = h.start + i - 1
      h.finish = h.finish + i - 1
      if h.finish + 1 <= #stripped then
        table.insert(stripped, h.finish + 1, string.rep("─", math.min(width, opts.wrap_at or width)))
        height = height + 1
      end
    end
  end

  -- Make the floating window.
  local bufnr = api.nvim_create_buf(false, true)
  local winnr = api.nvim_open_win(bufnr, false, M.make_floating_popup_options(width, height, opts))
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)
  api.nvim_buf_set_option(bufnr, 'modifiable', false)

  -- Switch to the floating window to apply the syntax highlighting.
  -- This is because the syntax command doesn't accept a target.
  local cwin = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(winnr)
  api.nvim_win_set_option(winnr, 'conceallevel', 2)
  api.nvim_win_set_option(winnr, 'concealcursor', 'n')

  vim.cmd("ownsyntax lsp_markdown")
  local idx = 1
  --@private
  local function apply_syntax_to_region(ft, start, finish)
    if ft == '' then return end
    local name = ft..idx
    idx = idx + 1
    local lang = "@"..ft:upper()
    -- TODO(ashkan): better validation before this.
    if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
      return
    end
    vim.cmd(string.format("syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s", name, start, finish + 1, lang))
  end
  -- Previous highlight region.
  -- TODO(ashkan): this wasn't working for some reason, but I would like to
  -- make sure that regions between code blocks are definitely markdown.
  -- local ph = {start = 0; finish = 1;}
  for _, h in ipairs(highlights) do
    -- apply_syntax_to_region('markdown', ph.finish, h.start)
    apply_syntax_to_region(h.ft, h.start, h.finish)
    -- ph = h
  end

  vim.api.nvim_set_current_win(cwin)
  return bufnr, winnr
end

--- Creates autocommands to close a preview window when events happen.
---
--@param events (table) list of events
--@param winnr (number) window id of preview window
--@see |autocmd-events|
function M.close_preview_autocmd(events, winnr)
  api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
end

--@internal
--- Computes size of float needed to show contents (with optional wrapping)
---
--@param contents table of lines to show in window
--@param opts dictionary with optional fields
--             - height  of floating window
--             - width   of floating window
--             - wrap_at character to wrap at for computing height
--             - max_width  maximal width of floating window
--             - max_height maximal height of floating window
--@returns width,height size of float
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
--@param contents table of lines to show in window
--@param syntax string of syntax to set for opened buffer
--@param opts dictionary with optional fields
--             - height    of floating window
--             - width     of floating window
--             - wrap_at   character to wrap at for computing height
--             - max_width  maximal width of floating window
--             - max_height maximal height of floating window
--             - pad_left   number of columns to pad contents at left
--             - pad_right  number of columns to pad contents at right
--             - pad_top    number of lines to pad contents at top
--             - pad_bottom number of lines to pad contents at bottom
--@returns bufnr,winnr buffer and window number of the newly created floating
---preview window
function M.open_floating_preview(contents, syntax, opts)
  validate {
    contents = { contents, 't' };
    syntax = { syntax, 's', true };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  -- Clean up input: trim empty lines from the end, pad
  contents = M._trim_and_pad(contents, opts)

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
  local width, height = M._make_floating_popup_size(contents, opts)

  local floating_bufnr = api.nvim_create_buf(false, true)
  if syntax then
    api.nvim_buf_set_option(floating_bufnr, 'syntax', syntax)
  end
  local float_option = M.make_floating_popup_options(width, height, opts)
  local floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)
  if syntax == 'markdown' then
    api.nvim_win_set_option(floating_winnr, 'conceallevel', 2)
  end
  api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
  api.nvim_buf_set_option(floating_bufnr, 'modifiable', false)
  api.nvim_buf_set_option(floating_bufnr, 'bufhidden', 'wipe')
  M.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, floating_winnr)
  return floating_bufnr, floating_winnr
end

do --[[ References ]]
  local reference_ns = api.nvim_create_namespace("vim_lsp_references")

  --- Removes document highlights from a buffer.
  ---
  --@param bufnr buffer id
  function M.buf_clear_references(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr, reference_ns, 0, -1)
  end

  --- Shows a list of document highlights for a certain buffer.
  ---
  --@param bufnr buffer id
  --@param references List of `DocumentHighlight` objects to highlight
  function M.buf_highlight_references(bufnr, references)
    validate { bufnr = {bufnr, 'n', true} }
    for _, reference in ipairs(references) do
      local start_pos = {reference["range"]["start"]["line"], reference["range"]["start"]["character"]}
      local end_pos = {reference["range"]["end"]["line"], reference["range"]["end"]["character"]}
      local document_highlight_kind = {
        [protocol.DocumentHighlightKind.Text] = "LspReferenceText";
        [protocol.DocumentHighlightKind.Read] = "LspReferenceRead";
        [protocol.DocumentHighlightKind.Write] = "LspReferenceWrite";
      }
      local kind = reference["kind"] or protocol.DocumentHighlightKind.Text
      highlight.range(bufnr, reference_ns, document_highlight_kind[kind], start_pos, end_pos)
    end
  end
end

local position_sort = sort_by_key(function(v)
  return {v.start.line, v.start.character}
end)

--- Returns the items with the byte position calculated correctly and in sorted
--- order, for display in quickfix and location lists.
---
--@param locations (table) list of `Location`s or `LocationLink`s
--@returns (table) list of items
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
    local bufnr = vim.uri_to_bufnr(uri)
    vim.fn.bufload(bufnr)
    local filename = vim.uri_to_fname(uri)
    for _, temp in ipairs(rows) do
      local pos = temp.start
      local row = pos.line
      local line = (api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
      local col = M.character_offset(bufnr, row, pos.character)
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

--- Fills current window's location list with given list of items.
--- Can be obtained with e.g. |vim.lsp.util.locations_to_items()|.
---
--@param items (table) list of items
function M.set_loclist(items)
  vim.fn.setloclist(0, {}, ' ', {
    title = 'Language Server';
    items = items;
  })
end

--- Fills quickfix list with given list of items.
--- Can be obtained with e.g. |vim.lsp.util.locations_to_items()|.
---
--@param items (table) list of items
function M.set_qflist(items)
  vim.fn.setqflist({}, ' ', {
    title = 'Language Server';
    items = items;
  })
end

-- Acording to LSP spec, if the client set "symbolKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
function M._get_symbol_kind_name(symbol_kind)
  return protocol.SymbolKind[symbol_kind] or "Unknown"
end

--- Converts symbols to quickfix list items.
---
--@param symbols DocumentSymbol[] or SymbolInformation[]
function M.symbols_to_items(symbols, bufnr)
  --@private
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
      elseif symbol.range then -- DocumentSymbole type
        local kind = M._get_symbol_kind_name(symbol.kind)
        table.insert(_items, {
          -- bufnr = _bufnr,
          filename = vim.api.nvim_buf_get_name(_bufnr),
          lnum = symbol.range.start.line + 1,
          col = symbol.range.start.character + 1,
          kind = kind,
          text = '['..kind..'] '..symbol.name
        })
        if symbol.children then
          for _, v in ipairs(_symbols_to_items(symbol.children, _items, _bufnr)) do
            vim.list_extend(_items, v)
          end
        end
      end
    end
    return _items
  end
  return _symbols_to_items(symbols, {}, bufnr)
end

--- Removes empty lines from the beginning and end.
--@param lines (table) list of lines to trim
--@returns (table) trimmed list of lines
function M.trim_empty_lines(lines)
  local start = 1
  for i = 1, #lines do
    if #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if #lines[i] > 0 then
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
--@param lines (table) list of lines
--@returns (string) filetype or 'markdown' if it was unchanged.
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

local str_utfindex = vim.str_utfindex
--@private
local function make_position_param()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  if not line then
    return { line = 0; character = 0; }
  end
  col = str_utfindex(line, col)
  return { line = row; character = col; }
end

--- Creates a `TextDocumentPositionParams` object for the current buffer and cursor position.
---
--@returns `TextDocumentPositionParams` object
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
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
--@returns { textDocument = { uri = `current_file_uri` }, range = { start =
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
--@param start_pos ({number, number}, optional) mark-indexed position.
---Defaults to the start of the last visual selection.
--@param end_pos ({number, number}, optional) mark-indexed position.
---Defaults to the end of the last visual selection.
--@returns { textDocument = { uri = `current_file_uri` }, range = { start =
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
  if A[2] > 0 then
    A = {A[1], M.character_offset(0, A[1], A[2])}
  end
  if B[2] > 0 then
    B = {B[1], M.character_offset(0, B[1], B[2])}
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
--@returns `TextDocumentIdentifier`
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentIdentifier
function M.make_text_document_params()
  return { uri = vim.uri_from_bufnr(0) }
end

--- Create the workspace params
--@param added
--@param removed
function M.make_workspace_params(added, removed)
  return { event = { added = added; removed = removed; } }
end
--- Returns visual width of tabstop.
---
--@see |softtabstop|
--@param bufnr (optional, number): Buffer handle, defaults to current
--@returns (number) tabstop visual width
function M.get_effective_tabstop(bufnr)
  validate { bufnr = {bufnr, 'n', true} }
  local bo = bufnr and vim.bo[bufnr] or vim.bo
  local sts = bo.softtabstop
  return (sts > 0 and sts) or (sts < 0 and bo.shiftwidth) or bo.tabstop
end

--- Creates a `FormattingOptions` object for the current buffer and cursor position.
---
--@param options Table with valid `FormattingOptions` entries
--@returns `FormattingOptions object
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_formatting
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
--@param buf buffer id (0 for current)
--@param row 0-indexed line
--@param col 0-indexed byte offset in line
--@returns (number, number) UTF-32 and UTF-16 index of the character in line {row} column {col} in buffer {buf}
function M.character_offset(buf, row, col)
  local line = api.nvim_buf_get_lines(buf, row, row+1, true)[1]
  -- If the col is past the EOL, use the line length.
  if col > #line then
    return str_utfindex(line)
  end
  return str_utfindex(line, col)
end

--- Helper function to return nested values in language server settings
---
--@param settings a table of language server settings
--@param section  a string indicating the field of the settings table
--@returns (table or string) The value of settings accessed via section
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
