local protocol = require 'vim.lsp.protocol'
local vim = vim
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend

local M = {}

local split = vim.split
local function split_lines(value)
  return split(value, '\n', true)
end

local function ok_or_nil(status, ...)
  if not status then return end
  return ...
end
local function npcall(fn, ...)
  return ok_or_nil(pcall(fn, ...))
end

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
local edit_sort_key = sort_by_key(function(e)
  return {e.A[1], e.A[2], e.i}
end)

function M.apply_text_edits(text_edits, bufnr)
  if not next(text_edits) then return end
  local start_line, finish_line = math.huge, -1
  local cleaned = {}
  for i, e in ipairs(text_edits) do
    start_line = math.min(e.range.start.line, start_line)
    finish_line = math.max(e.range["end"].line, finish_line)
    -- TODO(ashkan) sanity check ranges for overlap.
    table.insert(cleaned, {
      i = i;
      A = {e.range.start.line; e.range.start.character};
      B = {e.range["end"].line; e.range["end"].character};
      lines = vim.split(e.newText, '\n', true);
    })
  end

  -- Reverse sort the orders so we can apply them without interfering with
  -- eachother. Also add i as a sort key to mimic a stable sort.
  table.sort(cleaned, edit_sort_key)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  local lines = api.nvim_buf_get_lines(bufnr, start_line, finish_line + 1, false)
  local fix_eol = api.nvim_buf_get_option(bufnr, 'fixeol')
  local set_eol = fix_eol and api.nvim_buf_line_count(bufnr) <= finish_line + 1
  if set_eol and #lines[#lines] ~= 0 then
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
function M.apply_text_document_edit(text_document_edit)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)
  -- TODO(ashkan) check this is correct.
  if (M.buf_versions[bufnr] or 0) > text_document.version then
    print("Buffer ", text_document.uri, " newer than edits.")
    return
  end
  M.apply_text_edits(text_document_edit.edits, bufnr)
end

function M.get_current_line_to_cursor()
  local pos = api.nvim_win_get_cursor(0)
  local line = assert(api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
  return line:sub(pos[2]+1)
end

-- Sort by CompletionItem.sortText
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function sort_completion_items(items)
  if items[1] and items[1].sortText then
    table.sort(items, function(a, b) return a.sortText < b.sortText
    end)
  end
end

-- Some lanuguage servers return complementary candidates whose prefixes do not match are also returned.
-- So we exclude completion candidates whose prefix does not match.
local function remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = item.insertText or item.label
    return vim.startswith(word, prefix)
  end, items)
end

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
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

    local word = completion_item.insertText or completion_item.label
    table.insert(matches, {
      word = word,
      abbr = completion_item.label,
      kind = protocol.CompletionItemKind[completion_item.kind] or '',
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
    })
  end

  return matches
end

-- @params WorkspaceEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.apply_workspace_edit(workspace_edit)
  if workspace_edit.documentChanges then
    for _, change in ipairs(workspace_edit.documentChanges) do
      if change.kind then
        -- TODO(ashkan) handle CreateFile/RenameFile/DeleteFile
        error(string.format("Unsupported change: %q", vim.inspect(change)))
      else
        M.apply_text_document_edit(change)
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
  if (contents[1] == '' or contents[1] == nil) and #contents == 1 then
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

function M.jump_to_location(location)
  if location.uri == nil then return end
  -- Save position in jumplist
  vim.cmd "normal! m'"
  -- TODO(ashkan) use tagfunc here to update tagstack.
  local tag_temp_path = os.tmpname()
  local jump_word = vim.fn.expand("<cword>")
  local jump_fname = vim.uri_to_fname(location.uri)
  local jump_row = location.range.start.line
  local jump_col = location.range.start.character
  local tag_file = io.open(tag_temp_path, "w")
  local tag_file_content = string.format("%s\t%s\tcall cursor(%d, %d)",
      jump_word,
      jump_fname,
      tonumber(jump_row)+1,
      tonumber(jump_col)
  )
  tag_file:write(tag_file_content)
  tag_file:close()

  -- Store the original setting and set temporary new setting
  local ori_tag_setting = vim.api.nvim_get_option("tags")
  local ori_wildignore = vim.api.nvim_get_option("wildignore")
  vim.api.nvim_set_option("tags", tag_temp_path)
  vim.api.nvim_set_option("wildignore", "")

  -- Jump to the new location
  vim.cmd(string.format("tjump %s", jump_word))

  -- Restore the orignal setting
  vim.api.nvim_set_option("tags", ori_tag_setting)
  vim.api.nvim_set_option("wildignore", ori_wildignore)

  -- Remove the temp tag file
  os.remove(tag_temp_path)

  return true
