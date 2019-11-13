local protocol = require 'vim.lsp.protocol'
local validate = vim.validate
local api = vim.api

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
    return api.nvim_get_current_buf()
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
    api.nvim_buf_set_lines(bufnr, start.line, finish.line, false, new_lines)
    return
  end
  api.nvim_err_writeln('apply_text_edit currently only supports character ranges starting at 0')
  error('apply_text_edit currently only supports character ranges starting at 0')
  return
  --  TODO test and finish this support for character ranges.
--  local lines = api.nvim_buf_get_lines(0, start.line, finish.line + 1, false)
--  local suffix = lines[#lines]:sub(finish.character+2)
--  local prefix = lines[1]:sub(start.character+2)
--  new_lines[#new_lines] = new_lines[#new_lines]..suffix
--  new_lines[1] = prefix..new_lines[1]
--  api.nvim_buf_set_lines(0, start.line, finish.line, false, new_lines)
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
  local pos = api.nvim_win_get_cursor(0)
  local line = assert(api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
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
    api.nvim_command('edit '..fname)
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
  if contents[1] == '' or contents[1] == nil then
    return {}
  end
  return contents
end

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

  if vim.fn.winline() <= height then
    anchor = anchor..'N'
    row = 1
  else
    anchor = anchor..'S'
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

function M.open_floating_preview(contents, filetype, opts)
  validate {
    contents = { contents, 't' };
    filetype = { filetype, 's', true };
    opts = { opts, 't', true };
  }

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

  local floating_bufnr = api.nvim_create_buf(false, true)
  if filetype then
    api.nvim_buf_set_option(floating_bufnr, 'filetype', filetype)
  end
  local float_option = M.make_floating_popup_options(width, height, opts)
  local floating_winnr = api.nvim_open_win(floating_bufnr, false, float_option)
  if filetype == 'markdown' then
    api.nvim_win_set_option(floating_winnr, 'conceallevel', 2)
  end
  api.nvim_buf_set_lines(floating_bufnr, 0, -1, true, contents)
  api.nvim_buf_set_option(floating_bufnr, 'modifiable', false)
  api.nvim_command("autocmd CursorMoved <buffer> ++once lua pcall(vim.api.nvim_win_close, "..floating_winnr..", true)")
  return floating_bufnr, floating_winnr
end

local function validate_lsp_position(pos)
  validate { pos = {pos, 't'} }
  validate {
    line = {pos.line, 'n'};
    character = {pos.character, 'n'};
  }
  return true
end

function M.open_floating_peek_preview(bufnr, start, finish, opts)
  validate {
    bufnr = {bufnr, 'n'};
    start = {start, validate_lsp_position, 'valid start Position'};
    finish = {finish, validate_lsp_position, 'valid finish Position'};
    opts = { opts, 't', true };
  }
  local width = math.max(finish.character - start.character + 1, 1)
  local height = math.max(finish.line - start.line + 1, 1)
  local floating_winnr = api.nvim_open_win(bufnr, false, M.make_floating_popup_options(width, height, opts))
  api.nvim_win_set_cursor(floating_winnr, {start.line+1, start.character})
  api.nvim_command("autocmd CursorMoved * ++once lua pcall(vim.api.nvim_win_close, "..floating_winnr..", true)")
  return floating_winnr
end


local function highlight_range(bufnr, ns, hiname, start, finish)
  if start[1] == finish[1] then
    -- TODO care about encoding here since this is in byte index?
    api.nvim_buf_add_highlight(bufnr, ns, hiname, start[1], start[2], finish[2])
  else
    api.nvim_buf_add_highlight(bufnr, ns, hiname, start[1], start[2], -1)
    for line = start[1] + 1, finish[1] - 1 do
      api.nvim_buf_add_highlight(bufnr, ns, hiname, line, 0, -1)
    end
    api.nvim_buf_add_highlight(bufnr, ns, hiname, finish[1], 0, finish[2])
  end
end

do
  local all_buffer_diagnostics = {}

  local diagnostic_ns = api.nvim_create_namespace("vim_lsp_diagnostics")

  local default_severity_highlight = {
    [protocol.DiagnosticSeverity.Error] = { guifg = "Red" };
    [protocol.DiagnosticSeverity.Warning] = { guifg = "Orange" };
    [protocol.DiagnosticSeverity.Information] = { guifg = "LightBlue" };
    [protocol.DiagnosticSeverity.Hint] = { guifg = "LightGrey" };
  }

  local underline_highlight_name = "LspDiagnosticsUnderline"
  api.nvim_command(string.format("highlight %s gui=underline cterm=underline", underline_highlight_name))

  local function find_color_rgb(color)
    local rgb_hex = api.nvim_get_color_by_name(color)
    validate { color = {color, function() return rgb_hex ~= -1 end, "valid color name"} }
    return rgb_hex
  end

  --- Determine whether to use black or white text
  -- Ref: https://stackoverflow.com/a/1855903/837964
  -- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
  local function color_is_bright(r, g, b)
    -- Counting the perceptive luminance - human eye favors green color
    local luminance = (0.299*r + 0.587*g + 0.114*b)/255
    if luminance > 0.5 then
      return true -- Bright colors, black font
    else
      return false -- Dark colors, white font
    end
  end

  local severity_highlights = {}

  function M.set_severity_highlights(highlights)
    validate {highlights = {highlights, 't'}}
    for severity, default_color in pairs(default_severity_highlight) do
      local severity_name = protocol.DiagnosticSeverity[severity]
      local highlight_name = "LspDiagnostics"..severity_name
      local hi_info = highlights[severity] or default_color
      -- Try to fill in the foreground color with a sane default.
      if not hi_info.guifg and hi_info.guibg then
        -- TODO(ashkan) move this out when bitop is guaranteed to be included.
        local bit = require 'bit'
        local band, rshift = bit.band, bit.rshift
        local rgb = find_color_rgb(hi_info.guibg)
        local is_bright = color_is_bright(rshift(rgb, 16), band(rshift(rgb, 8), 0xFF), band(rgb, 0xFF))
        hi_info.guifg = is_bright and "Black" or "White"
      end
      if not hi_info.ctermfg and hi_info.ctermbg then
        -- TODO(ashkan) move this out when bitop is guaranteed to be included.
        local bit = require 'bit'
        local band, rshift = bit.band, bit.rshift
        local rgb = find_color_rgb(hi_info.ctermbg)
        local is_bright = color_is_bright(rshift(rgb, 16), band(rshift(rgb, 8), 0xFF), band(rgb, 0xFF))
        hi_info.ctermfg = is_bright and "Black" or "White"
      end
      local cmd_parts = {"highlight", highlight_name}
      for k, v in pairs(hi_info) do
        table.insert(cmd_parts, k.."="..v)
      end
      api.nvim_command(table.concat(cmd_parts, ' '))
      severity_highlights[severity] = highlight_name
    end
  end

  function M.buf_clear_diagnostics(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr
    api.nvim_buf_clear_namespace(bufnr, diagnostic_ns, 0, -1)
  end

  -- Initialize with the defaults.
  M.set_severity_highlights(default_severity_highlight)

  function M.get_severity_highlight_name(severity)
    return severity_highlights[severity]
  end

  function M.show_line_diagnostics()
    local bufnr = api.nvim_get_current_buf()
    local line = api.nvim_win_get_cursor(0)[1] - 1
    -- local marks = api.nvim_buf_get_extmarks(bufnr, diagnostic_ns, {line, 0}, {line, -1}, {})
    -- if #marks == 0 then
    --   return
    -- end
    -- local buffer_diagnostics = all_buffer_diagnostics[bufnr]
    local lines = {"Diagnostics:"}
    local highlights = {{0, "Bold"}}

    local buffer_diagnostics = all_buffer_diagnostics[bufnr]
    if not buffer_diagnostics then return end
    local line_diagnostics = buffer_diagnostics[line]
    if not line_diagnostics then return end

    for i, diagnostic in ipairs(line_diagnostics) do
    -- for i, mark in ipairs(marks) do
    --   local mark_id = mark[1]
    --   local diagnostic = buffer_diagnostics[mark_id]

      -- TODO(ashkan) make format configurable?
      local prefix = string.format("%d. ", i)
      local hiname = severity_highlights[diagnostic.severity]
      local message_lines = split_lines(diagnostic.message)
      table.insert(lines, prefix..message_lines[1])
      table.insert(highlights, {#prefix + 1, hiname})
      for j = 2, #message_lines do
        table.insert(lines, message_lines[j])
        table.insert(highlights, {0, hiname})
      end
    end
    local popup_bufnr, winnr = M.open_floating_preview(lines, 'plaintext')
    for i, hi in ipairs(highlights) do
      local prefixlen, hiname = unpack(hi)
      -- Start highlight after the prefix
      api.nvim_buf_add_highlight(popup_bufnr, -1, hiname, i-1, prefixlen, -1)
    end
    return popup_bufnr, winnr
  end

  function M.buf_diagnostics_save_positions(bufnr, diagnostics)
    validate {
      bufnr = {bufnr, 'n', true};
      diagnostics = {diagnostics, 't', true};
    }
    if not diagnostics then return end
    bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr

    if not all_buffer_diagnostics[bufnr] then
      -- Clean up our data when the buffer unloads.
      api.nvim_buf_attach(bufnr, false, {
        on_detach = function(b)
          all_buffer_diagnostics[b] = nil
        end
      })
    end
    all_buffer_diagnostics[bufnr] = {}
    local buffer_diagnostics = all_buffer_diagnostics[bufnr]

    for _, diagnostic in ipairs(diagnostics) do
      local start = diagnostic.range.start
      -- local mark_id = api.nvim_buf_set_extmark(bufnr, diagnostic_ns, 0, start.line, 0, {})
      -- buffer_diagnostics[mark_id] = diagnostic
      local line_diagnostics = buffer_diagnostics[start.line]
      if not line_diagnostics then
        line_diagnostics = {}
        buffer_diagnostics[start.line] = line_diagnostics
      end
      table.insert(line_diagnostics, diagnostic)
    end
  end


  function M.buf_diagnostics_underline(bufnr, diagnostics)
    for _, diagnostic in ipairs(diagnostics) do
      local start = diagnostic.range.start
      local finish = diagnostic.range["end"]

      -- TODO care about encoding here since this is in byte index?
      highlight_range(bufnr, diagnostic_ns, underline_highlight_name,
          {start.line, start.character},
          {finish.line, finish.character}
      )
    end
  end

  function M.buf_diagnostics_virtual_text(bufnr, diagnostics)
    local buffer_line_diagnostics = all_buffer_diagnostics[bufnr]
    if not buffer_line_diagnostics then
      M.buf_diagnostics_save_positions(bufnr, diagnostics)
    end
    buffer_line_diagnostics = all_buffer_diagnostics[bufnr]
    if not buffer_line_diagnostics then
      return
    end
    for line, line_diags in pairs(buffer_line_diagnostics) do
      local virt_texts = {}
      for i = 1, #line_diags - 1 do
        table.insert(virt_texts, {"■", severity_highlights[line_diags[i].severity]})
      end
      local last = line_diags[#line_diags]
      -- TODO(ashkan) use first line instead of subbing 2 spaces?
      table.insert(virt_texts, {"■ "..last.message:gsub("\r", ""):gsub("\n", "  "), severity_highlights[last.severity]})
      api.nvim_buf_set_virtual_text(bufnr, diagnostic_ns, line, virt_texts, {})
    end
  end
end

function M.buf_loclist(bufnr, locations)
  local targetwin
  for _, winnr in ipairs(api.nvim_list_wins()) do
    local winbuf = api.nvim_win_get_buf(winnr)
    if winbuf == bufnr then
      targetwin = winnr
      break
    end
  end
  if not targetwin then return end

  local items = {}
  local path = api.nvim_buf_get_name(bufnr)
  for _, d in ipairs(locations) do
    -- TODO: URL parsing here?
    local start = d.range.start
    table.insert(items, {
        filename = path,
        lnum = start.line + 1,
        col = start.character + 1,
        text = d.message,
    })
  end
  vim.fn.setloclist(targetwin, items, ' ', 'Language Server')
end

return M
-- vim:sw=2 ts=2 et
