local api, vfn = vim.api, vim.fn
local log = require('vim.lsp.log')
local snippet = require('vim.lsp._snippet_grammar')
local protocol = require('vim.lsp.protocol')
local util = require('vim.lsp.util')
local ms = protocol.Methods

local cmp_data = {}
local match_fuzzy = false

local function buf_data_init(bufnr)
  cmp_data[bufnr] = {
    incomplete = {},
    omni_pending = false,
  }
end

--- Parses snippets in a completion entry.
---
---@param input string unparsed snippet
---@return string parsed snippet
local function parse_snippet(input)
  local ok, parsed = pcall(function()
    return tostring(snippet.parse(input))
  end)
  if not ok then
    return input
  end
  return parsed
end

--- According to LSP spec, if the client set `completionItemKind.valueSet`,
--- the client must handle it properly even if it receives a value outside the
--- specification.
---
---@param completion_item_kind (`vim.lsp.protocol.completionItemKind`)
---@return (`vim.lsp.protocol.completionItemKind`)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or 'Unknown'
end

local function charidx_without_comp(bufnr, pos)
  if pos.character <= 0 then
    return pos.character
  end
  local text = api.nvim_buf_get_lines(bufnr, pos.line, pos.line + 1, false)[1]
  if #text == 0 then
    return pos.character
  end
  local idx = vfn.byteidxcomp(text, pos.character)
  if idx ~= -1 then
    if idx == #text then
      return vfn.strcharlen(text)
    else
      return vfn.charidx(text, idx, false)
    end
  end
  return pos.character
end

local function completion_handler(err, result, ctx)
  if err then
    log.warn(err.message)
  end

  local client = vim.lsp.get_clients({ id = ctx.client_id })
  if not result or not client or not api.nvim_buf_is_valid(ctx.bufnr) then
    return
  end

  local entrys = {}

  local compitems
  if vim.tbl_islist(result) then
    compitems = result
  else
    compitems = result.items
    cmp_data[ctx.bufnr].incomplete[ctx.client_id] = result.isIncomplete or false
  end

  local col = vfn.charcol('.')
  local line = api.nvim_get_current_line()
  local before_text = col == 1 and '' or line:sub(1, col - 1)
  local win = api.nvim_get_current_win()
  local pos = api.nvim_win_get_cursor(win)
  local _ = log.trace() and log.trace('omnifunc.line', pos, line)

  -- Get the start position of the current keyword
  local ok, retval = pcall(vfn.matchstrpos, before_text, '\\k*$')
  if not ok or not #retval == 0 then
    return
  end
  local prefix, start_idx = unpack(retval)
  local startcol = start_idx + 1
  prefix = prefix:lower()

  for _, item in ipairs(compitems) do
    local entry = {
      abbr = item.label,
      kind = get_completion_item_kind_name(item.kind),
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = item,
          },
        },
      },
    }

    local textEdit = vim.tbl_get(item, 'textEdit')
    if textEdit then
      local start_col = #prefix ~= 0 and vfn.charidx(before_text, start_idx) + 1 or col
      local range = {}
      if textEdit.range then
        range = textEdit.range
      elseif textEdit.insert then
        range = textEdit.insert
      end
      local te_startcol = charidx_without_comp(ctx.bufnr, range.start)
      if te_startcol ~= start_col then
        local offset = start_col - te_startcol - 1
        entry.word = textEdit.newText:sub(offset)
      else
        entry.word = textEdit.newText
      end
    elseif vim.tbl_get(item, 'insertText') then
      entry.word = item.insertText
    else
      entry.word = item.label
    end

    local register = true
    if vim.lsp.protocol.InsertTextFormat[item.insertTextFormat] == 'snippet' then
      entry.word = parse_snippet(item.textEdit.newText)
    elseif not client.completeItemsIsIncomplete then
      if #prefix ~= 0 then
        local filter = item.filterText or entry.word
        if
          filter and (match_fuzzy and #vfn.matchfuzzy({ filter }, prefix) == 0)
          or (not vim.startswith(filter:lower(), prefix) or not vim.startswith(filter, prefix))
        then
          register = false
        end
      end
    end

    if register then
      if item.detail and #item.detail > 0 then
        entry.menu = vim.split(item.detail, '\n', { trimempty = true })[1]
      end

      if item.documentation and #item.documentation > 0 then
        entry.info = item.info
      end

      entry.sortText = item.sortText or item.label
      entrys[#entrys + 1] = entry
    end
  end

  table.sort(entrys, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)

  if not cmp_data[ctx.bufnr].omni_pending then
    local mode = api.nvim_get_mode()['mode']
    if mode == 'i' or mode == 'ic' then
      vfn.complete(startcol, entrys)
    end
    return
  end

  cmp_data[ctx.bufnr].omni_pending = false
  cmp_data[ctx.bufnr].compitems = vim.list_extend(cmp_data[ctx.bufnr].compitems or {}, entrys)
end

local function completion_request(client, bufnr, trigger_kind, trigger_char)
  local params = util.make_position_params(api.nvim_get_current_win(), client.offset_encoding)
  params.context = {
    triggerKind = trigger_kind,
    triggerCharacter = trigger_char,
  }
  client.request(ms.textDocument_completion, params, completion_handler, bufnr)
end

--- |complete-items|.
---
---@see |complete-functions|
---@see |complete-items|
---@see |CompleteDone|
---
---@param findstart integer 0 or 1, decides behavior
---@param base integer findstart=0, text to match against
---
---@return integer|table Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
local function omnifunc(findstart, base)
  if log.debug() then
    log.debug('omnifunc.findstart', { findstart = findstart, base = base })
  end
  local curbuf = api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = curbuf, method = ms.textDocument_completion })

  if not cmp_data[curbuf] then
    buf_data_init(curbuf)
  end

  if findstart then
    cmp_data[curbuf].omni_pending = true
    for _, client in ipairs(clients) do
      completion_request(client, curbuf, 1, '')
    end

    local line = api.nvim_get_current_line()
    local win = vim.api.nvim_get_current_win()
    local pos = api.nvim_win_get_cursor(win)
    local before_text = vfn.strpart(line, 0, pos[2])
    local prefix = vfn.matchstr(before_text, '\\k\\+$')
    cmp_data[curbuf]['cmp_prefix'] = prefix
    return before_text:len() - prefix:len()
  end

  local count = 0
  while cmp_data[curbuf].omni_pending and count < 1000 do
    if vfn.complete_check() then
      return -2
    end
    vim.uv.sleep(200)
    count = count + 1
  end

  if cmp_data[curbuf].omni_pending then
    return -2
  end

  local compitems = {}
  local incomplete = false
  for _, v in pairs(cmp_data[curbuf]['incomplete']) do
    if v then
      incomplete = true
    end
  end

  if #cmp_data[curbuf]['cmp_prefix'] == 0 or incomplete then
    return compitems
  end

  return vim.tbl_filter(function(item)
    return vim.startwith(item, cmp_data[curbuf]['cmp_prefix'])
  end, compitems)
