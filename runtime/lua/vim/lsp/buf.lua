local validate = vim.validate
local api = vim.api
local vfn = vim.fn
local util = require 'vim.lsp.util'
local protocol = require 'vim.lsp.protocol'
local log = require 'vim.lsp.log'

local M = {}

local function ok_or_nil(status, ...)
  if not status then return end
  return ...
end
local function npcall(fn, ...)
  return ok_or_nil(pcall(fn, ...))
end

local function err_message(...)
  api.nvim_err_writeln(table.concat(vim.tbl_flatten{...}))
  api.nvim_command("redraw")
end

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

local function request(method, params, callback)
  --  TODO(ashkan) enable this.
  --  callback = vim.lsp.default_callbacks[method] or callback
  validate {
    method = {method, 's'};
    callback = {callback, 'f'};
  }
  return vim.lsp.buf_request(0, method, params, function(err, _, result, client_id)
    local _ = log.debug() and log.debug("vim.lsp.buf", method, client_id, err, result)
    if err then error(tostring(err)) end
    return callback(err, method, result, client_id)
  end)
end

local function focusable_preview(method, params, fn)
  if npcall(api.nvim_win_get_var, 0, method) then
    return api.nvim_command("wincmd p")
  end

  local bufnr = api.nvim_get_current_buf()
  do
    local win = find_window_by_var(method, bufnr)
    if win then
      return api.nvim_set_current_win(win)
    end
  end
  return request(method, params, function(_, _, result, _)
      -- TODO(ashkan) could show error in preview...
    local lines, filetype, opts = fn(result)
    if lines then
      local _, winnr = util.open_floating_preview(lines, filetype, opts)
      api.nvim_win_set_var(winnr, method, bufnr)
    end
  end)
end

function M.hover()
  local params = protocol.make_text_document_position_params()
  focusable_preview('textDocument/hover', params, function(result)
    if not (result and result.contents) then return end

    local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
    markdown_lines = util.trim_empty_lines(markdown_lines)
    if vim.tbl_isempty(markdown_lines) then
      return { 'No information available' }
    end
    return markdown_lines, util.try_trim_markdown_code_blocks(markdown_lines)
  end)
end

function M.peek_definition()
  local params = protocol.make_text_document_position_params()
  request('textDocument/peekDefinition', params, function(_, _, result, _)
    if not (result and result[1]) then return end
    local loc = result[1]
    local bufnr = vim.uri_to_bufnr(loc.uri) or error("couldn't find file "..tostring(loc.uri))
    local start = loc.range.start
    local finish = loc.range["end"]
    util.open_floating_peek_preview(bufnr, start, finish, { offset_x = 1 })
    local headbuf = util.open_floating_preview({"Peek:"}, nil, {
      offset_y = -(finish.line - start.line);
      width = finish.character - start.character + 2;
    })
    -- TODO(ashkan) change highlight group?
    api.nvim_buf_add_highlight(headbuf, -1, 'Keyword', 0, -1)
  end)
end


local function update_tagstack()
  local bufnr = api.nvim_get_current_buf()
  local line = vfn.line('.')
  local col = vfn.col('.')
  local tagname = vfn.expand('<cWORD>')
  local item = { bufnr = bufnr, from = { bufnr, line, col, 0 }, tagname = tagname }
  local winid = vfn.win_getid()
  local tagstack = vfn.gettagstack(winid)
  local action
  if tagstack.length == tagstack.curidx then
    action = 'r'
    tagstack.items[tagstack.curidx] = item
  elseif tagstack.length > tagstack.curidx then
    action = 'r'
    if tagstack.curidx > 1 then
      tagstack.items = table.insert(tagstack.items[tagstack.curidx - 1], item)
    else
      tagstack.items = { item }
    end
  else
    action = 'a'
    tagstack.items = { item }
  end
  tagstack.curidx = tagstack.curidx + 1
  vfn.settagstack(winid, tagstack, action)
end
local function handle_location(result)
  -- We can sometimes get a list of locations, so set the first value as the
  -- only value we want to handle
  -- TODO(ashkan) was this correct^? We could use location lists.
  if result[1] ~= nil then
    result = result[1]
  end
  if result.uri == nil then
    err_message('[LSP] Could not find a valid location')
    return
  end
  local result_file = vim.uri_to_fname(result.uri)
  local bufnr = vfn.bufadd(result_file)
  update_tagstack()
  api.nvim_set_current_buf(bufnr)
  local start = result.range.start
  api.nvim_win_set_cursor(0, {start.line + 1, start.character})
  return true