end

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

-- Check if a window with `unique_name` tagged is associated with the current
-- buffer. If not, make a new preview.
--
-- fn()'s return bufnr, winnr
-- case that a new floating window should be created.
function M.focusable_float(unique_name, fn)
  if npcall(api.nvim_win_get_var, 0, unique_name) then
    return api.nvim_command("wincmd p")
  end
  local bufnr = api.nvim_get_current_buf()
  do
    local win = find_window_by_var(unique_name, bufnr)
    if win then
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

-- Check if a window with `unique_name` tagged is associated with the current
-- buffer. If not, make a new preview.
--
-- fn()'s return values will be passed directly to open_floating_preview in the
-- case that a new floating window should be created.
function M.focusable_preview(unique_name, fn)
  return M.focusable_float(unique_name, function()
    return M.open_floating_preview(fn())
  end)
end

-- Convert markdown into syntax highlighted regions by stripping the code
-- blocks and converting them into highlighted code.
-- This will by default insert a blank line separator after those code block
-- regions to improve readability.
function M.fancy_floating_markdown(contents, opts)
  local pad_left = opts and opts.pad_left
  local pad_right = opts and opts.pad_right
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
  local width = 0
  for i, v in ipairs(stripped) do
    v = v:gsub("\r", "")
    if pad_left then v = (" "):rep(pad_left)..v end
    if pad_right then v = v..(" "):rep(pad_right) end
    stripped[i] = v
    width = math.max(width, #v)
  end
  if opts and opts.max_width then
    width = math.min(opts.max_width, width)
  end
  -- TODO(ashkan): decide how to make this customizable.
  local insert_separator = true
  if insert_separator then
    for i, h in ipairs(highlights) do
      h.start = h.start + i - 1
      h.finish = h.finish + i - 1
      if h.finish + 1 <= #stripped then
        table.insert(stripped, h.finish + 1, string.rep("─", width))
      end
    end
  end

  -- Make the floating window.
  local height = #stripped
  local bufnr = api.nvim_create_buf(false, true)
  local winnr = api.nvim_open_win(bufnr, false, M.make_floating_popup_options(width, height, opts))
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

  -- Switch to the floating window to apply the syntax highlighting.
  -- This is because the syntax command doesn't accept a target.
  local cwin = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(winnr)

  vim.cmd("ownsyntax markdown")
  local idx = 1
  local function highlight_region(ft, start, finish)
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
    -- highlight_region('markdown', ph.finish, h.start)
    highlight_region(h.ft, h.start, h.finish)
    -- ph = h
  end

  vim.api.nvim_set_current_win(cwin)
  return bufnr, winnr
end

function M.close_preview_autocmd(events, winnr)
  api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
end

function M.open_floating_preview(contents, filetype, opts)
  validate {
    contents = { contents, 't' };
    filetype = { filetype, 's', true };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  -- Trim empty lines from the end.
  contents = M.trim_empty_lines(contents)

  local width = opts.width
  local height = opts.height or #contents
  if not width then
    width = 0
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
  end

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
  -- TODO make InsertCharPre disappearing optional?
  api.nvim_command("autocmd CursorMoved,BufHidden,InsertCharPre <buffer> ++once lua pcall(vim.api.nvim_win_close, "..floating_winnr..", true)")
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
  local reference_ns = api.nvim_create_namespace("vim_lsp_references")
  local sign_ns = 'vim_lsp_signs'
  local underline_highlight_name = "LspDiagnosticsUnderline"
  vim.cmd(string.format("highlight default %s gui=underline cterm=underline", underline_highlight_name))
  for kind, _ in pairs(protocol.DiagnosticSeverity) do
    if type(kind) == 'string' then
      vim.cmd(string.format("highlight default link %s%s %s", underline_highlight_name, kind, underline_highlight_name))
    end
  end

  local severity_highlights = {}

  local default_severity_highlight = {
    [protocol.DiagnosticSeverity.Error] = { guifg = "Red" };
    [protocol.DiagnosticSeverity.Warning] = { guifg = "Orange" };
    [protocol.DiagnosticSeverity.Information] = { guifg = "LightBlue" };
    [protocol.DiagnosticSeverity.Hint] = { guifg = "LightGrey" };
  }

  -- Initialize default severity highlights
  for severity, hi_info in pairs(default_severity_highlight) do
    local severity_name = protocol.DiagnosticSeverity[severity]
    local highlight_name = "LspDiagnostics"..severity_name
    -- Try to fill in the foreground color with a sane default.
    local cmd_parts = {"highlight", "default", highlight_name}
    for k, v in pairs(hi_info) do
      table.insert(cmd_parts, k.."="..v)
    end
    api.nvim_command(table.concat(cmd_parts, ' '))
    severity_highlights[severity] = highlight_name
  end

  function M.buf_clear_diagnostics(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr

    -- clear sign group
    vim.fn.sign_unplace(sign_ns, {buffer=bufnr})

    -- clear virtual text namespace
    api.nvim_buf_clear_namespace(bufnr, diagnostic_ns, 0, -1)
  end

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
      local start = diagnostic.range["start"]
      local finish = diagnostic.range["end"]

      local hlmap = {
        [protocol.DiagnosticSeverity.Error]='Error',
        [protocol.DiagnosticSeverity.Warning]='Warning',
        [protocol.DiagnosticSeverity.Information]='Information',
        [protocol.DiagnosticSeverity.Hint]='Hint',
      }

      -- TODO care about encoding here since this is in byte index?
      highlight_range(bufnr, diagnostic_ns,
        underline_highlight_name..hlmap[diagnostic.severity],
        {start.line, start.character},
        {finish.line, finish.character}
      )
    end
  end

  function M.buf_clear_references(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr, reference_ns, 0, -1)
  end

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
      highlight_range(bufnr, reference_ns, document_highlight_kind[reference["kind"]], start_pos, end_pos)
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
  function M.buf_diagnostics_count(kind)
    local bufnr = vim.api.nvim_get_current_buf()
    local buffer_line_diagnostics = all_buffer_diagnostics[bufnr]
    if not buffer_line_diagnostics then return end
    local count = 0
    for _, line_diags in pairs(buffer_line_diagnostics) do
      for _, diag in ipairs(line_diags) do
        if protocol.DiagnosticSeverity[kind] == diag.severity then count = count + 1 end
      end
    end
    return count
  end
  function M.buf_diagnostics_signs(bufnr, diagnostics)
    vim.fn.sign_define('LspDiagnosticsErrorSign', {text=vim.g['LspDiagnosticsErrorSign'] or 'E', texthl='LspDiagnosticsError', linehl='', numhl=''})
    vim.fn.sign_define('LspDiagnosticsWarningSign', {text=vim.g['LspDiagnosticsWarningSign'] or 'W', texthl='LspDiagnosticsWarning', linehl='', numhl=''})
    vim.fn.sign_define('LspDiagnosticsInformationSign', {text=vim.g['LspDiagnosticsInformationSign'] or 'I', texthl='LspDiagnosticsInformation', linehl='', numhl=''})
    vim.fn.sign_define('LspDiagnosticsHintSign', {text=vim.g['LspDiagnosticsHintSign'] or 'H', texthl='LspDiagnosticsHint', linehl='', numhl=''})

    for _, diagnostic in ipairs(diagnostics) do
      local diagnostic_severity_map = {
        [protocol.DiagnosticSeverity.Error] = "LspDiagnosticsErrorSign";
        [protocol.DiagnosticSeverity.Warning] = "LspDiagnosticsWarningSign";
        [protocol.DiagnosticSeverity.Information] = "LspDiagnosticsInformationSign";
        [protocol.DiagnosticSeverity.Hint] = "LspDiagnosticsHintSign";
      }
      vim.fn.sign_place(0, sign_ns, diagnostic_severity_map[diagnostic.severity], bufnr, {lnum=(diagnostic.range.start.line+1)})
    end
  end
end

local position_sort = sort_by_key(function(v)
  return {v.start.line, v.start.character}
end)

-- Returns the items with the byte position calculated correctly and in sorted
-- order.
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
    local start = d.range.start
    local fname = assert(vim.uri_to_fname(d.uri))
    table.insert(grouped[fname], {start = start})
  end


  local keys = vim.tbl_keys(grouped)
  table.sort(keys)
  -- TODO(ashkan) I wish we could do this lazily.
  for _, fname in ipairs(keys) do
    local rows = grouped[fname]

    table.sort(rows, position_sort)
    local i = 0
    for line in io.lines(fname) do
      for _, temp in ipairs(rows) do
        local pos = temp.start
        local row = pos.line
        if i == row then
          local col
          if pos.character > #line then
            col = #line
          else
            col = vim.str_byteindex(line, pos.character)
          end
          table.insert(items, {
            filename = fname,
            lnum = row + 1,
            col = col + 1;
            text = line;
          })
        end
      end
      i = i + 1
    end
  end
  return items
end

function M.set_loclist(items)
  vim.fn.setloclist(0, {}, ' ', {
    title = 'Language Server';
    items = items;
  })
end

function M.set_qflist(items)
  vim.fn.setqflist({}, ' ', {
    title = 'Language Server';
    items = items;
  })
end

--- Convert symbols to quickfix list items
---
--@symbols DocumentSymbol[] or SymbolInformation[]
function M.symbols_to_items(symbols, bufnr)
  local function _symbols_to_items(_symbols, _items, _bufnr)
    for _, symbol in ipairs(_symbols) do
      if symbol.location then -- SymbolInformation type
        local range = symbol.location.range
        local kind = protocol.SymbolKind[symbol.kind]
        table.insert(_items, {
          filename = vim.uri_to_fname(symbol.location.uri),
          lnum = range.start.line + 1,
          col = range.start.character + 1,
          kind = kind,
          text = '['..kind..'] '..symbol.name,
        })
      elseif symbol.range then -- DocumentSymbole type
        local kind = protocol.SymbolKind[symbol.kind]
        table.insert(_items, {
          -- bufnr = _bufnr,
          filename = vim.api.nvim_buf_get_name(_bufnr),
          lnum = symbol.range.start.line + 1,
          col = symbol.range.start.character + 1,
          kind = kind,
          text = '['..kind..'] '..symbol.name
        })
        if symbol.children then
          for _, child in ipairs(symbol) do
            for _, v in ipairs(_symbols_to_items(child, _items, _bufnr)) do
              vim.list_extend(_items, v)
            end
          end
        end
      end
    end
    return _items
  end
  return _symbols_to_items(symbols, {}, bufnr)
end

-- Remove empty lines from the beginning and end.
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

-- Accepts markdown lines and tries to reduce it to a filetype if it is
-- just a single code block.
-- Note: This modifies the input.
--
-- Returns: filetype or 'markdown' if it was unchanged.
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
function M.make_position_params()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  col = str_utfindex(line, col)
  return {
    textDocument = M.make_text_document_params();
    position = { line = row; character = col; }
  }
end

function M.make_text_document_params()
  return { uri = vim.uri_from_bufnr(0) }
end

-- @param buf buffer handle or 0 for current.
-- @param row 0-indexed line
-- @param col 0-indexed byte offset in line
function M.character_offset(buf, row, col)
  local line = api.nvim_buf_get_lines(buf, row, row+1, true)[1]
  -- If the col is past the EOL, use the line length.
  if col > #line then
    return str_utfindex(line)
  end
  return str_utfindex(line, col)
end

M.buf_versions = {}

return M
-- vim:sw=2 ts=2 et