end

local function complete_ondone(bufnr)
  api.nvim_create_autocmd('CompleteDone', {
    group = api.nvim_create_augroup('lsp_auto_complete', { clear = false }),
    buffer = bufnr,
    callback = function()
      local textedits = vim.tbl_get(
        vim.v.completed_item,
        'user_data',
        'nvim',
        'lsp',
        'completion_item',
        'additionalTextEdits'
      )
      if textedits then
        vim.lsp.util.apply_text_edits(textedits, bufnr)
      end
    end,
  })
end

local function auto_complete(client, bufnr, fuzzy)
  match_fuzzy = fuzzy or false

  api.nvim_set_option_value('completeopt', 'menuone,noinsert,noselect', { scope = 'global' })
  api.nvim_create_autocmd('TextChangedI', {
    group = api.nvim_create_augroup('lsp_auto_complete', { clear = false }),
    buffer = bufnr,
    callback = function(args)
      if
        not vim.lsp.get_clients({
          bufnr = args.buf,
          method = ms.textDocument_completion,
          id = client.id,
        })
      then
        return
      end

      local col = vfn.charcol('.')
      local line = api.nvim_get_current_line()
      if col == 0 or #line == 0 then
        return
      end

      local triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked
      local triggerChar = ''

      local ok, val = pcall(api.nvim_eval, ([['%s' !~ '\k']]):format(line:sub(col - 1, col - 1)))
      if not ok then
        return
      end

      if val ~= 0 then
        local triggerCharacters = client.server_capabilities.completionProvider.triggerCharacters
          or {}
        if not vim.tbl_contains(triggerCharacters, line:sub(col - 1, col - 1)) then
          return
        end
        triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter
        triggerChar = line:sub(col - 1, col - 1)
      end

      if not cmp_data[args.buf] then
        buf_data_init(args.buf)
      end

      completion_request(client, args.buf, triggerKind, triggerChar)
    end,
  })
  complete_ondone()
end

return {
  omnifunc = omnifunc,
  auto_complete = auto_complete,
  completion_handler = completion_handler,
}