end
local function location_callback(_, method, result)
  if result == nil or vim.tbl_isempty(result) then
    local _ = log.info() and log.info(method, 'No location found')
    return nil
  end
  return handle_location(result)
end

function M.declaration()
  local params = protocol.make_text_document_position_params()
  request('textDocument/declaration', params, location_callback)
end

function M.definition()
  local params = protocol.make_text_document_position_params()
  request('textDocument/definition', params, location_callback)
end

function M.type_definition()
  local params = protocol.make_text_document_position_params()
  request('textDocument/typeDefinition', params, location_callback)
end

function M.implementation()
  local params = protocol.make_text_document_position_params()
  request('textDocument/implementation', params, location_callback)
end

--- Convert SignatureHelp response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_signatureHelp
local function signature_help_to_preview_contents(input)
  if not input.signatures then
    return
  end
  --The active signature. If omitted or the value lies outside the range of
  --`signatures` the value defaults to zero or is ignored if `signatures.length
  --=== 0`. Whenever possible implementors should make an active decision about
  --the active signature and shouldn't rely on a default value.
  local contents = {}
  local active_signature = input.activeSignature or 0
  -- If the activeSignature is not inside the valid range, then clip it.
  if active_signature >= #input.signatures then
    active_signature = 0
  end
  local signature = input.signatures[active_signature + 1]
  if not signature then
    return
  end
  vim.list_extend(contents, vim.split(signature.label, '\n', true))
  if signature.documentation then
    util.convert_input_to_markdown_lines(signature.documentation, contents)
  end
  if input.parameters then
    local active_parameter = input.activeParameter or 0
    -- If the activeParameter is not inside the valid range, then clip it.
    if active_parameter >= #input.parameters then
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
        util.convert_input_to_markdown_lines(parameter.documentation, contents)
      end
    end
  end
  return contents
end

function M.signature_help()
  local params = protocol.make_text_document_position_params()
  focusable_preview('textDocument/signatureHelp', params, function(result)
    if not (result and result.signatures and result.signatures[1]) then return end

    -- TODO show empty popup when signatures is empty?
    local lines = signature_help_to_preview_contents(result)
    lines = util.trim_empty_lines(lines)
    if vim.tbl_isempty(lines) then
      return { 'No signature available' }
    end
    return lines, util.try_trim_markdown_code_blocks(lines)
  end)
end

-- TODO(ashkan) ?
function M.completion(context)
  local params = protocol.make_text_document_position_params()
  params.context = context
  return request('textDocument/completion', params, function(_, _, result)
    if vim.tbl_isempty(result or {}) then return end
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local line = assert(api.nvim_buf_get_lines(0, row-1, row, false)[1])
    local line_to_cursor = line:sub(col+1)

    local matches = util.text_document_completion_list_to_complete_items(result, line_to_cursor)
    vim.fn.complete(col, matches)
  end)
end

