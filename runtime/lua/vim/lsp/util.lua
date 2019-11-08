local protocol = require 'vim.lsp.protocol'

local M = {}

local split = vim.split
local function split_lines(value)
  return split(value, '\n', true)
end

local list_extend = vim.list_extend

--- Find the longest shared prefix between prefix and word.
-- e.g. remove_prefix("123tes", "testing") == "ting"
local function remove_prefix(prefix, word)
  local max_prefix_length = math.min(#prefix, #word)
  local prefix_length = 0
  for i = 1, max_prefix_length do
    local current_line_suffix = prefix:sub(-i)
    local word_prefix = word:sub(1, i)
    if current_line_suffix == word_prefix then
      prefix_length = i
    end
  end
  return word:sub(prefix_length + 1)
end

local function resolve_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

-- local valid_windows_path_characters = "[^<>:\"/\\|?*]"
-- local valid_unix_path_characters = "[^/]"
-- https://github.com/davidm/lua-glob-pattern
-- https://stackoverflow.com/questions/1976007/what-characters-are-forbidden-in-windows-and-linux-directory-names
-- function M.glob_to_regex(glob)
-- end

--- Apply the TextEdit response.
-- @params TextEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.text_document_apply_text_edit(text_edit, bufnr)
  bufnr = resolve_bufnr(bufnr)
  local range = text_edit.range
  local start = range.start
  local finish = range['end']
  local new_lines = split_lines(text_edit.newText)
  if start.character == 0 and finish.character == 0 then
    vim.api.nvim_buf_set_lines(bufnr, start.line, finish.line, false, new_lines)
    return
  end
  vim.api.nvim_err_writeln('apply_text_edit currently only supports character ranges starting at 0')
  error('apply_text_edit currently only supports character ranges starting at 0')
  return
  --  TODO test and finish this support for character ranges.
--  local lines = vim.api.nvim_buf_get_lines(0, start.line, finish.line + 1, false)
--  local suffix = lines[#lines]:sub(finish.character+2)
--  local prefix = lines[1]:sub(start.character+2)
--  new_lines[#new_lines] = new_lines[#new_lines]..suffix
--  new_lines[1] = prefix..new_lines[1]
--  vim.api.nvim_buf_set_lines(0, start.line, finish.line, false, new_lines)
end

-- textDocument/completion response returns one of CompletionItem[], CompletionList or null.
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
function M.extract_completion_items(result)
  if type(result) == 'table' and result.items then
    return result.items
  elseif result ~= nil then
    return result
  else
    return {}
  end
end

--- Apply the TextDocumentEdit response.
-- @params TextDocumentEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.text_document_apply_text_document_edit(text_document_edit, bufnr)
  -- local text_document = text_document_edit.textDocument
  -- TODO use text_document_version?
  -- local text_document_version = text_document.version

  -- TODO technically, you could do this without doing multiple buf_get/set
  -- by getting the full region (smallest line and largest line) and doing
  -- the edits on the buffer, and then applying the buffer at the end.
  -- I'm not sure if that's better.
  for _, text_edit in ipairs(text_document_edit.edits) do
    M.text_document_apply_text_edit(text_edit, bufnr)
  end
end

function M.get_current_line_to_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = assert(vim.api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
  return line:sub(pos[2]+1)
end

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
function M.text_document_completion_list_to_complete_items(result, line_prefix)
  local items = M.extract_completion_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end
  -- Only initialize if we have some items.
  if not line_prefix then
    line_prefix = M.get_current_line_to_cursor()
  end

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

    local word = completion_item.insertText or completion_item.label

    -- Ref: `:h complete-items`
    table.insert(matches, {
      word = remove_prefix(line_prefix, word),
      abbr = completion_item.label,
      kind = protocol.CompletionItemKind[completion_item.kind] or '',
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 0,
      empty = 1,
    })
  end

  return matches
end

-- @params WorkspaceEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.workspace_apply_workspace_edit(workspace_edit)
  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      if change.kind then
        -- TODO(ashkan) handle CreateFile/RenameFile/DeleteFile
        error(string.format("Unsupported change: %q", vim.inspect(change)))
      else
        M.text_document_apply_text_document_edit(change)
      end
    end
    return
  end

  if workspace_edit.changes == nil or #workspace_edit.changes == 0 then
    return
  end

  for uri, changes in pairs(workspace_edit.changes) do
    local fname = vim.uri_to_fname(uri)
    -- TODO improve this approach. Try to edit open buffers without switching.
    -- Not sure how to handle files which aren't open. This is deprecated
    -- anyway, so I guess it could be left as is.
    vim.api.nvim_command('edit '..fname)
    for _, change in ipairs(changes) do
      M.text_document_apply_text_edit(change)
    end
  end
end

--- Convert any of MarkedString | MarkedString[] | MarkupContent into markdown text lines
-- see https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_hover
-- Useful for textDocument/hover, textDocument/signatureHelp, and potentially others.
function M.convert_input_to_markdown_lines(input, contents)
  contents = contents or {}
  -- MarkedString variation 1
  if type(input) == 'string' then
    list_extend(contents, split_lines(input))
  else
    assert(type(input) == 'table', "Expected a table for Hover.contents. Please file an issue on neovim/neovim")
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
  if contents[1] == '' or contents[1] == nil then
    return {}
  end
  return contents
end

local function get_floating_window_option(width, height)
  local anchor = ''
  local row, col

  if vim.fn.winline() <= height then
    anchor = anchor..'N'
    row = 1
  else
    anchor = anchor..'S'
    row = 0
  end

  if vim.fn.wincol() + width <= vim.api.nvim_get_option('columns') then
    anchor = anchor..'W'
    col = 0
  else
    anchor = anchor..'E'
    col = 1
  end

  return {
    anchor = anchor,
    col = col,
    height = height,
    relative = 'cursor',
    row = row,
    style = 'minimal',
    width = width,
  }
end

function M.open_floating_preview(contents, filetype)
  assert(type(contents) == 'table', 'open_floating_preview(): contents must be a table')

  -- Trim empty lines from the end.
  for i = #contents, 1, -1 do
    if #contents[i] == 0 then
      table.remove(contents)
    else
      break
    end
  end

  local width = 0
  local height = #contents
  for i, line in ipairs(contents) do
    -- Clean up the input and add left pad.
    line = " "..line:gsub("\r", "")
    -- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
    local line_width = vim.fn.strdisplaywidth(line)
    width = math.max(line_width, width)
    contents[i] = line
  end
  -- Add right padding of 1 each.
  width = width + 1

  local floating_bufnr = vim.api.nvim_create_buf(false, true)
  if filetype then
    if not (type(filetype) == 'string') then
      error(("Invalid filetype for open_floating_preview: %q"):format(filetype))
    end
    vim.api.nvim_buf_set_option(floating_bufnr, 'filetype', filetype)
  end

  local float_option = get_floating_window_option(width, height)
  local floating_winnr = vim.api.nvim_open_win(floating_bufnr, true, float_option)
  if filetype == 'markdown' then
    vim.api.nvim_win_set_option(floating_winnr, 'conceallevel', 2)
  end

  vim.api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)

  -- TODO is this necessary?
  local floating_win = vim.fn.win_id2win(floating_winnr)

  vim.api.nvim_command("wincmd p")
  vim.api.nvim_command("autocmd CursorMoved <buffer> ++once :"..floating_win.."wincmd c")
end

return M
-- vim:sw=2 ts=2 et
