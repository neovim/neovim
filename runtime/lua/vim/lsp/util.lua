-- NOTES FROM PR:
-- Removed:
--
-- M.buf_versions = {}
-- M.diagnostics_by_buf = {}


local protocol = require 'vim.lsp.protocol'
local vim = vim
local validate = vim.validate
local api = vim.api
local list_extend = vim.list_extend
local highlight = require 'vim.highlight'

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

--- If a is nil, then return b. Else return a
function M.if_nil(a, b)
  if a == nil then return b end
  return a
end


function M.tbl_sort_by_key(fn)
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

-- TODO: Decide if worth keeping around for backwards compat
function M.apply_text_edits(text_edits, bufnr)
  return require("vim.lsp.structures").TextEdit.apply_text_edit(text_edits, bufnr)
end

--- Apply the TextDocumentEdit response.
-- @params TextDocumentEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.apply_text_document_edit(text_document_edit)
  return require("vim.lsp.structures").TextDocumentEdit.apply_text_document_edit(text_document_edit)
end

-- @params WorkspaceEdit [table] see https://microsoft.github.io/language-server-protocol/specification
function M.apply_workspace_edit(workspace_edit)
  return require("vim.lsp.structures").WorkspaceEdit.apply_workspace_edit(workspace_edit)
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

function M.get_current_line_to_cursor()
  local pos = api.nvim_win_get_cursor(0)
  local line = assert(api.nvim_buf_get_lines(0, pos[1]-1, pos[1], false)[1])
  return line:sub(pos[2]+1)
end

-- TODO: Move this to structures.Completion ?
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

-- Parse completion entries, consuming snippet tokens
function M.parse_snippet(input)
  local res, _ = parse_snippet_rec(input, false)

  return res
end

-- Sort by CompletionItem.sortText
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function sort_completion_items(items)
  if items[1] and items[1].sortText then
    table.sort(items, function(a, b) return a.sortText < b.sortText
    end)
  end
end

-- Returns text that should be inserted when selecting completion item. The precedence is as follows:
-- textEdit.newText > insertText > label
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil then
    if protocol.InsertTextFormat[item.insertTextFormat] == "PlainText" then
      return item.textEdit.newText
    else
      return M.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil then
    if protocol.InsertTextFormat[item.insertTextFormat] == "PlainText" then
      return item.insertText
    else
      return M.parse_snippet(item.insertText)
    end
  end
  return item.label
end

-- Some language servers return complementary candidates whose prefixes do not match are also returned.
-- So we exclude completion candidates whose prefix does not match.
local function remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = get_completion_word(item)
    return vim.startswith(word, prefix)
  end, items)
end

-- Acording to LSP spec, if the client set "completionItemKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
function M._get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or "Unknown"
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

--- Convert SignatureHelp response to markdown lines.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_signatureHelp
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
  if signature_help.parameters then
    local active_parameter = signature_help.activeParameter or 0
    -- If the activeParameter is not inside the valid range, then clip it.
    if active_parameter >= #signature_help.parameters then
      active_parameter = 0
    end
    local parameter = signature.parameters and signature.parameters[active_parameter]
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
        M.convert_input_help_to_markdown_lines(parameter.documentation, contents)
      end
    end
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

-- Location stuff...
-- TODO(tjdevries): Could mark as deprecated? or just delete? we haven't yet released anything, so now is the time.
function M.jump_to_location(location)
  return require("vim.lsp.structures").Location.jump(location) ~= false
end

function M.preview_location(location)
  return require("vim.lsp.structures").Location.preview(location)
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

--- Trim empty lines from input and pad left and right with spaces
---
--@param contents table of lines to trim and pad
--@param opts dictionary with optional fields
--             - pad_left   number of columns to pad contents at left (default 1)
--             - pad_right  number of columns to pad contents at right (default 1)
--             - pad_top    number of lines to pad contents at top (default 0)
--             - pad_bottom number of lines to pad contents at bottom (default 0)
--@return contents table of trimmed and padded lines
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

