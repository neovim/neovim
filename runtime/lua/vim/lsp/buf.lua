local vim = vim
local validate = vim.validate
local api = vim.api
local vfn = vim.fn
local util = require 'vim.lsp.util'
local log = require 'vim.lsp.log'
local list_extend = vim.list_extend

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
      api.nvim_set_current_win(win)
      api.nvim_command("stopinsert")
      return
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
  local params = util.make_position_params()
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
  local params = util.make_position_params()
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
  local bufnr = vim.uri_to_bufnr(result.uri)
  update_tagstack()
  api.nvim_set_current_buf(bufnr)
  local row = result.range.start.line
  local col = result.range.start.character
  local line = api.nvim_buf_get_lines(0, row, row+1, true)[1]
  col = #line:sub(1, col)
  api.nvim_win_set_cursor(0, {row + 1, col})
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
  local params = util.make_position_params()
  request('textDocument/declaration', params, location_callback)
end

function M.definition()
  local params = util.make_position_params()
  request('textDocument/definition', params, location_callback)
end

function M.type_definition()
  local params = util.make_position_params()
  request('textDocument/typeDefinition', params, location_callback)
end

function M.implementation()
  local params = util.make_position_params()
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
  list_extend(contents, vim.split(signature.label, '\n', true))
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
  local params = util.make_position_params()
  focusable_preview('textDocument/signatureHelp', params, function(result)
    if not (result and result.signatures and result.signatures[1]) then
      return { 'No signature available' }
    end

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
  local params = util.make_position_params()
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

function M.formatting(options)
  validate { options = {options, 't', true} }
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = api.nvim_buf_get_option(0, 'tabstop');
    insertSpaces = api.nvim_buf_get_option(0, 'expandtab');
  })
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    options = options;
  }
  return request('textDocument/formatting', params, function(_, _, result)
    if not result then return end
    util.apply_text_edits(result)
  end)
end

function M.range_formatting(options, start_pos, end_pos)
  validate {
    options = {options, 't', true};
    start_pos = {start_pos, 't', true};
    end_pos = {end_pos, 't', true};
  }
  options = vim.tbl_extend('keep', options or {}, {
    tabSize = api.nvim_buf_get_option(0, 'tabstop');
    insertSpaces = api.nvim_buf_get_option(0, 'expandtab');
  })
  local A = list_extend({}, start_pos or api.nvim_buf_get_mark(0, '<'))
  local B = list_extend({}, end_pos or api.nvim_buf_get_mark(0, '>'))
  -- convert to 0-index
  A[1] = A[1] - 1
  B[1] = B[1] - 1
  -- account for encoding.
  if A[2] > 0 then
    A = {A[1], util.character_offset(0, unpack(A))}
  end
  if B[2] > 0 then
    B = {B[1], util.character_offset(0, unpack(B))}
  end
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(0) };
    range = {
      start = { line = A[1]; character = A[2]; };
      ["end"] = { line = B[1]; character = B[2]; };
    };
    options = options;
  }
  return request('textDocument/rangeFormatting', params, function(_, _, result)
    if not result then return end
    util.apply_text_edits(result)
  end)
end

function M.rename(new_name)
  -- TODO(ashkan) use prepareRename
  -- * result: [`Range`](#range) \| `{ range: Range, placeholder: string }` \| `null` describing the range of the string to rename and optionally a placeholder text of the string content to be renamed. If `null` is returned then it is deemed that a 'textDocument/rename' request is not valid at the given position.
  local params = util.make_position_params()
  new_name = new_name or npcall(vfn.input, "New Name: ")
  if not (new_name and #new_name > 0) then return end
  params.newName = new_name
  request('textDocument/rename', params, function(_, _, result)
    if not result then return end
    util.apply_workspace_edit(result)
  end)
end

function M.references(context)
  validate { context = { context, 't', true } }
  local params = util.make_position_params()
  params.context = context or {
    includeDeclaration = true;
  }
  params[vim.type_idx] = vim.types.dictionary
  request('textDocument/references', params, function(_, _, result)
    if not result then return end
    util.set_qflist(result)
    vim.api.nvim_command("copen")
  end)
end

return M
-- vim:sw=2 ts=2 et