local function apply_edit_to_lines(lines, start_pos, end_pos, new_lines)
  -- 0-indexing to 1-indexing makes things look a bit worse.
  local i_0 = start_pos[1] + 1
  local i_n = end_pos[1] + 1
  local n = i_n - i_0 + 1
  if not lines[i_0] or not lines[i_n] then
    error(vim.inspect{#lines, i_0, i_n, n, start_pos, end_pos, new_lines})
  end
  local prefix = ""
  local suffix = lines[i_n]:sub(end_pos[2]+1)
  lines[i_n] = lines[i_n]:sub(1, end_pos[2]+1)
  if start_pos[2] > 0 then
    prefix = lines[i_0]:sub(1, start_pos[2])
    -- lines[i_0] = lines[i_0]:sub(start.character+1)
  end
  -- TODO(ashkan) figure out how to avoid copy here. likely by changing algo.
  new_lines = vim.list_extend({}, new_lines)
  if #suffix > 0 then
    new_lines[#new_lines] = new_lines[#new_lines]..suffix
  end
  if #prefix > 0 then
    new_lines[1] = prefix..new_lines[1]
  end
  if #new_lines >= n then
    for i = 1, n do
      lines[i + i_0 - 1] = new_lines[i]
    end
    for i = n+1,#new_lines do
      table.insert(lines, i_n + 1, new_lines[i])
    end
  else
    for i = 1, #new_lines do
      lines[i + i_0 - 1] = new_lines[i]
    end
    for _ = #new_lines+1, n do
      table.remove(lines, i_0 + #new_lines + 1)
    end
  end
end

local function apply_text_edits(text_edits, bufnr)
  if not next(text_edits) then return end
  -- nvim.print("Start", #text_edits)
  local start_line, finish_line = math.huge, -1
  local cleaned = {}
  for _, e in ipairs(text_edits) do
    start_line = math.min(e.range.start.line, start_line)
    finish_line = math.max(e.range["end"].line, finish_line)
    table.insert(cleaned, {
      A = {e.range.start.line; e.range.start.character};
      B = {e.range["end"].line; e.range["end"].character};
      lines = vim.split(e.newText, '\n', true);
    })
  end
  local lines = api.nvim_buf_get_lines(bufnr, start_line, finish_line + 1, false)
  for i, e in ipairs(cleaned) do
    -- nvim.print(i, "e", e.A, e.B, #e.lines[#e.lines], e.lines)
    local y = 0
    local x = 0
    -- TODO(ashkan) this could be done in O(n) with dynamic programming
    for j = 1, i-1 do
      local o = cleaned[j]
      -- nvim.print(i, "o", o.A, o.B, x, y, #o.lines[#o.lines], o.lines)
      if o.A[1] <= e.A[1] and o.A[2] <= e.A[2] then
        y = y - (o.B[1] - o.A[1] + 1) + #o.lines
        -- Same line
        if #o.lines > 1 then
          x = -e.A[2] + #o.lines[#o.lines]
        else
          if o.A[1] == e.A[1] then
            -- Try to account for insertions.
            -- TODO how to account for deletions?
            x = x - (o.B[2] - o.A[2]) + #o.lines[#o.lines]
          end
        end
      end
    end
    local A = {e.A[1] + y - start_line, e.A[2] + x}
    local B = {e.B[1] + y - start_line, e.B[2] + x}
    -- if x ~= 0 or y ~= 0 then
    --   nvim.print(i, "_", e.A, e.B, y, x, A, B, e.lines)
    -- end
    apply_edit_to_lines(lines, A, B, e.lines)
  end
  api.nvim_buf_set_lines(bufnr, start_line, finish_line + 1, false, lines)
end

function M.formatting(options)
  validate { options = {options, 't', true} }
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    options = options or {};
  }
  params.options[vim.type_idx] = vim.types.dictionary
  return request('textDocument/formatting', params, function(_, _, result)
    if not result then return end
    apply_text_edits(result)
  end)
end

function M.range_formatting(options, start_pos, end_pos)
  validate {
    options = {options, 't', true};
    start_pos = {start_pos, 't', true};
    end_pos = {end_pos, 't', true};
  }
  start_pos = start_pos or vim.api.nvim_buf_get_mark(0, '<')
  end_pos = end_pos or vim.api.nvim_buf_get_mark(0, '>')
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    range = {
      start = { line = start_pos[1]; character = start_pos[2]; };
      ["end"] = { line = end_pos[1]; character = end_pos[2]; };
    };
    options = options or {};
  }
  params.options[vim.type_idx] = vim.types.dictionary
  return request('textDocument/rangeFormatting', params, function(_, _, result)
    if not result then return end
    apply_text_edits(result)
  end)
end

function M.rename(new_name)
  -- TODO(ashkan) use prepareRename
  -- * result: [`Range`](#range) \| `{ range: Range, placeholder: string }` \| `null` describing the range of the string to rename and optionally a placeholder text of the string content to be renamed. If `null` is returned then it is deemed that a 'textDocument/rename' request is not valid at the given position.
  local params = protocol.make_text_document_position_params()
  new_name = new_name or npcall(vfn.input, "New Name: ")
  if not (new_name and #new_name > 0) then return end
  params.newName = new_name
  request('textDocument/rename', params, function(_, _, result)
    if not result then return end
    util.apply_workspace_edit(result)
  end)
end

return M
-- vim:sw=2 ts=2 et