--- Convert markdown into syntax highlighted regions by stripping the code
--- blocks and converting them into highlighted code.
--- This will by default insert a blank line separator after those code block
--- regions to improve readability.
--- The result is shown in a floating preview
--- TODO: refactor to separate stripping/converting and make use of open_floating_preview
---
--@param contents table of lines to show in window
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
--             - separator insert separator after code block
--@return width,height size of float
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
  local insert_separator = opts.separator or true
  if insert_separator then
    for i, h in ipairs(highlights) do
      h.start = h.start + i - 1
      h.finish = h.finish + i - 1
      if h.finish + 1 <= #stripped then
        table.insert(stripped, h.finish + 1, string.rep("─", width))
        height = height + 1
      end
    end
  end

  -- Make the floating window.
  local bufnr = api.nvim_create_buf(false, true)
  local winnr = api.nvim_open_win(bufnr, false, M.make_floating_popup_options(width, height, opts))
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, stripped)

  -- Switch to the floating window to apply the syntax highlighting.
  -- This is because the syntax command doesn't accept a target.
  local cwin = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(winnr)

  vim.cmd("ownsyntax markdown")
  local idx = 1
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

function M.close_preview_autocmd(events, winnr)
  api.nvim_command("autocmd "..table.concat(events, ',').." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
end

--- Compute size of float needed to show contents (with optional wrapping)
---
--@param contents table of lines to show in window
--@param opts dictionary with optional fields
--             - height  of floating window
--             - width   of floating window
--             - wrap_at character to wrap at for computing height
--             - max_width  maximal width of floating window
--             - max_height maximal height of floating window
--@return width,height size of float
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

--- Show contents in a floating window
---
--@param contents table of lines to show in window
--@param filetype string of filetype to set for opened buffer
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
--@return bufnr,winnr buffer and window number of floating window or nil
function M.open_floating_preview(contents, filetype, opts)
  validate {
    contents = { contents, 't' };
    filetype = { filetype, 's', true };
    opts = { opts, 't', true };
  }
  opts = opts or {}

  -- Clean up input: trim empty lines from the end, pad
  contents = M._trim_and_pad(contents, opts)

  -- Compute size of float needed to show (wrapped) lines
  opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
  local width, height = M._make_floating_popup_size(contents, opts)

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
  M.close_preview_autocmd({"CursorMoved", "CursorMovedI", "BufHidden", "BufLeave"}, floating_winnr)
  return floating_bufnr, floating_winnr
end

do
  local reference_ns = api.nvim_create_namespace("vim_lsp_references")
  function M.buf_clear_diagnostics(bufnr, client_id)
    return require("vim.lsp.structures").Diagnostic.buf_clear_displayed_diagnostics(bufnr, client_id)
  end

  function M.get_severity_highlight_name(severity)
    return require("vim.lsp.structures").Diagnostic._get_severity_highlight_name(severity)
  end

  function M.get_floating_severity_highlight_name(severity)
    return require("vim.lsp.structures").Diagnostic._get_floating_severity_highlight_name(severity)
  end

  function M.get_line_diagnostics()
    local bufnr = api.nvim_get_current_buf()
    local line_nr = api.nvim_win_get_cursor(0)[1] - 1

    return require("vim.lsp.structures").Diagnostic.get_line_diagnostics(bufnr, line_nr)
  end

  function M.show_line_diagnostics()
    -- local marks = api.nvim_buf_get_extmarks(bufnr, diagnostic_ns, {line, 0}, {line, -1}, {})
    -- if #marks == 0 then
    --   return
    -- end
    local lines = {"Diagnostics:"}
    local highlights = {{0, "Bold"}}
    local line_diagnostics = M.get_line_diagnostics()
    if vim.tbl_isempty(line_diagnostics) then return end

    for i, diagnostic in ipairs(line_diagnostics) do
    -- for i, mark in ipairs(marks) do
    --   local mark_id = mark[1]
    --   local diagnostic = buffer_diagnostics[mark_id]

      -- TODO(ashkan) make format configurable?
      local prefix = string.format("%d. ", i)
      local hiname = M.get_floating_severity_highlight_name(diagnostic.severity)
      assert(hiname, 'unknown severity: ' .. tostring(diagnostic.severity))
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

  --- Saves the diagnostics (Diagnostic[]) for later user. See |vim.lsp.structures.Diagnostic|
  ---
  --@param bufnr bufnr for which the diagnostics are for.
  --@param diagnostics Diagnostics[] received from the language server.
  --@param client_id client for which the diagnostics are from.
  function M.buf_diagnostics_save_positions(bufnr, diagnostics, client_id)
    require("vim.lsp.structures").Diagnostic.save_buf_diagnostics(diagnostics, bufnr, client_id)
  end

  --- Gets the currently saved diagnostics for bufnr and client_id.
  function M.buf_diagnostics_get_positions(bufnr, client_id)
    return require("vim.lsp.structures").Diagnostic.get_buf_diagnostics(bufnr, client_id)
  end

  function M.buf_diagnostics_underline(bufnr, diagnostics, client_id)
    return require("vim.lsp.structures").Diagnostic.underline(diagnostics, bufnr, client_id)
  end

  function M.buf_diagnostics_virtual_text(bufnr, diagnostics, client_id)
    return require("vim.lsp.structures").Diagnostic.set_virtual_text(diagnostics, bufnr, client_id)
  end

  --- Returns the number of diagnostics of given kind for current buffer.
  ---
  --- Useful for showing diagnostic counts in statusline. eg:
  ---
  --- <pre>
  --- function! LspStatus() abort
  ---     let sl = ''
  ---     if luaeval('not vim.tbl_isempty(vim.lsp.buf_get_clients(0))')
  ---         let sl.='%#MyStatuslineLSP#E:'
  ---         let sl.='%#MyStatuslineLSPErrors#%{luaeval("vim.lsp.util.buf_diagnostics_count([[Error]])")}'
  ---         let sl.='%#MyStatuslineLSP# W:'
  ---         let sl.='%#MyStatuslineLSPWarnings#%{luaeval("vim.lsp.util.buf_diagnostics_count([[Warning]])")}'
  ---     else
  ---         let sl.='%#MyStatuslineLSPErrors#off'
  ---     endif
  ---     return sl
  --- endfunction
  --- let &l:statusline = '%#MyStatuslineLSP#LSP '.LspStatus()
  --- </pre>
  ---
  --@param kind Diagnostic severity kind: See |vim.lsp.protocol.DiagnosticSeverity|
  ---
  --@return Count of diagnostics
  function M.buf_diagnostics_count(kind)
    return require("vim.lsp.structures").Diagnostic.get_counts(vim.api.nvim_get_current_buf(), kind)
  end

  --- Place signs for each diagnostic in the sign column.
  ---
  --- Sign characters can be customized with the following commands:
  ---
  --- <pre>
  --- sign define LspDiagnosticsErrorSign text=E texthl=LspDiagnosticsError linehl= numhl=
  --- sign define LspDiagnosticsWarningSign text=W texthl=LspDiagnosticsWarning linehl= numhl=
  --- sign define LspDiagnosticsInformationSign text=I texthl=LspDiagnosticsInformation linehl= numhl=
  --- sign define LspDiagnosticsHintSign text=H texthl=LspDiagnosticsHint linehl= numhl=
  --- </pre>
  function M.buf_diagnostics_signs(bufnr, diagnostics, client_id)
    return require("vim.lsp.structures").Diagnostic.set_signs(diagnostics, bufnr, client_id)
  end


  -- TODO(tjdevries): need to make structures.References as well? or maybe just actions.References
  function M.buf_clear_references(bufnr)
    validate { bufnr = {bufnr, 'n', true} }
    api.nvim_buf_clear_namespace(bufnr, reference_ns, 0, -1)
  end

  function M.buf_highlight_references(bufnr, references)
    validate { bufnr = {bufnr, 'n', true} }
    local document_highlight_kind = {
      [protocol.DocumentHighlightKind.Text] = "LspReferenceText";
      [protocol.DocumentHighlightKind.Read] = "LspReferenceRead";
      [protocol.DocumentHighlightKind.Write] = "LspReferenceWrite";
    }

    for _, reference in ipairs(references) do
      local start_pos = {reference["range"]["start"]["line"], reference["range"]["start"]["character"]}
      local end_pos = {reference["range"]["end"]["line"], reference["range"]["end"]["character"]}
      local kind = reference["kind"] or protocol.DocumentHighlightKind.Text
      highlight.range(bufnr, reference_ns, document_highlight_kind[kind], start_pos, end_pos)
    end
  end
end

local position_sort = M.tbl_sort_by_key(function(v)
  return {v.start.line, v.start.character}
end)

-- Returns the items with the byte position calculated correctly and in sorted
-- order.
function M.locations_to_items(locations)
  -- This lets you pass a single location in, which is common in the LSP spec.
  if not vim.tbl_islist(locations) then
    locations = {locations}
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

-- Acording to LSP spec, if the client set "symbolKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
function M._get_symbol_kind_name(symbol_kind)
  return protocol.SymbolKind[symbol_kind] or "Unknown"
end

--- Convert symbols to quickfix list items
---
--@param symbols DocumentSymbol[] or SymbolInformation[]
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
local function make_position_param()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  col = str_utfindex(line, col)
  return { line = row; character = col; }
end

function M.make_position_params()
  return {
    textDocument = M.make_text_document_params();
    position = make_position_param()
  }
end

function M.make_range_params()
  local position = make_position_param()
  return {
    textDocument = { uri = vim.uri_from_bufnr(0) },
    range = { start = position; ["end"] = position; }
  }
end

function M.make_text_document_params()
  return { uri = vim.uri_from_bufnr(0) }
end

--- Get visual width of tabstop.
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

do
  local default = 1
  local type_str = 2
  local set_function = 3

  --- Generate a config helper for a module.
  ---
  --- Useful to handle changes to configuration gracefully and easily.
  ---
  --@param input_config_options Table of the form
  --    {
  --        k = { default_value, type_string, optional_on_set_function },
  --        ...
  --    }
  --
  --    where:
  --        `default_value` is the default value for config.k
  --        `type_string` is the string passed to |vim.validate()|
  --        `optional_on_set_function` is a function to be called when a value is set for the config.
  --            It is passed the new value.
  --
  --@returns The config table to use.
  M.generate_config = function(input_config_options, allow_unspecified_values)
    assert(input_config_options._values == nil, "_values is an invalid key")

    local config_options = vim.deepcopy(input_config_options)
    config_options._values = {}

    local config = setmetatable({}, {
      __index = function(_, k)
        if not allow_unspecified_values and config_options._values[k] == nil then
          error(string.format("Unsupported configuration option: %s", k))
        end

        return config_options._values[k]
      end,

      __newindex = function(_, k, v)
        if not allow_unspecified_values and config_options[k] == nil then
          error(string.format("Unsupported configuration option: %s", k))
        end

        -- Check types
        vim.validate{ [k] = { v, config_options[k][type_str] } }

        -- Optionally, run on_change callback
        if vim.is_callable(config_options[k][set_function]) then
          config_options[k][set_function](v)
        end

        -- Set value
        config_options._values[k] = v
      end
    })

    -- Set defaults on creation
    for k, v in pairs(input_config_options) do
      config[k] = v[default]
    end

    return config
  end
end

do
  local action_mt = {
    __call = function(t, err, method, result, client_id, bufnr)
      return t.default(err, method, result, client_id, bufnr)
    end,

    __index = function(t, k)
      if k == 'with' then
        return rawget(t, 'generator')
      end

      if k == 'default' then
        rawset(t, 'default', t.generator())
        return rawget(t, 'default')
      end

      error('Unsupported key: ', k)
    end,
  }

  --- Create generator for nicely configurable callbacks with __call semantics.
  --
  -- Useful for creating your own generator functions to be used in configurable
  -- callbacks for requests.
  M.wrap_generator = function(generator)
    vim.validate { generator = { generator, 'c' } }

    return setmetatable({
      generator = generator,
      _is_generator = true
    }, action_mt)
  end
end

return M
-- vim:sw=2 ts=2 et
